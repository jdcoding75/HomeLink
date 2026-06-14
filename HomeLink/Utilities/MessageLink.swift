// MessageLink.swift
// Pointward › Utilities
//
// Phase 2 — link delivery. Builds the shareable /m/[id] URL for a stored
// `messages` row, plus the warm share-sheet copy.
//
// ID-ONLY by decision: NOTHING but the message id travels in the URL — no
// content, emoji, sender name, or senderID, and NO query string. The id is an
// opaque key; the recipient's app fetches everything server-side when the link
// is opened (Build 4). The short_code fallback travels only in the human-
// readable share TEXT, never in the URL.

import Foundation

enum MessageLink {

    /// The canonical shareable link for a message:
    ///   https://pointward.app/m/<messageID>
    /// ID-only — no query string, no leaked fields.
    static func url(for messageID: UUID) -> String {
        "\(AppLinks.website)/m/\(messageID.uuidString)"
    }

    /// Warm, Pointward-voiced share copy: the link plus the short-code fallback
    /// so a no-app recipient can open Pointward and type the code. e.g.
    ///   "Sarah sent you a thought 💭  https://pointward.app/m/…
    ///    · no app? open Pointward and enter ABC234"
    /// The code is omitted if we don't have one (degrades to link-only).
    static func shareText(senderName: String, link: String, shortCode: String) -> String {
        let name = senderName.trimmingCharacters(in: .whitespaces).isEmpty
            ? "Someone" : senderName
        var text = "\(name) sent you a thought 💭  \(link)"
        let code = shortCode.trimmingCharacters(in: .whitespaces)
        if !code.isEmpty {
            text += "  · no app? open Pointward and enter \(code)"
        }
        return text
    }
}
