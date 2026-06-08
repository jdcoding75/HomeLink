// NotificationHandler.swift
// Pointward › Managers

import UserNotifications
import Combine
import os

@MainActor
final class NotificationHandler: NSObject, ObservableObject {

    private let log = Logger(subsystem: "com.jdcoding75.pointward", category: "notifications")

    private let pingManager: PingManager

    init(pingManager: PingManager) {
        self.pingManager = pingManager
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    /// A parsed "thought" push payload. (Pointing-presence pushes parse to nil.)
    struct ParsedPush: Equatable {
        let emoji: String
        let fromName: String
        let remoteID: UUID?
        let senderStyle: String?
        let message: String?
        let tagline: String?
    }

    /// Pure parser for an APNs payload — extracts the thought's fields, or nil
    /// for a "pointing" presence push or a malformed payload. Testable.
    static func parsePush(_ userInfo: [AnyHashable: Any]) -> ParsedPush? {
        if userInfo["type"] as? String == "pointing" { return nil }
        guard
            let emoji    = userInfo["pingEmoji"] as? String,
            let fromName = userInfo["fromName"]  as? String
        else { return nil }
        return ParsedPush(
            emoji: emoji,
            fromName: fromName,
            remoteID: (userInfo["pingId"] as? String).flatMap(UUID.init),
            senderStyle: userInfo["senderStyle"] as? String,
            message: userInfo["message"] as? String,
            tagline: userInfo["tagline"] as? String
        )
    }

    /// Route a raw payload into the app. Internal so the foreground/catch
    /// behaviour is testable without constructing a UNNotification.
    func handlePayload(_ userInfo: [AnyHashable: Any]) {
        log.info("push: payload received — keys: \(userInfo.keys.map { "\($0)" }.joined(separator: ","), privacy: .public)")

        // "Pointing" pushes become ambient presence — the compass edge glow
        if userInfo["type"] as? String == "pointing" {
            log.info("push: pointing presence from \(userInfo["fromName"] as? String ?? "someone", privacy: .public)")
            pingManager.presenceFelt(name: userInfo["fromName"] as? String ?? "someone")
            return
        }
        guard let parsed = Self.parsePush(userInfo) else {
            log.warning("push: payload missing pingEmoji/fromName — ignored")
            return
        }
        log.info("push: thought — emoji=\(parsed.emoji, privacy: .public) from=\(parsed.fromName, privacy: .public) pingId=\(parsed.remoteID?.uuidString ?? "nil", privacy: .public) style=\(parsed.senderStyle ?? "nil", privacy: .public) msg=\(parsed.message != nil, privacy: .public)")

        AppGroupStore.pendingPingEmoji     = parsed.emoji
        AppGroupStore.pendingPingFromName  = parsed.fromName
        AppGroupStore.pendingPingTimestamp = .now
        pingManager.receivePing(fromName: parsed.fromName, emoji: parsed.emoji,
                                remoteID: parsed.remoteID, senderStyle: parsed.senderStyle,
                                message: parsed.message, tagline: parsed.tagline)
    }
}

extension NotificationHandler {
    /// Foreground presentation policy: suppress the banner/sound entirely.
    /// Realtime (and the in-app catch) already deliver the thought, so the OS
    /// banner would be a duplicate. Pure + static so the rule is testable.
    static func foregroundPresentationOptions() -> UNNotificationPresentationOptions { [] }
}

extension NotificationHandler: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        log.info("push: arrived while app in FOREGROUND (realtime should deliver too — deduped)")
        handlePayload(notification.request.content.userInfo)
        return Self.foregroundPresentationOptions()
    }
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        log.info("push: user TAPPED notification — opening")
        handlePayload(response.notification.request.content.userInfo)
        // The catch lives on the compass — make sure it's the visible tab
        NotificationCenter.default.post(name: .pointwardOpenCompass, object: nil)
    }
}
