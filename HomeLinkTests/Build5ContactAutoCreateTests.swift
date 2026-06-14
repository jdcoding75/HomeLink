// Build5ContactAutoCreateTests.swift
// Pointward › Tests
//
// Phase 2 Build 5 — contact auto-create ON RECEIVE (senderID-keyed, silent).
//
// Exercises the REAL local model: PeopleManager.upsertContact + Person over an
// in-memory SwiftData store. Network fetch (getMessage / getUnopenedForShortCode)
// can't run in a unit test, so the short-code "N messages → one contact" case
// mirrors the EXACT view rule (ShortCodeEntryView.handle → ShortCodeClaim.split →
// a single upsert), the pattern PairingScenarioTests already uses.

import XCTest
import SwiftData
import CoreLocation
@testable import HomeLink

@MainActor
final class Build5ContactAutoCreateTests: XCTestCase {

    // ── In-memory world ──────────────────────────────────────────────────

    private func makeWorld() throws -> (PeopleManager, ModelContext, ModelContainer) {
        let container = try ModelContainer(
            for: Person.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let people = PeopleManager(subscriptionManager: SubscriptionManager(skinStore: nil))
        people.configure(with: context)
        return (people, context, container)
    }

    private func message(senderID: UUID, name: String?) -> Message {
        Message(id: UUID(), senderID: senderID, senderDisplayName: name,
                content: "hi", emoji: "🤗", instrument: "compass",
                opened: false, openedAt: nil, createdAt: nil)
    }

    // ════════════════════════════════════════════════════════════════════
    // CREATE
    // ════════════════════════════════════════════════════════════════════

    func testUpsertCreatesContactOnFirstSenderID() throws {
        let (people, _, container) = try makeWorld()
        _ = container
        let sid = UUID().uuidString

        let p = people.upsertContact(senderID: sid, displayName: "John")

        XCTAssertNotNil(p)
        XCTAssertEqual(people.people.count, 1, "first send → exactly one contact")
        XCTAssertEqual(p?.senderID, sid, "senderID is the immutable key")
        XCTAssertEqual(p?.pairedUserID, sid, "mirror-write bridge for today's bucket")
        XCTAssertEqual(p?.name, "John")
        XCTAssertEqual(p?.emoji, "", "auto-created contacts have NO emoji")
        XCTAssertNotNil(p?.lastReceivedAt, "lastReceivedAt populated for Build 6 sort")
        XCTAssertNotNil(p?.tagline, "every contact gets a voice")
    }

    func testEmptySenderIDIsRejected() throws {
        let (people, _, container) = try makeWorld()
        _ = container
        XCTAssertNil(people.upsertContact(senderID: "", displayName: "X"))
        XCTAssertTrue(people.people.isEmpty, "no contact for a missing senderID")
    }

    func testDistinctSendersMakeDistinctContacts() throws {
        let (people, _, container) = try makeWorld()
        _ = container
        people.upsertContact(senderID: UUID().uuidString, displayName: "A")
        people.upsertContact(senderID: UUID().uuidString, displayName: "B")
        XCTAssertEqual(people.people.count, 2, "different senderIDs → different contacts")
    }

    // ════════════════════════════════════════════════════════════════════
    // UPDATE (dedup) — one sender never becomes many contacts
    // ════════════════════════════════════════════════════════════════════

    func testRepeatSenderUpdatesNotDuplicates() throws {
        let (people, _, container) = try makeWorld()
        _ = container
        let sid = UUID().uuidString

        let first = people.upsertContact(senderID: sid, displayName: "John")
        let firstStamp = try XCTUnwrap(first?.lastReceivedAt)
        let second = people.upsertContact(senderID: sid, displayName: "John")

        XCTAssertEqual(people.people.count, 1, "same sender → still ONE contact")
        XCTAssertEqual(first?.id, second?.id, "the same Person is returned + updated")
        let secondStamp = try XCTUnwrap(second?.lastReceivedAt)
        XCTAssertGreaterThanOrEqual(secondStamp, firstStamp, "recency bumped, not reset")
    }

    func testClaimingNMessagesFromOneSenderMakesOneContact() throws {
        let (people, _, container) = try makeWorld()
        _ = container
        let sid = UUID()

        // The view rule: a short-code claim returns N unopened from ONE sender;
        // ShortCodeEntryView.handle upserts the claimed sender exactly ONCE.
        let claimed = (0..<4).map { message(senderID: sid, name: "John #\($0)") }
        let (newest, rest) = ShortCodeClaim.split(claimed)
        if let sender = newest ?? rest.first {
            people.upsertContact(senderID: sender.senderID.uuidString,
                                 displayName: sender.senderDisplayName)
        }
        XCTAssertEqual(people.people.count, 1, "4 messages, one sender → ONE contact")

        // Defence in depth: even if upsert were called per-message, the senderID
        // dedup still collapses them to one.
        for m in claimed {
            people.upsertContact(senderID: m.senderID.uuidString,
                                 displayName: m.senderDisplayName)
        }
        XCTAssertEqual(people.people.count, 1, "per-message calls still dedup to ONE")
    }

    // ════════════════════════════════════════════════════════════════════
    // RENAME OWNERSHIP — recipient owns their local name
    // ════════════════════════════════════════════════════════════════════

    func testManualRenameIsNotOverwrittenByLaterAutoUpdate() throws {
        let (people, _, container) = try makeWorld()
        _ = container
        let sid = UUID().uuidString

        let p = try XCTUnwrap(people.upsertContact(senderID: sid, displayName: "John"))
        // The recipient renames their local copy.
        p.name = "Dad"
        try people.save()

        // The same sender sends again with their own (different) display name.
        people.upsertContact(senderID: sid, displayName: "John Q. Sender")

        XCTAssertEqual(people.people.count, 1)
        XCTAssertEqual(p.name, "Dad", "a manual rename is NEVER overwritten")
    }

    func testBlankAutoNameIsFilledByALaterMessage() throws {
        let (people, _, container) = try makeWorld()
        _ = container
        let sid = UUID().uuidString

        // First message had no display name → contact created nameless.
        let p = try XCTUnwrap(people.upsertContact(senderID: sid, displayName: nil))
        XCTAssertEqual(p.name, "")

        // A later message carries a name → we FILL the blank (not a rename).
        people.upsertContact(senderID: sid, displayName: "John")
        XCTAssertEqual(p.name, "John", "an empty auto-name is filled when one arrives")
        XCTAssertEqual(people.people.count, 1)
    }

    // ════════════════════════════════════════════════════════════════════
    // LOOKUP
    // ════════════════════════════════════════════════════════════════════

    func testPersonForSenderIDResolvesTheContact() throws {
        let (people, _, container) = try makeWorld()
        _ = container
        let sid = UUID().uuidString
        let created = people.upsertContact(senderID: sid, displayName: "John")
        XCTAssertEqual(people.person(forSenderID: sid)?.id, created?.id)
        XCTAssertNil(people.person(forSenderID: UUID().uuidString), "unknown senderID → nil")
    }
}
