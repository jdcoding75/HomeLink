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

enum SupabaseServiceError: LocalizedError {
    case notConfigured
    case notSignedIn
    case invalidCodeFormat
    case codeNotFound
    case cannotPairWithSelf
    case codeAlreadyClaimed
    case networkProblem

    var errorDescription: String? {
        switch self {
        case .notConfigured:      return "The backend isn't configured yet."
        case .notSignedIn:        return "Sign in to send pings."
        case .invalidCodeFormat:  return "Codes look like POINT-XXXX — double-check and try again."
        case .codeNotFound:       return "That code wasn't found — make sure it's typed exactly."
        case .cannotPairWithSelf: return "That's your own code."
        case .codeAlreadyClaimed: return "That code is already paired with someone else."
        case .networkProblem:     return "Network problem — check your connection and try again."
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

    // MARK: - Auth (Apple Sign In)

    /// Exchange an ASAuthorizationAppleIDCredential's identity token for a
    /// Supabase session. Call from the Sign in with Apple completion handler.
    func signInWithApple(idToken: String, nonce: String) async throws {
        guard let client else { throw SupabaseServiceError.notConfigured }
        try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )
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
        try await client
            .from("users")
            .upsert(UserRow(id: me, appleUserID: appleUserID))
            .execute()
        Self.localUserID = me
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

        let mine: [ConnectionRow] = try await client
            .from("connections")
            .select()
            .eq("owner", value: me.uuidString)
            .eq("owner_person_id", value: personID.uuidString)
            .execute().value
        if let existing = mine.first {
            return existing.code
        }

        let code = Self.generatePairingCode()
        try await client
            .from("connections")
            .insert(ConnectionRow(code: code, owner: me, friend: nil,
                                  personName: personName, personEmoji: personEmoji,
                                  ownerPersonID: personID))
            .execute()
        log.info("pairing: created person invite \(code, privacy: .public)")
        return code
    }

    /// Peek at an invite without claiming it — powers the accept sheet's
    /// "[name] wants to connect with you".
    func lookupInvite(_ rawCode: String) async throws -> (name: String?, emoji: String?) {
        guard let client else { throw SupabaseServiceError.notConfigured }
        let code = Self.normalizePairingCode(rawCode)
        let rows: [ConnectionRow] = try await client
            .from("connections")
            .select()
            .eq("code", value: code)
            .execute().value
        guard let row = rows.first else { throw SupabaseServiceError.codeNotFound }
        return (row.personName, row.personEmoji)
    }

    /// Fetch (or create on first call) this user's pairing code, e.g. "POINT-4729".
    func myPairingCode() async throws -> String {
        guard let client else { throw SupabaseServiceError.notConfigured }
        guard let me = await currentUserID else { throw SupabaseServiceError.notSignedIn }

        let mine: [ConnectionRow] = try await client
            .from("connections")
            .select()
            .eq("owner", value: me.uuidString)
            .execute().value
        if let existing = mine.first {
            Self.localPairingCode = existing.code
            return existing.code
        }

        let code = Self.generatePairingCode()
        do {
            try await client
                .from("connections")
                .insert(ConnectionRow(code: code, owner: me, friend: nil))
                .execute()
        } catch {
            log.error("pairing: code insert failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
        log.info("pairing: created code \(code, privacy: .public)")
        Self.localPairingCode = code
        return code
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
    @discardableResult
    func redeem(_ rawCode: String) async throws -> RedeemResult {
        guard let client else { throw SupabaseServiceError.notConfigured }
        guard let me = await currentUserID else { throw SupabaseServiceError.notSignedIn }

        let code = Self.normalizePairingCode(rawCode)
        log.info("redeem: input '\(rawCode, privacy: .public)' → lookup '\(code, privacy: .public)'")

        // Wrong shape entirely? Say so before hitting the network.
        guard code.count == 10 else { throw SupabaseServiceError.invalidCodeFormat }

        let rows: [ConnectionRow]
        do {
            rows = try await client
                .from("connections")
                .select()
                .eq("code", value: code)
                .execute().value
        } catch let error as URLError {
            log.error("redeem: network error: \(error.localizedDescription, privacy: .public)")
            throw SupabaseServiceError.networkProblem
        }
        log.info("redeem: lookup matched \(rows.count) row(s)")
        guard let row = rows.first else { throw SupabaseServiceError.codeNotFound }
        guard row.owner != me else { throw SupabaseServiceError.cannotPairWithSelf }

        do {
            try await client
                .from("connections")
                .update(["friend": me.uuidString])
                .eq("code", value: code)
                .execute()
        } catch {
            log.error("redeem: claim update failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }

        // Verify the claim landed — RLS can match zero rows and "succeed" silently
        let check: [ConnectionRow] = try await client
            .from("connections")
            .select()
            .eq("code", value: code)
            .execute().value
        guard check.first?.friend == me else {
            log.error("redeem: claim did not persist (already claimed by someone else?)")
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

        let mine: [ConnectionRow] = try await client
            .from("connections")
            .select()
            .eq("owner", value: me.uuidString)
            .execute().value
        for row in mine where row.friend != nil {
            found.append(DiscoveredConnection(partnerID: row.friend!,
                                              myPersonID: row.ownerPersonID))
        }

        let theirs: [ConnectionRow] = try await client
            .from("connections")
            .select()
            .eq("friend", value: me.uuidString)
            .execute().value
        for row in theirs {
            found.append(DiscoveredConnection(partnerID: row.owner, myPersonID: nil))
        }

        if let first = found.first {
            Self.connectedFriendID = first.partnerID
        }
        return found
    }

    /// Look both directions for an established connection and cache the partner.
    @discardableResult
    func refreshConnection() async throws -> UUID? {
        guard let client else { throw SupabaseServiceError.notConfigured }
        guard let me = await currentUserID else { throw SupabaseServiceError.notSignedIn }

        // Someone redeemed my code
        let mine: [ConnectionRow] = try await client
            .from("connections")
            .select()
            .eq("owner", value: me.uuidString)
            .execute().value
        if let friend = mine.first?.friend {
            Self.connectedFriendID = friend
            return friend
        }

        // I redeemed someone else's code
        let theirs: [ConnectionRow] = try await client
            .from("connections")
            .select()
            .eq("friend", value: me.uuidString)
            .execute().value
        if let owner = theirs.first?.owner {
            Self.connectedFriendID = owner
            return owner
        }
        return nil
    }

    /// "POINT-" + four unambiguous characters (no 0/O/1/I/L).
    private static func generatePairingCode() -> String {
        let alphabet = Array("23456789ABCDEFGHJKMNPQRSTUVWXYZ")
        let suffix = String((0..<4).map { _ in alphabet.randomElement()! })
        return "POINT-\(suffix)"
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

    func registerDeviceToken(_ token: String) async {
        guard let client else {
            log.error("push: token registration skipped — not configured")
            return
        }
        guard let me = await currentUserID else {
            log.error("push: token registration skipped — not signed in")
            return
        }
        do {
            try await client
                .from("device_tokens")
                .upsert(DeviceTokenRow(token: token, userID: me, platform: "ios"))
                .execute()
            log.info("push: device token registered ✓ (\(token.prefix(8), privacy: .public)…)")
        } catch {
            log.error("push: token registration FAILED: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Pings

    /// Insert shape for the `pings` table.
    struct PingPayload: Codable {
        let fromUser: UUID
        let toUser: UUID
        let emoji: String

        enum CodingKeys: String, CodingKey {
            case fromUser = "from_user"
            case toUser   = "to_user"
            case emoji
        }
    }

    /// Realtime event shape (decoded with a plain JSONDecoder — dates as strings).
    struct PingEvent: Codable {
        let id: UUID?
        let fromUser: UUID
        let toUser: UUID
        let emoji: String
        let openedAt: String?

        enum CodingKeys: String, CodingKey {
            case id
            case fromUser = "from_user"
            case toUser   = "to_user"
            case emoji
            case openedAt = "opened_at"
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

        enum CodingKeys: String, CodingKey {
            case id
            case fromUser  = "from_user"
            case toUser    = "to_user"
            case emoji
            case createdAt = "created_at"
            case openedAt  = "opened_at"
        }
    }

    /// Send a ping (a "thought") to another Pointward user.
    func sendPing(to userID: UUID, emoji: String) async throws {
        guard let client else { throw SupabaseServiceError.notConfigured }
        guard let me = await currentUserID else { throw SupabaseServiceError.notSignedIn }
        try await client
            .from("pings")
            .insert(PingPayload(fromUser: me, toUser: userID, emoji: emoji))
            .execute()
    }

    /// Open the single consolidated realtime channel: incoming pings, felt
    /// receipts on our sent pings, and partner pointing events.
    /// Safe to call repeatedly — tears down any existing channel first.
    func startRealtime(
        partner: UUID?,
        onPing: @escaping (PingEvent) -> Void,
        onFelt: @escaping (PingEvent) -> Void,
        onPointed: @escaping () -> Void
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

        await channel.subscribe()
        log.info("realtime: consolidated channel subscribed (partner: \(partner?.uuidString ?? "none", privacy: .public))")

        // The streams end when the channel unsubscribes — loops exit cleanly.
        Task {
            for await insert in pingInserts {
                if let ping: PingEvent = try? insert.decodeRecord(decoder: JSONDecoder()) {
                    onPing(ping)
                }
            }
        }
        Task {
            for await update in feltUpdates {
                if let ping: PingEvent = try? update.decodeRecord(decoder: JSONDecoder()),
                   ping.openedAt != nil {
                    onFelt(ping)
                }
            }
        }
        if let pointingChanges {
            Task {
                for await _ in pointingChanges {
                    onPointed()
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
        _ = try? await client
            .from("pings")
            .update(["opened_at": ISO8601DateFormatter().string(from: .now)])
            .eq("id", value: id.uuidString)
            .execute()
    }

    /// All pings between me and one partner, newest first (ping history).
    func fetchPings(with partner: UUID) async -> [PingRecord] {
        guard let client, let me = await currentUserID else { return [] }
        let a = me.uuidString, b = partner.uuidString
        let rows: [PingRecord]? = try? await client
            .from("pings")
            .select()
            .or("and(from_user.eq.\(a),to_user.eq.\(b)),and(from_user.eq.\(b),to_user.eq.\(a))")
            .order("created_at", ascending: false)
            .execute().value
        return rows ?? []
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
        _ = try? await client
            .from("compass_bearings")
            .upsert(Row(userID: me, bearing: bearing,
                        updatedAt: ISO8601DateFormatter().string(from: .now)))
            .execute()
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
}
