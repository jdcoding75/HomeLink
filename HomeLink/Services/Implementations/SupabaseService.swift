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

enum SupabaseServiceError: LocalizedError {
    case notConfigured
    case notSignedIn
    case codeNotFound
    case cannotPairWithSelf

    var errorDescription: String? {
        switch self {
        case .notConfigured:      return "The backend isn't configured yet."
        case .notSignedIn:        return "Sign in to send pings."
        case .codeNotFound:       return "That code wasn't found — check it and try again."
        case .cannotPairWithSelf: return "That's your own code."
        }
    }
}

final class SupabaseService: ObservableObject {

    static let shared = SupabaseService()

    /// nil until SupabaseConfig is filled in — every API below guards on it.
    private(set) lazy var client: SupabaseClient? = {
        guard SupabaseConfig.isConfigured,
              let url = URL(string: SupabaseConfig.url) else { return nil }
        return SupabaseClient(supabaseURL: url, supabaseKey: SupabaseConfig.anonKey)
    }()

    private var realtimeChannel: RealtimeChannelV2?
    private var feltChannel: RealtimeChannelV2?
    private var pointingChannel: RealtimeChannelV2?

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

    // MARK: - Pairing (connections table: code · owner · friend)

    private struct ConnectionRow: Codable {
        let code: String
        let owner: UUID
        var friend: UUID?
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
        try await client
            .from("connections")
            .insert(ConnectionRow(code: code, owner: me, friend: nil))
            .execute()
        Self.localPairingCode = code
        return code
    }

    /// Enter a friend's code: claims their connection row and returns their id.
    @discardableResult
    func redeemCode(_ rawCode: String) async throws -> UUID {
        guard let client else { throw SupabaseServiceError.notConfigured }
        guard let me = await currentUserID else { throw SupabaseServiceError.notSignedIn }

        let code = rawCode.trimmingCharacters(in: .whitespaces).uppercased()
        let rows: [ConnectionRow] = try await client
            .from("connections")
            .select()
            .eq("code", value: code)
            .execute().value
        guard let row = rows.first else { throw SupabaseServiceError.codeNotFound }
        guard row.owner != me else { throw SupabaseServiceError.cannotPairWithSelf }

        try await client
            .from("connections")
            .update(["friend": me.uuidString])
            .eq("code", value: code)
            .execute()

        Self.connectedFriendID = row.owner
        return row.owner
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
        guard let client, let me = await currentUserID else { return }
        _ = try? await client
            .from("device_tokens")
            .upsert(DeviceTokenRow(token: token, userID: me, platform: "ios"))
            .execute()
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

    /// Subscribe to pings addressed to the signed-in user. The handler fires
    /// on every realtime insert until `stopListening()` is called.
    func startListeningForPings(onReceive: @escaping (PingEvent) -> Void) async {
        guard let client, let me = await currentUserID else { return }

        let channel = client.channel("incoming-pings")
        realtimeChannel = channel

        let inserts = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "pings",
            filter: "to_user=eq.\(me.uuidString)"
        )

        await channel.subscribe()

        for await insert in inserts {
            if let ping: PingEvent = try? insert.decodeRecord(decoder: JSONDecoder()) {
                onReceive(ping)
            }
        }
    }

    /// Felt receipts: fires when a ping WE sent gets opened by the recipient.
    func startListeningForFeltReceipts(onFelt: @escaping (PingEvent) -> Void) async {
        guard let client, let me = await currentUserID else { return }

        let channel = client.channel("felt-receipts")
        feltChannel = channel

        let updates = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "pings",
            filter: "from_user=eq.\(me.uuidString)"
        )

        await channel.subscribe()

        for await update in updates {
            if let ping: PingEvent = try? update.decodeRecord(decoder: JSONDecoder()),
               ping.openedAt != nil {
                onFelt(ping)
            }
        }
    }

    func stopListening() async {
        await realtimeChannel?.unsubscribe()
        await feltChannel?.unsubscribe()
        realtimeChannel = nil
        feltChannel = nil
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

    /// Fires whenever the paired partner's compass locks onto us (in-app path;
    /// closed-app delivery comes via push).
    func startListeningForPointing(partner: UUID, onPointed: @escaping () -> Void) async {
        guard let client, await currentUserID != nil else { return }

        let channel = client.channel("pointing")
        pointingChannel = channel

        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "compass_bearings",
            filter: "user_id=eq.\(partner.uuidString)"
        )

        await channel.subscribe()

        for await _ in changes {
            onPointed()
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
}
