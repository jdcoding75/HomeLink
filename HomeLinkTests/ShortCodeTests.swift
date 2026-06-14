// ShortCodeTests.swift
// Pointward › Tests
//
// Phase 2 Build 4b — the short-code fallback. These pin the two PURE pieces of
// the claim path: input normalization, and the newest-plays / rest-to-history
// split of a (newest-first) RPC result.

import XCTest
@testable import HomeLink

final class ShortCodeTests: XCTestCase {

    // MARK: - Normalization (lowercase / spaces → canonical)

    func testNormalizeUppercases() {
        XCTAssertEqual(ShortCode.normalize("ds2cvw"), "DS2CVW")
    }

    func testNormalizeStripsSpacesAndIsCaseInsensitive() {
        XCTAssertEqual(ShortCode.normalize("  ds 2c vw "), "DS2CVW")
        XCTAssertEqual(ShortCode.normalize("DS2CVW"), "DS2CVW")
        XCTAssertEqual(ShortCode.normalize("\tDs2\nCvw "), "DS2CVW")
    }

    func testIsCompleteGatesOnSixChars() {
        XCTAssertTrue(ShortCode.isComplete("ds2cvw"))
        XCTAssertTrue(ShortCode.isComplete(" DS2 CVW "))
        XCTAssertFalse(ShortCode.isComplete("ds2cv"))   // 5
        XCTAssertFalse(ShortCode.isComplete("ds2cvwx")) // 7
        XCTAssertFalse(ShortCode.isComplete(""))
    }

    // MARK: - Zero-result handling

    func testSplitOfZeroResultsYieldsNoNewestNoRest() {
        let (newest, rest) = ShortCodeClaim.split([])
        XCTAssertNil(newest, "zero results → nothing to play (caller shows empty state)")
        XCTAssertTrue(rest.isEmpty, "zero results → nothing to history")
    }

    // MARK: - Newest-plays / rest-to-history split (multi-message)

    func testSplitOfManyPlaysNewestRestToHistory() {
        // RPC returns NEWEST-FIRST → first plays, the remainder go to history.
        let msgs = [msg("newest"), msg("middle"), msg("oldest")]
        let (newest, rest) = ShortCodeClaim.split(msgs)
        XCTAssertEqual(newest?.content, "newest", "the newest (first) message plays")
        XCTAssertEqual(rest.map(\.content), ["middle", "oldest"],
                       "the rest (older) drop into history, order preserved")
        XCTAssertEqual(rest.count, 2)
    }

    func testSplitOfOnePlaysItWithEmptyHistory() {
        let (newest, rest) = ShortCodeClaim.split([msg("only")])
        XCTAssertEqual(newest?.content, "only")
        XCTAssertTrue(rest.isEmpty, "a single result plays, nothing to history")
    }

    // A valid emoji+instrument-only message (no content) must split fine too.
    func testSplitToleratesEmptyContentMessages() {
        let (newest, rest) = ShortCodeClaim.split([msgEmptyContent(), msg("older")])
        XCTAssertNotNil(newest)
        XCTAssertNil(newest?.content, "empty-content message is valid and still the newest")
        XCTAssertEqual(rest.map(\.content), ["older"])
    }

    // MARK: - Fixtures

    private func msg(_ content: String) -> Message {
        Message(id: UUID(), senderID: UUID(), senderDisplayName: "Sender",
                content: content, emoji: "🤗", instrument: "compass",
                opened: false, openedAt: nil, createdAt: nil)
    }

    private func msgEmptyContent() -> Message {
        Message(id: UUID(), senderID: UUID(), senderDisplayName: "Sender",
                content: nil, emoji: "🎁", instrument: "bow",
                opened: false, openedAt: nil, createdAt: nil)
    }
}
