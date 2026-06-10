// AudioRecorder.swift
// Pointward › Utilities
//
// "Create your own" thoughts:
//   • CustomThought / CustomThoughtStore — up to five user-created thoughts,
//     each an emoji + optional name + a sound (own recording OR a preset
//     voice from SoundEngine). Index and recordings persist in the
//     documents directory across launches.
//   • AudioRecorder — records up to 3 seconds to a temp .m4a via
//     AVAudioRecorder, with live metering for the waveform display.

import Foundation
import AVFoundation
import AudioToolbox
import Combine

// MARK: - Custom thoughts

struct CustomThought: Codable, Equatable, Identifiable {
    enum SoundKind: Codable, Equatable {
        case recording          // audio file named custom-<id>.m4a
        case preset(String)     // a SoundEngine emoji token, e.g. "💜"
        case system(UInt32)     // an Apple system sound id (curated list)
    }

    var id    = UUID()
    var emoji: String
    var name:  String?
    var sound: SoundKind
}

// MARK: - Apple system sounds (curated)

/// The warm, pleasant corner of Apple's system sound library — notification
/// tones, gentle alerts, soft UI sounds. No alarms, nothing harsh.
enum SystemSoundLibrary {
    struct Entry: Identifiable {
        let id: UInt32          // SystemSoundID
        let name: String
        let category: String
    }

    static let curated: [Entry] = [
        // Notification tones — the classic gentle ones
        Entry(id: 1003, name: "tri-tone",  category: "notification"),
        Entry(id: 1321, name: "bloom",     category: "notification"),
        Entry(id: 1322, name: "calypso",   category: "notification"),
        Entry(id: 1331, name: "spell",     category: "notification"),
        // Alert tones — warm and melodic
        Entry(id: 1325, name: "fanfare",   category: "alert"),
        Entry(id: 1326, name: "ladder",    category: "alert"),
        Entry(id: 1327, name: "minuet",    category: "alert"),
        Entry(id: 1330, name: "sherwood",  category: "alert"),
        Entry(id: 1334, name: "tiptoes",   category: "alert"),
        Entry(id: 1336, name: "update",    category: "alert"),
        // UI sounds — small and soft
        Entry(id: 1001, name: "swoosh",    category: "ui"),
        Entry(id: 1016, name: "tweet",     category: "ui"),
    ]

    static func play(_ id: UInt32) {
        AudioServicesPlaySystemSound(SystemSoundID(id))
    }
}

/// Up to five user-created thoughts, persisted as JSON in the documents
/// directory (alongside their .m4a recordings).
final class CustomThoughtStore: ObservableObject {

    /// One store everywhere — ProSetupView and the send screen share it.
    static let shared = CustomThoughtStore()


    static let maxCount = 5

    @Published private(set) var thoughts: [CustomThought] = []

    private var player: AVAudioPlayer?

    private static var docs: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    private static var indexURL: URL { docs.appendingPathComponent("custom-thoughts.json") }

    static func soundURL(for id: UUID) -> URL {
        docs.appendingPathComponent("custom-\(id.uuidString).m4a")
    }

    init() { load() }

    var isFull: Bool { thoughts.count >= Self.maxCount }

    func thought(id: UUID) -> CustomThought? {
        thoughts.first { $0.id == id }
    }

    func add(_ thought: CustomThought) {
        guard !isFull else { return }
        thoughts.append(thought)
        persist()
    }

    func update(_ thought: CustomThought) {
        guard let index = thoughts.firstIndex(where: { $0.id == thought.id }) else { return }
        thoughts[index] = thought
        persist()
    }

    func remove(id: UUID) {
        thoughts.removeAll { $0.id == id }
        try? FileManager.default.removeItem(at: Self.soundURL(for: id))
        persist()
    }

    /// Play a thought's sound — the user's recording, its preset voice,
    /// or its Apple system sound.
    func play(_ thought: CustomThought) {
        switch thought.sound {
        case .preset(let token):
            SoundEngine.shared.play(for: token)
        case .system(let soundID):
            SystemSoundLibrary.play(soundID)
        case .recording:
            player = try? AVAudioPlayer(contentsOf: Self.soundURL(for: thought.id))
            player?.volume = 1.0   // quiet mode retired
            player?.play()
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(thoughts) {
            try? data.write(to: Self.indexURL)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: Self.indexURL),
              let decoded = try? JSONDecoder().decode([CustomThought].self, from: data)
        else { return }
        // Drop any recording-thoughts whose audio file has vanished
        thoughts = decoded.filter { thought in
            if case .recording = thought.sound {
                return FileManager.default.fileExists(
                    atPath: Self.soundURL(for: thought.id).path)
            }
            return true
        }
    }
}

// MARK: - Recorder

/// Records a single take (max 3 s) to a temp file; the creation sheet
/// previews it and saves it into a CustomThought.
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

        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            // Timer fires on the main run loop. [weak self] breaks the
            // self → meterTimer → closure → self retain cycle, so an in-flight
            // meter timer never pins the recorder alive after the view is gone.
            MainActor.assumeIsolated {
                guard let self, let rec = self.recorder, rec.isRecording else { return }
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
        hasRecording = flag && FileManager.default.fileExists(atPath: tempURL.path)
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

    /// Copies the temp take to a permanent location. Stops a still-running
    /// recording first and verifies the file actually landed — the previous
    /// version could silently fail when tapped mid-recording.
    @discardableResult
    func saveTake(to destination: URL) -> Bool {
        if isRecording {
            recorder?.stop()
            isRecording = false
        }
        guard FileManager.default.fileExists(atPath: tempURL.path) else { return false }
        try? FileManager.default.removeItem(at: destination)
        do {
            try FileManager.default.copyItem(at: tempURL, to: destination)
            return FileManager.default.fileExists(atPath: destination.path)
        } catch {
            return false
        }
    }
}
