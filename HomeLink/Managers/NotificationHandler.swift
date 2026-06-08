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

    private func handlePayload(_ userInfo: [AnyHashable: Any]) {
        log.info("push: payload received — keys: \(userInfo.keys.map { "\($0)" }.joined(separator: ","), privacy: .public)")

        // "Pointing" pushes become ambient presence — the compass edge glow
        if userInfo["type"] as? String == "pointing" {
            log.info("push: pointing presence from \(userInfo["fromName"] as? String ?? "someone", privacy: .public)")
            pingManager.presenceFelt(name: userInfo["fromName"] as? String ?? "someone")
            return
        }
        guard
            let emoji    = userInfo["pingEmoji"] as? String,
            let fromName = userInfo["fromName"]  as? String
        else {
            log.warning("push: payload missing pingEmoji/fromName — ignored")
            return
        }
        // The Edge Function includes the ping's id + sender style so a
        // push-delivered catch can record its felt receipt and play the
        // sender's real animation (older payloads lack them — both optional).
        let remoteID    = (userInfo["pingId"] as? String).flatMap(UUID.init)
        let senderStyle = userInfo["senderStyle"] as? String

        log.info("push: thought — emoji=\(emoji, privacy: .public) from=\(fromName, privacy: .public) pingId=\(remoteID?.uuidString ?? "nil", privacy: .public) style=\(senderStyle ?? "nil", privacy: .public)")

        AppGroupStore.pendingPingEmoji     = emoji
        AppGroupStore.pendingPingFromName  = fromName
        AppGroupStore.pendingPingTimestamp = .now
        pingManager.receivePing(fromName: fromName, emoji: emoji,
                                remoteID: remoteID, senderStyle: senderStyle)
    }
}

extension NotificationHandler: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        log.info("push: arrived while app in FOREGROUND (realtime should deliver too — deduped)")
        handlePayload(notification.request.content.userInfo)
        return []
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
