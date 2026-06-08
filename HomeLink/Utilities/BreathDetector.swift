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
    private var previousLevel: Float = 0
    /// Rolling window of the last RMS readings → a steady level (spec: 10).
    private var levelWindow: [Float] = []
    private let windowSize = 10

    // Tuning — breath against a quiet room
    private let levelThreshold: Float  = 0.022   // above ambient hiss
    private let spikeJump: Float       = 0.10    // sharp = speech, reject
    private let requiredSeconds        = 1.6     // within the 1.5–2 s window
    // Live-arc normalization: breath sits roughly in this RMS band. We map
    // it to 0…1 so the arc reaches full glow on a strong steady exhale.
    private let levelFloor: Float      = 0.012   // below → silent (dim)
    private let levelCeiling: Float    = 0.090   // at/above → full glow

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
        defer { previousLevel = rms }

        // Rolling average (10 samples) → a steady live level for the arc.
        levelWindow.append(rms)
        if levelWindow.count > windowSize { levelWindow.removeFirst() }
        let smoothed = levelWindow.reduce(0, +) / Float(levelWindow.count)
        let normalized = Double((smoothed - levelFloor) / (levelCeiling - levelFloor))
        let target = min(1, max(0, normalized))
        // Ease toward the target so the arc glides rather than jitters.
        level += (target - level) * 0.35

        // A sharp jump is speech or a bump — breath rises gently
        let jumped = abs(rms - previousLevel) > spikeJump

        if rms > levelThreshold && !jumped {
            sustainedSeconds += dt
            exhaleProgress = min(1, sustainedSeconds / requiredSeconds)
            if sustainedSeconds >= requiredSeconds {
                sustainedSeconds = 0
                exhaleProgress = 0
                onExhale?()
            }
        } else {
            // The breath broke — ease back rather than hard reset
            sustainedSeconds = max(0, sustainedSeconds - dt * 2)
            exhaleProgress = min(1, sustainedSeconds / requiredSeconds)
        }
    }
}
