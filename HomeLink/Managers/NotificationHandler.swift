// NotificationHandler.swift
// Pointward › Managers

import UserNotifications
import Combine

@MainActor
final class NotificationHandler: NSObject, ObservableObject {

    private let pingManager: PingManager

    init(pingManager: PingManager) {
        self.pingManager = pingManager
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    private func handlePayload(_ userInfo: [AnyHashable: Any]) {
        guard
            let emoji    = userInfo["pingEmoji"] as? String,
            let fromName = userInfo["fromName"]  as? String
        else { return }
        AppGroupStore.pendingPingEmoji     = emoji
        AppGroupStore.pendingPingFromName  = fromName
        AppGroupStore.pendingPingTimestamp = .now
        pingManager.receivePing(fromName: fromName, emoji: emoji)
    }
}

extension NotificationHandler: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        handlePayload(notification.request.content.userInfo)
        return []
    }
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        handlePayload(response.notification.request.content.userInfo)
    }
}
