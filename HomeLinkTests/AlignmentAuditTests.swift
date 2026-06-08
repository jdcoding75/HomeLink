// AlignmentAuditTests.swift
// Pointward › Tests
//
// THE ALIGNMENT RULE — only the COMPASS aligns by rotating the phone. Every
// other instrument that aims does so by finger GESTURE (bow spin · flick
// swipe · rocket spin); wind (breath), wand (shake), and plane (auto-aim,
// tap-only) need no aiming at all.
//
// The gesture wiring itself lives in SwiftUI views (DragGesture →
// spinAngle/flickDeg, never CLHeading), which a unit test can't drive. These
// tests pin the structural invariants the views implement, exposed as data on
// `Instrument` (alignsByPhoneRotation / requiresAlignment), so a regression
// that reintroduces heading-based aiming on a non-compass instrument shows up
// here as a red test.

import XCTest
@testable import HomeLink

final class AlignmentAuditTests: XCTestCase {

    /// Compass SHOULD align by phone rotation — this is correct behaviour.
    func testCompassUsesPhoneRotation() {
        XCTAssertTrue(Instrument.compass.alignsByPhoneRotation,
                      "the compass aligns by rotating the phone — by design")
        XCTAssertTrue(Instrument.compass.requiresAlignment)
    }

    /// THE RULE: the compass is the ONLY instrument that uses phone rotation.
    func testOnlyCompassUsesPhoneRotation() {
        let rotators = Instrument.allCases.filter { $0.alignsByPhoneRotation }
        XCTAssertEqual(rotators, [.compass],
                       "only the compass may align by phone rotation; found \(rotators)")
    }

    /// Bow aims (it fires only when drawn AT the person) but by FINGER SPIN on
    /// the rim — never phone rotation.
    func testBowUsesFingerGestureOnly() {
        XCTAssertTrue(Instrument.bow.requiresAlignment)
        XCTAssertFalse(Instrument.bow.alignsByPhoneRotation,
                       "the bow aims by finger spin, not phone rotation")
        XCTAssertEqual(Instrument.bow.senderStyle, .bowArrow)
    }

    /// Rocket aims by FINGER SPIN on the body — nose points from spinAngle.
    func testRocketUsesFingerGestureOnly() {
        XCTAssertTrue(Instrument.rocket.requiresAlignment)
        XCTAssertFalse(Instrument.rocket.alignsByPhoneRotation,
                       "the rocket aims by finger spin, not phone rotation")
        XCTAssertEqual(Instrument.rocket.senderStyle, .rocket)
    }

    /// Flick aims by the SWIPE direction (gesture), checked against the marker
    /// — not by where the phone points.
    func testFlickUsesGestureAim() {
        XCTAssertTrue(Instrument.flick.requiresAlignment)
        XCTAssertFalse(Instrument.flick.alignsByPhoneRotation,
                       "the flick aims by swipe direction, not phone rotation")
        XCTAssertEqual(Instrument.flick.senderStyle, .fingerFlick)
    }

    /// Wind sends on a breath alone — no aiming, phone direction irrelevant.
    func testWindHasNoAlignmentRequirement() {
        // Wind rides the `.firefly` case in the wire format.
        XCTAssertFalse(Instrument.firefly.requiresAlignment,
                       "wind sends on a breath — no alignment")
        XCTAssertFalse(Instrument.firefly.alignsByPhoneRotation)
    }

    /// Wand sends on a shake alone — no aiming, phone direction irrelevant.
    func testWandHasNoAlignmentRequirement() {
        XCTAssertFalse(Instrument.wand.requiresAlignment,
                       "the wand sends on a shake — magic finds them")
        XCTAssertFalse(Instrument.wand.alignsByPhoneRotation)
    }

    /// Plane auto-aims toward the person: tap the propeller, it flies itself.
    /// No user alignment, no phone rotation.
    func testPlaneAutoAims() {
        XCTAssertFalse(Instrument.plane.requiresAlignment,
                       "the plane auto-aims — the user never aims it")
        XCTAssertFalse(Instrument.plane.alignsByPhoneRotation,
                       "the plane never requires phone rotation")
    }

    /// Sweep: every non-compass instrument is free of phone-rotation aiming.
    func testNoNonCompassInstrumentUsesPhoneRotation() {
        for inst in Instrument.allCases where inst != .compass {
            XCTAssertFalse(inst.alignsByPhoneRotation,
                           "\(inst) must not align by phone rotation")
        }
    }
}
