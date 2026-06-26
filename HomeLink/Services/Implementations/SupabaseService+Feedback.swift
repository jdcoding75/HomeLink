// SupabaseService+Feedback.swift
// Pointward › Services › Implementations
//
// In-app feedback insert → public.feedback. House-style extension on the SAME type
// (matches +Auth / +Profile / +Maintenance splits) so the shared SupabaseService.swift
// is untouched. ANON-ALLOWED: unlike insertMessage, there is NO `currentUserID` guard —
// the table's RLS permits anon+auth INSERT, and identity attaches ONLY when available.
// Thrown on failure (never swallowed) so the form can surface a retry.

import Foundation
import Supabase
import os

extension SupabaseService {

    /// Snake-case row for `public.feedback` (omits id/created_at — DB defaults).
    private nonisolated struct FeedbackInsert: Encodable {
        let category: String
        let body: String
        let userID: UUID?
        let displayName: String?
        let appVersion: String?
        let deviceInfo: String?
        enum CodingKeys: String, CodingKey {
            case category, body
            case userID      = "user_id"
            case displayName = "display_name"
            case appVersion  = "app_version"
            case deviceInfo  = "device_info"
        }
    }

    /// Insert a feedback row. NO sign-in guard (anon allowed); identity (`userID` /
    /// `displayName`) attaches only when present. `body` is clamped to the table's
    /// `length(body) <= 4000` CHECK so a long note can never bounce the insert.
    ///
    /// [feedback anon-fix · Option A] This deliberately does NOT use the shared
    /// `SupabaseClient` insert: that client ALWAYS sends `Authorization: Bearer
    /// <token>` and, with NO session, `token == supabaseKey` (the legacy anon JWT)
    /// — which the project REJECTS as a session bearer (401 · RLS), so a signed-out
    /// feedback insert would fail. (Verified: SupabaseClient.swift:360/390/395, and a
    /// real REST insert returns 201 with apikey-only / 401 with the legacy Bearer.)
    /// So we send a minimal anon REST POST: `apikey` ONLY, NO `Authorization` →
    /// PostgREST runs as the `anon` role → the table's `WITH CHECK true` INSERT
    /// policy (roles {anon, authenticated}) accepts it. Works signed-out AND
    /// signed-in (the role is `anon` either way; identity rides in the body). Throws
    /// on any non-2xx so the form's error path (retry, text preserved) engages.
    func insertFeedback(category: String,
                        body: String,
                        userID: UUID?,
                        displayName: String?,
                        appVersion: String?,
                        deviceInfo: String?) async throws {
        guard SupabaseConfig.isConfigured,
              let url = URL(string: "\(SupabaseConfig.url)/rest/v1/feedback") else {
            throw SupabaseServiceError.notConfigured
        }
        let payload = FeedbackInsert(
            category: category,
            body: String(body.prefix(4000)),
            userID: userID,
            displayName: (displayName?.isEmpty == true) ? nil : displayName,
            appVersion: appVersion,
            deviceInfo: deviceInfo)
        // Same encoding the SDK insert used (snake_case CodingKeys above; nil fields
        // are simply absent from the JSON — JSONEncoder omits nil Optionals).
        let bodyData = try JSONEncoder().encode(payload)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")   // anon role; NO Authorization
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = bodyData

        // Tiny inline retry (replaces the SDK's withRetry, which the shared client
        // provided): 2 attempts; retry only a transient transport error, never a
        // 4xx (those won't change on retry — throw so the form surfaces it).
        var lastError: Error?
        for attempt in 1...2 {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw SupabaseServiceError.networkProblem
                }
                guard (200...299).contains(http.statusCode) else {
                    // Non-2xx (401/4xx/5xx) is a FAILURE — never treated as success.
                    let detail = String(data: data, encoding: .utf8) ?? ""
                    log.error("feedback: insert HTTP \(http.statusCode, privacy: .public) \(detail, privacy: .public)")
                    throw SupabaseServiceError.networkProblem   // marker → caught as SupabaseServiceError (no retry); the form shows its own message
                }
                log.info("feedback: insert ✓ HTTP \(http.statusCode, privacy: .public)")
                return   // success
            } catch let error as SupabaseServiceError {
                throw error   // a non-2xx (above) — don't retry an HTTP failure
            } catch {
                // Transport error (network/timeout) — retry once.
                lastError = error
                if attempt == 1 { try? await Task.sleep(nanoseconds: 400_000_000) }
            }
        }
        throw lastError ?? SupabaseServiceError.networkProblem
    }
}
