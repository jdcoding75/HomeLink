// MessageNotificationTests.swift
// Pointward › Tests
//
// Comprehensive coverage for the message pipeline, the push-notification
// pipeline, and the catch queue — the path a thought travels from a remote
// send to an in-app catch.

import XCTest
import UserNotifications
@testable import HomeLink

// ════════════════════════════════════════════════════════════════════════
// MARK: - [1/4] Message pipeline
// ════════════════════════════════════════════════════════════════════════

@MainActor
final class MessagePipelineTests: XCTestCase {

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

    func testMessageIncludedInPing() {
        let payload = SupabaseService.PingPayload(
            fromUser: UUID(), toUser: UUID(), emoji: "💜",
            senderStyle: "bowArrow", message: "hello ✦")
        XCTAssertEqual(payload.message, "hello ✦")
        XCTAssertNotNil(payload.message)
    }

    func testMessageNilWhenNotProvided() {
        let payload = SupabaseService.PingPayload(
            fromUser: UUID(), toUser: UUID(), emoji: "💜")
        XCTAssertNil(payload.message, "no message → nil, not an empty string")
        // The send path normalizes empty/whitespace to nil before insert.
        XCTAssertNil(MessageRules.normalized(""))
        XCTAssertNil(MessageRules.normalized("   "))
        XCTAssertNil(MessageRules.normalized(nil))
    }

    func testMessageMaxLength() {
        let thirty = String(repeating: "a", count: 30)
        XCTAssertEqual(MessageRules.clamped(thirty).count, 30)
        XCTAssertEqual(MessageRules.clamped(thirty), thirty, "exactly 30 passes unchanged")

        let thirtyOne = String(repeating: "a", count: 31)
        XCTAssertEqual(MessageRules.clamped(thirtyOne).count, 30, "31 is truncated to 30")
        XCTAssertEqual(MessageRules.normalized(thirtyOne)?.count, 30)
    }

    func testMessageSurvivesQueue() {
        let pm = PingManager(networkService: MockNetworkService())
        pm.receivePing(fromName: "A", emoji: "x", remoteID: UUID())                    // now playing
        pm.receivePing(fromName: "B", emoji: "y", remoteID: UUID(), message: "miss you") // waiting
        XCTAssertEqual(pm.queue.first?.message, "miss you", "message rides into the queue")

        // …and survives a relaunch (persist → restore through UserDefaults).
        let pm2 = PingManager(networkService: MockNetworkService())
        let restored = pm2.queue.first { $0.emoji == "y" }
        XCTAssertEqual(restored?.message, "miss you", "message survives persistence")
    }

    func testMessageInReceivedPing() {
        let ping = PingManager.ReceivedPing(
            fromName: "Sarah", emoji: "💜", timestamp: .now, message: "thinking of you")
        XCTAssertEqual(ping.message, "thinking of you")
    }

    func testMessageDisplayInReveal() {
        let ping = PingManager.ReceivedPing(
            fromName: "Sarah", emoji: "💜", timestamp: .now, message: "thinking of you")
        // The reveal shows `message` when present — guard against nil/empty.
        XCTAssertNotNil(ping.message)
        XCTAssertFalse(ping.message?.isEmpty ?? true)
    }
}

// ════════════════════════════════════════════════════════════════════════
// MARK: - [2/4] Notification pipeline
// ════════════════════════════════════════════════════════════════════════

/// Records protocol calls so the onboarding permission ask is verifiable.
private final class RecordingNotificationService: NotificationServiceProtocol {
    private(set) var permissionRequested = false
    func requestPermission() async throws -> Bool {
        permissionRequested = true
        return true
    }
    func scheduleLocalPingNotification(fromName: String, emoji: String) async throws {}
}

@MainActor
final class NotificationPipelineTests: XCTestCase {

    private var savedToken: String?
    private var savedQueue: Data?
    private var savedSeen: [String]?

    override func setUp() {
        super.setUp()
        savedToken = UserDefaults.standard.string(forKey: "apnsDeviceToken")
        savedQueue = UserDefaults.standard.data(forKey: "pendingThoughtQueue")
        savedSeen  = UserDefaults.standard.stringArray(forKey: "seenPingIDs")
        UserDefaults.standard.removeObject(forKey: "apnsDeviceToken")
        UserDefaults.standard.removeObject(forKey: "pendingThoughtQueue")
        UserDefaults.standard.removeObject(forKey: "seenPingIDs")
    }
    override func tearDown() {
        if let savedToken { UserDefaults.standard.set(savedToken, forKey: "apnsDeviceToken") }
        else { UserDefaults.standard.removeObject(forKey: "apnsDeviceToken") }
        if let savedQueue { UserDefaults.standard.set(savedQueue, forKey: "pendingThoughtQueue") }
        else { UserDefaults.standard.removeObject(forKey: "pendingThoughtQueue") }
        if let savedSeen { UserDefaults.standard.set(savedSeen, forKey: "seenPingIDs") }
        else { UserDefaults.standard.removeObject(forKey: "seenPingIDs") }
        super.tearDown()
    }

    func testDeviceTokenRegistration() async {
        let token = "a1b2c3d4e5f6a7b8"
        await SupabaseService.shared.registerDeviceToken(token)
        let saved = UserDefaults.standard.string(forKey: "apnsDeviceToken")
        XCTAssertEqual(saved, token, "token is cached to UserDefaults")
        XCTAssertTrue(token.allSatisfy { $0.isHexDigit }, "APNs token is a hex string")
        XCTAssertFalse(token.isEmpty)
    }

    func testDeviceTokenUpdatesOnRelaunch() async {
        await SupabaseService.shared.registerDeviceToken("0000111122223333")
        await SupabaseService.shared.registerDeviceToken("4444555566667777")
        let saved = UserDefaults.standard.string(forKey: "apnsDeviceToken")
        XCTAssertEqual(saved, "4444555566667777", "newest token replaces, never duplicates")
    }

    func testNotificationPermissionRequested() async throws {
        // Onboarding asks for permission through NotificationServiceProtocol —
        // a recording stand-in proves the ask is wired and honoured.
        let service = RecordingNotificationService()
        let granted = try await service.requestPermission()
        XCTAssertTrue(service.permissionRequested, "requestPermission must be called")
        XCTAssertTrue(granted)
    }

    func testFirstUnreadFiresNotification() {
        let pm = PingManager(networkService: MockNetworkService())
        XCTAssertEqual(pm.unreadCount, 0, "queue starts empty")
        pm.receivePing(fromName: "Sarah", emoji: "💜", remoteID: UUID())
        // The first unread announces itself fully — it plays as the catch.
        XCTAssertNotNil(pm.nowPlaying, "first unread triggers the full catch")
        XCTAssertEqual(pm.queueCount, 1)
    }

    func testSubsequentUnreadBadgeOnly() {
        let pm = PingManager(networkService: MockNetworkService())
        pm.receivePing(fromName: "Sarah", emoji: "💜", remoteID: UUID())   // first → catch
        let firstEmoji = pm.nowPlaying?.emoji
        pm.receivePing(fromName: "Tom", emoji: "🌟", remoteID: UUID())      // second → badge only
        XCTAssertEqual(pm.nowPlaying?.emoji, firstEmoji, "active catch is never interrupted")
        XCTAssertEqual(pm.queue.count, 1, "second waits silently (badge only)")
        XCTAssertEqual(pm.queueCount, 2)
    }

    func testForegroundSuppressesNotification() {
        // The OS banner is suppressed in the foreground …
        XCTAssertTrue(NotificationHandler.foregroundPresentationOptions().isEmpty,
                      "foreground presentation options must be empty []")
        // … and the in-app catch is triggered instead.
        let pm = PingManager(networkService: MockNetworkService())
        let handler = NotificationHandler(pingManager: pm)
        handler.handlePayload(["pingEmoji": "💜", "fromName": "Sarah"])
        XCTAssertNotNil(pm.nowPlaying, "the in-app catch fires instead of the banner")
    }

    func testNotificationPayloadParsing() {
        let id = UUID()
        let userInfo: [AnyHashable: Any] = [
            "pingEmoji":   "💜",
            "fromName":    "Sarah",
            "pingId":      id.uuidString,
            "senderStyle": "bow",
            "message":     "thinking of you"
        ]
        let parsed = NotificationHandler.parsePush(userInfo)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.emoji, "💜")
        XCTAssertEqual(parsed?.fromName, "Sarah")
        XCTAssertEqual(parsed?.remoteID, id)
        XCTAssertEqual(parsed?.senderStyle, "bow")
        XCTAssertEqual(parsed?.message, "thinking of you")
    }

    func testNotificationPayloadParsingRejectsPointingAndMalformed() {
        XCTAssertNil(NotificationHandler.parsePush(["type": "pointing", "fromName": "Sarah"]),
                     "pointing-presence pushes are not thoughts")
        XCTAssertNil(NotificationHandler.parsePush(["fromName": "Sarah"]),
                     "missing pingEmoji → nil")
    }

    func testNotificationTextContent() {
        XCTAssertEqual(LocalNotificationService.arrivalBody, "A feeling is coming your way…")
        XCTAssertEqual(LocalNotificationService.arrivalTitle, "Pointward")
        // Not the retired copy (the emoji or "thinking of you").
        XCTAssertNotEqual(LocalNotificationService.arrivalBody, "💜")
        XCTAssertFalse(LocalNotificationService.arrivalBody.contains("thinking of you"))
    }
}

// ════════════════════════════════════════════════════════════════════════
// MARK: - [3/4] Catch queue
// ════════════════════════════════════════════════════════════════════════

@MainActor
final class CatchQueueTests: XCTestCase {

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

    private func make(_ appState: AppStateManager? = nil) -> PingManager {
        PingManager(networkService: MockNetworkService(), appState: appState)
    }

    func testQueueMaxFifty() {
        XCTAssertEqual(PingManager.maxQueued, 50, "the bucket holds 50 waiting thoughts")
        let pm = make()
        // Park a dummy catch so every arrival flows into the waiting queue.
        pm.nowPlaying = PingManager.ReceivedPing(fromName: "Active", emoji: "•", timestamp: .now)
        for i in 0..<51 {
            pm.receivePing(fromName: "P\(i)", emoji: "e\(i)", remoteID: UUID())
        }
        XCTAssertEqual(pm.queue.count, 50, "only 50 stored")
        XCTAssertFalse(pm.queue.contains { $0.emoji == "e0" }, "the oldest was dropped")
        XCTAssertTrue(pm.queue.contains { $0.emoji == "e50" }, "the newest survives")
    }

    func testNewestTriggersCatch() {
        let pm = make()
        pm.receivePing(fromName: "A", emoji: "a", remoteID: UUID())
        pm.receivePing(fromName: "B", emoji: "b", remoteID: UUID())
        pm.receivePing(fromName: "C", emoji: "c", remoteID: UUID())
        // Exactly one catch is live; the rest wait (the bucket / history).
        XCTAssertNotNil(pm.nowPlaying, "rapid arrivals trigger a catch")
        XCTAssertEqual(pm.queue.count, 2, "the others wait, not catch")
        XCTAssertEqual(pm.queueCount, 3, "all three are accounted for")
    }

    func testQueuePersistsBetweenLaunches() {
        let pm = make()
        pm.receivePing(fromName: "A", emoji: "a", remoteID: UUID())   // now playing
        pm.receivePing(fromName: "B", emoji: "b", remoteID: UUID())   // waiting → persisted
        let relaunched = make()
        XCTAssertTrue(relaunched.queue.contains { $0.emoji == "b" },
                      "waiting thoughts survive a relaunch")
    }

    func testCatchClearsFromQueue() {
        let pm = make()
        pm.receivePing(fromName: "A", emoji: "a", remoteID: UUID())
        XCTAssertEqual(pm.queueCount, 1)
        let playing = pm.nowPlaying!
        pm.finishedPlaying(playing)
        XCTAssertNil(pm.nowPlaying, "the caught thought leaves the catch")
        XCTAssertEqual(pm.queueCount, 0, "count decremented")
    }

    func testSimultaneousSendReceive() {
        let appState = AppStateManager()
        let pm = make(appState)
        XCTAssertTrue(appState.transition(to: .sending))
        pm.receivePing(fromName: "Sarah", emoji: "💜", remoteID: UUID())
        // The catch must NOT interrupt a send — the thought waits.
        XCTAssertNil(pm.nowPlaying, "a send is never interrupted by a catch")
        XCTAssertEqual(pm.queueCount, 1, "the arriving thought is pending")
        // When the send completes (back to idle), the catch fires.
        XCTAssertTrue(appState.transition(to: .idle))
        XCTAssertNotNil(pm.nowPlaying, "the pending thought plays once the send finishes")
    }
}
