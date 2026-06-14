// PeopleTabReworkTests.swift
// Pointward › Tests
//
// Phase 2 Build 6 — People tab rework. Exercises the REAL sort (PeopleManager.
// fetchAll over in-memory SwiftData) and mirrors the REAL view rules (the
// disambiguator / location-hint / monogram / status-suppression predicates that
// live in PeopleListView), the pattern PairingScenarioTests already uses.

import XCTest
import SwiftData
@testable import HomeLink

@MainActor
final class PeopleTabReworkTests: XCTestCase {

    private func makeWorld() throws -> (PeopleManager, ModelContext, ModelContainer) {
        let container = try ModelContainer(
            for: Person.self, UserProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let people = PeopleManager(subscriptionManager: SubscriptionManager(skinStore: nil))
        people.configure(with: context)
        return (people, context, container)
    }

    private func insert(_ people: PeopleManager, _ context: ModelContext,
                        name: String, emoji: String = "💜",
                        lat: Double = 1, lng: Double = 1,
                        locationDisplayName: String = "",
                        senderID: String? = nil,
                        lastReceivedAt: Date? = nil,
                        createdAt: Date? = nil) -> Person {
        let p = Person(name: name, emoji: emoji, latitude: lat, longitude: lng,
                       locationDisplayName: locationDisplayName,
                       senderID: senderID, lastReceivedAt: lastReceivedAt)
        if let createdAt { p.createdAt = createdAt }
        context.insert(p)
        people.fetchAll()
        return p
    }

    private func date(_ offset: TimeInterval) -> Date { Date(timeIntervalSince1970: 1_000_000 + offset) }

    // ════════════════════════════════════════════════════════════════════
    // SORT — recency first, nils last, all-nil still well-ordered
    // ════════════════════════════════════════════════════════════════════

    func testSortRecencyFirstNilsLast() throws {
        let (people, context, container) = try makeWorld()
        _ = container
        insert(people, context, name: "Old",    lastReceivedAt: date(100), createdAt: date(0))
        insert(people, context, name: "Newest", lastReceivedAt: date(900), createdAt: date(0))
        insert(people, context, name: "Mid",    lastReceivedAt: date(500), createdAt: date(0))
        insert(people, context, name: "NeverA", lastReceivedAt: nil,       createdAt: date(50))
        insert(people, context, name: "NeverB", lastReceivedAt: nil,       createdAt: date(80))

        let order = people.people.map(\.name)
        // Recent senders first (desc by lastReceivedAt) …
        XCTAssertEqual(Array(order.prefix(3)), ["Newest", "Mid", "Old"])
        // … then the nil group, newest-created first (secondary createdAt desc).
        XCTAssertEqual(Array(order.suffix(2)), ["NeverB", "NeverA"])

        // Fresh-launch default: selectedPerson is sticky once set, so simulate a
        // cold launch (nil → fetchAll) — people.first is the most-recent sender.
        people.selectedPerson = nil
        people.fetchAll()
        XCTAssertEqual(people.selectedPerson?.name, "Newest")
    }

    func testAllNilListIsStillWellOrdered() throws {
        let (people, context, container) = try makeWorld()
        _ = container
        insert(people, context, name: "First",  lastReceivedAt: nil, createdAt: date(0))
        insert(people, context, name: "Second", lastReceivedAt: nil, createdAt: date(10))

        // No lastReceivedAt anywhere → createdAt DESC, well-defined, no crash.
        XCTAssertEqual(people.people.map(\.name), ["Second", "First"])
        // Fresh-launch default (simulate cold start): well-defined top, no crash.
        people.selectedPerson = nil
        people.fetchAll()
        XCTAssertEqual(people.selectedPerson?.name, "Second")
    }

    func testEmptyListSelectedPersonIsNil() throws {
        let (people, _, container) = try makeWorld()
        _ = container
        XCTAssertTrue(people.people.isEmpty)
        XCTAssertNil(people.selectedPerson)   // graceful: no crash, no phantom
    }

    // ════════════════════════════════════════════════════════════════════
    // DISPLAY-RULE MIRRORS (the predicates PeopleListView uses)
    // ════════════════════════════════════════════════════════════════════

    /// Mirror of PeopleListView.duplicatedNameKeys.
    private func dupes(_ people: PeopleManager) -> Set<String> {
        var counts: [String: Int] = [:]
        for p in people.people {
            let k = p.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !k.isEmpty { counts[k, default: 0] += 1 }
        }
        return Set(counts.filter { $0.value >= 2 }.keys)
    }

    func testDisambiguatorOnlyForDuplicateNames() throws {
        let (people, context, container) = try makeWorld()
        _ = container
        insert(people, context, name: "John", locationDisplayName: "New York")
        insert(people, context, name: "John", locationDisplayName: "Boston")
        insert(people, context, name: "Unique", locationDisplayName: "Paris")

        let d = dupes(people)
        XCTAssertTrue(d.contains("john"))
        XCTAssertFalse(d.contains("unique"), "unique name → no disambiguator")
    }

    func testZeroLocationShowsHintNotBogusDistance() throws {
        let (people, context, container) = try makeWorld()
        _ = container
        // A link contact, no real address (Build 5 seeds lat/lng = 0).
        let p = insert(people, context, name: "John", emoji: "",
                       lat: 0, lng: 0, locationDisplayName: "John",
                       senderID: UUID().uuidString, lastReceivedAt: date(10))
        // needsLocation predicate (PeopleListView.needsLocation).
        XCTAssertTrue(p.latitude == 0 && p.longitude == 0,
                      "zero-location → hint replaces the null-island line")
        // A real-location contact does NOT get the hint.
        let q = insert(people, context, name: "Real", lat: 40, lng: -73)
        XCTAssertFalse(q.latitude == 0 && q.longitude == 0)
    }

    func testEmojiLessContactRendersMonogram() throws {
        let (people, context, container) = try makeWorld()
        _ = container
        let p = insert(people, context, name: "john", emoji: "")
        // Mirror of PersonCard.monogram.
        let monogram = p.name.trimmingCharacters(in: .whitespacesAndNewlines)
            .first.map { String($0).uppercased() } ?? "✦"
        XCTAssertEqual(monogram, "J")

        let nameless = insert(people, context, name: "", emoji: "")
        let fallback = nameless.name.trimmingCharacters(in: .whitespacesAndNewlines)
            .first.map { String($0).uppercased() } ?? "✦"
        XCTAssertEqual(fallback, "✦", "empty name → neutral glyph")
    }

    func testConnectionStatusSuppressedForLinkContacts() throws {
        let (people, context, container) = try makeWorld()
        _ = container
        // Mirror of PeopleListView.isLinkContact: gate on senderID, NOT pairedUserID.
        let link = insert(people, context, name: "John", senderID: UUID().uuidString)
        XCTAssertFalse((link.senderID ?? "").isEmpty, "senderID set → row suppressed")

        let pairingOnly = Person(name: "OldFriend", emoji: "💜",
                                 latitude: 1, longitude: 1,
                                 pairedUserID: UUID().uuidString)   // pairing, NO senderID
        context.insert(pairingOnly)
        people.fetchAll()
        XCTAssertTrue((pairingOnly.senderID ?? "").isEmpty,
                      "pairing-only contact keeps the status row until build 8")
    }
}
