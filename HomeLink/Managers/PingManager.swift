// PingManager.swift
// Pointward › Managers

import Foundation
import Combine

@MainActor
final class PingManager: ObservableObject {

    /// Legacy single-slot ping (still mirrored to the widget store).
    @Published var pendingPing: ReceivedPing?
    @Published var isSending   = false
    /// "Mum felt your thought ✓" — set when a sent ping gets opened remotely.
    @Published var feltNotice: String?
    /// "Mum is pointing toward you 🧭" — their compass just locked onto us.
    /// (Toast retired — the ambient presence glow replaced it. Kept.)
    @Published var pointingNotice: String?

    /// Ambient presence: the partner's needle is resting on us. The compass
    /// edge glows faintly from their direction — no badge, no alert, no text.
    @Published var partnerPointingAt: Date?
    @Published var partnerPointingName: String = "someone"

    // ── Thought queue ────────────────────────────────────────────────────
    /// Received thoughts waiting to be watched. Max 10; oldest drops off.
    @Published private(set) var queue: [ReceivedPing] = []
    /// The thought currently playing its arrival animation, if any.
    @Published var nowPlaying: ReceivedPing?

    static let maxQueued = 10

    private let networkService: NetworkServiceProtocol

    struct ReceivedPing: Equatable, Identifiable {
        let id = UUID()
        let fromName:  String
        let emoji:     String
        let timestamp: Date
        var remoteID:  UUID? = nil   // Supabase ping id, for read receipts
    }

    init(networkService: NetworkServiceProtocol) {
        self.networkService = networkService
    }

    func sendPing(to person: Person, emoji: String) async {
        isSending = true
        defer { isSending = false }
        let pairedID = person.pairedUserID ?? "local-stub"
        try? await networkService.sendPing(toPairedUserID: pairedID, emoji: emoji)
        HapticEngine.pingSent()
    }

    func showFelt(name: String) {
        feltNotice = "\(name) felt your thought ✓"
        Task {
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            feltNotice = nil
        }
    }

    /// Gentle "they're pointing at you" moment — soft double haptic, 4s toast.
    func showPointing(name: String) {
        guard UserDefaults.standard.object(forKey: "notifyPointing") as? Bool ?? true else { return }
        pointingNotice = "\(name) is pointing toward you"
        HapticEngine.pingReceived()
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            pointingNotice = nil
        }
    }

    /// New thought arrives → joins the queue. Core mode starts the
    /// direction-reveal immediately (the compass IS the inbox); Expressive
    /// mode shows the badge and waits for the tap.
    func receivePing(fromName: String, emoji: String, remoteID: UUID? = nil) {
        let ping = ReceivedPing(fromName: fromName, emoji: emoji, timestamp: .now, remoteID: remoteID)
        queue.append(ping)
        if queue.count > Self.maxQueued {
            queue.removeFirst(queue.count - Self.maxQueued)   // oldest drops off
        }
        AppGroupStore.pendingPingEmoji     = emoji
        AppGroupStore.pendingPingFromName  = fromName
        AppGroupStore.pendingPingTimestamp = .now
        HapticEngine.thoughtArrived()   // soft directional pull, not an alert

        if !ExpressionMode.isOn && nowPlaying == nil {
            playNext()
        }
    }

    /// Start (or skip to) the next queued thought.
    /// opened_at is set at the moment of REVEAL (markOpened), not here —
    /// "felt" means felt, not delivered.
    func playNext() {
        guard !queue.isEmpty else {
            nowPlaying = nil
            return
        }
        nowPlaying = queue.removeFirst()
    }

    /// The thought was actually experienced — bloom played, sound heard.
    func markOpened(_ ping: ReceivedPing) {
        if let remoteID = ping.remoteID {
            Task { await SupabaseService.shared.markPingOpened(remoteID) }
        }
    }

    /// Ambient presence arrived — their needle is resting on us.
    func presenceFelt(name: String) {
        guard UserDefaults.standard.object(forKey: "notifyPointing") as? Bool ?? true else { return }
        partnerPointingName = name
        partnerPointingAt = .now
    }

    /// Called when an arrival animation completes — auto-advances to the
    /// next thought after 2 seconds (tap skips ahead immediately).
    func finishedPlaying(_ ping: ReceivedPing) {
        guard nowPlaying?.id == ping.id else { return }
        nowPlaying = nil
        AppGroupStore.clearPendingPing()
        guard !queue.isEmpty else { return }
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if nowPlaying == nil { playNext() }
        }
    }

    /// Tap-to-skip: jump straight to the next thought, no 2-second gap.
    func skip(_ ping: ReceivedPing) {
        guard nowPlaying?.id == ping.id else { return }
        nowPlaying = nil
        AppGroupStore.clearPendingPing()
        playNext()
    }

    func clearPendingPing() {
        pendingPing = nil
        AppGroupStore.clearPendingPing()
    }
}
