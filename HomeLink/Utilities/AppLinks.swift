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

    // [pairing-retire step3] PAIRING link builders HARD-DELETED — the pairing era is
    // retired (codes unredeemable since 9b; mint stopped in step 2). Removed:
    // pairLink (/pair/<code>) · inviteMessage · friendInvite (alias) ·
    // personInviteMessage · thoughtInvite — plus their PairingLinkTests / HardeningTests
    // cases. The /m/ LINK builder lives in MessageLink (KEPT). `website` (used by
    // MessageLink + the generic share below) stays.

    /// Generic share (Settings).
    static let shareMessage =
        "Check out Pointward — a compass that always points toward the people you love 🧭\n\(website)"
}
