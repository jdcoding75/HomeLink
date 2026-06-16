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

    /// Parse a tapped universal link back to its message id, if it is a /m/<id>
    /// link with a valid UUID. Returns nil for any other path (e.g. /pair/…) or a
    /// malformed id. Pure + testable — the routing sibling of the pair route in
    /// RootView. (Build 4b will add the short-code fallback elsewhere; NOT here.)
    static func messageID(from url: URL) -> UUID? {
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count >= 2, parts[0].lowercased() == "m" else { return nil }
        return UUID(uuidString: parts[1])
    }

    /// Warm, Pointward-voiced share copy: the DESIGNED canonical invite line (with
    /// the sender's NAME) + the link + the short-code fallback so a no-app recipient
    /// can open Pointward and type the code. e.g.
    ///   "Sarah sent you a custom animated message ✦ tap to preview
    ///    https://pointward.app/m/…  · no app? open Pointward and enter ABC234"
    /// The code is omitted if we don't have one (degrades to link-only). The sender
    /// name is the recipient-facing display name, resolved at the call site
    /// (people.profile?.displayName ?? UserProfile.snapshot?.displayName ?? "").
    static func shareText(senderName: String, link: String, shortCode: String) -> String {
        let trimmed = senderName.trimmingCharacters(in: .whitespaces)
        // [share-text fix] The SMS preview is the recipient's first impression
        // (TRUTH "two invite surfaces" — surface 1 entices the tap). Use the
        // designed warm copy WITH the name; the generic is a LAST RESORT only when
        // the sender truly has no display name — NOT the default.
        // [pre-fix] generic-by-default, no "animated/preview" hook:
        // let name = trimmed.isEmpty ? "Someone" : senderName
        // var text = "\(name) sent you a thought 💭  \(link)"
        var text = trimmed.isEmpty
            ? "Someone sent you a thought ✦ tap to preview  \(link)"
            : "\(trimmed) sent you a custom animated message ✦ tap to preview  \(link)"
        let code = shortCode.trimmingCharacters(in: .whitespaces)
        if !code.isEmpty {
            text += "  · no app? open Pointward and enter \(code)"
        }
        return text
    }
}
