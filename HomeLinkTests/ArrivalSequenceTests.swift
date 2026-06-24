// ArrivalSequenceTests.swift
// HomeLinkTests
//
// [arrival-parity stage1] Locks the neutral `Arrival` input — its derived fields
// (style/emoji/message/senderName) come straight from the ReceivedPing, so any caller
// (PATH-2 now; PATH-1/replay later) builds the same shape. Hermetic: no device/SwiftUI.

import XCTest
@testable import HomeLink

final class ArrivalSequenceTests: XCTestCase {

    private func ping(style: SenderStyle, emoji: String, message: String?, from: String)
        -> PingManager.ReceivedPing {
        PingManager.ReceivedPing(
            fromName: from, emoji: emoji, timestamp: .now, remoteID: nil,
            senderStyle: style.rawValue, message: message, tagline: nil, isTest: false)
    }

    func testArrivalDerivesFromPing() {
        let p = ping(style: .rocket, emoji: "🚀", message: "to the moon", from: "Jess")
        let a = Arrival(ping: p, senderBearing: 137)
        XCTAssertEqual(a.style, .rocket)
        XCTAssertEqual(a.emoji, "🚀")
        XCTAssertEqual(a.message, "to the moon")
        XCTAssertEqual(a.senderName, "Jess")
        XCTAssertEqual(a.senderBearing, 137, accuracy: 0.001)
    }

    func testArrivalUnknownStyleDegradesToGlow() {
        // SenderStyle.from(unknown) → .glow (the wire-degrade rule) flows through Arrival.
        let p = PingManager.ReceivedPing(
            fromName: "x", emoji: "✨", timestamp: .now, remoteID: nil,
            senderStyle: "not-a-real-style", message: nil, tagline: nil, isTest: false)
        XCTAssertEqual(Arrival(ping: p, senderBearing: 0).style, .glow)
    }

    // The Arrival's style/emoji feed the SAME dispatch the receipt/transit use → the
    // sequence renders the right animation. (Cross-checks Stage 0's lock.)
    func testArrivalStyleFeedsDispatch() {
        let p = ping(style: .birthday, emoji: "🎁", message: nil, from: "Mom")
        let a = Arrival(ping: p, senderBearing: 0)
        XCTAssertEqual(AnimationDispatch.sendAnimationKind(for: a.style, emoji: a.emoji), .birthday)
        XCTAssertEqual(AnimationDispatch.receiptKind(for: a.style, emoji: a.emoji), .birthday)
    }
}
