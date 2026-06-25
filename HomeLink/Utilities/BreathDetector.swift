// BreathDetector.swift
// Pointward › Utilities
//
// THE BREATH — the wind instrument's release. Monitors the microphone for
// a slow steady exhale: smooth sustained level above an ambient threshold
// for 1.5–2 seconds, with spikes rejected (speech is jagged; breath is a
// long soft hill).
//
// Privacy: audio never leaves the device, nothing is recorded — only an
// RMS level per buffer, discarded immediately. When mic permission is
// denied the wind instrument degrades to hold-to-send.

import Foundation
import AVFoundation
import Combine

@MainActor
final class BreathDetector: ObservableObject {

    /// Mic granted and the tap is running.
    @Published private(set) var isListening = false
    /// Permission denied → caller should use the hold fallback.
    @Published private(set) var micDenied = false
    /// 0…1 toward a completed exhale — drives the gathering visuals.
    @Published private(set) var exhaleProgress: Double = 0
    /// 0…1 live, smoothed mic level — drives the "listening" arc in real
    /// time so the instrument visibly brightens with each breath. Unlike
    /// exhaleProgress (which counts toward a confirmed exhale), this is the
    /// instantaneous loudness, eased so it never flickers.
    @Published private(set) var level: Double = 0

    /// Fires once per detected exhale.
    var onExhale: (() -> Void)?

    private let engine = AVAudioEngine()
    private var sustainedSeconds: Double = 0
    private var previousDb: Float = -120
    // [anti-ambient 2026-06-20] Exhale-SHAPE gate. A real breath RISES from quiet;
    // a constant in-band room tone does not. `armed` is set only when the level
    // dips below the band (genuine quiet), and a sustained breath only counts while
    // armed. Firing DISARMS it, so the detector won't re-fire until a NEW quiet→
    // rise onset — this both rejects steady ambient AND single-shots the detector
    // (no immediate re-fire after a send). Starts false: a quiet moment arms it.
    private var armed = false
    /// Rolling window of the last RMS readings → a steady level (spec: 10).
    private var levelWindow: [Float] = []
    private let windowSize = 10

    // [3/7] Tuning — MUCH more sensitive. A breath is a soft hill above
    // ambient silence; the old thresholds were so strict real breathing barely
    // registered. Lowered the whole band and the required hold.
    private let silenceDb: Float  = -40   // below this → silence (was -50)
    // [anti-ambient 2026-06-20] Floor LIFTED above typical room ambient so a steady
    // room tone can no longer sit inside the breath band. Device-tunable — start
    // conservative; Joshua to dial in. (regression-fix for Item C / 393b31c.)
    private let breathLowDb: Float = -30  // breath detected from here (was -38 → self-fired on ambient; orig -45)
    private let breathHighDb: Float = -12 // breath band ceiling (was -25)
    private let speechDb: Float   = -6    // above this → shouting/noise, ignore
    private let spikeJumpDb: Float = 16    // a sharp jump = tap onset (was 12)
    // [anti-ambient 2026-06-20] Sustain RAISED back up (toward the original 1.6 s)
    // so a momentary in-band blip doesn't count — a real exhale is a long hill.
    private let requiredSeconds   = 1.04   // [wind-polish] ×0.8 (was 1.3) — less sustained breath effort to trigger; device-tunable. (earlier: 0.8 too twitchy; orig 1.6)
    // Live-arc normalization: map silence → full breath onto 0…1.
    private let arcFloorDb: Float   = -42  // very dim lavender
    private let arcCeilingDb: Float = -16  // full glow

    func start() {
        guard !isListening else { return }
        requestPermission { [weak self] granted in
            guard let self else { return }
            if granted {
                self.micDenied = false
                self.beginListening()
            } else {
                self.micDenied = true
            }
        }
    }

    func stop() {
        guard isListening else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isListening = false
        sustainedSeconds = 0
        exhaleProgress = 0
        level = 0
        levelWindow.removeAll()
        armed = false            // [anti-ambient] restart disarmed — a quiet moment re-arms
        // Hand the session back to ambient playback (SoundEngine's world)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
    }

    // ── Internals ─────────────────────────────────────────────────────────

    private func requestPermission(_ completion: @escaping (Bool) -> Void) {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        }
    }

    private func beginListening() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playAndRecord, options: [.mixWithOthers, .defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)

            let input  = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            // ~0.046 s per buffer at 44.1 kHz
            input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
                self?.process(buffer)
            }
            try engine.start()
            isListening = true
        } catch {
            micDenied = true   // engine failures degrade like a denial
        }
    }

    private nonisolated func process(_ buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData?[0] else { return }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return }
        var sum: Float = 0
        for i in 0..<frames { sum += data[i] * data[i] }
        let rms = sqrt(sum / Float(frames))
        let dt  = Double(frames) / buffer.format.sampleRate

        Task { @MainActor [weak self] in
            self?.evaluate(level: rms, dt: dt)
        }
    }

    private func evaluate(level rms: Float, dt: Double) {
        // Rolling average (10 samples) → a steady level, then to dB.
        levelWindow.append(rms)
        if levelWindow.count > windowSize { levelWindow.removeFirst() }
        let smoothed = levelWindow.reduce(0, +) / Float(levelWindow.count)
        let db = 20 * log10(max(smoothed, 1e-7))   // -inf guard

        defer { previousDb = db }

        // Live arc — map silence…full breath onto 0…1, eased so it glides.
        let normalized = Double((db - arcFloorDb) / (arcCeilingDb - arcFloorDb))
        let target = min(1, max(0, normalized))
        level += (target - level) * 0.35

        // A sharp jump is a tap or speech onset — a breath rises gradually.
        let jumped = abs(db - previousDb) > spikeJumpDb
        // In the breath band, below speech, with a gentle onset.
        let inBreathBand = db >= breathLowDb && db <= breathHighDb
        let isSpeech     = db > speechDb

        // [anti-ambient 2026-06-20] SHAPE GATE + single-shot. PRIOR (looped on
        // ambient — any sustained in-band level fired, then re-armed instantly):
        //   if inBreathBand && !isSpeech && !jumped {
        //       sustainedSeconds += dt
        //       exhaleProgress = min(1, sustainedSeconds / requiredSeconds)
        //       if sustainedSeconds >= requiredSeconds {
        //           sustainedSeconds = 0
        //           exhaleProgress = 0
        //           onExhale?()
        //       }
        //   } else {
        //       sustainedSeconds = max(0, sustainedSeconds - dt * 2)
        //       exhaleProgress = min(1, sustainedSeconds / requiredSeconds)
        //   }
        if db < breathLowDb {
            // Below the band = genuine quiet → ARM: the next rise into the band is
            // a real exhale onset. A steady in-band ambient level never reaches
            // here, so it can never arm (and never fires).
            armed = true
            sustainedSeconds = max(0, sustainedSeconds - dt * 2)
        } else if inBreathBand && !isSpeech && !jumped && armed {
            // A real exhale that rose from quiet — count the sustained hill.
            sustainedSeconds += dt
            if sustainedSeconds >= requiredSeconds {
                sustainedSeconds = 0
                armed = false            // single-shot: a NEW quiet→rise onset is required
                exhaleProgress = 0
                onExhale?()
                return                   // (defer updates previousDb)
            }
        } else {
            // Speech, a spike, above-band, or in-band WITHOUT a fresh onset
            // (constant ambient) — decay rather than hard-reset.
            sustainedSeconds = max(0, sustainedSeconds - dt * 2)
        }
        exhaleProgress = min(1, sustainedSeconds / requiredSeconds)
    }
}
