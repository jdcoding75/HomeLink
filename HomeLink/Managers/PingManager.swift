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

    /// State machine — wired by ServiceContainer. Catch mode and the
    /// caught-confirmation queueing rules flow through here.
    private weak var appState: AppStateManager?

    /// SENDER CAUGHT — the recipient caught our thought. The emoji we sent
    /// reappears briefly at the compass center. No text, no timestamp.
    struct CaughtMoment: Equatable {
        let emoji: String
        let at:    Date
    }
    @Published var caughtMoment: CaughtMoment?

    struct ReceivedPing: Equatable, Identifiable {
        let id = UUID()
        let fromName:  String
        let emoji:     String
        let timestamp: Date
        var remoteID:  UUID? = nil      // Supabase ping id, for read receipts
        /// sender_style from the wire — the SENDER's animation personality.
        /// nil (pre-migration rows) falls back to glow at the call site.
        var senderStyle: String? = nil
    }

    init(networkService: NetworkServiceProtocol, appState: AppStateManager? = nil) {
        self.networkService = networkService
        self.appState = appState
    }

    func sendPing(to person: Person, emoji: String) async {
        isSending = true
        defer { isSending = false }
        let pairedID = person.pairedUserID ?? "local-stub"
        // The real Supabase insert (SupabaseService.sendPing) carries
        // sender_style = SenderStyle.effectiveForCurrentUser; this legacy
        // mock path stays style-less.
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

    /// They caught it. A warm symbolic moment on the sender's compass —
    /// the emoji we sent, briefly, then gone. Never interrupts sending
    /// (or any other moment): it queues and plays when the screen is free.
    func showCaught(emoji: String) {
        let show: () -> Void = { [weak self] in
            guard let self else { return }
            self.caughtMoment = CaughtMoment(emoji: emoji, at: .now)
            Task {
                try? await Task.sleep(nanoseconds: 900_000_000)   // 600 ms + fade
                self.caughtMoment = nil
            }
        }
        if let appState, appState.currentState != .idle {
            appState.queueAnimation(show)
        } else {
            show()
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

    /// New thought arrives → catch mode. RULE: only the NEWEST incoming
    /// thought triggers the catch — anything older slips quietly into
    /// History (it's already persisted server-side in the pings table).
    func receivePing(fromName: String, emoji: String, remoteID: UUID? = nil,
                     senderStyle: String? = nil) {
        let ping = ReceivedPing(fromName: fromName, emoji: emoji, timestamp: .now,
                                remoteID: remoteID, senderStyle: senderStyle)
        // The queue holds at most the newest un-caught thought — an older
        // waiting one is superseded (→ History, never lost).
        queue = [ping]
        AppGroupStore.pendingPingEmoji     = emoji
        AppGroupStore.pendingPingFromName  = fromName
        AppGroupStore.pendingPingTimestamp = .now
        HapticEngine.thoughtArrived()   // soft directional pull, not an alert

        // A catch already on screen finishes its moment; the newest waits
        // its turn and starts the instant the screen frees up.
        if nowPlaying == nil {
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
