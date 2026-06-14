// Build7SeededBearingTests.swift
// Pointward › Tests
//
// Phase 2 Build 7 — compass seeded-bearing degradation. Tests the pure seed
// function (determinism / distinctness / fallback / range) and the live
// CompassManager seeded branch (nil rawBearing, no far-from-home, heading-only
// paint with no user location → which is also the reportPointing guard).

import XCTest
import CoreLocation
@testable import HomeLink

@MainActor
final class Build7SeededBearingTests: XCTestCase {

    private func person(senderID: String? = nil, lat: Double = 0, lng: Double = 0) -> Person {
        Person(name: "John", emoji: "", latitude: lat, longitude: lng, senderID: senderID)
    }

    // ── Pure seed: determinism / distinctness / fallback / range ──────────

    func testSeededBearingIsDeterministic() {
        let p = person(senderID: "3ef2a987-DS2CVW")
        let a = CompassManager.seededAbsoluteBearing(for: p)
        let b = CompassManager.seededAbsoluteBearing(for: p)
        XCTAssertEqual(a, b, "same key → same degrees, every call (and every launch)")
    }

    func testSeededBearingDistinctAcrossSenderIDs() {
        // 20 distinct senderIDs → the FNV-1a fold spreads them across the circle.
        let bearings = Set((0..<20).map {
            CompassManager.seededAbsoluteBearing(for: person(senderID: "sender-\($0)"))
        })
        XCTAssertGreaterThan(bearings.count, 1, "different senderIDs → different bearings")
    }

    func testSeededBearingFallsBackToPersonID() {
        // No senderID → keyed on person.id (always present), still deterministic.
        let p = person(senderID: nil)
        let a = CompassManager.seededAbsoluteBearing(for: p)
        let b = CompassManager.seededAbsoluteBearing(for: p)
        XCTAssertEqual(a, b, "senderID nil → person.id key, deterministic")
        // A different person.id → (almost certainly) a different bearing.
        let q = person(senderID: nil)
        XCTAssertNotEqual(p.id, q.id)
    }

    func testSeededBearingInRange() {
        for i in 0..<50 {
            let deg = CompassManager.seededAbsoluteBearing(for: person(senderID: "k\(i)"))
            XCTAssertTrue(deg >= 0 && deg < 360, "bearing must be 0..<360, got \(deg)")
        }
    }

    func testEmptySenderIDFallsBackToPersonID() {
        // An empty-string senderID is treated as "no senderID" → person.id key.
        let p = Person(name: "X", latitude: 0, longitude: 0, senderID: "")
        let viaEmpty = CompassManager.seededAbsoluteBearing(for: p)
        XCTAssertTrue(viaEmpty >= 0 && viaEmpty < 360)
    }

    // ── Live seeded branch (CompassManager) ───────────────────────────────

    func testSeededContactPaintsBearingWithNoUserLocation() {
        let compass = CompassManager(skinStore: SkinStore())
        let p = person(senderID: "abc123", lat: 0, lng: 0)   // no real location
        compass.start(tracking: p)   // no CLLocation delivered in a unit test

        // Heading-only paint: bearing = seeded − currentHeading(0) = seeded.
        XCTAssertEqual(compass.state.bearingDegrees,
                       CompassManager.seededAbsoluteBearing(for: p),
                       accuracy: 0.0001,
                       "seeded direction paints even with no user location")
        // The "this is seeded" signal — also the reportPointing guard.
        XCTAssertNil(compass.rawBearingToTarget, "seeded → rawBearingToTarget nil")
        // No real distance → never "far from home" (no null-island 8000km flag).
        XCTAssertFalse(compass.state.isFarFromHome)
        XCTAssertEqual(compass.state.distanceKm, 0, "seeded → no numeric distance")
    }

    func testReportPointingGuardIsNilForSeeded() {
        // reportPointingIfNeeded's first guard is `rawBearingToTarget != nil`.
        // For a seeded contact it's nil → mutual pointing can NEVER fire (matrix:
        // mutual REQUIRES_REAL), closing the Build-5 mirror-write leak.
        let compass = CompassManager(skinStore: SkinStore())
        compass.start(tracking: person(senderID: "seeded-1", lat: 0, lng: 0))
        XCTAssertNil(compass.rawBearingToTarget,
                     "guard value nil → reportPointing returns early for seeded")
    }
}
