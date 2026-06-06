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

    /// The TestFlight invite; includes the sender's pairing code when they have one.
    static func inviteMessage(pairingCode: String?) -> String {
        var message = """
        Join me on Pointward — a compass that always points toward the people you love.
        Download here: \(testFlight)
        """
        if let code = pairingCode, !code.isEmpty {
            message += "\nThen enter my pairing code: \(code)"
        }
        return message
    }

    /// The lightweight website invite (pairing share).
    static func friendInvite(code: String?) -> String {
        var message = "Join me on Pointward — download here: \(website)"
        if let code, !code.isEmpty {
            message += "\nEnter my code: \(code)"
        }
        return message
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
