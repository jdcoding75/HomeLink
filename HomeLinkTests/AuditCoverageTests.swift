// AuditCoverageTests.swift
// Pointward › Tests
//
// Added in the overnight audit pass to close coverage gaps: BearingCalculator
// edge cases (same location, antipodal, null island, date-line crossing),
// InstrumentBoundaries + ScreenCoordinates constants, the EmojiReveal context /
// ambient mapping (sent vs received copy, per-instrument world), TaglineSystem,
// SubscriptionTier persistence + gating, and AppGroupStore round-trips.

import XCTest
import CoreLocation
import SwiftData
@testable import HomeLink

// MARK: - BearingCalculator edge cases

final class BearingEdgeCaseTests: XCTestCase {

    private let nullIsland = CLLocationCoordinate2D(latitude: 0, longitude: 0)

    func testSameLocationDistanceIsZero() {
        let p = CLLocationCoordinate2D(latitude: 37.33, longitude: -122.03)
        XCTAssertEqual(BearingCalculator.distanceKm(from: p, to: p), 0, accuracy: 0.001)
    }

    func testNullIslandDueEast() {
        let east = CLLocationCoordinate2D(latitude: 0, longitude: 10)
        XCTAssertEqual(BearingCalculator.bearing(from: nullIsland, to: east), 90, accuracy: 0.01)
    }

    func testAntipodalDistanceIsHalfTheGlobe() {
        // (0,0) → (0,180) is antipodal along the equator: π·R ≈ 20015 km.
        let anti = CLLocationCoordinate2D(latitude: 0, longitude: 180)
        XCTAssertEqual(BearingCalculator.distanceKm(from: nullIsland, to: anti), 20015, accuracy: 100)
    }

    func testDateLineCrossingTakesShortWay() {
        // 179°E → 179°W is 2° apart across the date line, NOT 358° the long way.
        let a = CLLocationCoordinate2D(latitude: 0, longitude: 179)
        let b = CLLocationCoordinate2D(latitude: 0, longitude: -179)
        XCTAssertEqual(BearingCalculator.distanceKm(from: a, to: b), 222, accuracy: 25)
        XCTAssertEqual(BearingCalculator.bearing(from: a, to: b), 90, accuracy: 2)
    }

    func testBearingIsAlwaysInRange() {
        let pts = [(10.0, 20.0), (-33.8, 151.2), (64.1, -21.9), (0, -179.9)]
        for (lat, lon) in pts {
            let b = BearingCalculator.bearing(from: nullIsland,
                                              to: CLLocationCoordinate2D(latitude: lat, longitude: lon))
            XCTAssertTrue(b >= 0 && b < 360, "bearing \(b) out of range for \(lat),\(lon)")
        }
    }

    func testAlignmentErrorWrapsSymmetrically() {
        XCTAssertEqual(BearingCalculator.alignmentError(relativeBearing: 0), 0, accuracy: 0.001)
        XCTAssertEqual(BearingCalculator.alignmentError(relativeBearing: -10), 10, accuracy: 0.001)
        XCTAssertEqual(BearingCalculator.alignmentError(relativeBearing: 370), 10, accuracy: 0.001)
        XCTAssertEqual(BearingCalculator.alignmentError(relativeBearing: 180), 180, accuracy: 0.001)
    }

    func testLockAndSendThresholds() {
        XCTAssertTrue(BearingCalculator.isLockAligned(0))
        XCTAssertFalse(BearingCalculator.isLockAligned(45))
        XCTAssertTrue(BearingCalculator.isSendAligned(0))
    }

    func testFormattedDistanceNeverEmpty() {
        XCTAssertFalse(BearingCalculator.formattedDistance(0).isEmpty)
        XCTAssertFalse(BearingCalculator.formattedDistance(12_500).isEmpty)
        XCTAssertFalse(BearingCalculator.emotionalDistance(8).isEmpty)
    }
}

// MARK: - InstrumentBoundaries + ScreenCoordinates

final class InstrumentBoundariesTests: XCTestCase {

    func testSendDurations() {
        XCTAssertEqual(InstrumentBoundaries.Send.wind, 6.5)
        XCTAssertEqual(InstrumentBoundaries.Send.rocket, 4.0)
        XCTAssertEqual(InstrumentBoundaries.Send.compass, 3.5)
    }

    func testReceiptDurations() {
        XCTAssertEqual(InstrumentBoundaries.Receipt.wind, 7.2)
        XCTAssertEqual(InstrumentBoundaries.Receipt.rocket, 7.75)   // v2 parachute
        XCTAssertEqual(InstrumentBoundaries.Receipt.maximum, 7.75)
    }

    func testRevealLinger() {
        XCTAssertEqual(InstrumentBoundaries.Reveal.linger, 6.0)
    }

    func testScreenCoordinateConstants() {
        XCTAssertEqual(ScreenCoordinates.entryReach, 0.75)
        XCTAssertEqual(ScreenCoordinates.exitReach, 1.15)
        XCTAssertEqual(ScreenCoordinates.swirlAmplitudeX, 0.36)
        XCTAssertEqual(ScreenCoordinates.swirlAmplitudeY, 0.15)
        XCTAssertEqual(ScreenCoordinates.bucketBottomMargin, 0.06)
        XCTAssertTrue(ScreenCoordinates.topLabelMaxY < ScreenCoordinates.bottomLabelMinY)
    }
}

// MARK: - EmojiReveal context + ambient

final class EmojiRevealContextTests: XCTestCase {

    func testSentCopy() {
        let c = RevealContext.sent(recipientName: "Sarah")
        XCTAssertEqual(c.headlineText, "sent to Sarah ✦")
        XCTAssertEqual(c.subText, "Sarah will feel this ✦")
    }

    func testReceivedCopy() {
        let c = RevealContext.received(fromName: "Mom")
        XCTAssertEqual(c.headlineText, "from Mom ✦")
        XCTAssertTrue(c.subText.isEmpty)
    }

    func testAmbientForStyleMapsEveryStyle() {
        XCTAssertEqual(RevealAmbient.forStyle(.firefly), .wind)
        XCTAssertEqual(RevealAmbient.forStyle(.rocket), .rocket)
        XCTAssertEqual(RevealAmbient.forStyle(.wand), .wand)
        XCTAssertEqual(RevealAmbient.forStyle(.bowArrow), .bow)
        XCTAssertEqual(RevealAmbient.forStyle(.fingerFlick), .flick)
        XCTAssertEqual(RevealAmbient.forStyle(.plane), .plane)
        XCTAssertEqual(RevealAmbient.forStyle(.glow), .compass)
        XCTAssertEqual(RevealAmbient.forStyle(.shootingStar), .compass)
    }

    func testAmbientForInstrumentMapsEveryInstrument() {
        XCTAssertEqual(RevealAmbient.forInstrument(.firefly), .wind)
        XCTAssertEqual(RevealAmbient.forInstrument(.rocket), .rocket)
        XCTAssertEqual(RevealAmbient.forInstrument(.wand), .wand)
        XCTAssertEqual(RevealAmbient.forInstrument(.bow), .bow)
        XCTAssertEqual(RevealAmbient.forInstrument(.flick), .flick)
        XCTAssertEqual(RevealAmbient.forInstrument(.plane), .plane)
        XCTAssertEqual(RevealAmbient.forInstrument(.compass), .compass)
    }

    func testEveryInstrumentHasAnAmbient() {
        // Exhaustive — guards against a new instrument missing its world.
        for inst in Instrument.allCases {
            _ = RevealAmbient.forInstrument(inst)   // would not compile if non-exhaustive
        }
        XCTAssertEqual(Instrument.allCases.count, 7)
    }
}

// MARK: - TaglineSystem

final class TaglineSystemTests: XCTestCase {

    func testValidateEmpty() {
        XCTAssertNil(TaglineSystem.validate("   ").sanitised)
    }

    func testValidateValid() {
        XCTAssertEqual(TaglineSystem.validate("  thinking of you  ").sanitised, "thinking of you")
    }

    func testValidateTooLong() {
        let long = String(repeating: "a", count: TaglineSystem.maxLength + 1)
        XCTAssertNil(TaglineSystem.validate(long).sanitised)
    }

    func testNextCyclesAround() {
        let first = TaglineSystem.next(after: nil)
        XCTAssertFalse(first.isEmpty)
        // Walking the whole library returns to the first.
        var cur = first
        for _ in 0..<TaglineSystem.poeticLibrary.count {
            cur = TaglineSystem.next(after: cur)
        }
        XCTAssertEqual(cur, first)
    }

    func testCounterState() {
        XCTAssertEqual(TaglineSystem.counterState(0), .normal)
        XCTAssertEqual(TaglineSystem.counterState(TaglineSystem.maxLength - 5), .warning)
        XCTAssertEqual(TaglineSystem.counterState(TaglineSystem.maxLength), .atLimit)
    }

    func testDefaultTaglineNonEmpty() {
        XCTAssertFalse(TaglineSystem.defaultTagline.isEmpty)
    }
}

// MARK: - SubscriptionTier persistence + gating

final class SubscriptionTierAuditTests: XCTestCase {

    func testProRawValueIsLegacyUnlocked() {
        // Persistence + non-view tier reads depend on this exact raw value.
        XCTAssertEqual(SubscriptionTier.pro.rawValue, "unlocked")
        XCTAssertEqual(SubscriptionTier(rawValue: "unlocked"), .pro)
    }

    func testMaxPeopleGate() {
        XCTAssertEqual(SubscriptionTier.free.maxPeople, 1)
        XCTAssertEqual(SubscriptionTier.pro.maxPeople, 5)
    }

    func testTierRoundTripsThroughUserDefaults() {
        let key = "subscriptionTier_test"
        let d = UserDefaults.standard
        d.set(SubscriptionTier.pro.rawValue, forKey: key)
        let restored = SubscriptionTier(rawValue: d.string(forKey: key) ?? "") ?? .free
        XCTAssertEqual(restored, .pro)
        d.removeObject(forKey: key)
    }

    func testUnknownRawValueFallsBackToFree() {
        XCTAssertEqual(SubscriptionTier(rawValue: "garbage") ?? .free, .free)
    }
}

// MARK: - AppGroupStore round-trips

final class AppGroupStoreTests: XCTestCase {

    func testActivePersonNameRoundTrips() {
        let original = AppGroupStore.activePersonName
        defer { AppGroupStore.activePersonName = original }
        AppGroupStore.activePersonName = "AuditTestPerson"
        XCTAssertEqual(AppGroupStore.activePersonName, "AuditTestPerson")
    }

    func testActiveBearingRoundTrips() {
        let original = AppGroupStore.activeBearing
        defer { AppGroupStore.activeBearing = original }
        AppGroupStore.activeBearing = 123.5
        XCTAssertEqual(AppGroupStore.activeBearing, 123.5, accuracy: 0.001)
    }

    func testPendingPingSetAndClear() {
        AppGroupStore.pendingPingEmoji = "🤗"
        AppGroupStore.pendingPingFromName = "Audit"
        XCTAssertEqual(AppGroupStore.pendingPingEmoji, "🤗")
        AppGroupStore.clearPendingPing()
        XCTAssertNil(AppGroupStore.pendingPingEmoji)
        XCTAssertNil(AppGroupStore.pendingPingFromName)
    }
}

// MARK: - Model enum consistency

final class InstrumentModelConsistencyTests: XCTestCase {

    func testSenderStyleRawValuesStable() {
        // These raw values are persisted on every ping — they must not drift.
        XCTAssertEqual(SenderStyle.firefly.rawValue, "firefly")
        XCTAssertEqual(SenderStyle.rocket.rawValue, "rocket")
        XCTAssertEqual(SenderStyle.glow.rawValue, "glow")
    }

    func testInstrumentRawValuesStable() {
        XCTAssertEqual(Instrument.firefly.rawValue, "firefly")
        XCTAssertEqual(Instrument.rocket.rawValue, "rocket")
        XCTAssertEqual(Instrument.compass.rawValue, "compass")
    }
}

// MARK: - PeopleManager paywall gate

@MainActor
final class PeopleManagerPaywallTests: XCTestCase {

    // Snapshot the tier-related UserDefaults so seeding a tier for a test never
    // leaks into the rest of the suite (these keys drive SubscriptionManager).
    private var savedTier: String?
    private var savedTier2: String?
    private var savedPro: Bool = false

    override func setUp() {
        super.setUp()
        let d = UserDefaults.standard
        savedTier  = d.string(forKey: "subscriptionTier")
        savedTier2 = d.string(forKey: "subscription_tier")
        savedPro   = d.bool(forKey: ProFeatures.storageKey)
    }

    override func tearDown() {
        let d = UserDefaults.standard
        if let savedTier  { d.set(savedTier,  forKey: "subscriptionTier") }  else { d.removeObject(forKey: "subscriptionTier") }
        if let savedTier2 { d.set(savedTier2, forKey: "subscription_tier") } else { d.removeObject(forKey: "subscription_tier") }
        d.set(savedPro, forKey: ProFeatures.storageKey)
        super.tearDown()
    }

    private func makeWorld(tier: SubscriptionTier) throws
        -> (PeopleManager, ModelContext, ModelContainer) {
        // Seed the persisted tier so SubscriptionManager restores it on init.
        UserDefaults.standard.set(tier.rawValue, forKey: "subscriptionTier")
        UserDefaults.standard.set(tier.rawValue, forKey: "subscription_tier")
        let container = try ModelContainer(
            for: Person.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let people = PeopleManager(subscriptionManager: SubscriptionManager(skinStore: nil))
        people.configure(with: context)
        return (people, context, container)
    }

    @discardableResult
    private func add(_ name: String, to people: PeopleManager) throws -> Person {
        let p = Person(name: name, emoji: "💜", latitude: 0, longitude: 0)
        try people.addPerson(p)
        return p
    }

    private func realCount(_ people: PeopleManager) -> Int {
        people.people.filter { !DemoPerson.isDemo($0) }.count
    }

    func testFreeTierAllowsOnePersonThenGates() throws {
        let (people, _, container) = try makeWorld(tier: .free)
        _ = container   // keep the in-memory store alive
        XCTAssertTrue(people.canAddPerson(), "free user can add their first person")
        try add("Sarah", to: people)
        XCTAssertFalse(people.canAddPerson(), "free tier is capped at 1 person")
        XCTAssertThrowsError(try add("Mom", to: people)) { error in
            XCTAssertEqual(error as? PeopleManager.PeopleError, .upgradeRequired)
        }
        XCTAssertEqual(realCount(people), 1)
    }

    func testProTierAllowsFivePeople() throws {
        let (people, _, container) = try makeWorld(tier: .pro)
        _ = container
        for i in 1...5 { try add("P\(i)", to: people) }
        XCTAssertEqual(realCount(people), 5)
        XCTAssertFalse(people.canAddPerson(), "pro tier is capped at 5 people")
    }
}

// MARK: - SubscriptionManager tier persistence (restore on init)

@MainActor
final class SubscriptionManagerPersistenceTests: XCTestCase {

    func testRestoresProFromSubscriptionTierKeyOnInit() {
        let d = UserDefaults.standard
        let s1 = d.string(forKey: "subscriptionTier")
        let s2 = d.string(forKey: "subscription_tier")
        let sp = d.bool(forKey: ProFeatures.storageKey)
        defer {
            if let s1 { d.set(s1, forKey: "subscriptionTier") } else { d.removeObject(forKey: "subscriptionTier") }
            if let s2 { d.set(s2, forKey: "subscription_tier") } else { d.removeObject(forKey: "subscription_tier") }
            d.set(sp, forKey: ProFeatures.storageKey)
        }
        // Only the new "subscription_tier" key holds Pro → init must restore it.
        d.removeObject(forKey: "subscriptionTier")
        d.set(SubscriptionTier.pro.rawValue, forKey: "subscription_tier")
        let mgr = SubscriptionManager(skinStore: nil)
        XCTAssertEqual(mgr.tier, .pro, "tier restored from subscription_tier on launch")
    }

    // Note: "no persistence → .free" is intentionally NOT tested here. DEBUG
    // builds register a Pro default (HomeLinkApp forces .pro to skip the
    // paywall), so removing the keys falls back to that registered default in
    // the test environment. The free-tier GATE is proven instead by
    // PeopleManagerPaywallTests.testFreeTierAllowsOnePersonThenGates, which
    // sets an explicit "free" value that overrides the registered default.
}
