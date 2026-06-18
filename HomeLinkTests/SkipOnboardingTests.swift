// SkipOnboardingTests.swift
// Pointward › Tests
//
// [4/6] REGRESSION GUARD — the `-skipOnboarding` developer path must ALWAYS
// land on the compass with mock Sarah: onboarding marked complete, Sarah in
// SwiftData, Sarah selected, and the mock connection set. This had been
// regressing from concurrent builds, so the contract is locked down here.
//
// The test exercises the SAME injection function RootView calls
// (DevTools.injectMockData) plus the onboarding-flag flip that
// PointwardApp/RootView perform — without spinning up the full app.

import XCTest
import SwiftData
@testable import HomeLink

@MainActor
final class SkipOnboardingTests: XCTestCase {

    /// A fresh PeopleManager + PingManager backed by an in-memory store, with
    /// a clean local identity cache (no leftover Sarah/connection).
    private func makeWorld() throws -> (PeopleManager, PingManager, ModelContainer) {
        let container = try ModelContainer(
            for: Person.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let people = PeopleManager(subscriptionManager: SubscriptionManager(skinStore: nil))
        people.configure(with: ModelContext(container))
        let pings = PingManager(networkService: MockNetworkService())

        // Clean slate — these are UserDefaults-backed statics.
        // [pairing-retire step6] connectedFriendID reset removed (var deleted).
        SupabaseService.localUserID = nil
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")

        return (people, pings, container)
    }

    func testSkipOnboardingInjectsSarah() throws {
        let (people, pings, container) = try makeWorld()
        _ = container

        // RootView/PointwardApp flip the onboarding flag, then inject the mock.
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        DevTools.injectMockData(people: people, pings: pings, withHistory: false)

        // 1 — onboarding is marked complete.
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"),
                      "skip-onboarding must mark onboarding complete")

        // 2 — Sarah exists in SwiftData.
        // [9b · B3] migrated person(forPairedUserID:) → person(forSenderID:) — Sarah's
        // mirror-write keeps pairedUserID == senderID, so this is behavior-identical.
        let sarah = people.person(forSenderID: DevTools.mockFriendID.uuidString)
        XCTAssertNotNil(sarah, "Sarah must be injected into SwiftData")
        XCTAssertEqual(sarah?.name, DevTools.mockName)
        XCTAssertEqual(sarah?.latitude ?? 0, DevTools.mockCoord.latitude, accuracy: 0.0001,
                       "Sarah points toward New York")
        XCTAssertEqual(sarah?.longitude ?? 0, DevTools.mockCoord.longitude, accuracy: 0.0001)

        // 3 — Sarah is the selected person (the compass tracks her).
        XCTAssertEqual(people.selectedPerson?.id, sarah?.id,
                       "Sarah must be the selected person")

        // 4 — the mock connection is set. [pairing-retire step6] the pairing-era
        // connectedFriendID assertion removed (var deleted); the LINK-era key
        // (senderID, mirrored to pairedUserID) is the connection of record.
        XCTAssertEqual(sarah?.pairedUserID, DevTools.mockFriendID.uuidString,
                       "Sarah's card must carry the mock connection")
        XCTAssertEqual(sarah?.senderID, DevTools.mockFriendID.uuidString,
                       "Sarah's card must carry the mock senderID (link-era connection)")
    }

    /// Re-running injection (every launch re-checks the arg) must not create a
    /// second Sarah — the contract is idempotent.
    func testSkipOnboardingIsIdempotent() throws {
        let (people, pings, container) = try makeWorld()
        _ = container

        DevTools.injectMockData(people: people, pings: pings, withHistory: false)
        DevTools.injectMockData(people: people, pings: pings, withHistory: false)

        let sarahs = people.people.filter { $0.pairedUserID == DevTools.mockFriendID.uuidString }
        XCTAssertEqual(sarahs.count, 1, "re-injecting must not duplicate Sarah")
    }
}
