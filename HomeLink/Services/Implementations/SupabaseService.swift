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
    // [concurrency 2026-06-13] @discardableResult — many call sites run a write
    // (.execute() → PostgrestResponse<Void>) purely for effect and ignore the
    // result; without this, each is a "result of call to withRetry is unused"
    // warning (a Swift 6 error). Callers that DO need the value still get it.
    @discardableResult
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
        try await client.from("connections").delete()
            .or("owner.eq.\(id),friend.eq.\(id)").execute()
        try await client.from("compass_bearings").delete().eq("user_id", value: id).execute()
        try await client.from("users").delete().eq("id", value: id).execute()
        Self.connectedFriendID = nil
        Self.localUserID = nil
        try await client.auth.signOut()
        log.info("DEV: cleared all data and signed out ✓")
    }

    /// Remove only the pairing connections (keeps pings history) so pairing
    /// can be re-tested without a fresh account.
    func clearConnectionsOnly() async throws {
        guard let client else { throw SupabaseServiceError.notConfigured }
        guard let me = await currentUserID else { throw SupabaseServiceError.notConfigured }
        let id = me.uuidString
        try await client.from("connections").delete()
            .or("owner.eq.\(id),friend.eq.\(id)").execute()
        Self.connectedFriendID = nil
        log.info("DEV: cleared partner connections for \(id.prefix(8), privacy: .public) ✓")
    }
    #endif

    /// [1/4] Mirror YOUR profile into public.users — best-effort, so it no-ops
    /// silently on databases that haven't added the profile columns yet. Split
    /// into homogeneous updates to avoid a heterogeneous-JSON dependency.
    func updateUserProfile(name: String, emoji: String, latitude: Double, longitude: Double) async {
        guard let client, let me = await currentUserID else { return }
        do {
            try await client
                .from("users")
                .update(["display_name": name, "emoji": emoji])
                .eq("id", value: me.uuidString)
                .execute()
            try await client
                .from("users")
                .update(["latitude": latitude, "longitude": longitude])
                .eq("id", value: me.uuidString)
                .execute()
        } catch {
            log.warning("profile: users mirror skipped (columns missing?) — \(error.localizedDescription, privacy: .public)")
        }
    }

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

    // [concurrency 2026-06-13] `nonisolated` so the synthesized Encodable
    // conformance isn't main-actor-isolated (this type is nested in the
    // @MainActor SupabaseService). Pure data struct → behavior-identical; clears
    // the Swift-6 "main actor-isolated conformance to 'Encodable'" warning.
    private nonisolated struct UserRow: Codable {
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
        // [phase2 stage B] (S2) primary drain — now signed in, write any connections
        // queued while signed OUT (the fresh-install /m/ open path). Covers both the
        // onboarding + settings sign-in paths (both route through ensureUser).
        await drainPendingConnections()
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
        var friendPersonID: UUID?    // the FRIEND's local Person.id (set on claim)

        enum CodingKeys: String, CodingKey {
            case code, owner, friend
            case personName     = "person_name"
            case personEmoji    = "person_emoji"
            case ownerPersonID  = "owner_person_id"
            case friendPersonID = "friend_person_id"
        }
    }

    /// Read-only superset that ALSO carries the owner's location columns
    /// (owner_latitude / owner_longitude). Decoded from SELECTs — the optional
    /// owner-location fields are simply nil on pre-migration databases, so this
    /// is always safe to decode. Never used for INSERT (which would send those
    /// keys and fail where the columns don't exist).
    private struct FullConnectionRow: Decodable {
        let code: String
        let owner: UUID
        var friend: UUID?
        var personName: String?
        var personEmoji: String?
        var ownerPersonID: UUID?
        var friendPersonID: UUID?
        var ownerLatitude: Double?
        var ownerLongitude: Double?

        enum CodingKeys: String, CodingKey {
            case code, owner, friend
            case personName     = "person_name"
            case personEmoji    = "person_emoji"
            case ownerPersonID  = "owner_person_id"
            case friendPersonID = "friend_person_id"
            case ownerLatitude  = "owner_latitude"
            case ownerLongitude = "owner_longitude"
        }
    }

    struct RedeemResult {
        let ownerID: UUID
        let personName: String?
        let personEmoji: String?
        /// The owner's location, when their invite carried a profile — lets the
        /// recipient auto-build a pre-filled, correctly-placed person card.
        var ownerLatitude: Double? = nil
        var ownerLongitude: Double? = nil
    }

    struct DiscoveredConnection {
        let partnerID: UUID
        let myPersonID: UUID?   // set when I'm the owner — which card to bind
    }

    /// Create (or reuse) an invite tied to one of MY person cards. The invite
    /// carries MY profile (name · emoji · location) so when the recipient
    /// accepts, their app auto-builds a pre-filled card representing ME, while
    /// owner_person_id re-links the right card on my side. [2/4]
    func createInvite(ownerName: String, ownerEmoji: String,
                      ownerLatitude: Double?, ownerLongitude: Double?,
                      ownerPersonID: UUID) async throws -> String {
        guard let client else { throw SupabaseServiceError.notConfigured }
        guard let me = await currentUserID else { throw SupabaseServiceError.notSignedIn }

        log.info("pairing: createInvite for person \(ownerPersonID.uuidString, privacy: .public)")
        let mine: [ConnectionRow] = try await withRetry(label: "createInvite.lookup") {
            try await client
                .from("connections")
                .select()
                .eq("owner", value: me.uuidString)
                .eq("owner_person_id", value: ownerPersonID.uuidString)
                .execute().value
        }
        if let existing = mine.first {
            log.info("pairing: reusing person invite \(existing.code, privacy: .public)")
            return existing.code
        }

        let code = Self.generatePairingCode()
        try await insertInvite(code: code, owner: me, ownerName: ownerName,
                               ownerEmoji: ownerEmoji,
                               ownerLatitude: ownerLatitude, ownerLongitude: ownerLongitude,
                               ownerPersonID: ownerPersonID)
        log.info("pairing: created person invite \(code, privacy: .public)")
        return code
    }

    /// [2/4] The SELF-PROFILE invite — YOUR code, carrying YOUR profile and no
    /// specific person card. Reuses your existing unclaimed generic code (the
    /// one myPairingCode mints) and stamps your profile onto it, so the code
    /// stays stable while sharing your latest identity. Returns POINT-XXXX.
    func createProfileInvite(name: String, emoji: String,
                             latitude: Double?, longitude: Double?) async throws -> String {
        guard let client else { throw SupabaseServiceError.notConfigured }
        guard let me = await currentUserID else { throw SupabaseServiceError.notSignedIn }

        // Find an unclaimed, generic (no owner_person_id) row to reuse.
        let mine: [ConnectionRow] = try await withRetry(label: "profileInvite.lookup") {
            try await client
                .from("connections")
                .select()
                .eq("owner", value: me.uuidString)
                .execute().value
        }
        let reusable = mine.first { $0.friend == nil && $0.ownerPersonID == nil }
        let code = reusable?.code ?? Self.generatePairingCode()

        if reusable != nil {
            try await updateInviteProfile(code: code, name: name, emoji: emoji,
                                          latitude: latitude, longitude: longitude)
            log.info("pairing: stamped profile onto existing code \(code, privacy: .public)")
        } else {
            try await insertInvite(code: code, owner: me, ownerName: name, ownerEmoji: emoji,
                                   ownerLatitude: latitude, ownerLongitude: longitude,
                                   ownerPersonID: nil)
            log.info("pairing: created profile code \(code, privacy: .public)")
        }
        Self.localPairingCode = code
        return code
    }

    /// Insert a connection row carrying the owner's profile. Two steps so it's
    /// safe before the owner-location columns exist: the identity (name/emoji
    /// in person_name/person_emoji, which always exist) lands via the Codable
    /// row; the location is a best-effort follow-up that no-ops on pre-migration
    /// databases.
    private func insertInvite(code: String, owner: UUID,
                              ownerName: String, ownerEmoji: String,
                              ownerLatitude: Double?, ownerLongitude: Double?,
                              ownerPersonID: UUID?) async throws {
        guard let client else { throw SupabaseServiceError.notConfigured }
        try await withRetry(label: "invite.insert") {
            try await client
                .from("connections")
                .insert(ConnectionRow(code: code, owner: owner, friend: nil,
                                      personName: ownerName, personEmoji: ownerEmoji,
                                      ownerPersonID: ownerPersonID))
                .execute()
        }
        await stampLocation(code: code, latitude: ownerLatitude, longitude: ownerLongitude)
    }

    /// Stamp the owner's latest profile onto an existing code. Identity columns
    /// always exist; location is best-effort.
    private func updateInviteProfile(code: String, name: String, emoji: String,
                                     latitude: Double?, longitude: Double?) async throws {
        guard let client else { throw SupabaseServiceError.notConfigured }
        try await withRetry(label: "invite.update") {
            try await client
                .from("connections")
                .update(["person_name": name, "person_emoji": emoji])
                .eq("code", value: code)
                .execute()
        }
        await stampLocation(code: code, latitude: latitude, longitude: longitude)
    }

    /// Best-effort write of the owner's lat/lng onto a connection row — silently
    /// no-ops where the owner_latitude/owner_longitude columns don't exist yet.
    private func stampLocation(code: String, latitude: Double?, longitude: Double?) async {
        guard let client, let latitude, let longitude else { return }
        do {
            try await client
                .from("connections")
                .update(["owner_latitude": latitude, "owner_longitude": longitude])
                .eq("code", value: code)
                .execute()
        } catch {
            log.warning("pairing: owner location not stored (columns missing?) — \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Peek at an invite without claiming it — powers the accept sheet's
    /// "[name] wants to connect with you".
    func lookupInvite(_ rawCode: String) async throws
        -> (name: String?, emoji: String?, latitude: Double?, longitude: Double?) {
        guard let client else { throw SupabaseServiceError.notConfigured }
        let code = Self.normalizePairingCode(rawCode)
        log.info("pairing: lookupInvite \(code, privacy: .public)")
        // FullConnectionRow also carries the owner's location (nil pre-migration),
        // so the accept screen can show where the sender is before claiming.
        let rows: [FullConnectionRow] = try await withRetry(label: "lookupInvite") {
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
        return (row.personName, row.personEmoji, row.ownerLatitude, row.ownerLongitude)
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
    /// The pure decision at the heart of `redeem`: given a connection row's
    /// owner and current friend, and who *we* are, what should claiming do?
    /// Extracted so the self-pair / already-claimed / idempotent / both-sides
    /// rules are testable without a live backend. [8/8]
    enum PairOutcome: Equatable {
        case pairWithSelf     // the code is our own → refuse
        case alreadyClaimed   // someone else holds it → refuse
        case alreadyOurs      // we already claimed it → idempotent success
        case proceed          // unclaimed → claim it; both sides link
    }

    static func claimOutcome(owner: UUID, friend: UUID?, me: UUID) -> PairOutcome {
        if owner == me { return .pairWithSelf }
        if let friend { return friend == me ? .alreadyOurs : .alreadyClaimed }
        return .proceed
    }

    func redeem(_ rawCode: String, friendPersonID: UUID? = nil) async throws -> RedeemResult {
        guard let client else { throw SupabaseServiceError.notConfigured }
        guard let me = await currentUserID else { throw SupabaseServiceError.notSignedIn }

        let code = Self.normalizePairingCode(rawCode)
        log.info("redeem: input '\(rawCode, privacy: .public)' → lookup '\(code, privacy: .public)'")

        // Wrong shape entirely? Say so before hitting the network.
        guard Self.isValidPairingCode(code) else { throw SupabaseServiceError.invalidCodeFormat }

        let rows: [FullConnectionRow] = try await withRetry(label: "redeem.lookup") {
            try await client
                .from("connections")
                .select()
                .eq("code", value: code)
                .execute().value
        }
        log.info("redeem: lookup matched \(rows.count) row(s)")
        guard let row = rows.first else { throw SupabaseServiceError.codeNotFound }
        switch Self.claimOutcome(owner: row.owner, friend: row.friend, me: me) {
        case .pairWithSelf:
            throw SupabaseServiceError.cannotPairWithSelf
        case .alreadyClaimed:
            log.warning("redeem: code already claimed by another user")
            throw SupabaseServiceError.codeAlreadyClaimed
        case .alreadyOurs:
            // A retry after a network drop mid-pair → idempotent success.
            log.info("redeem: already claimed by me — idempotent success")
            Self.connectedFriendID = row.owner
            return RedeemResult(ownerID: row.owner,
                                personName: row.personName,
                                personEmoji: row.personEmoji,
                                ownerLatitude: row.ownerLatitude,
                                ownerLongitude: row.ownerLongitude)
        case .proceed:
            break   // unclaimed — fall through to the atomic claim below
        }

        // Atomic claim: only an UNCLAIMED row matches — two phones racing on
        // the same code can't both win. friend_person_id records WHICH of
        // the recipient's cards is the sender, so both sides stay linked to
        // the right person. (Falls back to friend-only if the column is
        // missing — pre-migration databases.)
        var claim = ["friend": me.uuidString]
        if let friendPersonID { claim["friend_person_id"] = friendPersonID.uuidString }
        do {
            let payload = claim
            try await withRetry(label: "redeem.claim") {
                try await client
                    .from("connections")
                    .update(payload)
                    .eq("code", value: code)
                    .is("friend", value: nil)
                    .execute()
            }
        } catch let error as SupabaseServiceError {
            throw error
        } catch {
            log.warning("redeem: claim with friend_person_id failed (pre-migration schema?) — retrying friend-only")
            try await withRetry(label: "redeem.claim.legacy") {
                try await client
                    .from("connections")
                    .update(["friend": me.uuidString])
                    .eq("code", value: code)
                    .is("friend", value: nil)
                    .execute()
            }
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
                            personEmoji: row.personEmoji,
                            ownerLatitude: row.ownerLatitude,
                            ownerLongitude: row.ownerLongitude)
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

    // [concurrency 2026-06-13] `nonisolated` — see UserRow. Pure data struct for
    // the device_tokens upsert; clears the Swift-6 Encodable-isolation warning.
    private nonisolated struct DeviceTokenRow: Codable {
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
        _ = onPointed; _ = onPaired   // [build9] retained in signature, no longer fired
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

    // MARK: - Pointing (compass locked on them)

    /// Report that our compass just locked onto the paired person.
    /// Written only on lock edges (throttled by the caller) — never per heading.
    func reportPointing(bearing: Double) async {
        // [build9] RETIRED (pure pairing, mutual-pointing) — no-op. compass_bearings
        // write commented; the realtime read stream is also retired. Kept as a
        // no-op stub so the (also-stripped) CompassManager caller compiles.
        // guard let client, let me = await currentUserID else { return }
        // struct Row: Codable {
        //     let userID: UUID
        //     let bearing: Double
        //     let updatedAt: String
        //     enum CodingKeys: String, CodingKey {
        //         case userID    = "user_id"
        //         case bearing
        //         case updatedAt = "updated_at"
        //     }
        // }
        // do {
        //     try await client
        //         .from("compass_bearings")
        //         .upsert(Row(userID: me, bearing: bearing,
        //                     updatedAt: ISO8601DateFormatter().string(from: .now)))
        //         .execute()
        // } catch {
        //     log.error("pointing: bearing report FAILED: …")
        // }
    }

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

    // MARK: - Stale data cleanup

    /// Launch-time housekeeping so the backend doesn't accumulate dead presence
    /// and token rows. RLS scopes every delete to `auth.uid()`, so this only
    /// ever prunes OUR OWN rows — global pruning of every user's stale data is a
    /// server-side scheduled job (Postgres `cleanup_stale_data`), not something
    /// a client can or should do. Best-effort and silent on failure: launch must
    /// never be blocked by housekeeping. Call from a background task. [3/8]
    ///
    /// - compass_bearings: our presence bearing older than 1 hour (a stale
    ///   "pointing at you" glow should not linger after we've moved on).
    /// - device_tokens: tokens not refreshed in 60 days — the device re-registers
    ///   a fresh token every launch, so anything this old is a dead device.
    /// Connections are deliberately untouched: they are the social graph (never
    /// auto-deleted), and there is no per-connection activity column to drive a
    /// "30 days inactive" sweep — that would need a schema change + a server job.
    func cleanupStaleData() async {
        guard let client, let me = await currentUserID else { return }
        let iso = ISO8601DateFormatter()
        let oneHourAgo   = iso.string(from: Date().addingTimeInterval(-3_600))
        let sixtyDaysAgo = iso.string(from: Date().addingTimeInterval(-60 * 24 * 3_600))
        do {
            try await client
                .from("compass_bearings")
                .delete()
                .eq("user_id", value: me.uuidString)
                .lt("updated_at", value: oneHourAgo)
                .execute()
            try await client
                .from("device_tokens")
                .delete()
                .eq("user_id", value: me.uuidString)
                .lt("updated_at", value: sixtyDaysAgo)
                .execute()
            log.info("cleanup: pruned our own stale bearings/tokens ✓")
        } catch {
            log.error("cleanup: stale-data prune failed (non-fatal): \(error.localizedDescription, privacy: .public)")
        }
    }
}
