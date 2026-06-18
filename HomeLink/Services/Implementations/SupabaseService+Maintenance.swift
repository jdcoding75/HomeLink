// SupabaseService+Maintenance.swift
// Pointward › Services › Implementations
//
// [cleanup] Safe-containment Step 3 — device tokens (push registration) + giving total
// + launch-time stale-data cleanup, extracted VERBATIM from SupabaseService.swift into an
// extension on the SAME type (zero API change, callers unchanged). The DEBUG-only
// clearAllMyData wipe stays in the main file (it's #if DEBUG-wrapped).

import Foundation
import Supabase
import os

extension SupabaseService {

    // MARK: - Device tokens (for push via Edge Function)

    // [concurrency 2026-06-13] `nonisolated` — see UserRow. Pure data struct for
    // the device_tokens upsert; clears the Swift-6 Encodable-isolation warning.
    fileprivate nonisolated struct DeviceTokenRow: Codable {
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
    fileprivate static var cachedDeviceToken: String? {
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
