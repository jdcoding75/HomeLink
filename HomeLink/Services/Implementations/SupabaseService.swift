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

enum SupabaseServiceError: LocalizedError, Equatable {
    case notConfigured
    case notSignedIn
    case invalidCodeFormat
    case codeNotFound
    case cannotPairWithSelf
    case codeAlreadyClaimed
    case networkProblem
    case timedOut

    var errorDescription: String? {
        switch self {
        case .notConfigured:      return "The backend isn't configured yet."
        case .notSignedIn:        return "Sign in to send pings."
        case .invalidCodeFormat:  return "Codes look like POINT-XXXX — double-check and try again."
        case .codeNotFound:       return "That code wasn't found — make sure it's typed exactly."
        case .cannotPairWithSelf: return "That's your own code."
        case .codeAlreadyClaimed: return "That code is already paired with someone else."
        case .networkProblem:     return "Network problem — check your connection and try again."
        case .timedOut:           return "That took too long — check your connection and try again."
        }
    }
}

final class SupabaseService: ObservableObject {

    static let shared = SupabaseService()

    /// Console logging for the pairing/ping flows — filter on
    /// subsystem com.jdcoding75.pointward in Console.app.
    private let log = Logger(subsystem: "com.jdcoding75.pointward", category: "supabase")

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
    private func withRetry<T: Sendable>(
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
    private static func friendly(_ error: Error) -> Error {
        if let serviceError = error as? SupabaseServiceError { return serviceError }
        if isTransient(error) { return SupabaseServiceError.networkProblem }
        return error
    }

    // MARK: - Auth (Apple Sign In)

    /// Exchange an ASAuthorizationAppleIDCredential's identity token for a
    /// Supabase session. Call from the Sign in with Apple completion handler.
    func signInWithApple(idToken: String, nonce: String) async throws {
        guard let client else { throw SupabaseServiceError.notConfigured }
        log.info("auth: signInWithApple starting")
        do {
            try await client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .apple,
                    idToken: idToken,
                    nonce: nonce
                )
            )
            log.info("auth: signInWithApple ✓")
        } catch {
            log.error("auth: signInWithApple FAILED: \(error.localizedDescription, privacy: .public)")
            throw Self.friendly(error)
        }
    }

    func signOut() async throws {
        guard let client else { throw SupabaseServiceError.notConfigured }
        try await client.auth.signOut()
    }

    /// The signed-in user's id, or nil when signed out / unconfigured.
    var currentUserID: UUID? {
        get async {
            guard let client else { return nil }
            return try? await client.auth.session.user.id
        }
    }

    // MARK: - Local identity cache (UserDefaults)

    static var localUserID: UUID? {
        get { UserDefaults.standard.string(forKey: "currentUserID").flatMap(UUID.init) }
        set { UserDefaults.standard.set(newValue?.uuidString, forKey: "currentUserID") }
    }

    static var connectedFriendID: UUID? {
        get { UserDefaults.standard.string(forKey: "connectedFriendID").flatMap(UUID.init) }
        set { UserDefaults.standard.set(newValue?.uuidString, forKey: "connectedFriendID") }
    }

    static var localPairingCode: String? {
        get { UserDefaults.standard.string(forKey: "pairingCode") }
        set { UserDefaults.standard.set(newValue, forKey: "pairingCode") }
    }

    // MARK: - Users table

    private struct UserRow: Codable {
        let id: UUID
        let appleUserID: String?

        enum CodingKeys: String, CodingKey {
            case id
            case appleUserID = "apple_user_id"
        }
    }

    /// After Apple Sign In: upsert our row in public.users and cache the id.
    /// Returns the Supabase user UUID.
    @discardableResult
    func ensureUser(appleUserID: String) async throws -> UUID {
        guard let client else { throw SupabaseServiceError.notConfigured }
        guard let me = await currentUserID else { throw SupabaseServiceError.notSignedIn }
        try await withRetry(label: "ensureUser") {
            try await client
                .from("users")
                .upsert(UserRow(id: me, appleUserID: appleUserID))
                .execute()
        }
        Self.localUserID = me
        log.info("auth: user ensured ✓ id=\(me.uuidString, privacy: .public)")
        // APNs may have delivered the device token BEFORE sign-in completed —
        // registration was skipped then; flush the cached token now.
        await registerCachedDeviceTokenIfNeeded()
        return me
    }

    // MARK: - Pairing (connections: code · owner · friend · person identity)

    private struct ConnectionRow: Codable {
        let code: String
        let owner: UUID
        var friend: UUID?
        var personName: String?      // who the owner says this connection is
        var personEmoji: String?
        var ownerPersonID: UUID?     // the owner's local Person.id, to re-link

        enum CodingKeys: String, CodingKey {
            case code, owner, friend
            case personName    = "person_name"
            case personEmoji   = "person_emoji"
            case ownerPersonID = "owner_person_id"
        }
    }

    struct RedeemResult {
        let ownerID: UUID
        let personName: String?
        let personEmoji: String?
    }

    struct DiscoveredConnection {
        let partnerID: UUID
        let myPersonID: UUID?   // set when I'm the owner — which card to bind
    }

    /// Create (or reuse) an invite code tied to a specific person card —
    /// the recipient sees the name/emoji and gets the person auto-added.
    func createInvite(personName: String, personEmoji: String, personID: UUID) async throws -> String {
        guard let client else { throw SupabaseServiceError.notConfigured }
        guard let me = await currentUserID else { throw SupabaseServiceError.notSignedIn }

        log.info("pairing: createInvite for person \(personID.uuidString, privacy: .public)")
        let mine: [ConnectionRow] = try await withRetry(label: "createInvite.lookup") {
            try await client
                .from("connections")
                .select()
                .eq("owner", value: me.uuidString)
                .eq("owner_person_id", value: personID.uuidString)
                .execute().value
        }
        if let existing = mine.first {
            log.info("pairing: reusing person invite \(existing.code, privacy: .public)")
            return existing.code
        }

        let code = Self.generatePairingCode()
        try await withRetry(label: "createInvite.insert") {
            try await client
                .from("connections")
                .insert(ConnectionRow(code: code, owner: me, friend: nil,
                                      personName: personName, personEmoji: personEmoji,
                                      ownerPersonID: personID))
                .execute()
        }
        log.info("pairing: created person invite \(code, privacy: .public)")
        return code
    }

    /// Peek at an invite without claiming it — powers the accept sheet's
    /// "[name] wants to connect with you".
    func lookupInvite(_ rawCode: String) async throws -> (name: String?, emoji: String?) {
        guard let client else { throw SupabaseServiceError.notConfigured }
        let code = Self.normalizePairingCode(rawCode)
        log.info("pairing: lookupInvite \(code, privacy: .public)")
        let rows: [ConnectionRow] = try await withRetry(label: "lookupInvite") {
            try await client
                .from("connections")
                .select()
                .eq("code", value: code)
                .execute().value
        }
        guard let row = rows.first else {
            log.warning("pairing: lookupInvite — code not found")
            throw SupabaseServiceError.codeNotFound
        }
        return (row.personName, row.personEmoji)
    }

    /// Fetch (or create on first call) this user's pairing code, e.g. "POINT-4729".
    /// Prefers a still-UNCLAIMED generic code: person invites belong to their
    /// cards, and a claimed code can never pair anyone again — handing either
    /// out as "your code" used to silently break the next pairing.
    func myPairingCode() async throws -> String {
        guard let client else { throw SupabaseServiceError.notConfigured }
        guard let me = await currentUserID else { throw SupabaseServiceError.notSignedIn }

        let mine: [ConnectionRow] = try await withRetry(label: "myPairingCode.lookup") {
            try await client
                .from("connections")
                .select()
                .eq("owner", value: me.uuidString)
                .execute().value
        }
        if let open = mine.first(where: { $0.friend == nil && $0.ownerPersonID == nil })
                   ?? mine.first(where: { $0.friend == nil }) {
            Self.localPairingCode = open.code
            log.info("pairing: my code \(open.code, privacy: .public) (existing, unclaimed)")
            return open.code
        }

        // All codes claimed (or none yet) — mint a fresh one. Retry with a
        // different code on the (rare) primary-key collision.
        var lastError: Error = SupabaseServiceError.networkProblem
        for _ in 0..<3 {
            let code = Self.generatePairingCode()
            do {
                try await withRetry(label: "myPairingCode.insert") {
                    try await client
                        .from("connections")
                        .insert(ConnectionRow(code: code, owner: me, friend: nil))
                        .execute()
                }
                log.info("pairing: created code \(code, privacy: .public)")
                Self.localPairingCode = code
                return code
            } catch {
                lastError = error
                log.warning("pairing: code insert failed (collision/network) — \(error.localizedDescription, privacy: .public)")
            }
        }
        throw lastError
    }

    /// Normalize whatever the user typed into the stored form "POINT-XXXX".
    /// The UI displays codes as "POINT · GP2S", so people enter dots, spaces,
    /// lowercase, or just the suffix — all of these must resolve.
    static func normalizePairingCode(_ raw: String) -> String {
        let alphanumerics = raw.uppercased().filter { $0.isLetter || $0.isNumber }
        let suffix = alphanumerics.hasPrefix("POINT")
            ? String(alphanumerics.dropFirst(5))
            : alphanumerics
        return "POINT-\(suffix)"
    }

    /// Enter a friend's code: claims their connection row. Returns the owner's
    /// id plus the person identity stored with the invite (for auto-adding).
    ///
    /// Failure-mode map (each one logged + thrown as a human message):
    ///   bad format     → invalidCodeFormat, before any network call
    ///   no such code   → codeNotFound
    ///   own code       → cannotPairWithSelf
    ///   already taken  → codeAlreadyClaimed (atomic: claim only lands on an
    ///                    unclaimed row, then is verified with a read-back)
    ///   network drop   → networkProblem/timedOut after a retry, at any step;
    ///                    re-entering the same code later is idempotent —
    ///                    a row already claimed by ME counts as success.
    @discardableResult
    func redeem(_ rawCode: String) async throws -> RedeemResult {
        guard let client else { throw SupabaseServiceError.notConfigured }
        guard let me = await currentUserID else { throw SupabaseServiceError.notSignedIn }

        let code = Self.normalizePairingCode(rawCode)
        log.info("redeem: input '\(rawCode, privacy: .public)' → lookup '\(code, privacy: .public)'")

        // Wrong shape entirely? Say so before hitting the network.
        guard Self.isValidPairingCode(code) else { throw SupabaseServiceError.invalidCodeFormat }

        let rows: [ConnectionRow] = try await withRetry(label: "redeem.lookup") {
            try await client
                .from("connections")
                .select()
                .eq("code", value: code)
                .execute().value
        }
        log.info("redeem: lookup matched \(rows.count) row(s)")
        guard let row = rows.first else { throw SupabaseServiceError.codeNotFound }
        guard row.owner != me else { throw SupabaseServiceError.cannotPairWithSelf }

        if let friend = row.friend, friend != me {
            log.warning("redeem: code already claimed by another user")
            throw SupabaseServiceError.codeAlreadyClaimed
        }

        // Already mine (a retry after a network drop mid-pair) → done.
        if row.friend == me {
            log.info("redeem: already claimed by me — idempotent success")
            Self.connectedFriendID = row.owner
            return RedeemResult(ownerID: row.owner,
                                personName: row.personName,
                                personEmoji: row.personEmoji)
        }

        // Atomic claim: only an UNCLAIMED row matches — two phones racing on
        // the same code can't both win.
        try await withRetry(label: "redeem.claim") {
            try await client
                .from("connections")
                .update(["friend": me.uuidString])
                .eq("code", value: code)
                .is("friend", value: nil)
                .execute()
        }

        // Verify the claim landed — RLS (or losing the race) can match zero
        // rows and "succeed" silently.
        let check: [ConnectionRow] = try await withRetry(label: "redeem.verify") {
            try await client
                .from("connections")
                .select()
                .eq("code", value: code)
                .execute().value
        }
        guard check.first?.friend == me else {
            log.error("redeem: claim did not persist (claimed by someone else in the race?)")
            throw SupabaseServiceError.codeAlreadyClaimed
        }

        Self.connectedFriendID = row.owner
        log.info("redeem: connected ✓ partner=\(row.owner.uuidString, privacy: .public)")
        return RedeemResult(ownerID: row.owner,
                            personName: row.personName,
                            personEmoji: row.personEmoji)
    }

    /// Legacy shape — returns just the partner id.
    @discardableResult
    func redeemCode(_ rawCode: String) async throws -> UUID {
        try await redeem(rawCode).ownerID
    }

    /// Every established connection, both directions, with the owner-side
    /// person id so the right card gets bound.
    func refreshConnections() async throws -> [DiscoveredConnection] {
        guard let client else { throw SupabaseServiceError.notConfigured }
        guard let me = await currentUserID else { throw SupabaseServiceError.notSignedIn }

        var found: [DiscoveredConnection] = []

        let mine: [ConnectionRow] = try await withRetry(label: "refreshConnections.mine") {
            try await client
                .from("connections")
                .select()
                .eq("owner", value: me.uuidString)
                .execute().value
        }
        for row in mine where row.friend != nil {
            found.append(DiscoveredConnection(partnerID: row.friend!,
                                              myPersonID: row.ownerPersonID))
        }

        let theirs: [ConnectionRow] = try await withRetry(label: "refreshConnections.theirs") {
            try await client
                .from("connections")
                .select()
                .eq("friend", value: me.uuidString)
                .execute().value
        }
        for row in theirs {
            found.append(DiscoveredConnection(partnerID: row.owner, myPersonID: nil))
        }

        log.info("pairing: refreshConnections → \(found.count) connection(s)")
        // Keep the cached partner stable across refreshes — only replace it
        // when it's gone (unpaired) or never set.
        let cached = Self.connectedFriendID
        if cached == nil || !found.contains(where: { $0.partnerID == cached }) {
            Self.connectedFriendID = found.first?.partnerID
        }
        return found
    }

    /// Look both directions for an established connection and cache the partner.
    @discardableResult
    func refreshConnection() async throws -> UUID? {
        guard let client else { throw SupabaseServiceError.notConfigured }
        guard let me = await currentUserID else { throw SupabaseServiceError.notSignedIn }

        // Someone redeemed one of my codes. NOTE: scan ALL rows — with person
        // invites a user owns several, and the claimed one is rarely first.
        let mine: [ConnectionRow] = try await withRetry(label: "refreshConnection.mine") {
            try await client
                .from("connections")
                .select()
                .eq("owner", value: me.uuidString)
                .execute().value
        }
        if let friend = mine.compactMap(\.friend).first {
            Self.connectedFriendID = friend
            log.info("pairing: refreshConnection → partner \(friend.uuidString, privacy: .public) (they redeemed my code)")
            return friend
        }

        // I redeemed someone else's code
        let theirs: [ConnectionRow] = try await withRetry(label: "refreshConnection.theirs") {
            try await client
                .from("connections")
                .select()
                .eq("friend", value: me.uuidString)
                .execute().value
        }
        if let owner = theirs.first?.owner {
            Self.connectedFriendID = owner
            log.info("pairing: refreshConnection → partner \(owner.uuidString, privacy: .public) (I redeemed theirs)")
            return owner
        }
        log.info("pairing: refreshConnection → no connection yet")
        return nil
    }

    /// "POINT-" + four unambiguous characters (no 0/O/1/I/L).
    static func generatePairingCode() -> String {
        let alphabet = Array("23456789ABCDEFGHJKMNPQRSTUVWXYZ")
        let suffix = String((0..<4).map { _ in alphabet.randomElement()! })
        return "POINT-\(suffix)"
    }

    /// True only for the canonical stored form: "POINT-" + 4 alphanumerics.
    static func isValidPairingCode(_ code: String) -> Bool {
        guard code.count == 10, code.hasPrefix("POINT-") else { return false }
        return code.dropFirst(6).allSatisfy { $0.isLetter || $0.isNumber }
    }

    // MARK: - Device tokens (for push via Edge Function)

    private struct DeviceTokenRow: Codable {
        let token: String
        let userID: UUID
        let platform: String

        enum CodingKeys: String, CodingKey {
            case token
            case userID = "user_id"
            case platform
        }
    }

    /// The latest APNs token, kept locally so registration can be replayed
    /// after sign-in or on the next launch if the upload ever fails.
    private static var cachedDeviceToken: String? {
        get { UserDefaults.standard.string(forKey: "apnsDeviceToken") }
        set { UserDefaults.standard.set(newValue, forKey: "apnsDeviceToken") }
    }

    func registerDeviceToken(_ token: String) async {
        // Always remember the newest token first — whatever happens below,
        // a later registerCachedDeviceTokenIfNeeded() can finish the job.
        Self.cachedDeviceToken = token
        log.info("push: APNs token received (\(token.prefix(8), privacy: .public)…)")
        guard let client else {
            log.error("push: token registration deferred — backend not configured")
            return
        }
        guard let me = await currentUserID else {
            log.warning("push: token registration deferred — not signed in yet (will retry after sign-in)")
            return
        }
        do {
            try await withRetry(label: "registerDeviceToken") {
                try await client
                    .from("device_tokens")
                    .upsert(DeviceTokenRow(token: token, userID: me, platform: "ios"))
                    .execute()
            }
            log.info("push: device token registered ✓ (\(token.prefix(8), privacy: .public)…)")
        } catch {
            log.error("push: token registration FAILED (cached for retry): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Replay a token that arrived before sign-in (or whose upload failed).
    /// Called after ensureUser and on every app foreground — idempotent.
    func registerCachedDeviceTokenIfNeeded() async {
        guard let token = Self.cachedDeviceToken else { return }
        await registerDeviceToken(token)
    }

    // MARK: - Pings

    /// Insert shape for the `pings` table. senderStyle is optional so the
    /// nil (legacy) payload omits the key entirely — sends keep working on
    /// a database that hasn't run the sender_style migration yet.
    struct PingPayload: Codable {
        let fromUser: UUID
        let toUser: UUID
        let emoji: String
        var senderStyle: String? = nil

        enum CodingKeys: String, CodingKey {
            case fromUser    = "from_user"
            case toUser      = "to_user"
            case emoji
            case senderStyle = "sender_style"
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

        enum CodingKeys: String, CodingKey {
            case id
            case fromUser    = "from_user"
            case toUser      = "to_user"
            case emoji
            case openedAt    = "opened_at"
            case senderStyle = "sender_style"
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

        enum CodingKeys: String, CodingKey {
            case id
            case fromUser    = "from_user"
            case toUser      = "to_user"
            case emoji
            case createdAt   = "created_at"
            case openedAt    = "opened_at"
            case senderStyle = "sender_style"
        }
    }

    /// Send a ping (a "thought") to another Pointward user, carrying the
    /// sender's style so the catch and replays play THEIR animation.
    /// If the database hasn't run the sender_style migration yet, the
    /// styled insert fails — retry once with the legacy payload so a
    /// schema lag never blocks a thought. Network errors are retried and
    /// then THROWN: the caller must surface them, never swallow them.
    func sendPing(to userID: UUID, emoji: String, style: SenderStyle? = nil) async throws {
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
                                        senderStyle: styleRaw))
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
        partner: UUID?,
        onPing: @escaping (PingEvent) -> Void,
        onFelt: @escaping (PingEvent) -> Void,
        onPointed: @escaping (Double?) -> Void,
        onPaired: @escaping (DiscoveredConnection) -> Void = { _ in }
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
        let pointingChanges = partner.map { p in
            channel.postgresChange(
                AnyAction.self, schema: "public", table: "compass_bearings",
                filter: "user_id=eq.\(p.uuidString)")
        }
        // Someone redeemed one of MY codes → friend fills in → celebrate live
        let connectionClaims = channel.postgresChange(
            UpdateAction.self, schema: "public", table: "connections",
            filter: "owner=eq.\(me.uuidString)")

        await channel.subscribe()
        log.info("realtime: consolidated channel subscribed (partner: \(partner?.uuidString ?? "none", privacy: .public))")

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
        if let pointingChanges {
            Task { [log] in
                for await change in pointingChanges {
                    // Carry their reported bearing when we can decode it —
                    // feeds the mutual-pointing check. nil keeps the glow.
                    var bearing: Double?
                    switch change {
                    case .insert(let action):
                        bearing = (try? action.decodeRecord(decoder: JSONDecoder()) as PointingEvent)?.bearing
                    case .update(let action):
                        bearing = (try? action.decodeRecord(decoder: JSONDecoder()) as PointingEvent)?.bearing
                    default:
                        break
                    }
                    log.info("realtime: partner pointing event (bearing=\(bearing.map { String(Int($0)) } ?? "?", privacy: .public)°)")
                    onPointed(bearing)
                }
            }
        }
        Task { [log] in
            for await update in connectionClaims {
                do {
                    let row: ConnectionRow = try update.decodeRecord(decoder: JSONDecoder())
                    guard let friend = row.friend else { continue }
                    log.info("realtime: connection claimed ✦ partner=\(friend.uuidString, privacy: .public)")
                    Self.connectedFriendID = friend
                    onPaired(DiscoveredConnection(partnerID: friend,
                                                  myPersonID: row.ownerPersonID))
                } catch {
                    log.error("realtime: connection claim DECODE FAILED: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
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

    // MARK: - Pointing (compass locked on them)

    /// Report that our compass just locked onto the paired person.
    /// Written only on lock edges (throttled by the caller) — never per heading.
    func reportPointing(bearing: Double) async {
        guard let client, let me = await currentUserID else { return }
        struct Row: Codable {
            let userID: UUID
            let bearing: Double
            let updatedAt: String
            enum CodingKeys: String, CodingKey {
                case userID    = "user_id"
                case bearing
                case updatedAt = "updated_at"
            }
        }
        do {
            try await client
                .from("compass_bearings")
                .upsert(Row(userID: me, bearing: bearing,
                            updatedAt: ISO8601DateFormatter().string(from: .now)))
                .execute()
            log.info("pointing: bearing reported ✓ (\(Int(bearing), privacy: .public)°)")
        } catch {
            log.error("pointing: bearing report FAILED: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// The "notify me when someone points toward me" preference, server-side
    /// so the push Edge Function can respect it even when the app is closed.
    func setNotifyPointing(_ enabled: Bool) async {
        guard let client, let me = await currentUserID else { return }
        _ = try? await client
            .from("users")
            .update(["notify_pointing": enabled])
            .eq("id", value: me.uuidString)
            .execute()
    }

    // MARK: - Presence (last seen)

    /// Stamp our presence — called on every app open.
    func touchLastSeen() async {
        guard let client, let me = await currentUserID else { return }
        _ = try? await client
            .from("users")
            .update(["last_seen": ISO8601DateFormatter().string(from: .now)])
            .eq("id", value: me.uuidString)
            .execute()
    }

    /// A partner's last_seen, for "active recently / last seen 2 hours ago".
    func fetchLastSeen(of user: UUID) async -> Date? {
        struct Row: Codable {
            let lastSeen: Date?
            enum CodingKeys: String, CodingKey { case lastSeen = "last_seen" }
        }
        guard let client else { return nil }
        let rows: [Row]? = try? await client
            .from("users")
            .select("last_seen")
            .eq("id", value: user.uuidString)
            .execute().value
        return rows?.first?.lastSeen
    }

    // MARK: - Giving back

    /// Total donated so far, in cents. Nil when offline/unconfigured —
    /// callers fall back to $0 gracefully.
    func fetchGivingTotalCents() async -> Int? {
        struct Row: Codable {
            let totalDonatedCents: Int
            enum CodingKeys: String, CodingKey {
                case totalDonatedCents = "total_donated_cents"
            }
        }
        guard let client else { return nil }
        let rows: [Row]? = try? await client
            .from("giving")
            .select("total_donated_cents")
            .limit(1)
            .execute().value
        return rows?.first?.totalDonatedCents
    }
}
