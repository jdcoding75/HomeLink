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
    /// (New York) and sending/receiving work with no sign-in or partner.
    /// Idempotent — re-selects an existing Sarah rather than duplicating her.
    ///
    /// ⚠️ DO NOT REMOVE — required for testing. This is the single source of
    /// truth behind `-skipOnboarding` (see RootView.applySkipOnboardingIfNeeded)
    /// and the testSkipOnboardingInjectsSarah regression test. Changing the
    /// mock identity/coords below will break both.
    @MainActor
    static func injectMockData(people: PeopleManager, pings: PingManager? = nil,
                               withHistory: Bool = false) {
        SupabaseService.connectedFriendID = mockFriendID
        if SupabaseService.localUserID == nil { SupabaseService.localUserID = mockMeID }

        // [build9] Sarah repointed off pairing: dedup + insert via the link-era
        // upsertContact (senderID-keyed). It mirror-writes pairedUserID = senderID,
        // so the legacy delivery recipient + the connected-status still work, and
        // `person(forSenderID:)` is now her lookup key (no more person(forPairedUserID:)).
        let isNew = people.person(forSenderID: mockFriendID.uuidString) == nil
        let sarah = people.upsertContact(senderID: mockFriendID.uuidString,
                                         displayName: mockName)
        // upsertContact creates a location-less, emoji-less contact — give the dev
        // mock her full identity (NYC, emoji, tagline) so the compass points at her.
        if let sarah {
            sarah.emoji               = mockEmoji
            sarah.latitude            = mockCoord.latitude
            sarah.longitude           = mockCoord.longitude
            sarah.displayAddress      = "New York, NY"
            sarah.locationDisplayName = "New York"
            sarah.tagline             = mockTagline
            try? people.save()
            people.select(sarah)
        }
        // Seed history once, only when Sarah is FIRST created.
        if isNew, withHistory, let pings { injectMockHistory(pings: pings) }
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
                                message: String?, tagline: String?, fromName: String,
                                autoPlay: Bool = true) {
        pings.receivePing(
            fromName: fromName.isEmpty ? mockName : fromName,
            emoji: emoji,
            remoteID: UUID(),
            senderStyle: style.rawValue,
            message: (message?.isEmpty ?? true) ? nil : message,
            tagline: (tagline?.isEmpty ?? true) ? nil : tagline,
            isTest: true,
            autoPlay: autoPlay)
    }

    // ── [2/5] Automated animation testing ────────────────────────────────

    /// [3/7] Random content pools for one-tap animation testing — restricted to
    /// the SAME curated base set the send row offers (the 6 with sounds wired).
    static let testEmojis = CuratedEmoji.base.map { $0.emoji }
    static let testMessages = ["thinking of you", "miss you", "almost home",
                               "love you", "☀️ for you", "saw this & smiled"]
    static let testTaglines = ["near is a feeling ✦", "across the miles ✦",
                               "quick as a thought ✦", "carried on the wind ✦",
                               "straight to you ✦"]

    /// The instruments, in the order they appear to the user, each paired with
    /// the SenderStyle its thoughts travel + land with.
    /// [registry 2026-06-13] Derived from AnimationManifest.liveInstruments (the
    /// single source of truth — one live row per instrument, in user-facing
    /// order) — was a hardcoded 7-tuple that could drift from the manifest.
    static let instrumentSequence: [(icon: String, style: SenderStyle)] =
        AnimationManifest.liveInstruments.map { (icon: $0.icon, style: $0.style) }

    /// [5/5] Send ONE test thought for EACH of the 7 instruments, in order
    /// (compass → bow → flick → rocket → wind → wand → plane). Each gets a
    /// DIFFERENT emoji from the curated base set, a random default message, and
    /// a 2-second gap between sends. They all QUEUE in the bucket (autoPlay:
    /// false — none auto-opens), so the dev can then tap "🪣 Auto-catch all" to
    /// watch all 7 receive animations play in sequence.
    @MainActor
    static func testAllAnimations(pings: PingManager) {
        let emojis = testEmojis   // the curated base set (6)
        for (i, entry) in instrumentSequence.enumerated() {
            let delay = Double(i) * 2.0    // 2 s gap between sends
            let emoji = emojis.isEmpty ? "✨" : emojis[i % emojis.count]   // distinct, cycles
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                sendTestThought(
                    pings: pings,
                    style: entry.style,
                    emoji: emoji,
                    message: testMessages.randomElement(),
                    tagline: testTaglines.randomElement(),
                    fromName: "\(entry.icon) \(entry.style.displayName) test",
                    autoPlay: false)            // queue only — Auto-catch plays them
            }
        }
    }

    /// [4/5] Auto-catch the entire bucket — plays every queued thought's full
    /// landing in sequence, auto-aligned, 2 s apart. No manual spinning.
    @MainActor
    static func autoCatchAll(pings: PingManager) {
        pings.startAutoCatch()
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
        UserDefaults.standard.set(false, forKey: "enteredViaLink")   // [build10 shot2]
    }

    /// Show onboarding again but KEEP existing data.
    static func clearOnboardingFlagOnly() {
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.set(false, forKey: "enteredViaLink")   // [build10 shot2]
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
        "enteredViaLink",           // [build10 shot2] link-arriver guest entry flag
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
        guard let sarah = people.person(forSenderID: mockFriendID.uuidString) else { return }
        let km = farAway ? 5000.0 : 0.5
        sarah.latitude  = mockCoord.latitude + km / 111.2
        sarah.longitude = mockCoord.longitude
        try? people.save()
        compass.start(tracking: sarah)   // re-track so the new distance shows now
    }
}
#endif
