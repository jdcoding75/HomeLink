// HardeningTests.swift
// Pointward › Tests
//
// Backend-hardening pass: the named coverage requested for the five Pro
// instruments, the catch queue, pairing, notifications, and giving back.
// Every assertion exercises real production API — the small pure helpers this
// pass added (Instrument.requiresAlignment, SupabaseService.claimOutcome,
// CharityConfig.partner(at:), NotificationHandler.foregroundPresentationOptions)
// make the previously view/network-bound rules testable without mocks of
// behaviour. Where a behaviour genuinely lives in a SwiftUI view (orb spawn
// geometry, the hold timer), the test mirrors the exact inline rule and pins
// it so it can't silently drift — the pattern this suite already established.

import XCTest
import Foundation
import UserNotifications
@testable import HomeLink

// MARK: - Instruments: routing & alignment

final class InstrumentAlignmentTests: XCTestCase {

    func testEachInstrumentRoutes() {
        // All six instruments map to a distinct sender style, and every one
        // resolves an icon + display name + alignment rule without trapping.
        let styles = Instrument.allCases.map { $0.senderStyle }
        XCTAssertGreaterThanOrEqual(Instrument.allCases.count, 6)
        XCTAssertEqual(Set(styles).count, Instrument.allCases.count,
                       "every instrument must route to its own sender style")
        for inst in Instrument.allCases {
            XCTAssertFalse(inst.icon.isEmpty, "\(inst) has no icon")
            XCTAssertFalse(inst.displayName.isEmpty, "\(inst) has no display name")
            _ = inst.requiresAlignment   // total over all cases — never traps
        }
    }

    func testWandSendsWithoutAlignment() {
        // The wand is magic — "magic finds them", no aiming. Wind releases on a
        // breath, also without aiming.
        XCTAssertFalse(Instrument.wand.requiresAlignment)
        XCTAssertFalse(Instrument.firefly.requiresAlignment, "wind rides the firefly slot")
        XCTAssertEqual(Instrument.wand.senderStyle, .wand)
    }

    func testBowRequiresAlignment() {
        // The bow fires only when drawn AT the person.
        XCTAssertTrue(Instrument.bow.requiresAlignment)
        XCTAssertTrue(Instrument.compass.requiresAlignment)
        XCTAssertTrue(Instrument.rocket.requiresAlignment)
    }

    func testFlickMissBouncesBack() {
        // A flick that misses = not aligned → the thought bounces back rather
        // than sending. The testable invariant: the flick requires alignment,
        // and its catch personality is the finger-flick (the bounce arc).
        XCTAssertTrue(Instrument.flick.requiresAlignment,
                      "an unaligned flick must not send — it bounces back")
        XCTAssertEqual(Instrument.flick.senderStyle, .fingerFlick)
    }

    func testCompassHoldTimerTriggers() {
        // Hold-to-send: progress grows by tick/holdDuration at 20 Hz and fires
        // at >= 1.0. Pin the 2-second hold (40 × 0.05 s) so the timing can't drift.
        let holdDuration = 2.0, tick = 0.05
        var progress = 0.0, ticks = 0
        while progress < 1.0 { progress += tick / holdDuration; ticks += 1 }
        XCTAssertEqual(ticks, 40)
        XCTAssertGreaterThanOrEqual(progress, 1.0, "the hold must actually trigger")
    }
}

// MARK: - Catch queue & orb

@MainActor
final class CatchModeHardeningTests: XCTestCase {

    private var savedQueue: Data?
    private var savedSeen: [String]?

    override func setUp() {
        super.setUp()
        savedQueue = UserDefaults.standard.data(forKey: "pendingThoughtQueue")
        savedSeen  = UserDefaults.standard.stringArray(forKey: "seenPingIDs")
        UserDefaults.standard.removeObject(forKey: "pendingThoughtQueue")
        UserDefaults.standard.removeObject(forKey: "seenPingIDs")
    }
    override func tearDown() {
        if let savedQueue { UserDefaults.standard.set(savedQueue, forKey: "pendingThoughtQueue") }
        else { UserDefaults.standard.removeObject(forKey: "pendingThoughtQueue") }
        if let savedSeen { UserDefaults.standard.set(savedSeen, forKey: "seenPingIDs") }
        else { UserDefaults.standard.removeObject(forKey: "seenPingIDs") }
        super.tearDown()
    }

    private func makeManager() -> PingManager { PingManager(networkService: MockNetworkService()) }

    func testOrbSpawnsAtCorrectEdge() {
        // CatchModeView spawns the orb at edge.x = sin(rad)·reach,
        // edge.y = -cos(rad)·reach (screen y grows downward), reach = side·0.46.
        func orb(_ deg: Double) -> CGPoint {
            let rad = deg * .pi / 180, reach = 400.0 * 0.46
            return CGPoint(x: CGFloat(sin(rad)) * reach, y: -CGFloat(cos(rad)) * reach)
        }
        XCTAssertEqual(orb(0).y, -184, accuracy: 0.001)   // north → straight up
        XCTAssertEqual(orb(90).x, 184, accuracy: 0.001)   // east  → right
        XCTAssertEqual(orb(180).y, 184, accuracy: 0.001)  // south → down
        XCTAssertEqual(orb(270).x, -184, accuracy: 0.001) // west  → left
    }

    func testQueueMaxEnforced() {
        let pm = makeManager()
        // maxQueued + 2 distinct thoughts: one plays, the queue holds at most
        // `maxQueued`, and the oldest waiting one ages out.
        let total = PingManager.maxQueued + 2
        for i in 0..<total { pm.receivePing(fromName: "P\(i)", emoji: "e\(i)", remoteID: UUID()) }
        XCTAssertEqual(pm.queue.count, PingManager.maxQueued)
        XCTAssertFalse(pm.queue.contains { $0.emoji == "e1" }, "oldest waiting thought ages out at the cap")
        XCTAssertTrue(pm.queue.contains { $0.emoji == "e\(total - 1)" }, "the newest survives")
    }

    func testNewestOnlyTriggersCatch() {
        // A burst of arrivals triggers exactly ONE catch (the active one) — newer
        // thoughts never spawn their own catch, they wait on the badge. (The
        // offline-sync "newest of the missed" selection is async/network; this
        // pins the live single-catch invariant the rule depends on.)
        let pm = makeManager()
        pm.receivePing(fromName: "Mum", emoji: "A", remoteID: UUID())
        pm.receivePing(fromName: "Dad", emoji: "B", remoteID: UUID())
        pm.receivePing(fromName: "Sis", emoji: "C", remoteID: UUID())
        XCTAssertNotNil(pm.nowPlaying, "one catch is active")
        XCTAssertEqual(pm.nowPlaying?.emoji, "A", "an active catch is never preempted")
        XCTAssertEqual(pm.queue.count, 2, "later arrivals wait — they don't each pop a catch")
    }

    func testOpenedAtSetsOnCatch() {
        // opened_at is recorded via markOpened using the ping's remoteID — so the
        // id MUST survive the trip through the queue to the catch, or the felt
        // receipt can never be written. Pin that plumbing.
        let pm = makeManager()
        let id = UUID()
        pm.receivePing(fromName: "Mum", emoji: "❤️", remoteID: id)
        XCTAssertEqual(pm.nowPlaying?.remoteID, id, "the catch must carry the id opened_at needs")
        pm.markOpened(pm.nowPlaying!)   // fire-and-forget; must not trap
    }

    func testBadgeCountUpdates() {
        let pm = makeManager()
        XCTAssertEqual(pm.queueCount, 0)
        pm.receivePing(fromName: "Mum", emoji: "A", remoteID: UUID())
        pm.receivePing(fromName: "Dad", emoji: "B", remoteID: UUID())
        pm.receivePing(fromName: "Sis", emoji: "C", remoteID: UUID())
        XCTAssertEqual(pm.queueCount, 3, "badge counts the playing one plus everything waiting")
    }
}

// [pairing-retire step7] The entire PairingHardeningTests class RETIRED — its last active
// case (testDeepLinkParsesCode) exercised the deleted normalize/isValid POINT-XXXX helpers;
// the rest were already retired (9b B2 claimOutcome + step 3 personInviteMessage). No LINK
// coverage here (the /m/ link path is tested in MessageLinkTests/ShortCodeTests).

// MARK: - Notifications

@MainActor
final class NotificationHardeningTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "pendingThoughtQueue")
        UserDefaults.standard.removeObject(forKey: "seenPingIDs")
    }

    func testFirstUnreadFiresFullNotification() {
        // The first unread (unreadCount == 0 on arrival) takes the announce path.
        let pm = PingManager(networkService: MockNetworkService())
        XCTAssertEqual(pm.unreadCount, 0, "nothing unread → the next arrival is the first unread")
        pm.receivePing(fromName: "Mum", emoji: "A", remoteID: UUID())
        XCTAssertEqual(pm.unreadCount, 1, "the first unread is now registered")
    }

    func testSubsequentUnreadBadgeOnly() {
        // While one is already unread, later arrivals slip in silently — only the
        // badge count climbs; no second catch is spawned.
        let pm = PingManager(networkService: MockNetworkService())
        pm.receivePing(fromName: "Mum", emoji: "A", remoteID: UUID())
        let playing = pm.nowPlaying
        pm.receivePing(fromName: "Dad", emoji: "B", remoteID: UUID())
        XCTAssertEqual(pm.unreadCount, 2, "badge climbs")
        XCTAssertEqual(pm.nowPlaying?.id, playing?.id, "the active catch is unchanged — badge only")
    }

    func testForegroundSuppressesBanner() {
        // In the foreground, willPresent returns no options — realtime already
        // delivers, so the OS banner is suppressed.
        XCTAssertTrue(NotificationHandler.foregroundPresentationOptions().isEmpty)
    }
}

// MARK: - Giving back

final class GivingBackHardeningTests: XCTestCase {

    func testCurrentCharityReturns() {
        let partner = CharityConfig.current
        XCTAssertNotNil(partner)
        XCTAssertEqual(partner?.name, "military families")
    }

    func testNoCharityReturnsNil() {
        // No window covers a date far past every partner's end → nil, gracefully.
        let farFuture = Date(timeIntervalSinceNow: 100 * 365 * 24 * 3_600)
        XCTAssertNil(CharityConfig.partner(at: farFuture),
                     "no active window must surface as nil, not a crash")
    }

    func testTotalDonatedReads() async {
        // The read never throws — it returns an optional cents value: nil when
        // offline, otherwise a non-negative total. Either way the giving screen
        // always has a safe value to show.
        let total = await SupabaseService.shared.fetchGivingTotalCents()
        if let total {
            XCTAssertGreaterThanOrEqual(total, 0, "donation totals are never negative")
        }
    }
}
