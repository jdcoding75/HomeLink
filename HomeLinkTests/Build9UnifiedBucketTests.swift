// Build9UnifiedBucketTests.swift
// Pointward › Tests
//
// Phase 2 Build 9 — the unified, SENDER-AGNOSTIC history bucket. The bucket is now
// built purely from PingManager.caughtHistory (no server "messages sent to me"
// query exists). These exercise the REAL recordCaught behaviour that the bucket
// reads: all-senders (no per-person filter), opened-/m/ messages land in history,
// remoteID dedup, and the 50-cap — the contract CompassView.loadCompassThoughts
// depends on.

import XCTest
@testable import HomeLink

@MainActor
final class Build9UnifiedBucketTests: XCTestCase {

    // caughtHistory persists to UserDefaults.standard — isolate each test so a
    // prior run's history doesn't leak into a fresh PingManager (which restores it).
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "caughtHistory")
    }
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "caughtHistory")
        super.tearDown()
    }

    private func makePings() -> PingManager {
        PingManager(networkService: MockNetworkService())
    }

    private func ping(from name: String, id: UUID = UUID()) -> PingManager.ReceivedPing {
        PingManager.ReceivedPing(fromName: name, emoji: "🤗", timestamp: .now,
                                 remoteID: id, isTest: false)
    }

    // (a) The bucket is sender-agnostic — history holds EVERY sender, unfiltered.
    func testCaughtHistoryHoldsAllSendersUnfiltered() {
        let pings = makePings()
        pings.recordCaught(ping(from: "John"))
        pings.recordCaught(ping(from: "Mum"))
        pings.recordCaught(ping(from: "A stranger"))

        let senders = Set(pings.caughtHistory.map(\.fromName))
        XCTAssertEqual(senders, ["John", "Mum", "A stranger"],
                       "every sender shows — the bucket is no longer scoped to one person")
    }

    // (b) An opened /m/ message lands in history (the build-9 IncomingMessageView fix
    //     records it; previously /m/ opens were never recorded). Modelled here as a
    //     message-derived ping with remoteID = message.id.
    func testOpenedMessageLandsInHistory() {
        let pings = makePings()
        let messageID = UUID()
        // What IncomingMessageView.historyPing(from:) now records on a valid open.
        pings.recordCaught(PingManager.ReceivedPing(
            fromName: "John", emoji: "🎁", timestamp: .now, remoteID: messageID))

        XCTAssertEqual(pings.caughtHistory.count, 1)
        XCTAssertEqual(pings.caughtHistory.first?.remoteID, messageID)
    }

    // (c) No duplicate when the same message is opened (/m/) then short-code-claimed
    //     — both record with remoteID = message.id, and recordCaught dedups on it.
    func testNoDuplicateAcrossOpenThenClaim() {
        let pings = makePings()
        let messageID = UUID()
        pings.recordCaught(ping(from: "John", id: messageID))   // /m/ open
        pings.recordCaught(ping(from: "John", id: messageID))   // later short-code claim

        XCTAssertEqual(pings.caughtHistory.count, 1, "remoteID dedup → one entry, not two")
    }

    // (d) The 50-cap holds for the unified set (FIFO — newest kept).
    func testFiftyCapHoldsForUnifiedBucket() {
        let pings = makePings()
        for i in 0..<60 { pings.recordCaught(ping(from: "sender-\(i)")) }

        XCTAssertEqual(pings.caughtHistory.count, PingManager.maxCaughtHistory)
        XCTAssertEqual(PingManager.maxCaughtHistory, 50)
        // Newest survive: the last-recorded sender is still present, the first isn't.
        let names = Set(pings.caughtHistory.map(\.fromName))
        XCTAssertTrue(names.contains("sender-59"), "newest kept")
        XCTAssertFalse(names.contains("sender-0"), "oldest dropped (FIFO)")
    }
}
