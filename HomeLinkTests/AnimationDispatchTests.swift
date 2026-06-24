// AnimationDispatchTests.swift
// HomeLinkTests
//
// [arrival-parity stage0] Locks the PURE animation dispatch (AnimationDispatch.send/
// receiptKind) — the "path X stage Y → animation Z" assertions. Hermetic: no device,
// no SwiftUI, no ServiceContainer. Any future pipeline move (Stage 1+) that silently
// changes which animation a style plays will fail here.

import XCTest
@testable import HomeLink

final class AnimationDispatchTests: XCTestCase {

    // SEND: every style → expected kind (non-special emoji "")
    func testSendKindPerStyle() {
        let expected: [SenderStyle: SendAnimationKind] = [
            .glow: .shared, .shootingStar: .shared, .firefly: .shared, .rocket: .shared,
            .fingerFlick: .fingerFlick, .bowArrow: .bowArrow, .wand: .wand, .plane: .plane,
            .birthday: .birthday, .firework: .firework,
        ]
        for (style, kind) in expected {
            XCTAssertEqual(AnimationDispatch.sendAnimationKind(for: style, emoji: ""), kind, "send \(style)")
        }
    }

    // SEND: legacy emoji fallback overrides a non-special style
    func testSendKindEmojiFallback() {
        XCTAssertEqual(AnimationDispatch.sendAnimationKind(for: .glow, emoji: "🎂"), .birthday)
        XCTAssertEqual(AnimationDispatch.sendAnimationKind(for: .glow, emoji: "🎆"), .firework)
        // a birthday-style send with the 🎁 default still → birthday (by style)
        XCTAssertEqual(AnimationDispatch.sendAnimationKind(for: .birthday, emoji: "🎁"), .birthday)
    }

    // RECEIPT: every style → expected kind (incl. wand→.standard R4, glow→.compass)
    func testReceiptKindPerStyle() {
        let expected: [SenderStyle: ReceiptKind] = [
            .glow: .compass, .shootingStar: .standard, .firefly: .wind, .rocket: .rocket,
            .fingerFlick: .flick, .bowArrow: .bow, .wand: .standard, .plane: .plane,
            .birthday: .birthday, .firework: .firework,
        ]
        for (style, kind) in expected {
            XCTAssertEqual(AnimationDispatch.receiptKind(for: style, emoji: ""), kind, "receipt \(style)")
        }
    }

    func testReceiptKindEmojiFallback() {
        XCTAssertEqual(AnimationDispatch.receiptKind(for: .glow, emoji: "🎂"), .birthday)
        XCTAssertEqual(AnimationDispatch.receiptKind(for: .glow, emoji: "🎆"), .firework)
    }

    // Exhaustiveness sanity: every style is a total function for both dispatchers.
    func testAllStylesTotal() {
        for style in SenderStyle.allCases {
            _ = AnimationDispatch.sendAnimationKind(for: style, emoji: "✨")
            _ = AnimationDispatch.receiptKind(for: style, emoji: "✨")
        }
    }
}
