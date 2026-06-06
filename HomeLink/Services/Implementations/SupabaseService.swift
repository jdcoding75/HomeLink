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

    /// Row shape for the `pings` table (create in the Supabase dashboard):
    ///   id uuid default gen_random_uuid() · from_user uuid · to_user uuid
    ///   emoji text · created_at timestamptz default now()
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
    func startListeningForPings(onReceive: @escaping (PingPayload) -> Void) async {
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
            if let ping: PingPayload = try? insert.decodeRecord(decoder: JSONDecoder()) {
                onReceive(ping)
            }
        }
    }

    func stopListening() async {
        await realtimeChannel?.unsubscribe()
        realtimeChannel = nil
    }
}
