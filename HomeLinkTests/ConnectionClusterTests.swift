// ConnectionClusterTests.swift
// Pointward › Tests
//
// Pairing-cluster harness (P1 + P2 + P3 logic) — verifies the connection state
// machine WITHOUT two phones. The server layer (record_connection / delete RLS /
// fetchMyConnections / link_connections row state) is verified directly against
// Supabase; real APNs-to-closed-app, true cold install, UI/animation, and the live
// realtime socket stay in the short MANUAL-ONLY checklist (see
// reports/connection_test_harness.md). These tests cover the deterministic LOCAL
// logic over an in-memory SwiftData store + a mocked ConnectionService
// ([conn-di-seam]), so the delete/fallback SUCCESS paths are unit-tested too.

import XCTest
import SwiftData
@testable import HomeLink

/// Mock for the injected ConnectionService — records calls, returns canned results.
private final class MockConnectionService: ConnectionService {
    var profile: SupabaseService.PublicProfile?
    var deleteResult: Bool
    private(set) var profileFetches: [UUID] = []
    private(set) var deletedOthers: [UUID] = []
    init(profile: SupabaseService.PublicProfile? = nil, deleteResult: Bool = true) {
        self.profile = profile
        self.deleteResult = deleteResult
    }
    func fetchPublicProfile(of user: UUID) async -> SupabaseService.PublicProfile? {
        profileFetches.append(user); return profile
    }
    func deleteConnection(other: UUID) async -> Bool {
        deletedOthers.append(other); return deleteResult
    }
}

@MainActor
final class ConnectionClusterTests: XCTestCase {

    // ── In-memory world (Person + SentLink) + injected connection service ──
    private func makeWorld(connection: ConnectionService = MockConnectionService())
        throws -> (PeopleManager, ModelContext) {
        let container = try ModelContainer(
            for: Person.self, SentLink.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let people = PeopleManager(subscriptionManager: SubscriptionManager(skinStore: nil),
                                   connectionService: connection)
        people.configure(with: context)
        return (people, context)
    }
    private func row(connected: UUID, via: UUID) -> SupabaseService.LinkConnection {
        SupabaseService.LinkConnection(connectedUserID: connected, viaMessageID: via, connectedAt: .now)
    }

    // 1 — DEDUP: one contact per user id (upsertContact / person(forSenderID:))
    func testUpsertDedupsOnSenderID() throws {
        let (people, _) = try makeWorld()
        let y = UUID().uuidString
        let a = people.upsertContact(senderID: y, displayName: "John")
        let b = people.upsertContact(senderID: y, displayName: "John again")
        XCTAssertEqual(people.people.count, 1)
        XCTAssertEqual(a?.id, b?.id, "same id → found + updated, not duplicated")
        people.upsertContact(senderID: UUID().uuidString, displayName: "Other")
        XCTAssertEqual(people.people.count, 2, "new id → new contact")
    }

    // 2 — stampConnections SentLink (warm) path
    func testStampWarmPath() async throws {
        let (people, ctx) = try makeWorld()
        let target = Person(name: "Wife", latitude: 0, longitude: 0); ctx.insert(target)
        let mX = UUID(); ctx.insert(SentLink(messageID: mX, personID: target.id))
        try ctx.save(); people.fetchAll()
        let y = UUID()
        await people.stampConnections([row(connected: y, via: mX)])
        XCTAssertEqual(people.person(forSenderID: y.uuidString)?.id, target.id)
        XCTAssertEqual(target.pairedUserID, y.uuidString, "pairedUserID mirror set")
        XCTAssertEqual(people.people.count, 1, "no new contact")
    }

    // 3 — 256e854 fallback (no SentLink) resolves via server profile → makeActive:false + dedup
    func testFallbackResolvesProfileMakeActiveFalseNoDup() async throws {
        let mock = MockConnectionService(
            profile: SupabaseService.PublicProfile(displayName: "Alice", emoji: nil,
                                                   latitude: 40.0, longitude: -74.0))
        let (people, _) = try makeWorld(connection: mock)
        let active = people.upsertContact(senderID: UUID().uuidString, displayName: "Active")
        let y = UUID()
        await people.stampConnections([row(connected: y, via: UUID())])   // no SentLink → fallback
        let surfaced = try XCTUnwrap(people.person(forSenderID: y.uuidString))
        XCTAssertEqual(surfaced.name, "Alice", "name resolved from server profile")
        XCTAssertEqual(surfaced.latitude, 40.0, accuracy: 0.0001, "location applied from profile")
        XCTAssertEqual(people.selectedPerson?.id, active?.id, "fallback did NOT change the active person")
        XCTAssertEqual(mock.profileFetches, [y], "resolved the OTHER user via profile")
        await people.stampConnections([row(connected: y, via: UUID())])
        XCTAssertEqual(people.people.filter { $0.senderID == y.uuidString }.count, 1, "no dup on repeat")
    }

    // 4 — P1(b) SAME-ID GUARD: a SentLink can't stamp Y onto a 2nd contact when B already holds Y
    func testSameIDGuardSkipsSecondHolder() async throws {
        let (people, ctx) = try makeWorld()
        let y = UUID()
        let b = try XCTUnwrap(people.upsertContact(senderID: y.uuidString, displayName: "B-holder"))
        let a = Person(name: "A-target", latitude: 0, longitude: 0); ctx.insert(a)
        let mX = UUID(); ctx.insert(SentLink(messageID: mX, personID: a.id))
        try ctx.save(); people.fetchAll()
        await people.stampConnections([row(connected: y, via: mX)])
        XCTAssertNil(a.senderID, "A NOT stamped (guard skipped the second holder)")
        XCTAssertEqual(people.person(forSenderID: y.uuidString)?.id, b.id, "only B holds Y")
    }

    // 5 — P1(d) "(2)" suffix (display-only; raw Person.name unchanged; rename clears it)
    func testDisambiguatedName() throws {
        let (people, _) = try makeWorld()
        let first  = try XCTUnwrap(people.upsertContact(senderID: UUID().uuidString, displayName: "Alex"))
        let second = try XCTUnwrap(people.upsertContact(senderID: UUID().uuidString, displayName: "Alex"))
        first.createdAt  = Date(timeIntervalSince1970: 1000)
        second.createdAt = Date(timeIntervalSince1970: 2000)
        try people.save()
        XCTAssertEqual(people.disambiguatedName(for: first),  "Alex")
        XCTAssertEqual(people.disambiguatedName(for: second), "Alex (2)")
        XCTAssertEqual(first.name,  "Alex")
        XCTAssertEqual(second.name, "Alex", "raw Person.name is NEVER decorated")
        second.name = "Alexa"; try people.save()
        XCTAssertEqual(people.disambiguatedName(for: first), "Alex", "rename clears the collision → no suffix")
    }

    // 6 — P1(c) same-id annotation
    func testSameIDOtherName() throws {
        let (people, ctx) = try makeWorld()
        let y = UUID().uuidString
        let one = try XCTUnwrap(people.upsertContact(senderID: y, displayName: "Mom"))
        let two = Person(name: "Jess", latitude: 0, longitude: 0, senderID: y)   // direct insert (upsert would dedup)
        ctx.insert(two); try ctx.save(); people.fetchAll()
        XCTAssertEqual(people.sameIDOtherName(for: one), "Jess")
        XCTAssertEqual(people.sameIDOtherName(for: two), "Mom")
        let solo = try XCTUnwrap(people.upsertContact(senderID: UUID().uuidString, displayName: "Solo"))
        XCTAssertNil(people.sameIDOtherName(for: solo), "unique id → no annotation")
    }

    // 7a — P2 delete: manual contact (no senderID) → local-only, NO server call
    func testDeleteManualIsLocalOnly() async throws {
        let mock = MockConnectionService()
        let (people, ctx) = try makeWorld(connection: mock)
        let manual = Person(name: "Manual", latitude: 0, longitude: 0); ctx.insert(manual)
        try ctx.save(); people.fetchAll()
        try await people.deletePerson(manual)
        XCTAssertTrue(people.people.isEmpty)
        XCTAssertTrue(mock.deletedOthers.isEmpty, "manual (no senderID) → NO server disconnect call")
    }

    // 7b — P2 delete: connected, server disconnect FAILS → throws + NOT deleted (no re-surface window)
    func testDeleteConnectedFailsClosed() async throws {
        let mock = MockConnectionService(deleteResult: false)
        let (people, _) = try makeWorld(connection: mock)
        let c = try XCTUnwrap(people.upsertContact(senderID: UUID().uuidString, displayName: "Connected"))
        let other = try XCTUnwrap(UUID(uuidString: c.senderID ?? ""))
        do {
            try await people.deletePerson(c)
            XCTFail("expected disconnectFailed when the server disconnect fails")
        } catch PeopleManager.PeopleError.disconnectFailed {
            XCTAssertEqual(people.people.count, 1, "NOT deleted on disconnect failure")
            XCTAssertEqual(mock.deletedOthers, [other], "attempted the server disconnect FIRST")
        }
    }

    // 7c — P2 delete: connected, server disconnect SUCCEEDS → local delete proceeds (ordering)
    func testDeleteConnectedSuccessDeletes() async throws {
        let mock = MockConnectionService(deleteResult: true)
        let (people, _) = try makeWorld(connection: mock)
        let c = try XCTUnwrap(people.upsertContact(senderID: UUID().uuidString, displayName: "Connected"))
        let other = try XCTUnwrap(UUID(uuidString: c.senderID ?? ""))
        try await people.deletePerson(c)
        XCTAssertTrue(people.people.isEmpty, "server disconnect ✓ → local delete proceeds")
        XCTAssertEqual(mock.deletedOthers, [other], "disconnected the right user, server-first")
    }

    // ── S1–S5: reconnect / churn class (reports/connection_state_audit.md §4) ──

    // S1 — clean connect → green (warm SentLink resolves a live contact)
    func testS1_cleanConnectGreens() async throws {
        let (people, ctx) = try makeWorld()
        let target = Person(name: "Wife", latitude: 0, longitude: 0); ctx.insert(target)
        let m = UUID(); ctx.insert(SentLink(messageID: m, personID: target.id))
        try ctx.save(); people.fetchAll()
        let y = UUID()
        await people.stampConnections([row(connected: y, via: m)])
        XCTAssertEqual(people.person(forSenderID: y.uuidString)?.id, target.id, "clean connect → contact greens")
    }

    // S2 — delete→reconnect (THE BUG): dangling SentLink (OLD→missing person) + stale row(via=OLD)
    //      → POST-FIX falls through to connected_user_id → the sender re-greens.
    func testS2_deleteReconnectGreensViaFallback() async throws {
        let mock = MockConnectionService(
            profile: SupabaseService.PublicProfile(displayName: "Jess", emoji: nil, latitude: nil, longitude: nil))
        let (people, ctx) = try makeWorld(connection: mock)
        let oldMsg = UUID()
        ctx.insert(SentLink(messageID: oldMsg, personID: UUID()))   // DANGLING: no Person for this personID
        try ctx.save(); people.fetchAll()
        let y = UUID()
        await people.stampConnections([row(connected: y, via: oldMsg)])
        let greened = try XCTUnwrap(people.person(forSenderID: y.uuidString),
                                    "sender re-greens despite dangling SentLink + stale via")
        XCTAssertEqual(greened.name, "Jess", "stamped from the server profile (connected_user_id fallback)")
    }

    // S3 — one-sided-deleted: my (me,Y) row is gone → no row for Y in my fetch → Y not greened
    func testS3_oneSidedDeletedNotGreen() async throws {
        let (people, _) = try makeWorld()
        let y = UUID()
        await people.stampConnections([])   // fetchMyConnections (sender_id=me) returns nothing for Y
        XCTAssertNil(people.person(forSenderID: y.uuidString), "no row for Y → not greened")
    }

    // S4 — both-connected: each side greens the other (two independent in-memory worlds)
    func testS4_bothConnected() async throws {
        let mockJohn = MockConnectionService(
            profile: SupabaseService.PublicProfile(displayName: "Jess", emoji: nil, latitude: nil, longitude: nil))
        let mockJess = MockConnectionService(
            profile: SupabaseService.PublicProfile(displayName: "John", emoji: nil, latitude: nil, longitude: nil))
        let (john, _) = try makeWorld(connection: mockJohn)
        let (jess, _) = try makeWorld(connection: mockJess)
        let jessID = UUID(); let johnID = UUID()
        await john.stampConnections([row(connected: jessID, via: UUID())])   // no SentLink → fallback
        await jess.stampConnections([row(connected: johnID, via: UUID())])
        XCTAssertNotNil(john.person(forSenderID: jessID.uuidString), "John greens Jess")
        XCTAssertNotNil(jess.person(forSenderID: johnID.uuidString), "Jess greens John")
    }

    // S5 — churn / stale-SentLink with an already-connected contact → idempotent, no dup, stays green
    func testS5_churnStaleSentLinkNoDup() async throws {
        let mock = MockConnectionService(
            profile: SupabaseService.PublicProfile(displayName: "Y", emoji: nil, latitude: nil, longitude: nil))
        let (people, ctx) = try makeWorld(connection: mock)
        let y = UUID()
        _ = try XCTUnwrap(people.upsertContact(senderID: y.uuidString, displayName: "Mom"))   // already connected
        let staleMsg = UUID(); ctx.insert(SentLink(messageID: staleMsg, personID: UUID()))   // dangling
        try ctx.save(); people.fetchAll()
        await people.stampConnections([row(connected: y, via: staleMsg)])
        XCTAssertEqual(people.people.filter { $0.senderID == y.uuidString }.count, 1, "no duplicate under churn")
        XCTAssertNotNil(people.person(forSenderID: y.uuidString), "stays green")
    }

    // ── [contacts-pick] cluster ──────────────────────────────────────────────

    // 2b — CONFIRMING TEST (locks the decided "no change"): the same-id annotation is
    // NAME-AGNOSTIC — two contacts that share a senderID under CLEARLY different names
    // still annotate each other (so the dup-on-rename "JD/Momma" case WOULD surface IF
    // both carried the id; it doesn't only because the typed one has no senderID).
    func testSameIDAnnotationFiresAcrossDifferentNames() throws {
        let (people, ctx) = try makeWorld()
        let y = UUID().uuidString
        let momma = try XCTUnwrap(people.upsertContact(senderID: y, displayName: "Momma"))
        let jd = Person(name: "JD", latitude: 0, longitude: 0, senderID: y)   // direct insert; upsert would dedup
        ctx.insert(jd); try ctx.save(); people.fetchAll()
        XCTAssertEqual(people.sameIDOtherName(for: momma), "JD", "fires across different names")
        XCTAssertEqual(people.sameIDOtherName(for: jd), "Momma")
    }

    // [contacts-pick] 1c — defaultSendChannel: phone (SMS) first, email fallback, nil when neither.
    func testDefaultSendChannel() {
        XCTAssertEqual(PeopleManager.defaultSendChannel(phone: "+1 555 0100", email: "a@b.com"), "sms",
                       "phone present → SMS first")
        XCTAssertEqual(PeopleManager.defaultSendChannel(phone: nil, email: "a@b.com"), "email",
                       "no phone → email fallback")
        XCTAssertEqual(PeopleManager.defaultSendChannel(phone: "   ", email: "a@b.com"), "email",
                       "blank phone is ignored → email")
        XCTAssertNil(PeopleManager.defaultSendChannel(phone: nil, email: nil), "neither → nil")
        XCTAssertNil(PeopleManager.defaultSendChannel(phone: "", email: "  "), "both blank → nil")
    }
}
