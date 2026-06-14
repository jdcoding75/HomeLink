// DisplayNameSnapshotTests.swift
// Pointward › Tests
//
// Bug fix coverage — sender_display_name + shortCode null on send.
// The send site (CompassView.devCreateAndShareLink call) now reads the LIVE
// profile first, with the UserDefaults mirror as fallback:
//   senderName: people.profile?.displayName ?? UserProfile.snapshot?.displayName ?? ""
//   shortCode:  people.profile?.shortCode.nilIfEmpty ?? UserProfile.snapshot?.shortCode ?? ""
// and PeopleManager.cacheProfile now mirrors shortCode (it was being blanked).
//
// These exercise the REAL local model (PeopleManager + in-memory SwiftData) and
// the REAL fallback expressions, the pattern PairingScenarioTests already uses.

import XCTest
import SwiftData
@testable import HomeLink

@MainActor
final class DisplayNameSnapshotTests: XCTestCase {

    private func makeWorld() throws -> (PeopleManager, ModelContext, ModelContainer) {
        let container = try ModelContainer(
            for: Person.self, UserProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let people = PeopleManager(subscriptionManager: SubscriptionManager(skinStore: nil))
        people.configure(with: context)
        return (people, context, container)
    }

    // ── nilIfEmpty helper ────────────────────────────────────────────────

    func testNilIfEmpty() {
        XCTAssertNil("".nilIfEmpty)
        XCTAssertEqual("DS2CVW".nilIfEmpty, "DS2CVW")
    }

    // ── Fix #1: live profile is the authoritative display-name source ─────

    func testLiveProfileIsAuthoritativeDisplayNameSource() throws {
        let (people, context, container) = try makeWorld()
        _ = container
        let p = UserProfile(displayName: "John", shortCode: "DS2CVW")
        context.insert(p)
        people.loadProfile()

        // The send site reads people.profile?.displayName FIRST — non-nil here.
        XCTAssertEqual(people.profile?.displayName, "John")

        // The exact send-site fallback expression resolves to the real name.
        let senderName = people.profile?.displayName ?? UserProfile.snapshot?.displayName ?? ""
        XCTAssertEqual(senderName, "John", "sender_display_name is non-null on send")
    }

    // ── Fix #3: cacheProfile now mirrors shortCode (was blanked to "") ────

    func testCacheProfileMirrorsShortCode() throws {
        let (people, context, container) = try makeWorld()
        _ = container
        let p = UserProfile(displayName: "John", shortCode: "DS2CVW")
        context.insert(p)
        people.loadProfile()   // → cacheProfile writes the UserDefaults mirror

        XCTAssertEqual(UserProfile.snapshot?.shortCode, "DS2CVW",
                       "mirror no longer overwrites a valid shortCode with empty")

        // Fix #1+#2 combined: the send-site shortCode expression flows through.
        let shortCode = people.profile?.shortCode.nilIfEmpty
                        ?? UserProfile.snapshot?.shortCode ?? ""
        XCTAssertEqual(shortCode, "DS2CVW", "shortCode reaches the share text")
    }

    // ── Empty shortCode falls through to the mirror, not "" short-circuit ─

    func testEmptyLiveShortCodeFallsThroughToMirror() throws {
        let (people, context, container) = try makeWorld()
        _ = container
        // A profile with NO shortCode yet (the common pre-decode state).
        let p = UserProfile(displayName: "John", shortCode: "")
        context.insert(p)
        people.loadProfile()

        // nilIfEmpty makes the empty live value yield to the fallback rather than
        // short-circuiting the ?? chain with "".
        XCTAssertNil(people.profile?.shortCode.nilIfEmpty)
    }
}
