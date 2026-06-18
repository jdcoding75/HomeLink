// SupabaseService+Profile.swift
// Pointward › Services › Implementations
//
// [cleanup] Safe-containment Step 3 — self-profile (users-table mirror) + presence,
// extracted VERBATIM from SupabaseService.swift into an extension on the SAME type
// (zero API change, callers unchanged). NOTE: the short_code / fill-via-link reads
// (fetchMyShortCode, fetchPublicProfile) are LINK-adjacent and deliberately LEFT in the
// main file — only the self-profile write + presence move here.

import Foundation
import Supabase
import os

extension SupabaseService {

    // MARK: - Users table (self profile)

    /// [#6 fix C] lat/lng are now OPTIONAL — `display_name` + `emoji` are written
    /// UNCONDITIONALLY (a name-only profile, no address, MUST still set display_name;
    /// the geocode-gating was the root of the NULL-display_name / "Someone" bug). The
    /// location update runs only when BOTH coordinates are present.
    func updateUserProfile(name: String, emoji: String,
                           latitude: Double? = nil, longitude: Double? = nil) async {
        guard let client, let me = await currentUserID else { return }
        do {
            try await client
                .from("users")
                .update(["display_name": name, "emoji": emoji])
                .eq("id", value: me.uuidString)
                .execute()
            if let latitude, let longitude {
                try await client
                    .from("users")
                    .update(["latitude": latitude, "longitude": longitude])
                    .eq("id", value: me.uuidString)
                    .execute()
            }
        } catch {
            log.warning("profile: users mirror skipped (columns missing?) — \(error.localizedDescription, privacy: .public)")
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
