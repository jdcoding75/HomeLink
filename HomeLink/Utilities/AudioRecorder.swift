// AudioRecorder.swift
// Pointward › Utilities
//
// Personal sound recording for "send a thought":
//   • AudioRecorder — records up to 3 seconds to a temp .m4a via
//     AVAudioRecorder, with live metering for the waveform display.
//   • CustomSoundStore — persists up to two saved recordings (documents
//     directory) plus the emoji each one wears; survives app launches.

import Foundation
import AVFoundation
import Combine

// MARK: - Custom sound slots

struct CustomSound: Codable, Equatable {
    var emoji: String
    var fileName: String
}

/// Up to two user-recorded sounds. Files live in the documents directory as
/// custom-sound-<slot>.m4a; slot metadata (emoji + file name) in UserDefaults.
final class CustomSoundStore: ObservableObject {

    @Published private(set) var slots: [CustomSound?] = [nil, nil]

    private var player: AVAudioPlayer?
    private static let defaultsKey = "customSounds"

    init() { load() }

    static func url(forSlot slot: Int) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("custom-sound-\(slot).m4a")
    }

    func sound(at slot: Int) -> CustomSound? {
        guard slots.indices.contains(slot) else { return nil }
        return slots[slot]
    }

    func save(emoji: String, slot: Int) {
        guard slots.indices.contains(slot) else { return }
        slots[slot] = CustomSound(emoji: emoji, fileName: "custom-sound-\(slot).m4a")
        persist()
    }

    /// Plays the slot's saved recording (used during the send animation).
    func play(slot: Int) {
        guard sound(at: slot) != nil else { return }
        player = try? AVAudioPlayer(contentsOf: Self.url(forSlot: slot))
        player?.volume = UserDefaults.standard.bool(forKey: "quietMode") ? 0.4 : 1.0
        player?.play()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(slots) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
              let decoded = try? JSONDecoder().decode([CustomSound?].self, from: data),
              decoded.count == 2 else { return }
        // Only trust slots whose audio file actually exists
        slots = decoded.enumerated().map { idx, sound in
            guard sound != nil,
                  FileManager.default.fileExists(atPath: Self.url(forSlot: idx).path)
            else { return nil }
            return sound
        }
    }
}

// MARK: - Recorder

/// Records a single take (max 3 s) to a temp file; the recording sheet
/// previews it and saves it into a CustomSoundStore slot.
final class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {

    @Published var isRecording  = false
    @Published var hasRecording = false
    @Published var elapsed: Double = 0
    @Published var levels: [CGFloat] = []   // rolling waveform while recording

    let maxDuration: TimeInterval = 3.0
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("thought-take.m4a")

    private var recorder: AVAudioRecorder?
    private var preview: AVAudioPlayer?
    private var meterTimer: Timer?

    /// Ask for mic permission (system prompt on first use), then record.
    func beginRecording() {
        Task { @MainActor in
            guard await AVAudioApplication.requestRecordPermission() else { return }
            startRecording()
        }
    }

    private func startRecording() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, options: [.defaultToSpeaker])
        try? session.setActive(true)

        try? FileManager.default.removeItem(at: tempURL)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        guard let rec = try? AVAudioRecorder(url: tempURL, settings: settings) else { return }
        rec.delegate = self
        rec.isMeteringEnabled = true
        recorder     = rec
        levels       = []
        elapsed      = 0
        hasRecording = false
        isRecording  = rec.record(forDuration: maxDuration)   // auto-stops at 3 s

        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            // Timer fires on the main run loop
            MainActor.assumeIsolated {
                guard let rec = self.recorder, rec.isRecording else { return }
                rec.updateMeters()
                let power = rec.averagePower(forChannel: 0)        // −160…0 dB
                let norm  = max(0, min(1, (power + 50) / 50))      // usable window
                self.levels.append(CGFloat(norm))
                if self.levels.count > 28 { self.levels.removeFirst() }
                self.elapsed = rec.currentTime
            }
        }
    }

    func stopRecording() {
        recorder?.stop()   // delegate finishes up
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        meterTimer?.invalidate()
        meterTimer   = nil
        isRecording  = false
        hasRecording = flag
        // Hand the session back to playback-friendly ambient
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
    }

    func playPreview() {
        preview = try? AVAudioPlayer(contentsOf: tempURL)
        preview?.play()
    }

    func discardTake() {
        recorder?.stop()
        meterTimer?.invalidate()
        meterTimer   = nil
        isRecording  = false
        hasRecording = false
        levels       = []
        elapsed      = 0
    }

    /// Copies the temp take into the slot's permanent file. True on success.
    @discardableResult
    func saveTake(toSlot slot: Int) -> Bool {
        let dest = CustomSoundStore.url(forSlot: slot)
        try? FileManager.default.removeItem(at: dest)
        return (try? FileManager.default.copyItem(at: tempURL, to: dest)) != nil
    }
}
