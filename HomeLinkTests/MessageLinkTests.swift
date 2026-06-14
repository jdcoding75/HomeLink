// MessageLinkTests.swift
// Pointward › Tests
//
// Phase 2 — the link builder is the one piece of the link-delivery path that
// must never leak data into the URL. These tests pin the exact format and prove
// it stays ID-ONLY (no content / emoji / name / senderID / query string).

import XCTest
@testable import HomeLink

final class MessageLinkTests: XCTestCase {

    func testURLIsExactIDOnlyFormat() {
        let id = UUID(uuidString: "12345678-1234-1234-1234-1234567890AB")!
        let url = MessageLink.url(for: id)
        XCTAssertEqual(url, "https://pointward.app/m/12345678-1234-1234-1234-1234567890AB")
    }

    func testURLContainsTheMessageID() {
        let id = UUID()
        let url = MessageLink.url(for: id)
        XCTAssertTrue(url.contains(id.uuidString), "the link must carry the message id")
        XCTAssertTrue(url.hasPrefix("https://pointward.app/m/"), "must use the /m/ path on the canonical host")
    }

    /// The link is the privacy boundary: nothing but the id may travel in it.
    func testURLLeaksNoFieldsAndHasNoQueryString() {
        let id = UUID()
        let url = MessageLink.url(for: id)
        XCTAssertFalse(url.contains("?"), "ID-only: no query string")
        XCTAssertFalse(url.contains("&"), "ID-only: no query params")
        XCTAssertFalse(url.contains("from"), "must NOT carry a sender id")
        XCTAssertFalse(url.contains("name"), "must NOT carry a display name")
        XCTAssertFalse(url.contains("emoji"), "must NOT carry the emoji")
        XCTAssertFalse(url.contains("content"), "must NOT carry the content")
        // Exactly: scheme + host + /m/ + uuid — four path-ish pieces, no more.
        XCTAssertEqual(url, "https://pointward.app/m/\(id.uuidString)")
    }

    func testShareTextIncludesLinkAndShortCode() {
        let link = "https://pointward.app/m/ABC"
        let text = MessageLink.shareText(senderName: "Sarah", link: link, shortCode: "ABC234")
        XCTAssertTrue(text.contains("Sarah"), "warm: names the sender")
        XCTAssertTrue(text.contains(link), "must include the link")
        XCTAssertTrue(text.contains("ABC234"), "must include the short-code fallback")
    }

    func testShareTextFallsBackToSomeoneWhenNameEmpty() {
        let text = MessageLink.shareText(senderName: "", link: "L", shortCode: "ABC234")
        XCTAssertTrue(text.contains("Someone"), "empty name degrades gracefully")
    }

    func testShareTextOmitsCodeClauseWhenNoCode() {
        let text = MessageLink.shareText(senderName: "Sarah", link: "L", shortCode: "")
        XCTAssertFalse(text.contains("enter"), "no code → no code clause")
        XCTAssertTrue(text.contains("L"), "link still present")
    }
}
