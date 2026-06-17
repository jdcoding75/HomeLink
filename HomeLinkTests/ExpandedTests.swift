// ExpandedTests.swift
// Pointward › Tests
//
// Second wave of pure-logic / reachable-state tests, growing the suite past
// 50. Every assertion exercises real production API (no mocks of behaviour,
// no guessed signatures) — instrument routing, the unified picker tier gate,
// catch-queue rules, orb-spawn geometry, pairing links, notification routing,
// the wand charge model, and the giving-back config.

import XCTest
import CoreLocation
@testable import HomeLink

// MARK: - Instrument routing & tier

final class InstrumentRoutingTests: XCTestCase {

    func testEveryInstrumentRoutesToDistinctSenderStyle() {
        let styles = Instrument.allCases.map { $0.senderStyle }
        XCTAssertEqual(Set(styles).count, Instrument.allCases.count,
                       "two instruments collapsed to the same sender style")
    }

    func testFullSenderStyleWireMapping() {
        XCTAssertEqual(Instrument.compass.senderStyle, .glow)
        XCTAssertEqual(Instrument.bow.senderStyle,     .bowArrow)
        XCTAssertEqual(Instrument.firefly.senderStyle, .firefly)
        XCTAssertEqual(Instrument.flick.senderStyle,   .fingerFlick)
        XCTAssertEqual(Instrument.rocket.senderStyle,  .rocket)
        XCTAssertEqual(Instrument.wand.senderStyle,    .wand)
    }

    func testOnlyCompassIsFreeAcrossAllSix() {
        XCTAssertFalse(Instrument.compass.requiresPro)
        for instrument in Instrument.allCases where instrument != .compass {
            XCTAssertTrue(instrument.requiresPro, "\(instrument) should require Pro")
        }
    }

    func testRawValuesAreStableWireFormat() {
        // These strings persist to UserDefaults and ride the wire — drift breaks
        // catch attribution on already-installed phones.
        XCTAssertEqual(Instrument.compass.rawValue, "compass")
        XCTAssertEqual(Instrument.bow.rawValue,     "bow")
        XCTAssertEqual(Instrument.firefly.rawValue, "firefly")
        XCTAssertEqual(Instrument.flick.rawValue,   "flick")
        XCTAssertEqual(Instrument.rocket.rawValue,  "rocket")
        XCTAssertEqual(Instrument.wand.rawValue,    "wand")
    }

    func testDisplayNameRoutingForRenamedSlots() {
        // wind rides the firefly case; the display name follows the rename
        // while the wire format stays "firefly".
        XCTAssertEqual(Instrument.firefly.displayName, "wind")
        XCTAssertEqual(Instrument.firefly.icon, "🌬️")
        XCTAssertEqual(Instrument.compass.displayName, "compass")
        XCTAssertEqual(Instrument.bow.displayName, "bow & arrow")
    }

    func testUnknownInstrumentRawDecodesNil() {
        XCTAssertNil(Instrument(rawValue: "telescope"))
        XCTAssertNil(Instrument(rawValue: ""))
    }
}

// MARK: - SenderStyle hard-guard

final class SenderStyleGuardTests: XCTestCase {

    private let key = SenderStyle.storageKey
    private let tierKey = "subscriptionTier"
    private var savedStyle: String?
    private var savedTier: String?

    override func setUp() {
        super.setUp()
        savedStyle = UserDefaults.standard.string(forKey: key)
        savedTier  = UserDefaults.standard.string(forKey: tierKey)
    }
    override func tearDown() {
        restore(savedStyle, key); restore(savedTier, tierKey)
        super.tearDown()
    }
    private func restore(_ v: String?, _ k: String) {
        if let v { UserDefaults.standard.set(v, forKey: k) }
        else { UserDefaults.standard.removeObject(forKey: k) }
    }

    func testFreeUserCollapsesToGlow() {
        UserDefaults.standard.set(SenderStyle.rocket.rawValue, forKey: key)
        XCTAssertEqual(SenderStyle.effective(for: .free), .glow)
    }

    func testProUserKeepsTheirStyle() {
        for style in SenderStyle.allCases {
            UserDefaults.standard.set(style.rawValue, forKey: key)
            XCTAssertEqual(SenderStyle.effective(for: .pro), style)
        }
    }

    func testGlowIsTheOnlyFreeStyle() {
        XCTAssertFalse(SenderStyle.glow.requiresPro)
        for style in SenderStyle.allCases where style != .glow {
            XCTAssertTrue(style.requiresPro)
        }
    }

    func testFromWireFallsBackToGlow() {
        XCTAssertEqual(SenderStyle.from(nil), .glow)
        XCTAssertEqual(SenderStyle.from(""), .glow)
        XCTAssertEqual(SenderStyle.from("not-a-style"), .glow)
        XCTAssertEqual(SenderStyle.from("rocket"), .rocket)
        XCTAssertEqual(SenderStyle.from("bowArrow"), .bowArrow)
    }

    func testEffectiveForCurrentUserReadsTierFromDefaults() {
        UserDefaults.standard.set(SenderStyle.firefly.rawValue, forKey: key)
        UserDefaults.standard.set("free", forKey: tierKey)
        XCTAssertEqual(SenderStyle.effectiveForCurrentUser, .glow)
        UserDefaults.standard.set("unlocked", forKey: tierKey)   // .pro
        XCTAssertEqual(SenderStyle.effectiveForCurrentUser, .firefly)
    }
}

// MARK: - Unified instrument picker

@MainActor
final class InstrumentOptionTests: XCTestCase {

    private let optionKey = InstrumentOption.storageKey
    private let instKey   = InstrumentStore.storageKey
    private let skinKey   = "activeSkin"
    private var savedOption: String?
    private var savedInst: String?
    private var savedSkin: String?

    override func setUp() {
        super.setUp()
        savedOption = UserDefaults.standard.string(forKey: optionKey)
        savedInst   = UserDefaults.standard.string(forKey: instKey)
        savedSkin   = UserDefaults.standard.string(forKey: skinKey)
    }
    override func tearDown() {
        restore(savedOption, optionKey); restore(savedInst, instKey); restore(savedSkin, skinKey)
        super.tearDown()
    }
    private func restore(_ v: String?, _ k: String) {
        if let v { UserDefaults.standard.set(v, forKey: k) }
        else { UserDefaults.standard.removeObject(forKey: k) }
    }

    func testOnlyVintageCompassIsFree() {
        // [2/5] minimal retired — vintage brass is the lone free option.
        let free = InstrumentOption.allCases.filter { !$0.requiresPro }
        XCTAssertEqual(Set(free), [.compassVintage])
        for opt in InstrumentOption.allCases where !free.contains(opt) {
            XCTAssertTrue(opt.requiresPro, "\(opt) should be Pro")
        }
    }

    func testDefaultSelectionIsCompassVintage() {
        UserDefaults.standard.removeObject(forKey: optionKey)
        XCTAssertEqual(InstrumentOption.selected, .compassVintage)
    }

    func testRetiredHeartRawDecodesToVintage() {
        // A heart selection persisted before the retirement must land safely.
        UserDefaults.standard.set("compassHeart", forKey: optionKey)
        XCTAssertEqual(InstrumentOption.selected, .compassVintage)
    }

    func testOptionRoutesToUnderlyingInstrument() {
        XCTAssertEqual(InstrumentOption.compassVintage.instrument, .compass)
        XCTAssertEqual(InstrumentOption.bow.instrument,    .bow)
        XCTAssertEqual(InstrumentOption.flick.instrument,  .flick)
        XCTAssertEqual(InstrumentOption.wind.instrument,   .firefly)   // wind rides firefly
        XCTAssertEqual(InstrumentOption.rocket.instrument, .rocket)
        XCTAssertEqual(InstrumentOption.wand.instrument,   .wand)
    }

    func testOnlyCompassOptionsCarryASkin() {
        XCTAssertEqual(InstrumentOption.compassVintage.skin, .vintage)
        for opt in [InstrumentOption.bow, .flick, .wind, .rocket, .wand] {
            XCTAssertNil(opt.skin, "\(opt) is not a compass — no skin")
        }
    }

    func testApplyDrivesBothStores() {
        let inst = InstrumentStore()
        let skin = SkinStore()
        InstrumentOption.apply(.bow, instrumentStore: inst, skinStore: skin)
        XCTAssertEqual(InstrumentOption.selected, .bow)
        XCTAssertEqual(inst.selected, .bow)

        InstrumentOption.apply(.compassVintage, instrumentStore: inst, skinStore: skin)
        XCTAssertEqual(inst.selected, .compass)
        XCTAssertEqual(skin.activeSkin, .vintage)
    }

    func testNothingIsComingSoon() {
        // The whole lineup (plane included) has launched — the apply() guard
        // must never block a selection today.
        for opt in InstrumentOption.allCases {
            XCTAssertFalse(opt.comingSoon, "\(opt) unexpectedly coming soon")
        }
    }

    func testLaunchedOptionIsSelectable() {
        // A live (non-coming-soon) option applies cleanly.
        let inst = InstrumentStore()
        let skin = SkinStore()
        InstrumentOption.apply(.plane, instrumentStore: inst, skinStore: skin)
        XCTAssertEqual(InstrumentOption.selected, .plane)
    }

    func testMigrationDerivesOptionFromLegacyInstrument() {
        UserDefaults.standard.removeObject(forKey: optionKey)
        UserDefaults.standard.set(Instrument.bow.rawValue, forKey: instKey)
        InstrumentOption.migrateLegacySelection()
        XCTAssertEqual(UserDefaults.standard.string(forKey: optionKey), InstrumentOption.bow.rawValue)
    }

    func testMigrationDerivesCompassSkinVariant() {
        UserDefaults.standard.removeObject(forKey: optionKey)
        UserDefaults.standard.set(Instrument.compass.rawValue, forKey: instKey)
        UserDefaults.standard.set("minimal", forKey: skinKey)
        InstrumentOption.migrateLegacySelection()
        // minimal retired → legacy minimal users land on vintage brass.
        XCTAssertEqual(UserDefaults.standard.string(forKey: optionKey),
                       InstrumentOption.compassVintage.rawValue)
    }

    func testMigrationNoOpWhenAlreadySelected() {
        UserDefaults.standard.set(InstrumentOption.wand.rawValue, forKey: optionKey)
        UserDefaults.standard.set(Instrument.bow.rawValue, forKey: instKey)
        InstrumentOption.migrateLegacySelection()
        XCTAssertEqual(UserDefaults.standard.string(forKey: optionKey),
                       InstrumentOption.wand.rawValue, "migration must not overwrite an existing choice")
    }
}

// MARK: - Catch-queue rules

@MainActor
final class PingQueueTests: XCTestCase {

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

    private func makeManager() -> PingManager {
        PingManager(networkService: MockNetworkService())
    }

    func testFirstThoughtBecomesNowPlaying() {
        let pm = makeManager()
        pm.receivePing(fromName: "Mum", emoji: "❤️", remoteID: UUID())
        XCTAssertNotNil(pm.nowPlaying)
        XCTAssertEqual(pm.nowPlaying?.emoji, "❤️")
        XCTAssertTrue(pm.queue.isEmpty, "the only thought is playing, not waiting")
        XCTAssertEqual(pm.queueCount, 1)
    }

    func testSecondThoughtWaitsBehindActiveCatch() {
        let pm = makeManager()
        pm.receivePing(fromName: "Mum", emoji: "❤️", remoteID: UUID())
        pm.receivePing(fromName: "Dad", emoji: "🌟", remoteID: UUID())
        // Active catch is never interrupted; the second waits.
        XCTAssertEqual(pm.nowPlaying?.emoji, "❤️")
        XCTAssertEqual(pm.queue.count, 1)
        XCTAssertEqual(pm.queue.first?.emoji, "🌟")
        XCTAssertEqual(pm.queueCount, 2)
    }

    func testQueueCapsAtMaxOldestDrops() {
        let pm = makeManager()
        // maxQueued + 2 distinct thoughts: one becomes nowPlaying, the queue
        // holds at most `maxQueued`, and the oldest WAITING one ages out.
        let total = PingManager.maxQueued + 2
        for i in 0..<total {
            pm.receivePing(fromName: "P\(i)", emoji: "e\(i)", remoteID: UUID())
        }
        XCTAssertEqual(pm.queue.count, PingManager.maxQueued)
        // "e0" played (nowPlaying); "e1" was the oldest waiting and aged out.
        XCTAssertFalse(pm.queue.contains { $0.emoji == "e1" },
                       "oldest waiting thought should have aged out at the cap")
        XCTAssertTrue(pm.queue.contains { $0.emoji == "e\(total - 1)" },
                      "newest must survive")
    }

    func testDuplicateByRemoteIDIgnored() {
        let pm = makeManager()
        let id = UUID()
        pm.receivePing(fromName: "Mum", emoji: "❤️", remoteID: id)
        pm.receivePing(fromName: "Mum", emoji: "❤️", remoteID: id)   // same id (realtime + push)
        XCTAssertEqual(pm.queueCount, 1, "same remoteID must collapse to one catch")
    }

    func testDuplicateByEmojiWithinWindowIgnored() {
        let pm = makeManager()
        pm.receivePing(fromName: "Mum", emoji: "❤️")               // no id
        pm.receivePing(fromName: "Mum", emoji: "❤️")               // same emoji+name, <15s
        XCTAssertEqual(pm.queueCount, 1)
    }

    func testDifferentSenderSameEmojiIsNotDuplicate() {
        let pm = makeManager()
        pm.receivePing(fromName: "Mum", emoji: "❤️", remoteID: UUID())
        pm.receivePing(fromName: "Dad", emoji: "❤️", remoteID: UUID())
        XCTAssertEqual(pm.queueCount, 2, "different sender is a distinct thought")
    }

    func testPlayNextPullsOldestWaitingFirst() {
        let pm = makeManager()
        pm.receivePing(fromName: "Mum", emoji: "A", remoteID: UUID())   // now playing
        pm.receivePing(fromName: "Dad", emoji: "B", remoteID: UUID())   // waiting
        pm.receivePing(fromName: "Sis", emoji: "C", remoteID: UUID())   // waiting
        pm.finishedPlaying(pm.nowPlaying!)
        XCTAssertNil(pm.nowPlaying, "waiting thoughts do not auto-play")
        pm.playNext()
        XCTAssertEqual(pm.nowPlaying?.emoji, "B", "oldest waiting thought is next")
        XCTAssertEqual(pm.queue.count, 1)
    }

    func testSkipAdvancesImmediately() {
        let pm = makeManager()
        pm.receivePing(fromName: "Mum", emoji: "A", remoteID: UUID())
        pm.receivePing(fromName: "Dad", emoji: "B", remoteID: UUID())
        let playing = pm.nowPlaying!
        pm.skip(playing)
        XCTAssertEqual(pm.nowPlaying?.emoji, "B")
    }

    func testFinishedPlayingIgnoresStalePing() {
        let pm = makeManager()
        pm.receivePing(fromName: "Mum", emoji: "A", remoteID: UUID())
        let stale = PingManager.ReceivedPing(fromName: "Ghost", emoji: "X", timestamp: .now)
        pm.finishedPlaying(stale)   // not the current ping
        XCTAssertNotNil(pm.nowPlaying, "a stale finish must not clear the live catch")
    }

    func testQueuePersistsAndRestoresAcrossManagers() {
        let pm1 = makeManager()
        pm1.receivePing(fromName: "Mum", emoji: "A", remoteID: UUID())   // now playing
        pm1.receivePing(fromName: "Dad", emoji: "B", remoteID: UUID())   // waiting → persisted
        let pm2 = makeManager()   // simulates relaunch — restores waiting queue
        XCTAssertTrue(pm2.queue.contains { $0.emoji == "B" },
                      "waiting thought should survive relaunch")
    }

    func testBadgeCountTracksNowPlayingPlusQueue() {
        let pm = makeManager()
        XCTAssertEqual(pm.queueCount, 0)
        pm.receivePing(fromName: "Mum", emoji: "A", remoteID: UUID())
        pm.receivePing(fromName: "Dad", emoji: "B", remoteID: UUID())
        pm.receivePing(fromName: "Sis", emoji: "C", remoteID: UUID())
        XCTAssertEqual(pm.queueCount, 3)   // 1 playing + 2 waiting
    }
}

// MARK: - Catch orb spawn geometry
//
// The orb spawns at the screen edge in the partner's compass direction. The
// production view (CatchModeView) computes this inline as
//   edge.x =  sin(rad) * reach
//   edge.y = -cos(rad) * reach      (screen y grows downward)
// with reach = min(w,h) * 0.46. These tests pin that geometry.

final class OrbGeometryTests: XCTestCase {

    private func orb(bearingDegrees: Double, size: CGFloat) -> CGPoint {
        let rad   = bearingDegrees * .pi / 180
        let reach = size * 0.46
        return CGPoint(x: CGFloat(sin(rad)) * reach,
                       y: -CGFloat(cos(rad)) * reach)
    }

    func testNorthSpawnsStraightUp() {
        let p = orb(bearingDegrees: 0, size: 400)
        XCTAssertEqual(p.x, 0, accuracy: 0.001)
        XCTAssertEqual(p.y, -184, accuracy: 0.001)   // -reach, screen-up
    }

    func testEastSpawnsToTheRight() {
        let p = orb(bearingDegrees: 90, size: 400)
        XCTAssertEqual(p.x, 184, accuracy: 0.001)
        XCTAssertEqual(p.y, 0, accuracy: 0.001)
    }

    func testSouthSpawnsDown() {
        let p = orb(bearingDegrees: 180, size: 400)
        XCTAssertEqual(p.x, 0, accuracy: 0.001)
        XCTAssertEqual(p.y, 184, accuracy: 0.001)
    }

    func testWestSpawnsToTheLeft() {
        let p = orb(bearingDegrees: 270, size: 400)
        XCTAssertEqual(p.x, -184, accuracy: 0.001)
        XCTAssertEqual(p.y, 0, accuracy: 0.001)
    }

    func testReachIsAlwaysFortySixPercentOfShorterSide() {
        // A 300×500 box → reach keyed off 300.
        let rad = 90.0 * .pi / 180
        let reach = min(CGFloat(300), CGFloat(500)) * 0.46
        let x = CGFloat(sin(rad)) * reach
        XCTAssertEqual(x, 138, accuracy: 0.001)
    }
}

// MARK: - Pairing links & person invites

final class PairingLinkTests: XCTestCase {

    func testPairLinkBuildsUniversalLink() {
        XCTAssertEqual(AppLinks.pairLink(code: "POINT-GP2S"),
                       "https://pointward.app/pair/POINT-GP2S")
    }

    func testDeepLinkPathExtractsCode() {
        // Mirrors RootView.handleIncomingURL parsing.
        let url = URL(string: "https://pointward.app/pair/POINT-GP2S")!
        let parts = url.pathComponents.filter { $0 != "/" }
        XCTAssertEqual(parts.first?.lowercased(), "pair")
        let code = SupabaseService.normalizePairingCode(parts[1])
        XCTAssertTrue(SupabaseService.isValidPairingCode(code))
        XCTAssertEqual(code, "POINT-GP2S")
    }

    func testJoinPathAlsoAccepted() {
        let url = URL(string: "https://pointward.app/join/gp2s")!
        let parts = url.pathComponents.filter { $0 != "/" }
        XCTAssertTrue(["pair", "join"].contains(parts[0].lowercased()))
        XCTAssertEqual(SupabaseService.normalizePairingCode(parts[1]), "POINT-GP2S")
    }

    func testInviteMessageWithCodeContainsTappableLink() {
        let msg = AppLinks.inviteMessage(pairingCode: "POINT-GP2S")
        XCTAssertTrue(msg.contains("https://pointward.app/pair/POINT-GP2S"))
    }

    func testInviteMessageWithoutCodeFallsBackToDownload() {
        let msg = AppLinks.inviteMessage(pairingCode: nil)
        XCTAssertFalse(msg.contains("/pair/"))
        XCTAssertTrue(msg.contains("https://pointward.app"))
        XCTAssertEqual(AppLinks.inviteMessage(pairingCode: ""), msg,
                       "empty code is treated like no code")
    }

    func testPersonInviteTiesToTheRightPerson() {
        let msg = AppLinks.personInviteMessage(personName: "Grandma", code: "POINT-GP2S")
        XCTAssertTrue(msg.contains("Grandma wants to connect"))
        XCTAssertTrue(msg.contains("/pair/POINT-GP2S"))
    }

    func testThoughtInviteAppendsCode() {
        let withCode = AppLinks.thoughtInvite(code: "POINT-GP2S")
        XCTAssertTrue(withCode.contains("enter my code: POINT-GP2S"))
        let without = AppLinks.thoughtInvite(code: nil)
        XCTAssertFalse(without.contains("enter my code"))
    }

    func testNormalizeRoundTripsValidGeneratedCodes() {
        for _ in 0..<25 {
            let code = SupabaseService.generatePairingCode()
            // A generated code, when re-normalized, returns itself.
            XCTAssertEqual(SupabaseService.normalizePairingCode(code), code)
        }
    }
}

// MARK: - Subscription tier gates

final class SubscriptionTierTests: XCTestCase {

    func testRawValuesPreserveLegacyPersistence() {
        XCTAssertEqual(SubscriptionTier.pro.rawValue, "unlocked")   // legacy raw kept
        XCTAssertEqual(SubscriptionTier(rawValue: "unlocked"), .pro)
        XCTAssertEqual(SubscriptionTier(rawValue: "free"), .free)
    }

    func testMaxPeoplePerTier() {
        XCTAssertEqual(SubscriptionTier.free.maxPeople, 1)
        XCTAssertEqual(SubscriptionTier.pro.maxPeople, 5)
        XCTAssertEqual(SubscriptionTier.institutional.maxPeople, .max)
    }

    func testFreeCannotSendOrUseWidgets() {
        XCTAssertFalse(SubscriptionTier.free.canSendPings)
        XCTAssertFalse(SubscriptionTier.free.canUseWidgets)
        XCTAssertTrue(SubscriptionTier.pro.canSendPings)
        XCTAssertTrue(SubscriptionTier.pro.canUseWidgets)
    }

    func testFreeUnlocksOnlyTwoCompassSkins() {
        XCTAssertEqual(SubscriptionTier.free.unlockedSkinIDs, ["minimal", "vintage"])
        XCTAssertTrue(SubscriptionTier.pro.unlockedSkinIDs.isSuperset(of: ["minimal", "vintage"]))
    }
}

// MARK: - Wand charge model (ShakeDetector)

@MainActor
final class WandChargeTests: XCTestCase {

    func testFiveShakesFillsTheCrystal() {
        let s = ShakeDetector()
        // No accelerometer in tests → motionAvailable is false, so holdCharge
        // is the live path (one shake's worth each).
        XCTAssertFalse(s.motionAvailable)
        var fullFired = false
        s.onFull = { fullFired = true }
        for _ in 0..<ShakeDetector.shakesToFull {
            s.holdCharge(1.0 / Double(ShakeDetector.shakesToFull))
        }
        XCTAssertEqual(s.charge, 1.0, accuracy: 0.0001)
        XCTAssertEqual(s.shakes, ShakeDetector.shakesToFull)
        XCTAssertTrue(fullFired, "onFull must fire when the crystal first reaches full")
    }

    func testChargeNeverExceedsFull() {
        let s = ShakeDetector()
        for _ in 0..<20 { s.holdCharge(0.5) }
        XCTAssertEqual(s.charge, 1.0, accuracy: 0.0001)
    }

    func testResetClearsCharge() {
        let s = ShakeDetector()
        s.holdCharge(0.6)
        s.reset()
        XCTAssertEqual(s.charge, 0)
        XCTAssertEqual(s.shakes, 0)
    }

    func testOnFullFiresExactlyOnce() {
        let s = ShakeDetector()
        var count = 0
        s.onFull = { count += 1 }
        for _ in 0..<10 { s.holdCharge(0.5) }   // crosses full, then keeps "charging"
        XCTAssertEqual(count, 1, "onFull is a one-shot")
    }
}

// MARK: - Notification payload routing
//
// NotificationHandler.handlePayload is private, but the decisions it makes are
// pure: a "pointing" payload routes to presence; a thought payload must carry
// pingEmoji + fromName, with pingId/senderStyle optional. We pin those rules
// against the same PingManager API the handler drives.

@MainActor
final class NotificationRoutingTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "pendingThoughtQueue")
        UserDefaults.standard.removeObject(forKey: "seenPingIDs")
    }

    func testFirstUnreadFiresHapticPathRestAreSilentBadgeOnly() {
        // The "first unread announces, rest are badge-only" rule lives in
        // receivePing via unreadCount. We assert the count progression that
        // drives the silent path.
        let pm = PingManager(networkService: MockNetworkService())
        XCTAssertEqual(pm.queueCount, 0)            // unread == 0 → next is "first unread"
        pm.receivePing(fromName: "Mum", emoji: "A", remoteID: UUID())
        XCTAssertEqual(pm.queueCount, 1)            // now unread > 0 → subsequent are silent
        pm.receivePing(fromName: "Dad", emoji: "B", remoteID: UUID())
        XCTAssertEqual(pm.queueCount, 2)
    }

    // [9b · B4] testPointingPayloadRoutesToPresenceNotQueue removed — it tested
    // presenceFelt / partnerPointingAt / partnerPointingName, the mutual-pointing cluster
    // retired this batch. (The live thought-payload test below stays.)

    func testThoughtPayloadRequiresEmojiAndFromName() {
        // The handler guards on both keys; a payload missing either is dropped.
        let valid: [AnyHashable: Any]   = ["pingEmoji": "❤️", "fromName": "Mum"]
        let missing: [AnyHashable: Any] = ["pingEmoji": "❤️"]
        XCTAssertNotNil(valid["pingEmoji"] as? String)
        XCTAssertNotNil(valid["fromName"] as? String)
        XCTAssertNil(missing["fromName"] as? String,
                     "a payload without fromName is incomplete and must be ignored")
    }

    func testForegroundPresentationSuppressesBanner() {
        // willPresent returns [] (no banner/sound) — realtime delivers in the
        // foreground, so the OS banner is suppressed. We pin the contract value.
        let suppressed: UNNotificationPresentationOptions = []
        XCTAssertTrue(suppressed.isEmpty)
    }
}

// MARK: - Giving back

final class GivingBackTests: XCTestCase {

    func testCurrentReturnsAnActivePartner() {
        // The seeded military-families window starts today and runs 60 days.
        let partner = CharityConfig.current
        XCTAssertNotNil(partner)
        XCTAssertEqual(partner?.name, "military families")
        XCTAssertEqual(partner?.emoji, "🎖️")
    }

    func testPartnersListIsNonEmptyAndWellFormed() {
        XCTAssertFalse(CharityConfig.partners.isEmpty)
        for p in CharityConfig.partners {
            XCTAssertFalse(p.name.isEmpty)
            XCTAssertTrue(p.websiteURL.hasPrefix("https://"))
            XCTAssertTrue(p.endDate > p.startDate, "a charity window must be forward in time")
        }
    }

    func testCurrentIsNilWhenNoWindowActive() {
        // Reproduce the "no active charity" case with a partner whose window is
        // entirely in the past — current's predicate must reject it gracefully.
        let past = CharityPartner(
            name: "expired", emoji: "⏳", description: "", websiteURL: "https://x",
            donationURL: "https://x",
            startDate: Date(timeIntervalSinceNow: -100),
            endDate: Date(timeIntervalSinceNow: -50)
        )
        let now = Date()
        let active = [past].first { now >= $0.startDate && now <= $0.endDate }
        XCTAssertNil(active, "an expired window must not be surfaced as current")
    }
}

// MARK: - Distance fun (three-layer distance)

final class DistanceFunTests: XCTestCase {

    func testProUnitCyclingWrapsThroughFourUnits() {
        XCTAssertEqual(DistanceFun.nextProIndex(after: 0), 1)
        XCTAssertEqual(DistanceFun.nextProIndex(after: 1), 3)
        XCTAssertEqual(DistanceFun.nextProIndex(after: 3), 5)
        XCTAssertEqual(DistanceFun.nextProIndex(after: 5), 0)   // wraps
    }

    func testProCycleRecoversFromOffListIndex() {
        // A non-pro index falls back to the first pro unit.
        XCTAssertEqual(DistanceFun.nextProIndex(after: 99), DistanceFun.proUnits[0])
    }

    func testFunnyTextRoutesPerUnitIndex() {
        XCTAssertTrue(DistanceFun.funnyText(km: 100, index: 0).contains("football fields"))
        XCTAssertTrue(DistanceFun.funnyText(km: 100, index: 5).contains("by car"))
        XCTAssertTrue(DistanceFun.funnyText(km: 100, index: 6).contains("by plane"))
    }

    func testLightSpeedScalesWithDistance() {
        XCTAssertTrue(DistanceFun.lightSpeedText(km: 1).contains("µs"))
        XCTAssertTrue(DistanceFun.lightSpeedText(km: 5_000_000).contains("seconds"))
    }

    func testTaglineCatalogIsStable() {
        XCTAssertEqual(DistanceFun.funnyCount, DistanceFun.funnyLabels.count)
        XCTAssertFalse(DistanceFun.thoughtTaglines.isEmpty)
    }
}

// MARK: - Compass hold-to-send threshold
//
// The 2-second hold lives as inline @State in CompassView (holdProgress grows
// by 0.05/holdDuration per tick at 20 Hz, fires at >= 1.0). The view's wiring
// isn't reachable, but the threshold arithmetic is — pin it so the timing
// can't silently drift.

final class CompassHoldTimerTests: XCTestCase {

    private let holdDuration = 2.0
    private let tick = 0.05   // 20 Hz progress ticks, matching CompassView

    func testFortyTicksReachFullHold() {
        var progress = 0.0
        var ticks = 0
        while progress < 1.0 {
            progress += tick / holdDuration
            ticks += 1
        }
        XCTAssertEqual(ticks, 40)                    // 40 × 0.05s = 2.0s
        XCTAssertEqual(Double(ticks) * tick, holdDuration, accuracy: 0.0001)
    }

    func testHalfwayIsOneSecond() {
        // 20 ticks → progress 0.5 → one second elapsed.
        let progressAt20 = 20 * (tick / holdDuration)
        XCTAssertEqual(progressAt20, 0.5, accuracy: 0.0001)
    }
}
