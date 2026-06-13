// Message.swift
// Pointward › Models
//
// Phase 2 — the link-delivery record. Mirrors the `messages` table (the target
// of a pointward.app/m/[id] link). DTO only: Build 3 will INSERT it, Build 4
// will DECODE it. Nothing is wired into the send flow in this build.
//
// ⚠️ The `messages` table does NOT exist until the Phase 2 migration
// (supabase/migrations/20260613000000_short_code_messages.sql) is applied.
//
// Convention (matches PingPayload / PingEvent in SupabaseService): a Codable
// struct with camelCase properties + explicit snake_case CodingKeys, and
// timestamps decoded as ISO strings (not Date) to stay agnostic of the
// PostgREST/JSON date format.

import Foundation

struct Message: Codable, Identifiable, Hashable {
    /// PK — the messageID in /m/[id].
    let id: UUID
    /// references users.id — the immutable senderID (routing key).
    let senderID: UUID
    /// Snapshot of the sender's display name AT SEND TIME (denormalized so
    /// opening a message never has to read another user's row).
    let senderDisplayName: String?
    let content: String?
    let emoji: String?
    let instrument: String?
    /// Flips to true only when the recipient actually SEES the animation
    /// (wired in a later build), not on link tap / app open.
    let opened: Bool
    /// ISO timestamp string — enables the Phase 3 "message opened" notification.
    let openedAt: String?
    /// ISO timestamp string — enables message expiry later.
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case senderID          = "sender_id"
        case senderDisplayName = "sender_display_name"
        case content
        case emoji
        case instrument
        case opened
        case openedAt          = "opened_at"
        case createdAt         = "created_at"
    }
}
