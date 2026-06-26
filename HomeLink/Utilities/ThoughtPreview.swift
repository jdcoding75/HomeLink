// ThoughtPreview.swift
// Pointward › Utilities
//
// Ship-safe self-send helper. Unlike DevTools (which is entirely #if DEBUG and
// never ships), this compiles into release / TestFlight so the in-app
// "Send myself a test thought" preview works for ALL users. It only creates a
// LOCAL test ReceivedPing through the public PingManager API — no network, no
// mock identities, nothing destructive.

import Foundation

enum ThoughtPreview {
    /// Display name used only when the sender field is left blank.
    static let defaultFromName = "Me"

    /// Curated emoji set shown in preview / exploration surfaces.
    static var previewEmojis: [String] { CuratedEmoji.base.map { $0.emoji } }

    /// Create one local test thought and (optionally) auto-play its full receipt.
    static func sendTestThought(pings: PingManager, style: SenderStyle, emoji: String,
                                message: String?, tagline: String?, fromName: String,
                                autoPlay: Bool = true) {
        pings.receivePing(
            fromName: fromName.isEmpty ? defaultFromName : fromName,
            emoji: emoji,
            remoteID: UUID(),
            senderStyle: style.rawValue,
            message: (message?.isEmpty ?? true) ? nil : message,
            tagline: (tagline?.isEmpty ?? true) ? nil : tagline,
            isTest: true,
            autoPlay: autoPlay)
    }
}
