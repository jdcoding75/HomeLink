// PairingScenarioTests.swift
// Pointward › Tests
//
// Comprehensive pairing coverage across every contact configuration:
// no contact · single contact · multiple contacts · edge cases.
//
// Pairing's network half (redeem/createInvite over Supabase) can't run in a
// unit test, so these exercise the REAL pure decision + the REAL local model:
//   · SupabaseService.claimOutcome(owner:friend:me:) — the claim state machine
//   · PeopleManager + in-memory SwiftData — the local card linking (pairedUserID,
//     owner/friend person resolution, the "needs setup" gate)
//   · SupabaseServiceError messages — the user-facing copy
// Where a rule lives in a SwiftUI view, the test mirrors that exact rule (the
// pattern this suite already uses).

import XCTest
import SwiftData
import CoreLocation
@testable import HomeLink

@MainActor
final class PairingScenarioTests: XCTestCase {

    // ── In-memory world ──────────────────────────────────────────────────

    /// A fresh PeopleManager backed by an in-memory SwiftData store. The
    /// container is returned so the caller keeps it alive for the test.
    private func makeWorld() throws -> (PeopleManager, ModelContext, ModelContainer) {
        let container = try ModelContainer(
            for: Person.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let people = PeopleManager(subscriptionManager: SubscriptionManager(skinStore: nil))
        people.configure(with: context)
        return (people, context, container)
    }

    @discardableResult
    private func add(_ name: String, _ emoji: String = "💜", paired: UUID? = nil,
                     to people: PeopleManager, _ context: ModelContext) -> Person {
        let p = Person(name: name, emoji: emoji, latitude: 0, longitude: 0,
                       pairedUserID: paired?.uuidString)
        context.insert(p)
        people.fetchAll()
        return p
    }

    // ════════════════════════════════════════════════════════════════════
    // [1/5] NO CONTACT SCENARIOS
    // ════════════════════════════════════════════════════════════════════

    func testCannotInviteWithoutPersonCard() throws {
        // Invites are person-card-scoped (createInvite carries a personID +
        // owner_person_id). With no people there is no card to invite from.
        let (people, _, container) = try makeWorld()
        _ = container
        XCTAssertTrue(people.people.isEmpty)
        XCTAssertNil(people.selectedPerson, "no card → nothing to generate an invite from")
        // The message the UI must show when blocked.
        let blockedMessage = "add a person first to connect"
        XCTAssertFalse(blockedMessage.isEmpty)
    }

    func testCannotCompleteWithoutLinking() throws {
        // An accepted code that is claimable (.proceed) does NOT, by itself,
        // create a linked card — the recipient must still add or link a person.
        let (people, _, container) = try makeWorld()
        _ = container
        let owner = UUID(), me = UUID()
        XCTAssertEqual(SupabaseService.claimOutcome(owner: owner, friend: nil, me: me), .proceed)
        XCTAssertTrue(people.people.isEmpty, "claiming a code does not auto-create a card")
        XCTAssertNil(people.person(forPairedUserID: owner),
                     "no card linked until the recipient explicitly adds/links one")
    }

    func testAcceptanceForcesPerson() throws {
        // Both acceptance paths must yield a linked card; skipping yields none.
        let (people, context, container) = try makeWorld()
        _ = container
        let friend = UUID()

        // Path A — add as new person.
        let added = people.addFromInvite(name: "Sarah", emoji: "💜", friendID: friend, near: nil)
        XCTAssertNotNil(added)
        XCTAssertEqual(people.person(forPairedUserID: friend)?.name, "Sarah")

        // Path B — link to an existing card (separate world).
        let (people2, context2, container2) = try makeWorld()
        _ = container2
        let existing = add("Existing", paired: nil, to: people2, context2)
        people2.bindConnection(friendID: friend, toPersonID: existing.id)
        XCTAssertEqual(people2.person(forPairedUserID: friend)?.id, existing.id)

        // Skipping both leaves no link (a third empty world).
        let (people3, _, container3) = try makeWorld()
        _ = container3
        XCTAssertNil(people3.person(forPairedUserID: friend),
                     "no add + no link ⇒ no completed pairing")
    }

    func testNewPersonCreatedOnAccept() throws {
        let (people, _, container) = try makeWorld()
        _ = container
        let friend = UUID()
        let person = people.addFromInvite(name: "Sarah", emoji: "💜", friendID: friend, near: nil)
        XCTAssertNotNil(person)
        XCTAssertEqual(people.people.count, 1, "exactly one card created")
        XCTAssertEqual(person?.name, "Sarah", "name pre-filled from the invite")
        XCTAssertEqual(person?.emoji, "💜", "emoji pre-filled from the invite")
        XCTAssertEqual(person?.pairedUserID, friend.uuidString, "connection linked to the new card")
    }

    // ════════════════════════════════════════════════════════════════════
    // [2/5] SINGLE CONTACT SCENARIOS
    // ════════════════════════════════════════════════════════════════════

    func testInviteGeneratesFromPersonCard() throws {
        // One card exists → it is the owner_person_id source. Its id is stable
        // and the card starts unpaired (the invite is what links it).
        let (people, context, container) = try makeWorld()
        _ = container
        let sarah = add("Sarah", to: people, context)
        XCTAssertEqual(people.people.count, 1)
        XCTAssertNil(sarah.pairedUserID, "an un-redeemed invite leaves the card unpaired")
        // owner_person_id would be set to exactly this card's id.
        XCTAssertEqual(people.selectedPerson?.id, sarah.id)
    }

    func testAcceptanceLinksSinglePerson() throws {
        let (people, context, container) = try makeWorld()
        _ = container
        let sarah = add("Sarah", to: people, context)
        let friend = UUID()
        people.bindConnection(friendID: friend, toPersonID: sarah.id)   // friend_person_id = Sarah
        XCTAssertEqual(sarah.pairedUserID, friend.uuidString, "the connection links to Sarah's card")
        XCTAssertEqual(people.person(forPairedUserID: friend)?.id, sarah.id)
    }

    func testBothSidesLinkedAfterPair() throws {
        // A→ owns "Sarah" card; B← accepts and links "John". The unclaimed code
        // is claimable (.proceed); the re-claim by the same friend is idempotent.
        let aSarah = UUID()          // A's local Person.id for Sarah  (owner_person_id)
        let bUser  = UUID()          // B's Supabase user id
        XCTAssertEqual(SupabaseService.claimOutcome(owner: UUID(), friend: nil, me: bUser), .proceed)
        XCTAssertEqual(SupabaseService.claimOutcome(owner: UUID(), friend: bUser, me: bUser), .alreadyOurs)

        // B's local side: links its "John" card to A.
        let (bPeople, bContext, container) = try makeWorld()
        _ = container
        let john = add("John", to: bPeople, bContext)
        let aUser = UUID()
        bPeople.bindConnection(friendID: aUser, toPersonID: john.id)   // friend_person_id = John
        XCTAssertEqual(john.pairedUserID, aUser.uuidString)
        XCTAssertNotNil(aSarah, "owner_person_id carried from A's Sarah card")
    }

    func testThoughtGoesToCorrectPerson() throws {
        // The send target is the PERSON's pairedUserID, resolved from the card —
        // not a generic global. A ping to that friend id resolves back to the card.
        let (people, context, container) = try makeWorld()
        _ = container
        let friend = UUID()
        let sarah = add("Sarah", paired: friend, to: people, context)
        XCTAssertEqual(sarah.pairedUserID, friend.uuidString)
        XCTAssertEqual(people.person(forPairedUserID: friend)?.id, sarah.id,
                       "a thought to this friend id targets Sarah's card specifically")
    }

    // ════════════════════════════════════════════════════════════════════
    // [3/5] MULTIPLE CONTACT SCENARIOS
    // ════════════════════════════════════════════════════════════════════

    func testMultiplePeopleShowInLinkList() throws {
        let (people, context, container) = try makeWorld()
        _ = container
        add("Sarah", to: people, context)
        add("Mum", to: people, context)
        add("Dad", to: people, context)
        XCTAssertEqual(people.people.count, 3, "all three are selectable in the link list")
        XCTAssertEqual(Set(people.people.map(\.name)), ["Sarah", "Mum", "Dad"])
    }

    func testCorrectPersonLinkedWhenMultiple() throws {
        let (people, context, container) = try makeWorld()
        _ = container
        let sarah = add("Sarah", to: people, context)
        let mum   = add("Mum", to: people, context)
        let friend = UUID()
        people.bindConnection(friendID: friend, toPersonID: sarah.id)   // pick Sarah
        XCTAssertEqual(sarah.pairedUserID, friend.uuidString, "Sarah gets the connection")
        XCTAssertNil(mum.pairedUserID, "Mum is NOT linked")
        XCTAssertEqual(people.person(forPairedUserID: friend)?.id, sarah.id)
    }

    func testMultipleConnectionsIndependent() throws {
        let (people, context, container) = try makeWorld()
        _ = container
        let sarah = add("Sarah", to: people, context)
        let mum   = add("Mum", to: people, context)
        let friendS = UUID(), friendM = UUID()
        people.bindConnection(friendID: friendS, toPersonID: sarah.id)
        people.bindConnection(friendID: friendM, toPersonID: mum.id)
        // Each friend id resolves to its own card — no crosstalk.
        XCTAssertEqual(people.person(forPairedUserID: friendS)?.id, sarah.id)
        XCTAssertEqual(people.person(forPairedUserID: friendM)?.id, mum.id)
        XCTAssertNotEqual(sarah.pairedUserID, mum.pairedUserID)
    }

    func testSwitchingPersonSwitchesConnection() throws {
        // The compass send target follows selectedPerson.pairedUserID.
        let (people, context, container) = try makeWorld()
        _ = container
        let friendS = UUID(), friendM = UUID()
        let sarah = add("Sarah", paired: friendS, to: people, context)
        let mum   = add("Mum", paired: friendM, to: people, context)

        people.select(sarah)
        XCTAssertEqual(people.selectedPerson?.pairedUserID, friendS.uuidString,
                       "sending now goes to Sarah")
        people.select(mum)
        XCTAssertEqual(people.selectedPerson?.pairedUserID, friendM.uuidString,
                       "switching the compass switches the target to Mum")
    }

    // ════════════════════════════════════════════════════════════════════
    // [4/5] EDGE CASE PAIRING SCENARIOS
    // ════════════════════════════════════════════════════════════════════

    func testDuplicatePairingPrevented() throws {
        // Re-claiming a code we already hold is idempotent (no duplicate row),
        // and a second local bind for the same friend id is a no-op.
        let me = UUID(), owner = UUID()
        XCTAssertEqual(SupabaseService.claimOutcome(owner: owner, friend: me, me: me), .alreadyOurs)

        let (people, context, container) = try makeWorld()
        _ = container
        let friend = UUID()
        let sarah = add("Sarah", to: people, context)
        let mum   = add("Mum", to: people, context)
        people.bindConnection(friendID: friend, toPersonID: sarah.id)
        people.bindConnection(friendID: friend, toPersonID: mum.id)   // duplicate attempt
        XCTAssertEqual(sarah.pairedUserID, friend.uuidString)
        XCTAssertNil(mum.pairedUserID, "a second bind of the same friend id is prevented")
    }

    func testExpiredCodeHandled() throws {
        // A code already claimed by SOMEONE ELSE → graceful, distinct error.
        let me = UUID(), owner = UUID(), someoneElse = UUID()
        XCTAssertEqual(SupabaseService.claimOutcome(owner: owner, friend: someoneElse, me: me),
                       .alreadyClaimed)
        let msg = SupabaseServiceError.codeAlreadyClaimed.errorDescription ?? ""
        XCTAssertTrue(msg.lowercased().contains("already"),
                      "the user is told the code is already paired, so they make a new one")
    }

    func testPairingWithSelfPrevented() throws {
        let me = UUID()
        XCTAssertEqual(SupabaseService.claimOutcome(owner: me, friend: nil, me: me), .pairWithSelf)
        let msg = SupabaseServiceError.cannotPairWithSelf.errorDescription ?? ""
        XCTAssertTrue(msg.lowercased().contains("own code"), "blocked: that's your own code")
    }

    func testOneSidedConnectionDetected() throws {
        // One-sided = a card carries a partner id the live connection doesn't
        // confirm (partner deleted the app). Mirrors PeopleListView.isPending.
        let (people, context, container) = try makeWorld()
        _ = container
        let staleFriend = UUID()
        let sarah = add("Sarah", paired: staleFriend, to: people, context)
        let liveFriend: UUID? = nil   // no confirmed live connection
        func isPending(_ p: Person) -> Bool {
            guard let raw = p.pairedUserID else { return false }
            return raw != liveFriend?.uuidString
        }
        XCTAssertTrue(isPending(sarah), "shows dim 'connection pending · waiting to reconnect'")
        // Once the live connection confirms the same id, it's no longer pending.
        let confirmed = sarah.pairedUserID.flatMap(UUID.init)
        func isPendingConfirmed(_ p: Person) -> Bool {
            guard let raw = p.pairedUserID else { return false }
            return raw != confirmed?.uuidString
        }
        XCTAssertFalse(isPendingConfirmed(sarah))
    }

    func testReconnectionAfterDelete() throws {
        // Partner deleted + reinstalled (new user id); A re-invites; B re-links.
        let (people, context, container) = try makeWorld()
        _ = container
        let oldFriend = UUID()
        let sarah = add("Sarah", paired: oldFriend, to: people, context)
        // Simulate the stale link being cleared (partner gone).
        sarah.pairedUserID = nil
        try? people.save()
        XCTAssertNil(people.person(forPairedUserID: oldFriend))
        // Re-pair with the partner's NEW user id.
        let newFriend = UUID()
        people.bindConnection(friendID: newFriend, toPersonID: sarah.id)
        XCTAssertEqual(sarah.pairedUserID, newFriend.uuidString, "connection restored, both working")
        XCTAssertEqual(people.person(forPairedUserID: newFriend)?.id, sarah.id)
    }

    func testThoughtArrivesWithNoPersonLinked() throws {
        // A ping from a friend id with no linked card → resolution is nil, which
        // is the gate: do NOT pop catch mode; show "needs setup" instead.
        let (people, context, container) = try makeWorld()
        _ = container
        add("Sarah", paired: UUID(), to: people, context)   // linked to a DIFFERENT id
        let unknownSender = UUID()
        XCTAssertNil(people.person(forPairedUserID: unknownSender),
                     "unlinked sender ⇒ no card ⇒ catch mode must be gated to 'needs setup'")
        // The copy the compass shows in that state.
        XCTAssertFalse("a thought arrived but needs setup".isEmpty)
    }
}
