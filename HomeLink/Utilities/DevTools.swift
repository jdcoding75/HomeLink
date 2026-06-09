// DevTools.swift
// Pointward › Utilities
//
// DEVELOPER TESTING TOOLS — DEBUG ONLY. The entire file is wrapped in
// `#if DEBUG`, so none of it compiles into a release / App Store build. It lets
// us exercise the receive/replay/compass experience without a second phone,
// Apple Sign In, or a network.

#if DEBUG
import Foundation
import CoreLocation

enum DevTools {

    // ── Mock identity (stable across launches) ───────────────────────────
    static let mockFriendID = UUID(uuidString: "5A5A0000-0000-4000-8000-00000000A001")!
    static let mockMeID     = UUID(uuidString: "5A5A0000-0000-4000-8000-00000000B002")!
    static let mockName     = "Sarah"
    static let mockEmoji    = "💜"
    static let mockTagline  = "near is a feeling ✦"
    /// New York.
    static let mockCoord = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)

    /// Set in PointwardApp.init when -skipOnboarding is present; consumed once
    /// by RootView (which has the configured model context to inject into).
    static let injectFlagKey = "devInjectMockOnLaunch"

    static var wantsSkipOnboarding: Bool {
        CommandLine.arguments.contains("-skipOnboarding")
    }

    // ── Mock data injection ──────────────────────────────────────────────

    /// Inject mock Sarah + a mock connection so the compass points at someone
    /// and sending/receiving work with no sign-in or partner. Idempotent.
    @MainActor
    static func injectMockData(people: PeopleManager, pings: PingManager? = nil,
                               withHistory: Bool = false) {
        SupabaseService.connectedFriendID = mockFriendID
        if SupabaseService.localUserID == nil { SupabaseService.localUserID = mockMeID }

        if let existing = people.person(forPairedUserID: mockFriendID) {
            // Sarah already exists (a prior launch) — just re-select her and the
            // connection; do NOT re-seed history, or thoughts pile up every launch.
            people.select(existing)
        } else {
            let sarah = Person(
                name: mockName, emoji: mockEmoji,
                latitude: mockCoord.latitude, longitude: mockCoord.longitude,
                displayAddress: "New York, NY", locationDisplayName: "New York",
                pairedUserID: mockFriendID.uuidString, tagline: mockTagline)
            people.insertFromInvite(sarah)
            people.select(sarah)
            // Seed history once, only when Sarah is first created.
            if withHistory, let pings { injectMockHistory(pings: pings) }
        }
    }

    /// Five mixed-instrument thoughts to partially fill the bucket — good for
    /// testing history + replay + the badge.
    @MainActor
    static func injectMockHistory(pings: PingManager) {
        let samples: [(SenderStyle, String, String)] = [
            (.rocket,   "🚀", "to the moon and back"),
            (.bowArrow, "🏹", "thinking of you"),
            (.firefly,  "🌬️", "a soft breath your way"),
            (.wand,     "🪄", "a little magic"),
            (.glow,     "💜", "near is a feeling"),
        ]
        for (style, emoji, msg) in samples {
            pings.receivePing(fromName: mockName, emoji: emoji, remoteID: UUID(),
                              senderStyle: style.rawValue, message: msg, tagline: mockTagline)
        }
    }

    // ── Local message generator ──────────────────────────────────────────

    /// Create a ReceivedPing locally and trigger the FULL receipt experience —
    /// catch mode, landing animation, the works — as if it came from a phone.
    @MainActor
    static func sendTestThought(pings: PingManager, style: SenderStyle, emoji: String,
                                message: String?, tagline: String?, fromName: String) {
        pings.receivePing(
            fromName: fromName.isEmpty ? mockName : fromName,
            emoji: emoji,
            remoteID: UUID(),
            senderStyle: style.rawValue,
            message: (message?.isEmpty ?? true) ? nil : message,
            tagline: (tagline?.isEmpty ?? true) ? nil : tagline,
            isTest: true)
    }

    // ── [2/5] Automated animation testing ────────────────────────────────

    /// Random content pools for one-tap animation testing.
    static let testEmojis   = ["❤️", "🤗", "🌸", "🌙", "✨", "💋", "🔥", "🎉", "🍕", "💜"]
    static let testMessages = ["thinking of you", "miss you", "hi ✦", "almost home",
                               "love you", "☀️ for you", "saw this & smiled"]
    static let testTaglines = ["near is a feeling ✦", "across the miles ✦",
                               "quick as a thought ✦", "carried on the wind ✦",
                               "straight to you ✦"]

    /// The seven instruments, in the order they appear to the user, each paired
    /// with the SenderStyle its thoughts travel + land with.
    static let instrumentSequence: [(icon: String, style: SenderStyle)] = [
        ("🧭", .glow),        // compass
        ("🏹", .bowArrow),    // bow
        ("👆", .fingerFlick), // flick
        ("🚀", .rocket),      // rocket
        ("🌬️", .firefly),     // wind
        ("🪄", .wand),        // wand
        ("✈️", .plane),       // plane
    ]

    /// Send ONE random-content test thought for each instrument, in order.
    /// Each is queued (distinct sender name so none de-dupe away); the first
    /// opens the receipt and the rest wait on the bucket badge — catch one,
    /// the next is already there. Random emoji · message · tagline each.
    @MainActor
    static func testAllAnimations(pings: PingManager) {
        // Stagger the inserts a touch so the queue settles in order.
        for (i, entry) in instrumentSequence.enumerated() {
            let delay = Double(i) * 0.4
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                sendTestThought(
                    pings: pings,
                    style: entry.style,
                    emoji: testEmojis.randomElement() ?? "✨",
                    message: testMessages.randomElement(),
                    tagline: testTaglines.randomElement(),
                    fromName: "\(entry.icon) \(entry.style.displayName) test")
            }
        }
    }

    /// Send ONE random instrument with random content — the quickest single
    /// animation check.
    @MainActor
    static func testRandom(pings: PingManager) {
        let entry = instrumentSequence.randomElement() ?? ("🧭", .glow)
        sendTestThought(
            pings: pings,
            style: entry.style,
            emoji: testEmojis.randomElement() ?? "✨",
            message: testMessages.randomElement(),
            tagline: testTaglines.randomElement(),
            fromName: "\(entry.icon) \(entry.style.displayName) test")
    }

    /// Send a test thought using the user's own custom emoji token — verifies a
    /// saved slot (preset/phone-sound custom thought or a library emoji) works
    /// end to end. The token is rendered the same way the send screen does.
    @MainActor
    static func sendTestCustomEmoji(pings: PingManager, token: String) {
        // "yours:<uuid>" → the custom thought's display emoji; else the token.
        let emoji: String
        if token.hasPrefix("yours:"),
           let id = UUID(uuidString: String(token.dropFirst(6))),
           let thought = CustomThoughtStore.shared.thought(id: id) {
            emoji = thought.emoji
        } else if token == "gecko" {
            emoji = "🦎"
        } else {
            emoji = token
        }
        let entry = instrumentSequence.randomElement() ?? ("🧭", .glow)
        sendTestThought(
            pings: pings,
            style: entry.style,
            emoji: emoji,
            message: testMessages.randomElement(),
            tagline: testTaglines.randomElement(),
            fromName: "custom emoji test")
    }

    // ── Reset / flags ────────────────────────────────────────────────────

    /// Wipe local people + connection + onboarding flag → back to onboarding.
    @MainActor
    static func resetToOnboarding(people: PeopleManager) {
        for p in people.people { try? people.deletePerson(p) }
        SupabaseService.connectedFriendID = nil
        UserDefaults.standard.removeObject(forKey: injectFlagKey)
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
    }

    /// Show onboarding again but KEEP existing data.
    static func clearOnboardingFlagOnly() {
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
    }

    // ── [4/5] Surgical local wipe ────────────────────────────────────────

    /// The EXPLICIT list of UserDefaults keys that are user DATA — the only
    /// keys "clear all my data" is allowed to remove locally. Anything not on
    /// this list (developer settings, sound personalities, instrument/skin/
    /// emoji-set choices, subscription, units, haptics) is deliberately kept.
    static let userDataDefaultsKeys: [String] = [
        "currentUserID",            // local identity cache
        "connectedFriendID",        // the paired friend
        "pairingCode",              // pairing data
        "hasCompletedOnboarding",   // onboarding flag
        "apnsDeviceToken",          // device push token
        "seenPingIDs",              // received-thought ledger
        "pendingThoughtQueue",      // unread bucket queue
        "postOnboardConnectPromptShown",
        injectFlagKey,              // dev mock-inject flag
    ]

    /// Clear ONLY user data locally — SwiftData people, all local thoughts, and
    /// the user-data UserDefaults keys above. Never touches developer tool
    /// settings, sound styles, instrument/skin/emoji preferences, the Apple
    /// Sign In credential, subscription state, or iOS permissions. Pairs with
    /// SupabaseService.clearAllMyData() (server side + sign out).
    @MainActor
    static func clearLocalUserData(people: PeopleManager, pings: PingManager) {
        // Local SwiftData — every person card (carries the connection binding).
        for p in people.people { try? people.deletePerson(p) }
        // Every local thought (bucket queue + caught + widget mirror + ledger).
        pings.clearAllThoughts()
        // The targeted UserDefaults keys — explicit, never a blanket wipe.
        let defaults = UserDefaults.standard
        for key in userDataDefaultsKeys { defaults.removeObject(forKey: key) }
        // Onboarding shows again so the app returns to a clean first-run state.
        defaults.set(false, forKey: "hasCompletedOnboarding")
    }

    // ── Distance simulation ──────────────────────────────────────────────

    /// Move mock Sarah far (≈5000 km) or near (≈0.5 km) of New York so the
    /// distance display can be tested without travelling. 1° lat ≈ 111.2 km.
    @MainActor
    static func setMockDistance(farAway: Bool, people: PeopleManager, compass: CompassManager) {
        guard let sarah = people.person(forPairedUserID: mockFriendID) else { return }
        let km = farAway ? 5000.0 : 0.5
        sarah.latitude  = mockCoord.latitude + km / 111.2
        sarah.longitude = mockCoord.longitude
        try? people.save()
        compass.start(tracking: sarah)   // re-track so the new distance shows now
    }
}
#endif
