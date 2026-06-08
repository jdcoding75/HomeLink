// PingManager.swift
// Pointward › Managers

import Foundation
import Combine
import os

@MainActor
final class PingManager: ObservableObject {

    private let log = Logger(subsystem: "com.jdcoding75.pointward", category: "pings")

    /// Legacy single-slot ping (still mirrored to the widget store).
    @Published var pendingPing: ReceivedPing?
    @Published var isSending   = false
    /// "Mum felt your thought ✓" — set when a sent ping gets opened remotely.
    @Published var feltNotice: String?
    /// "couldn't send — check your connection" — a real send failed after
    /// retries. The animation already played; the user must know the
    /// thought did NOT travel.
    @Published var sendFailedNotice: String?
    /// "Mum is pointing toward you 🧭" — their compass just locked onto us.
    /// (Toast retired — the ambient presence glow replaced it. Kept.)
    @Published var pointingNotice: String?

    /// Ambient presence: the partner's needle is resting on us. The compass
    /// edge glows faintly from their direction — no badge, no alert, no text.
    @Published var partnerPointingAt: Date?
    @Published var partnerPointingName: String = "someone"

    // ── Thought queue ────────────────────────────────────────────────────
    /// Received thoughts waiting to be watched. Max 10; oldest drops off.
    @Published private(set) var queue: [ReceivedPing] = [] {
        didSet {
            queueCount  = queue.count + (nowPlaying == nil ? 0 : 1)
            unreadCount = queueCount
            persistQueue()
        }
    }
    /// The thought currently playing its arrival animation, if any.
    @Published var nowPlaying: ReceivedPing? {
        didSet {
            queueCount  = queue.count + (nowPlaying == nil ? 0 : 1)
            unreadCount = queueCount
        }
    }
    /// Unread thoughts (waiting + the one being caught) — drives the badge.
    @Published var queueCount: Int = 0
    /// QUEUE NOTIFICATION RULE: only the FIRST unread announces itself —
    /// arrivals while this is > 0 slip in silently (badge only). Resets
    /// to 0 automatically when the user catches up (queue drains).
    @Published private(set) var unreadCount: Int = 0

    static let maxQueued = 50

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
        /// [5/5] Optional short message (≤30 chars) the sender attached.
        var message: String? = nil
    }

    init(networkService: NetworkServiceProtocol, appState: AppStateManager? = nil) {
        self.networkService = networkService
        self.appState = appState
        restoreQueue()   // waiting thoughts survive an app relaunch
    }

    // ── Queue persistence — unread thoughts survive relaunches ──────────

    private struct PersistedPing: Codable {
        let fromName: String
        let emoji: String
        let timestamp: Date
        let remoteID: UUID?
        let senderStyle: String?
        var message: String? = nil
    }

    private func persistQueue() {
        let stored = queue.map {
            PersistedPing(fromName: $0.fromName, emoji: $0.emoji,
                          timestamp: $0.timestamp, remoteID: $0.remoteID,
                          senderStyle: $0.senderStyle, message: $0.message)
        }
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: "pendingThoughtQueue")
        }
    }

    private func restoreQueue() {
        guard let data = UserDefaults.standard.data(forKey: "pendingThoughtQueue"),
              let stored = try? JSONDecoder().decode([PersistedPing].self, from: data),
              !stored.isEmpty else { return }
        log.info("queue: restored \(stored.count) waiting thought(s) from last session")
        queue = stored.map {
            ReceivedPing(fromName: $0.fromName, emoji: $0.emoji,
                         timestamp: $0.timestamp, remoteID: $0.remoteID,
                         senderStyle: $0.senderStyle, message: $0.message)
        }
    }

    // ── Offline catch queue — thoughts that arrived while we were away ──
    //
    // Realtime and pushes both miss when the app is offline; the pings are
    // safe in Supabase. On every foreground/reconnect we sweep for unread
    // ones we've never SEEN: the newest becomes the catch, the rest stay in
    // History (they're already there server-side). No error states — quiet
    // either way.

    /// Ping ids that ever entered the local queue — so offline sweeps never
    /// re-trigger a catch for something already offered. Capped at 50. [3/6]
    private var seenPingIDs: [String] {
        get { UserDefaults.standard.stringArray(forKey: "seenPingIDs") ?? [] }
        set { UserDefaults.standard.set(Array(newValue.suffix(50)), forKey: "seenPingIDs") }
    }

    private func rememberSeen(_ id: UUID?) {
        guard let id else { return }
        var seen = seenPingIDs
        guard !seen.contains(id.uuidString) else { return }
        seen.append(id.uuidString)
        seenPingIDs = seen
    }

    /// Sweep one partner's pings for unread thoughts that never reached
    /// this device. `resolveName` maps the partner id to their card name.
    func syncMissedThoughts(partnerID: UUID, partnerName: String) async {
        let records = await SupabaseService.shared.fetchPings(with: partnerID)
        let me = SupabaseService.localUserID
        let seen = Set(seenPingIDs)
        // Unread, addressed to me, never seen here — oldest…newest
        let missed = records
            .filter { record in
                record.openedAt == nil
                    && record.toUser.uuidString == me?.uuidString
                    && !seen.contains(record.id.uuidString)
            }
            .sorted { $0.createdAt < $1.createdAt }
        guard !missed.isEmpty else { return }
        log.info("offline-sync: \(missed.count) missed thought(s) from \(partnerName, privacy: .public)")

        // All are remembered as seen; only the NEWEST goes through the
        // queue → catch. Older ones rest in History (already server-side).
        for record in missed { rememberSeen(record.id) }
        if let newest = missed.last {
            receivePing(fromName: partnerName, emoji: newest.emoji,
                        remoteID: newest.id, senderStyle: newest.senderStyle,
                        message: newest.message)
        }
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

    /// THE real send. Fires the Supabase insert (with its own retry layer)
    /// and — critically — surfaces failure instead of swallowing it: the
    /// flight animation plays optimistically, but if the insert never lands
    /// the user is told their thought did not travel.
    func sendRemote(to userID: UUID, emoji: String, style: SenderStyle, message: String? = nil) {
        log.info("sendRemote: → \(userID.uuidString, privacy: .public) emoji=\(emoji, privacy: .public) style=\(style.rawValue, privacy: .public) msg=\(message != nil, privacy: .public)")
        Task {
            do {
                try await SupabaseService.shared.sendPing(to: userID, emoji: emoji, style: style, message: message)
                log.info("sendRemote: delivered ✓")
            } catch {
                log.error("sendRemote: FAILED — \(error.localizedDescription, privacy: .public)")
                sendFailedNotice = "couldn't send — check your connection"
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                sendFailedNotice = nil
            }
        }
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
        // [2/6] Ambient presence is always on now — no setting gate.
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
                     senderStyle: String? = nil, message: String? = nil) {
        log.info("receivePing: from=\(fromName, privacy: .public) emoji=\(emoji, privacy: .public) remoteID=\(remoteID?.uuidString ?? "nil", privacy: .public) style=\(senderStyle ?? "nil", privacy: .public)")

        // DEDUPE: in the foreground the same thought arrives twice — once
        // over realtime (with remoteID) and once as the APNs push (without).
        // Same id, or same emoji+sender within 15 s → one catch, not two.
        let isDuplicate = ([nowPlaying].compactMap { $0 } + queue).contains { existing in
            if let id = remoteID, existing.remoteID == id { return true }
            return existing.emoji == emoji
                && existing.fromName == fromName
                && Date.now.timeIntervalSince(existing.timestamp) < 15
        }
        if isDuplicate {
            log.info("receivePing: duplicate (realtime + push) — ignored")
            return
        }

        // QUEUE NOTIFICATION RULE: only the FIRST unread thought announces
        // itself. While one is already waiting, newcomers slip in silently —
        // no haptic, no fanfare; the badge count is the only change.
        let isFirstUnread = unreadCount == 0

        let ping = ReceivedPing(fromName: fromName, emoji: emoji, timestamp: .now,
                                remoteID: remoteID, senderStyle: senderStyle,
                                message: message)
        // MULTI-SENDER QUEUE: an active catch is NEVER interrupted, and
        // waiting thoughts are ALL kept — each with its own sender name and
        // style, so every later catch and replay is correctly attributed.
        // Oldest drops past 10 (it lives in History server-side anyway).
        var updated = queue
        updated.append(ping)
        if updated.count > Self.maxQueued {
            updated.removeFirst(updated.count - Self.maxQueued)
        }
        queue = updated
        rememberSeen(remoteID)
        AppGroupStore.pendingPingEmoji     = emoji
        AppGroupStore.pendingPingFromName  = fromName
        AppGroupStore.pendingPingTimestamp = .now
        if isFirstUnread && appState?.currentState != .sending {
            HapticEngine.thoughtArrived()   // soft directional pull, not an alert
        } else {
            log.info("receivePing: arrived silently (badge only) — first unread already waiting, or a send is in progress")
        }

        // A catch already on screen finishes its moment; anything else
        // waits on the badge and plays when the user taps for it.
        if nowPlaying == nil && queue.count == 1 {
            // [2/5] SIMULTANEOUS SEND/RECEIVE — never let an arriving thought
            // interrupt a send in progress. While sending, it sits in the
            // queue (badge only); the catch fires the instant the send
            // completes (the screen returns to idle and the queue drains).
            if appState?.currentState == .sending {
                log.info("receivePing: send in progress — queued, catch will play when the send completes")
                appState?.queueAnimation { [weak self] in self?.playNext() }
            } else {
                playNext()
            }
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
            log.info("markOpened: id=\(remoteID.uuidString, privacy: .public)")
            Task { await SupabaseService.shared.markPingOpened(remoteID) }
        } else {
            // Push-delivered pings used to arrive without an id — the felt
            // receipt was silently lost. The push payload now carries pingId.
            log.warning("markOpened: no remoteID — felt receipt cannot be recorded")
        }
    }

    /// Ambient presence arrived — their needle is resting on us.
    /// `bearing` is THEIR reported absolute bearing (toward us), when the
    /// event carried one — feeds the mutual-pointing check.
    func presenceFelt(name: String, bearing: Double? = nil) {
        // [2/6] Ambient presence is ALWAYS ON now (the Settings toggle is gone).
        // We always update state here so the mutual-pointing check keeps a fresh
        // bearing + timestamp; the once-per-person-per-day throttle on the
        // VISIBLE glow lives at the glow-activation site in CompassView.
        partnerPointingName = name
        partnerPointingAt = .now
        partnerPointingBearing = bearing
    }

    // ── Replay, app-wide ─────────────────────────────────────────────────
    /// Set from any tab; RootView presents the full-screen replay overlay.
    struct ReplayRequest: Identifiable, Equatable {
        let id = UUID()
        let emoji: String
        let bearingDegrees: Double
        let styleRaw: String?
        var fromName: String = ""
    }
    @Published var replayRequest: ReplayRequest?

    func requestReplay(emoji: String, bearingDegrees: Double, styleRaw: String?,
                       fromName: String = "") {
        log.info("replay: requested — \(emoji, privacy: .public) bearing=\(Int(bearingDegrees), privacy: .public)°")
        replayRequest = ReplayRequest(emoji: emoji, bearingDegrees: bearingDegrees,
                                      styleRaw: styleRaw, fromName: fromName)
    }

    // ── Felt receipts, live ──────────────────────────────────────────────
    /// Bumped whenever one of OUR sent pings gets opened — history views
    /// listening to this refetch and flip their dot to "felt".
    @Published var lastFeltAt: Date?

    // ── Mutual pointing — the most magical moment ────────────────────────
    /// Their last reported absolute bearing (toward us), from realtime/push.
    @Published var partnerPointingBearing: Double?
    /// Set when BOTH needles rest on each other within 15° — golden moment.
    @Published var mutualMoment: Date?
    private var lastMutualMoment: Date = .distantPast

    /// Called with OUR absolute bearing toward them + our alignment error
    /// whenever either side's pointing state changes. Requires their
    /// pointing report to be fresh (within 90 s) so the moment is genuinely
    /// simultaneous. Throttled to once per 5 minutes.
    func checkMutualPointing(myAbsoluteBearing: Double, myAlignmentError: Double) {
        guard myAlignmentError <= 15,
              let theirBearing = partnerPointingBearing,
              let theirStamp = partnerPointingAt,
              Date.now.timeIntervalSince(theirStamp) < 90,
              Date.now.timeIntervalSince(lastMutualMoment) > 300   // once per 5 min
        else { return }
        // Their bearing should be (roughly) the reciprocal of ours
        let reciprocal = (myAbsoluteBearing + 180).truncatingRemainder(dividingBy: 360)
        let diff = BearingCalculator.alignmentError(relativeBearing: theirBearing - reciprocal)
        guard diff <= 15 else {
            log.debug("mutual: not reciprocal (their=\(Int(theirBearing), privacy: .public)° vs expected=\(Int(reciprocal), privacy: .public)°, off \(Int(diff), privacy: .public)°)")
            return
        }
        lastMutualMoment = .now
        log.info("mutual: ✦ BOTH POINTING — golden moment (off by \(Int(diff), privacy: .public)°)")
        mutualMoment = .now
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            mutualMoment = nil
        }
    }

    /// Called when an arrival animation completes. Waiting thoughts do NOT
    /// auto-play — the badge shows the count and the user taps to catch the
    /// next when ready. (previous: auto-advance after 2 s — retired)
    func finishedPlaying(_ ping: ReceivedPing) {
        guard nowPlaying?.id == ping.id else { return }
        nowPlaying = nil
        AppGroupStore.clearPendingPing()
        if !queue.isEmpty {
            log.info("queue: \(self.queue.count) thought(s) waiting — badge shows, user taps to catch")
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

// ── Message rules — the optional ≤30-char note that rides a thought ───────
// Pure + testable, so the same clamping/normalizing runs in the compose UI
// (CompassView) and the send path (SupabaseService.sendPing).
enum MessageRules {
    static let maxLength = 30

    /// Trim a message to the maximum length (the compose field uses this).
    static func clamped(_ message: String) -> String {
        String(message.prefix(maxLength))
    }

    /// Normalize for sending: an empty/whitespace-only message becomes nil so
    /// it's omitted from the payload entirely; otherwise it's clamped.
    static func normalized(_ message: String?) -> String? {
        guard let message else { return nil }
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : clamped(trimmed)
    }
}
