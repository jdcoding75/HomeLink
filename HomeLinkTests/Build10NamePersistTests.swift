// Build10NamePersistTests.swift
// Pointward › Tests
//
// Bug #6 coverage — display_name must persist for a NAME-ONLY profile
// (no geocoded address). Before Build 10, onboarding committed the profile
// only conditionally and the server mirror was gated on a geocoded location,
// so a user who entered just their name (the friction-free majority path)
// could finish with display_name unset — the send banner then showed no name.
//
// This guards the LOCAL invariant at its source of truth (PeopleManager):
// saveProfile with geocoded == nil must still write displayName, and the
// send-site expression must resolve to that name. (The SERVER mirror —
// SupabaseService.updateUserProfile — now writes display_name unconditionally
// too; that's a network call, exercised on-device, not unit-testable here.)
//
// Same real-model + in-memory SwiftData pattern as DisplayNameSnapshotTests.

import XCTest
import SwiftData
@testable import HomeLink

@MainActor
final class Build10NamePersistTests: XCTestCase {

    private func makeWorld() throws -> (PeopleManager, ModelContext, ModelContainer) {
        let container = try ModelContainer(
            for: Person.self, UserProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let people = PeopleManager(subscriptionManager: SubscriptionManager(skinStore: nil))
        people.configure(with: context)
        return (people, context, container)
    }

    // ── #6: a name-only profile (no geocode) still persists display_name ──

    func testNameOnlyProfilePersistsDisplayName() throws {
        let (people, context, container) = try makeWorld()
        _ = (context, container)

        // The friction-free path: name + emoji, NO geocoded location.
        let saved = people.saveProfile(name: "Joshua", emoji: "🙂", geocoded: nil)

        // display_name is written unconditionally — not gated on a location.
        XCTAssertEqual(saved.displayName, "Joshua")
        XCTAssertEqual(people.profile?.displayName, "Joshua",
                       "display_name persists for a name-only profile (#6)")

        // No location was provided → the 0,0 placeholder stands (name was the only ask).
        XCTAssertFalse(saved.hasLocation,
                       "name-only profile carries no location, yet display_name still persists")

        // The send-site source expression resolves to the real name (non-null banner).
        let senderName = people.profile?.displayName ?? UserProfile.snapshot?.displayName ?? ""
        XCTAssertEqual(senderName, "Joshua", "sender_display_name is non-null on send (#6)")
    }
}
