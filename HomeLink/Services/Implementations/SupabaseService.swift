// SupabaseService.swift
// Pointward › Services › Implementations
//
// Phase 2 backend bridge — Supabase client plus the three capabilities the
// roadmap needs: Apple Sign In auth, sending a ping to another user, and
// receiving pings over a realtime subscription.
//
// SAFE BY DEFAULT: until SupabaseConfig has real credentials, `client` is
// nil and every call throws/returns early — Phase 1 offline behavior is
// completely untouched. Nothing constructs this service yet; it's wired up
// when Phase 2 UI lands.

import Foundation
import Combine
import Supabase
import os

// [concurrency 2026-06-13] PostgREST's PostgrestResponse isn't marked Sendable
// upstream, so every `.execute()` result that flows through withRetry's
// `T: Sendable` constraint warns "type 'PostgrestResponse<Void>' does not conform
// to the 'Sendable' protocol" (a Swift 6 error). We only ever read these response
// values (and usually discard them), so an @unchecked Sendable conformance is
// safe. Marked @retroactive since the type lives in another module.
extension PostgrestResponse: @retroactive @unchecked Sendable {}

enum SupabaseServiceError: LocalizedError, Equatable {
    case notConfigured
    case notSignedIn
    // [9b · B3] invalidCodeFormat / codeNotFound / cannotPairWithSelf / codeAlreadyClaimed
    // removed — only the deleted redeem/lookupInvite threw them.
    case networkProblem
    case timedOut

    var errorDescription: String? {
        switch self {
        case .notConfigured:      return "The backend isn't configured yet."
        case .notSignedIn:        return "Sign in to send pings."
        case .networkProblem:     return "Network problem — check your connection and try again."
        case .timedOut:           return "That took too long — check your connection and try again."
        }
    }
}

final class SupabaseService: ObservableObject {

    static let shared = SupabaseService()

    /// Console logging for the pairing/ping flows — filter on
    /// subsystem com.jdcoding75.pointward in Console.app.
    let log = Logger(subsystem: "com.jdcoding75.pointward", category: "supabase")

    /// nil until SupabaseConfig is filled in — every API below guards on it.
    private(set) lazy var client: SupabaseClient? = {
        guard SupabaseConfig.isConfigured,
              let url = URL(string: SupabaseConfig.url) else { return nil }
        return SupabaseClient(supabaseURL: url, supabaseKey: SupabaseConfig.anonKey)
    }()

    /// One consolidated realtime channel for everything (pings in, felt
    /// receipts, pointing) — opened on foreground, closed on background.
    private var realtimeChannel: RealtimeChannelV2?

    // MARK: - Resilience (timeout · retry · friendly errors)

    /// Hard timeout so a dead connection fails fast instead of hanging a
    /// spinner forever — the URLSession default (60 s) is far too long for
    /// an interactive pairing/sending moment.
    private func withTimeout<T: Sendable>(
        _ seconds: Double = 12,
        _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw SupabaseServiceError.timedOut
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    /// Retry transient (network/timeout) failures once after a short pause,
    /// then surface a human-readable error. Non-transient errors (RLS,
    /// schema, bad input) throw immediately — retrying won't fix those.
    // [concurrency 2026-06-13] @discardableResult — many call sites run a write
    // (.execute() → PostgrestResponse<Void>) purely for effect and ignore the
    // result; without this, each is a "result of call to withRetry is unused"
    // warning (a Swift 6 error). Callers that DO need the value still get it.
    @discardableResult
    func withRetry<T: Sendable>(
        attempts: Int = 2,
        label: String,
        _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        var lastError: Error = SupabaseServiceError.networkProblem
        for attempt in 1...attempts {
            do {
                return try await withTimeout { try await operation() }
            } catch {
                lastError = error
                guard Self.isTransient(error), attempt < attempts else { break }
                log.warning("\(label, privacy: .public): transient failure (attempt \(attempt)/\(attempts)) — retrying: \(error.localizedDescription, privacy: .public)")
                try? await Task.sleep(nanoseconds: 800_000_000)
            }
        }
        log.error("\(label, privacy: .public): FAILED — \(String(describing: lastError), privacy: .public)")
        throw Self.friendly(lastError)
    }

    private static func isTransient(_ error: Error) -> Bool {
        if error is URLError { return true }
        if let serviceError = error as? SupabaseServiceError {
            return serviceError == .timedOut || serviceError == .networkProblem
        }
        return (error as NSError).domain == NSURLErrorDomain
    }

    /// Map low-level transport errors to a human message; pass ours through.
    static func friendly(_ error: Error) -> Error {
        if let serviceError = error as? SupabaseServiceError { return serviceError }
        if isTransient(error) { return SupabaseServiceError.networkProblem }
        return error
    }

    // MARK: - Auth (Apple Sign In)


    #if DEBUG
    // ── [5/5] Developer test-data tools — DEBUG ONLY, never ships ──────────

    /// Wipe every trace of this user from the backend, then sign out so the
    /// app returns to onboarding — clean testing without reinstalling.
    func clearAllMyData() async throws {
        guard let client else { throw SupabaseServiceError.notConfigured }
        guard let me = await currentUserID else { throw SupabaseServiceError.notConfigured }
        let id = me.uuidString
        log.info("DEV: clearing ALL data for \(id.prefix(8), privacy: .public)…")
        try await client.from("device_tokens").delete().eq("user_id", value: id).execute()
        try await client.from("pings").delete()
            .or("from_user.eq.\(id),to_user.eq.\(id)").execute()
        // [pairing-retire step8] connections-table delete REMOVED — the pairing `connections`
        // table was dropped server-side; this call would now error. (link_connections is a
        // SEPARATE table, untouched.)
        try await client.from("compass_bearings").delete().eq("user_id", value: id).execute()
        try await client.from("users").delete().eq("id", value: id).execute()
        Self.localUserID = nil
        try await client.auth.signOut()
        log.info("DEV: cleared all data and signed out ✓")
    }

    // [pairing-retire step8] clearConnectionsOnly() HARD-DELETED — a DEV-only pairing-test
    // helper (zero callers) that deleted from the now-dropped `connections` table. Pairing
    // is fully retired; nothing re-tests it.
    #endif

    /// [1/4] Mirror YOUR profile into public.users — best-effort, so it no-ops
    /// silently on databases that haven't added the profile columns yet. Split
    /// into homogeneous updates to avoid a heterogeneous-JSON dependency.

    // [phase2] Read-only decode of OUR own public.users row — just the
    // short_code for now. nonisolated Decodable (pure data) → no main-actor
    // Encodable warning; Decodable-only so it can never write.
    private nonisolated struct SelfProfileRow: Decodable {
        let shortCode: String?
        enum CodingKeys: String, CodingKey { case shortCode = "short_code" }
    }

    /// [phase2] Fetch OUR own `short_code` from public.users. Read-only, no UI
    /// surfacing yet (Build 3+ wires it). Returns nil — degrading gracefully —
    /// when signed out, unconfigured, or the column doesn't exist yet (the
    /// short_code migration hasn't been applied). Does NOT touch the send/pairing
    /// paths and does NOT read message rows.
    func fetchMyShortCode() async -> String? {
        guard let client, let me = await currentUserID else { return nil }
        do {
            let rows: [SelfProfileRow] = try await client
                .from("users")
                .select("short_code")
                .eq("id", value: me.uuidString)
                .limit(1)
                .execute().value
            return rows.first?.shortCode
        } catch {
            log.warning("profile: short_code read skipped (column missing?) — \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// The signed-in user's id, or nil when signed out / unconfigured.


    // [pairing-retire step6] connectedFriendID static var HARD-DELETED — the pairing-era
    // "cached partner" was set only by the (deleted) refreshConnection readers and read
    // only by vestigial plumbing (RootView partner, the now-gone PeopleListView presence).
    // The LINK connection state lives per-Person on senderID; there is no global partner.

    // [pairing-retire step7] localPairingCode cache HARD-DELETED — it was written only by
    // myPairingCode (deleted) and cleared on signout (also removed). The "pairingCode"
    // UserDefaults key stays in DevTools.userDataDefaultsKeys so a legacy stored value is
    // still wiped on reset.


    // MARK: - Pairing  [pairing-retire step7 — FULLY RETIRED, code-only; table = step 8]
    // The entire pairing-code subsystem is HARD-DELETED (all uncalled in app code since
    // step 2): ConnectionRow (the `connections`-row model), myPairingCode() (mint),
    // generatePairingCode() / normalizePairingCode() / isValidPairingCode() (the POINT-XXXX
    // code helpers), and DiscoveredConnection/refreshConnection(s) (removed in steps 5-6).
    // The `connections` TABLE itself is left for step 8 (server SQL) — it is referenced
    // ONLY by the DEV clear utilities (clearAllMyData / clearConnectionsOnly), which no-op
    // cleanly until the table is dropped. The LINK mechanism (link_connections / senderID /
    // short_code) is the connection model and is untouched.


    // MARK: - Pings

    /// Insert shape for the `pings` table. senderStyle is optional so the
    /// nil (legacy) payload omits the key entirely — sends keep working on
    /// a database that hasn't run the sender_style migration yet.
    struct PingPayload: Codable {
        let fromUser: UUID
        let toUser: UUID
        let emoji: String
        var senderStyle: String? = nil
        var message: String? = nil          // [5/5] optional ≤30-char note
        var tagline: String? = nil          // sender's per-person tagline

        enum CodingKeys: String, CodingKey {
            case fromUser    = "from_user"
            case toUser      = "to_user"
            case emoji
            case senderStyle = "sender_style"
            case message
            case tagline
        }
    }

    /// Realtime event shape (decoded with a plain JSONDecoder — dates as strings).
    struct PingEvent: Codable {
        let id: UUID?
        let fromUser: UUID
        let toUser: UUID
        let emoji: String
        let openedAt: String?
        /// glow | shootingStar | firefly — nil on rows from before the migration.
        let senderStyle: String?
        let message: String?          // [5/5] optional note
        let tagline: String?          // sender's per-person tagline

        enum CodingKeys: String, CodingKey {
            case id
            case fromUser    = "from_user"
            case toUser      = "to_user"
            case emoji
            case openedAt    = "opened_at"
            case senderStyle = "sender_style"
            case message
            case tagline
        }
    }

    /// Full row for ping history (decoded by PostgREST's date-aware decoder).
    struct PingRecord: Codable, Identifiable {
        let id: UUID
        let fromUser: UUID
        let toUser: UUID
        let emoji: String
        let createdAt: Date
        let openedAt: Date?
        /// glow | shootingStar | firefly — nil on rows from before the migration.
        let senderStyle: String?
        let message: String?          // [5/5] optional note
        let tagline: String?          // sender's per-person tagline
        /// [build9] LOCAL-ONLY sender display name for the unified (sender-agnostic)
        /// bucket. NOT in CodingKeys → nil from server rows; set when building the
        /// bucket from local caughtHistory so each item shows its OWN sender.
        var fromName: String? = nil

        enum CodingKeys: String, CodingKey {
            case id
            case fromUser    = "from_user"
            case toUser      = "to_user"
            case emoji
            case createdAt   = "created_at"
            case openedAt    = "opened_at"
            case senderStyle = "sender_style"
            case message
            case tagline
        }
    }

    /// Send a ping (a "thought") to another Pointward user, carrying the
    /// sender's style so the catch and replays play THEIR animation.
    /// If the database hasn't run the sender_style migration yet, the
    /// styled insert fails — retry once with the legacy payload so a
    /// schema lag never blocks a thought. Network errors are retried and
    /// then THROWN: the caller must surface them, never swallow them.
    func sendPing(to userID: UUID, emoji: String, style: SenderStyle? = nil,
                  message: String? = nil, tagline: String? = nil) async throws {
        guard let client else { throw SupabaseServiceError.notConfigured }
        guard let me = await currentUserID else { throw SupabaseServiceError.notSignedIn }
        // One selection defines everything: the wire style follows the
        // chosen instrument (falls back to the compass → glow for free).
        // Callers that know the instrument pass `style` explicitly.
        let styleRaw: String
        if let style {
            styleRaw = style.rawValue
        } else {
            let savedInstrument = UserDefaults.standard.string(forKey: InstrumentStore.storageKey) ?? ""
            let savedTier = UserDefaults.standard.string(forKey: "subscriptionTier") ?? ""
            let tier = SubscriptionTier(rawValue: savedTier) ?? .free
            var instrument = Instrument(rawValue: savedInstrument) ?? .compass
            if instrument.requiresPro && tier == .free { instrument = .compass }
            styleRaw = instrument.senderStyle.rawValue
        }
        log.info("pings: sendPing → to=\(userID.uuidString, privacy: .public) emoji=\(emoji, privacy: .public) style=\(styleRaw, privacy: .public)")
        do {
            try await withRetry(label: "sendPing") {
                try await client
                    .from("pings")
                    .insert(PingPayload(fromUser: me, toUser: userID, emoji: emoji,
                                        senderStyle: styleRaw,
                                        message: message?.isEmpty == true ? nil : message,
                                        tagline: tagline?.isEmpty == true ? nil : tagline))
                    .execute()
            }
            log.info("pings: sendPing ✓ insert accepted")
        } catch let error as SupabaseServiceError {
            // Transport problem — a legacy retry can't help; surface it.
            throw error
        } catch {
            log.error("pings: styled insert failed (pre-migration schema?) — retrying legacy: \(error.localizedDescription, privacy: .public)")
            try await withRetry(label: "sendPing.legacy") {
                try await client
                    .from("pings")
                    .insert(PingPayload(fromUser: me, toUser: userID, emoji: emoji))
                    .execute()
            }
            log.info("pings: sendPing ✓ insert accepted (legacy payload)")
        }
    }

    // MARK: - Messages (Phase 2 link delivery)

    // [phase2] Insert payload for public.messages. nonisolated pure-data struct
    // (no main-actor Encodable warning). opened / opened_at / created_at are left
    // to the DB defaults — we send only the columns we own at send time.
    private nonisolated struct MessageInsert: Encodable {
        let senderID: UUID
        let senderDisplayName: String?
        let content: String?
        let emoji: String?
        let instrument: String?
        enum CodingKeys: String, CodingKey {
            case senderID          = "sender_id"
            case senderDisplayName = "sender_display_name"
            case content
            case emoji
            case instrument
        }
    }

    private nonisolated struct InsertedMessageID: Decodable, Sendable { let id: UUID }

    /// [phase2] Store a thought as a `messages` row (the /m/[id] link-delivery
    /// record) and return the new message id. Mirrors sendPing's contract:
    /// auth-guarded, retried via withRetry, and THROWN on failure (never
    /// swallowed) so the caller can surface a retry. Does NOT touch
    /// pings / pairing. `senderDisplayName` is the caller's snapshot of the
    /// profile name at send time (denormalized into the row).
    func insertMessage(content: String?, emoji: String, instrument: String,
                       senderDisplayName: String?) async throws -> UUID {
        guard let client else { throw SupabaseServiceError.notConfigured }
        guard let me = await currentUserID else { throw SupabaseServiceError.notSignedIn }
        let payload = MessageInsert(
            senderID: me,
            senderDisplayName: senderDisplayName?.isEmpty == true ? nil : senderDisplayName,
            content: content?.isEmpty == true ? nil : content,
            emoji: emoji,
            instrument: instrument)
        log.info("messages: insert → sender=\(me.uuidString, privacy: .public) emoji=\(emoji, privacy: .public) instrument=\(instrument, privacy: .public)")
        let row: InsertedMessageID = try await withRetry(label: "insertMessage") {
            try await client
                .from("messages")
                .insert(payload)
                .select("id")
                .single()
                .execute()
                .value
        }
        log.info("messages: insert ✓ id=\(row.id.uuidString, privacy: .public)")
        return row.id
    }

    // MARK: - Messages: open by link (Phase 2 Build 4a)

    /// [phase2] Fetch the single message behind a /m/[id] link via the
    /// `get_message(p_id)` SECURITY DEFINER RPC (Build 2 migration). Anon-callable
    /// — the recipient opening the link may be signed out or a DIFFERENT user than
    /// the sender, so this does NOT require currentUserID. Returns nil for a
    /// bad/expired id (the function returns an empty set). Retried via withRetry.
    func getMessage(id: UUID) async throws -> Message? {
        guard let client else { throw SupabaseServiceError.notConfigured }
        log.info("messages: get → id=\(id.uuidString, privacy: .public)")
        let rows: [Message] = try await withRetry(label: "getMessage") {
            try await client
                .rpc("get_message", params: ["p_id": id.uuidString])
                .execute()
                .value
        }
        log.info("messages: get ✓ found=\(rows.first != nil)")
        return rows.first
    }

    /// [phase2 4b] The SHORT-CODE FALLBACK fetch — resolve a typed sender code to
    /// that sender's UNOPENED messages (newest-first), via the
    /// `get_unopened_for_short_code(p_code)` SECURITY DEFINER RPC (Build 2
    /// migration). Anon-callable (the recipient may be signed out / not the
    /// sender) — no currentUserID guard, mirroring `getMessage`. Returns an empty
    /// array for an unknown code OR a code whose messages are all already opened
    /// (the caller treats both as the gentle empty state). Server-side already
    /// uppercases the code; we normalize on the client too. Retried via withRetry.
    func getUnopenedForShortCode(_ code: String) async throws -> [Message] {
        guard let client else { throw SupabaseServiceError.notConfigured }
        let normalized = ShortCode.normalize(code)
        log.info("messages: short-code claim → code=\(normalized, privacy: .public)")
        let rows: [Message] = try await withRetry(label: "getUnopenedForShortCode") {
            try await client
                .rpc("get_unopened_for_short_code", params: ["p_code": normalized])
                .execute()
                .value
        }
        log.info("messages: short-code claim ✓ count=\(rows.count)")
        return rows
    }

    /// [phase2] Flip a message's `opened` flag via the `mark_opened(p_id)`
    /// SECURITY DEFINER RPC (Build 4a migration — NOT YET APPLIED). The recipient
    /// may be unauthenticated / not the row owner, so this bypasses RLS as the
    /// function owner; the SQL only flips a still-unopened row (idempotent).
    /// Best-effort: logged, never thrown to the UI (a failed flip just leaves the
    /// message recoverable, which is the intended fail-safe).
    func markMessageOpened(id: UUID) async {
        guard let client else { return }
        do {
            try await client
                .rpc("mark_opened", params: ["p_id": id.uuidString])
                .execute()
            log.info("messages: mark_opened ✓ id=\(id.uuidString, privacy: .public)")
        } catch {
            log.error("messages: mark_opened failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Connection signal (Phase 2 Stage B)

    /// A row from `link_connections` (the bilateral connection signal), as read by the
    /// SENDER (RLS returns only rows where `sender_id = me`). `via_message_id` is the
    /// join key back to the sender's local `SentLink` → the right contact to stamp.
    struct LinkConnection: Decodable {
        let connectedUserID: UUID
        let viaMessageID: UUID?
        let connectedAt: Date
        enum CodingKeys: String, CodingKey {
            case connectedUserID = "connected_user_id"
            case viaMessageID    = "via_message_id"
            case connectedAt     = "connected_at"
        }
    }

    /// The receiver records "I connected to the sender of this message." The
    /// `record_connection` RPC is authenticated-only + forces `connected_user_id =
    /// auth.uid()`, so a signed-OUT caller no-ops server-side (safe to call anyway).
    /// Returns true on a clean execute (so the S2 sweep can keep failures for retry).
    @discardableResult
    func recordConnection(messageID: UUID) async -> Bool {
        guard let client else { return false }
        do {
            try await client
                .rpc("record_connection", params: ["p_message_id": messageID.uuidString])
                .execute()
            log.info("connection: record_connection ✓ msg=\(messageID.uuidString, privacy: .public)")
            return true
        } catch {
            log.error("connection: record_connection failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// The SENDER reads who has connected to them (RLS scopes to own rows). Empty on
    /// failure / signed-out — never throws to the caller.
    func fetchMyConnections() async -> [LinkConnection] {
        guard let client, let me = await currentUserID else { return [] }
        do {
            let rows: [LinkConnection] = try await client
                .from("link_connections")
                .select()
                .eq("sender_id", value: me.uuidString)   // belt + suspenders (RLS already scopes)
                .execute().value
            log.info("connection: fetched \(rows.count) connection(s)")
            return rows
        } catch {
            log.error("connection: fetchMyConnections failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    /// (S2) Post-sign-in sweep: write the connection for every `/m/` the receiver
    /// opened while signed OUT. No-op when signed out; idempotent (the RPC's
    /// on-conflict-do-nothing); a failed write stays in the queue for next launch.
    func drainPendingConnections() async {
        guard Self.localUserID != nil else { return }
        for id in PendingConnections.all {
            if await recordConnection(messageID: id) { PendingConnections.remove(id) }
        }
    }

    /// [phase2 stage C] Read-receipts (POLL — messages is not in realtime). The ids of
    /// MY sent messages the recipient has OPENED IN FULL (the `opened` flag flips only
    /// at the receipt's natural completion — the locked "opened = in-app full open").
    /// RLS ("messages read own", auth.uid() = sender_id) scopes this to my own rows.
    func fetchOpenedSentMessageIDs() async -> [UUID] {
        guard let client, let me = await currentUserID else { return [] }
        struct Row: Decodable { let id: UUID }
        do {
            let rows: [Row] = try await client
                .from("messages")
                .select("id")
                .eq("sender_id", value: me.uuidString)
                .eq("opened", value: true)
                .execute().value
            return rows.map(\.id)
        } catch {
            log.error("receipt: fetchOpenedSentMessageIDs failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    /// Realtime shape of a partner's compass_bearings row.
    struct PointingEvent: Codable {
        let userID: UUID
        let bearing: Double
        enum CodingKeys: String, CodingKey {
            case userID = "user_id"
            case bearing
        }
    }

    /// Open the single consolidated realtime channel: incoming pings, felt
    /// receipts on our sent pings, partner pointing events, and pairing
    /// claims on our own invite codes (the inviter-side celebration).
    /// Safe to call repeatedly — tears down any existing channel first.
    func startRealtime(
        // [pairing-retire step6] `partner` + `onPaired` params REMOVED — both vestigial:
        // the pings/felt streams below filter on to_user/from_user = me (no partner id
        // needed), and the pairing-claim stream that once fired onPaired is retired.
        onPing: @escaping (PingEvent) -> Void,
        onFelt: @escaping (PingEvent) -> Void,
        onPointed: @escaping (Double?) -> Void
    ) async {
        guard let client, let me = await currentUserID else { return }
        await stopListening()

        let channel = client.channel("pointward")
        realtimeChannel = channel

        let pingInserts = channel.postgresChange(
            InsertAction.self, schema: "public", table: "pings",
            filter: "to_user=eq.\(me.uuidString)")
        let feltUpdates = channel.postgresChange(
            UpdateAction.self, schema: "public", table: "pings",
            filter: "from_user=eq.\(me.uuidString)")
        // [build9] PAIRING streams retired — compass_bearings (mutual-pointing) +
        // connections (claim celebrate). The pings/felt DELIVERY streams above stay.
        // (Clears the compass_bearings + connections postgresChange deprecations.)
        // let pointingChanges = partner.map { p in
        //     channel.postgresChange(
        //         AnyAction.self, schema: "public", table: "compass_bearings",
        //         filter: "user_id=eq.\(p.uuidString)")
        // }
        // // Someone redeemed one of MY codes → friend fills in → celebrate live
        // let connectionClaims = channel.postgresChange(
        //     UpdateAction.self, schema: "public", table: "connections",
        //     filter: "owner=eq.\(me.uuidString)")

        await channel.subscribe()
        log.info("realtime: consolidated channel subscribed")

        // The streams end when the channel unsubscribes — loops exit cleanly.
        Task { [log] in
            for await insert in pingInserts {
                do {
                    let ping: PingEvent = try insert.decodeRecord(decoder: JSONDecoder())
                    log.info("realtime: ping insert received — emoji=\(ping.emoji, privacy: .public) style=\(ping.senderStyle ?? "nil", privacy: .public)")
                    onPing(ping)
                } catch {
                    // A decode failure here means a SILENTLY LOST thought —
                    // log loudly so it's visible in Console during testing.
                    log.error("realtime: ping insert DECODE FAILED: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
        Task { [log] in
            for await update in feltUpdates {
                do {
                    let ping: PingEvent = try update.decodeRecord(decoder: JSONDecoder())
                    if ping.openedAt != nil {
                        log.info("realtime: felt receipt — emoji=\(ping.emoji, privacy: .public)")
                        onFelt(ping)
                    }
                } catch {
                    log.error("realtime: felt update DECODE FAILED: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
        // [build9] PAIRING stream loops retired (compass_bearings + connections).
        // onPointed / onPaired closures are now never invoked (left in the signature
        // so the caller is unchanged; they compile but no longer fire).
        // if let pointingChanges {
        //     Task { [log] in
        //         for await change in pointingChanges {
        //             var bearing: Double?
        //             switch change {
        //             case .insert(let action):
        //                 bearing = (try? action.decodeRecord(decoder: JSONDecoder()) as PointingEvent)?.bearing
        //             case .update(let action):
        //                 bearing = (try? action.decodeRecord(decoder: JSONDecoder()) as PointingEvent)?.bearing
        //             default:
        //                 break
        //             }
        //             log.info("realtime: partner pointing event …")
        //             onPointed(bearing)
        //         }
        //     }
        // }
        // Task { [log] in
        //     for await update in connectionClaims {
        //         do {
        //             let row: ConnectionRow = try update.decodeRecord(decoder: JSONDecoder())
        //             guard let friend = row.friend else { continue }
        //             Self.connectedFriendID = friend
        //             onPaired(DiscoveredConnection(partnerID: friend,
        //                                           myPersonID: row.ownerPersonID))
        //         } catch {
        //             log.error("realtime: connection claim DECODE FAILED: …")
        //         }
        //     }
        // }
        _ = onPointed   // [build9] retained in signature, no longer fired (onPaired removed step6)
    }

    func stopListening() async {
        guard let channel = realtimeChannel else { return }
        await channel.unsubscribe()
        realtimeChannel = nil
        log.info("realtime: channel closed")
    }

    /// Read receipt: the recipient marks a ping as opened/felt.
    func markPingOpened(_ id: UUID) async {
        guard let client else { return }
        do {
            try await withRetry(label: "markPingOpened") {
                try await client
                    .from("pings")
                    .update(["opened_at": ISO8601DateFormatter().string(from: .now)])
                    .eq("id", value: id.uuidString)
                    .execute()
            }
            log.info("pings: marked opened ✓ id=\(id.uuidString, privacy: .public)")
        } catch {
            log.error("pings: markPingOpened FAILED id=\(id.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// [unread-badge fix · Option A] Bulk read-receipt: mark ALL of MY unopened
    /// pings opened — called on app foreground so the server "unread" count
    /// (`pings.opened_at IS NULL` for `to_user = me`, which the Edge Function badges
    /// on) drops to 0 and the badge stops climbing. The per-ping `markPingOpened`
    /// (on full reveal) stays as-is; this is the broader "acknowledge on open" sweep.
    /// DESIGN (Joshua): badge = "unseen since last open" — opening the app
    /// acknowledges thoughts, so `opened_at` here means "seen/acknowledged", not
    /// strictly "felt in full" (accepted trade-off; also shifts the sender's
    /// "opened ✦" receipt to fire on app-open). Keyed to the signed-in user.
    /// ⚠️ RLS: needs `pings` to permit a recipient UPDATE of `opened_at` (today
    /// `pings` has no RLS policy in-repo → RLS off → allowed, same as markPingOpened).
    /// The log surfaces a block ("FAILED") if a policy is ever added without UPDATE.
    func markAllMyPingsOpened() async {
        guard let client, let me = await currentUserID else { return }
        do {
            try await withRetry(label: "markAllMyPingsOpened") {
                try await client
                    .from("pings")
                    .update(["opened_at": ISO8601DateFormatter().string(from: .now)])
                    .eq("to_user", value: me.uuidString)
                    .is("opened_at", value: nil)
                    .execute()
            }
            log.info("pings: marked all opened ✓ (to_user=\(me.uuidString.prefix(8), privacy: .public))")
        } catch {
            log.error("pings: markAllMyPingsOpened FAILED: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// All pings between me and one partner, newest first (ping history).
    func fetchPings(with partner: UUID) async -> [PingRecord] {
        guard let client, let me = await currentUserID else { return [] }
        let a = me.uuidString, b = partner.uuidString
        do {
            let rows: [PingRecord] = try await client
                .from("pings")
                .select()
                .or("and(from_user.eq.\(a),to_user.eq.\(b)),and(from_user.eq.\(b),to_user.eq.\(a))")
                .order("created_at", ascending: false)
                .execute().value
            log.info("pings: history fetched — \(rows.count) row(s)")
            return rows
        } catch {
            log.error("pings: history fetch FAILED: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    // [9b · B4] reportPointing no-op stub REMOVED — its only caller
    // (CompassManager.reportPointingIfNeeded) is gone with the mutual-pointing cluster.
    // The `compass_bearings` write was already retired (build9).

    /// The "notify me when someone points toward me" preference, server-side
    /// so the push Edge Function can respect it even when the app is closed.
    func setNotifyPointing(_ enabled: Bool) async {
        guard let client, let me = await currentUserID else { return }
        do {
            try await client
                .from("users")
                .update(["notify_pointing": enabled])
                .eq("id", value: me.uuidString)
                .execute()
            log.info("users: notify_pointing set to \(enabled, privacy: .public) ✓")
        } catch {
            // Was a silent try? — the local toggle and the server could diverge
            // with no trace. Surface the failure so it's visible in Console. [7/8]
            log.error("users: setNotifyPointing FAILED — local toggle and server may diverge: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Presence (last seen)


    // [build10 shot2] FILL-VIA-LINK — a connected user's PUBLIC profile, read by id.
    // Same wide-open `users` SELECT (RLS `using(true)`) the `fetchLastSeen(of:)` read
    // below already relies on — just more columns. Used by the link-arriver compose-back
    // to aim the compass back at the SENDER (sender_id from the arrived message).
    // latitude/longitude are OPTIONAL (Home Location is optional → often null) — the
    // caller falls through to the seeded bearing when absent. Read-only, best-effort.
    nonisolated struct PublicProfile: Decodable {
        let displayName: String?
        let emoji: String?
        let latitude: Double?
        let longitude: Double?
        enum CodingKeys: String, CodingKey {
            case displayName = "display_name"
            case emoji
            case latitude
            case longitude
        }
    }

    func fetchPublicProfile(of user: UUID) async -> PublicProfile? {
        guard let client else { return nil }
        let rows: [PublicProfile]? = try? await client
            .from("users")
            .select("display_name, emoji, latitude, longitude")
            .eq("id", value: user.uuidString)
            .limit(1)
            .execute().value
        return rows?.first
    }

    /// A partner's last_seen, for "active recently / last seen 2 hours ago".


}
