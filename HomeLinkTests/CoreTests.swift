// CoreTests.swift
// Pointward › Tests
//
// Pure-logic tests for the parts that must never silently regress:
// bearing math, alignment thresholds, pairing-code format, and the
// free-tier instrument gate.

import XCTest
import CoreLocation
@testable import HomeLink

final class BearingCalculatorTests: XCTestCase {

    // Reference points
    private let london  = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
    private let newYork = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)

    // MARK: Bearings

    func testBearingLondonToNewYork() {
        // Great-circle initial bearing London → NYC ≈ 288° (WNW)
        let bearing = BearingCalculator.bearing(from: london, to: newYork)
        XCTAssertEqual(bearing, 288, accuracy: 2.0)
    }

    func testBearingDueNorth() {
        let origin = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let north  = CLLocationCoordinate2D(latitude: 10, longitude: 0)
        XCTAssertEqual(BearingCalculator.bearing(from: origin, to: north), 0, accuracy: 0.001)
    }

    func testBearingDueEast() {
        let origin = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let east   = CLLocationCoordinate2D(latitude: 0, longitude: 10)
        XCTAssertEqual(BearingCalculator.bearing(from: origin, to: east), 90, accuracy: 0.001)
    }

    func testBearingDueSouthAndWest() {
        let origin = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let south  = CLLocationCoordinate2D(latitude: -10, longitude: 0)
        let west   = CLLocationCoordinate2D(latitude: 0, longitude: -10)
        XCTAssertEqual(BearingCalculator.bearing(from: origin, to: south), 180, accuracy: 0.001)
        XCTAssertEqual(BearingCalculator.bearing(from: origin, to: west), 270, accuracy: 0.001)
    }

    // MARK: Distance

    func testDistanceLondonToNewYork() {
        // Haversine London → NYC ≈ 5570 km
        let km = BearingCalculator.distanceKm(from: london, to: newYork)
        XCTAssertEqual(km, 5570, accuracy: 30)
    }

    func testDistanceZero() {
        XCTAssertEqual(BearingCalculator.distanceKm(from: london, to: london), 0, accuracy: 0.001)
    }

    func testDistanceOneDegreeLatitude() {
        // 1° of latitude ≈ 111.2 km everywhere
        let a = CLLocationCoordinate2D(latitude: 50, longitude: 7)
        let b = CLLocationCoordinate2D(latitude: 51, longitude: 7)
        XCTAssertEqual(BearingCalculator.distanceKm(from: a, to: b), 111.2, accuracy: 1.0)
    }

    // MARK: Formatted distances

    func testFormattedDistanceMetricFirst() {
        UserDefaults.standard.set(false, forKey: "useMiles")
        defer { UserDefaults.standard.removeObject(forKey: "useMiles") }
        XCTAssertEqual(BearingCalculator.formattedDistance(142), "142 km · 88 mi")
        // Below a mile the imperial side drops to feet
        XCTAssertEqual(BearingCalculator.formattedDistance(0.5), "500 m · 1640 ft")
    }

    func testFormattedDistanceMilesFirst() {
        UserDefaults.standard.set(true, forKey: "useMiles")
        defer { UserDefaults.standard.removeObject(forKey: "useMiles") }
        XCTAssertEqual(BearingCalculator.formattedDistance(142), "88 mi · 142 km")
    }

    func testFormattedSmallDistanceUsesFeet() {
        UserDefaults.standard.set(true, forKey: "useMiles")
        defer { UserDefaults.standard.removeObject(forKey: "useMiles") }
        // 0.5 km = 0.31 mi → leads with feet
        XCTAssertTrue(BearingCalculator.formattedDistance(0.5).hasPrefix("1640 ft"))
    }

    func testCardinalDirections() {
        XCTAssertEqual(BearingCalculator.cardinalDirection(0), "N")
        XCTAssertEqual(BearingCalculator.cardinalDirection(90), "E")
        XCTAssertEqual(BearingCalculator.cardinalDirection(180), "S")
        XCTAssertEqual(BearingCalculator.cardinalDirection(270), "W")
        XCTAssertEqual(BearingCalculator.cardinalDirection(359), "N")
    }
}

// MARK: - Alignment detection

final class AlignmentTests: XCTestCase {

    func testLockWithinFiveDegrees() {
        XCTAssertTrue(BearingCalculator.isLockAligned(0))
        XCTAssertTrue(BearingCalculator.isLockAligned(4.9))
        XCTAssertTrue(BearingCalculator.isLockAligned(5.0))
        XCTAssertFalse(BearingCalculator.isLockAligned(5.1))
    }

    func testSendWithinFifteenDegrees() {
        XCTAssertTrue(BearingCalculator.isSendAligned(14.9))
        XCTAssertTrue(BearingCalculator.isSendAligned(15.0))
        XCTAssertFalse(BearingCalculator.isSendAligned(15.1))
        XCTAssertFalse(BearingCalculator.isSendAligned(90))
        XCTAssertFalse(BearingCalculator.isSendAligned(180))
    }

    func testNearNorthWrapAround() {
        // 359° relative is only 1° off — the wrap must not read as 359° off
        XCTAssertEqual(BearingCalculator.alignmentError(relativeBearing: 359), 1, accuracy: 0.001)
        XCTAssertEqual(BearingCalculator.alignmentError(relativeBearing: 1), 1, accuracy: 0.001)
        XCTAssertTrue(BearingCalculator.isLockAligned(359))
        XCTAssertTrue(BearingCalculator.isLockAligned(355.5))
        XCTAssertFalse(BearingCalculator.isLockAligned(354))
        XCTAssertTrue(BearingCalculator.isSendAligned(345.5))
        XCTAssertFalse(BearingCalculator.isSendAligned(344))
    }

    func testNegativeAndOverflowInputs() {
        XCTAssertEqual(BearingCalculator.alignmentError(relativeBearing: -1), 1, accuracy: 0.001)
        XCTAssertEqual(BearingCalculator.alignmentError(relativeBearing: 361), 1, accuracy: 0.001)
        XCTAssertEqual(BearingCalculator.alignmentError(relativeBearing: 180), 180, accuracy: 0.001)
    }
}

// MARK: - Pairing codes

final class PairingCodeTests: XCTestCase {

    func testGeneratedFormatIsAlwaysPointDashFour() {
        for _ in 0..<100 {
            let code = SupabaseService.generatePairingCode()
            XCTAssertTrue(SupabaseService.isValidPairingCode(code),
                          "generated code \(code) failed its own validation")
            XCTAssertEqual(code.count, 10)
            XCTAssertTrue(code.hasPrefix("POINT-"))
            // No ambiguous characters, ever
            for forbidden in ["0", "O", "1", "I", "L"] {
                XCTAssertFalse(code.dropFirst(6).contains(forbidden),
                               "code \(code) contains ambiguous char \(forbidden)")
            }
        }
    }

    func testValidationRejectsWrongShapes() {
        XCTAssertFalse(SupabaseService.isValidPairingCode(""))
        XCTAssertFalse(SupabaseService.isValidPairingCode("POINT-"))
        XCTAssertFalse(SupabaseService.isValidPairingCode("POINT-AB"))       // too short
        XCTAssertFalse(SupabaseService.isValidPairingCode("POINT-ABCDE"))    // too long
        XCTAssertFalse(SupabaseService.isValidPairingCode("PONT-ABCD"))      // wrong prefix
        XCTAssertFalse(SupabaseService.isValidPairingCode("point-abcd"))     // lowercase
        XCTAssertFalse(SupabaseService.isValidPairingCode("POINT-AB!?"))     // symbols
        XCTAssertTrue(SupabaseService.isValidPairingCode("POINT-GP2S"))
    }

    func testNormalizationAcceptsHumanInput() {
        // The UI displays "POINT · GP2S" — people type all of these:
        XCTAssertEqual(SupabaseService.normalizePairingCode("POINT-GP2S"), "POINT-GP2S")
        XCTAssertEqual(SupabaseService.normalizePairingCode("point gp2s"), "POINT-GP2S")
        XCTAssertEqual(SupabaseService.normalizePairingCode("POINT · GP2S"), "POINT-GP2S")
        XCTAssertEqual(SupabaseService.normalizePairingCode("gp2s"), "POINT-GP2S")
        XCTAssertEqual(SupabaseService.normalizePairingCode("  GP2S  "), "POINT-GP2S")
    }

    func testCodesAreUniqueAcrossGenerations() {
        // 10 draws from a 923k space — a collision here means the RNG broke
        let codes = (0..<10).map { _ in SupabaseService.generatePairingCode() }
        XCTAssertEqual(Set(codes).count, codes.count, "duplicate codes generated: \(codes)")
    }
}

// MARK: - Instrument selection (tier gate)

@MainActor
final class InstrumentSelectionTests: XCTestCase {

    private let instrumentKey = InstrumentStore.storageKey
    private let tierKey = "subscriptionTier"
    private var savedInstrument: String?
    private var savedTier: String?

    override func setUp() {
        super.setUp()
        savedInstrument = UserDefaults.standard.string(forKey: instrumentKey)
        savedTier = UserDefaults.standard.string(forKey: tierKey)
    }

    override func tearDown() {
        restore(savedInstrument, forKey: instrumentKey)
        restore(savedTier, forKey: tierKey)
        super.tearDown()
    }

    private func restore(_ value: String?, forKey key: String) {
        if let value { UserDefaults.standard.set(value, forKey: key) }
        else { UserDefaults.standard.removeObject(forKey: key) }
    }

    func testFreeUserAlwaysGetsCompass() {
        UserDefaults.standard.set(Instrument.bow.rawValue, forKey: instrumentKey)
        UserDefaults.standard.set("free", forKey: tierKey)
        let store = InstrumentStore()
        XCTAssertEqual(store.selected, .compass, "free tier must be forced back to the compass")
    }

    func testProUserKeepsTheirInstrument() {
        for instrument in Instrument.allCases {
            UserDefaults.standard.set(instrument.rawValue, forKey: instrumentKey)
            UserDefaults.standard.set("unlocked", forKey: tierKey)   // SubscriptionTier.pro
            let store = InstrumentStore()
            XCTAssertEqual(store.selected, instrument)
        }
    }

    func testDefaultIsCompass() {
        UserDefaults.standard.removeObject(forKey: instrumentKey)
        UserDefaults.standard.removeObject(forKey: tierKey)
        let store = InstrumentStore()
        XCTAssertEqual(store.selected, .compass)
    }

    func testEnforceTierDowngradesAtRuntime() {
        UserDefaults.standard.set(Instrument.flick.rawValue, forKey: instrumentKey)
        UserDefaults.standard.set("unlocked", forKey: tierKey)
        let store = InstrumentStore()
        XCTAssertEqual(store.selected, .flick)
        store.enforceTier(.free)   // purchase restore failed / downgrade
        XCTAssertEqual(store.selected, .compass)
    }

    func testInstrumentToSenderStyleWireMapping() {
        // The wire format the catch animation keys off — must never drift
        XCTAssertEqual(Instrument.compass.senderStyle, .glow)
        XCTAssertEqual(Instrument.bow.senderStyle, .bowArrow)
        XCTAssertEqual(Instrument.firefly.senderStyle, .firefly)
        XCTAssertEqual(Instrument.flick.senderStyle, .fingerFlick)
    }

    func testOnlyCompassIsFree() {
        XCTAssertFalse(Instrument.compass.requiresPro)
        XCTAssertTrue(Instrument.bow.requiresPro)
        XCTAssertTrue(Instrument.firefly.requiresPro)
        XCTAssertTrue(Instrument.flick.requiresPro)
    }
}
