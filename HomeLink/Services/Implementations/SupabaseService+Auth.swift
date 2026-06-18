// SupabaseService+Auth.swift
// Pointward › Services › Implementations
//
// [cleanup] Safe-containment Step 3 — Auth (Apple Sign In) + local identity cache,
// extracted VERBATIM from SupabaseService.swift into an extension on the SAME type
// (zero API change, callers unchanged). `log` / `withRetry` / `friendly` were widened
// private→internal (still internal, no external API) so this extension can use them —
// the standard extension-split mechanic.

import Foundation
import Supabase
import os

extension SupabaseService {

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

    // MARK: - Users row + ensureUser (post-sign-in upsert)

    // [concurrency 2026-06-13] `nonisolated` so the synthesized Encodable
    // conformance isn't main-actor-isolated (this type is nested in the
    // @MainActor SupabaseService). Pure data struct → behavior-identical; clears
    // the Swift-6 "main actor-isolated conformance to 'Encodable'" warning.
    fileprivate nonisolated struct UserRow: Codable {
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
}
