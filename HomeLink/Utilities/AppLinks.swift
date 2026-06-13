// AppLinks.swift
// Pointward › Utilities
//
// Outward-facing links and invite copy, in one place.
// PLACEHOLDER: swap in the real TestFlight public-link code once the build
// is approved (App Store Connect → TestFlight → public link).

import Foundation

enum AppLinks {
    static let testFlight = "https://testflight.apple.com/join/pointward"
    static let website    = "https://pointward.app"

    /// Deep link that pairs instantly when tapped on a phone with the app.
    static func pairLink(code: String) -> String {
        "\(website)/pair/\(code)"
    }

    /// The pairing invite — one tappable universal link does everything.
    static func inviteMessage(pairingCode: String?) -> String {
        guard let code = pairingCode, !code.isEmpty else {
            return """
            come find me on Pointward ✦ 🧭
            Download here: \(website)
            """
        }
        return """
        come find me on Pointward ✦ 🧭
        Tap to connect instantly:
        \(pairLink(code: code))
        """
    }

    /// Same pairing invite — kept as an alias for existing call sites.
    static func friendInvite(code: String?) -> String {
        inviteMessage(pairingCode: code)
    }

    /// The PERSONAL invite — tied to one person card, so accepting links
    /// the right person on both sides.
    static func personInviteMessage(personName: String, code: String) -> String {
        """
        Join me on Pointward 🧭
        \(personName) wants to connect with you.
        Tap to connect instantly:
        \(pairLink(code: code))
        """
    }

    /// Post-thought invite: "I just sent you a thought…"
    static func thoughtInvite(code: String?) -> String {
        var message = "I just sent you a thought on Pointward 🧭\nDownload here: \(website)"
        if let code, !code.isEmpty {
            message += "\nThen enter my code: \(code)"
        }
        return message
    }

    /// Generic share (Settings).
    static let shareMessage =
        "Check out Pointward — a compass that always points toward the people you love 🧭\n\(website)"
}
