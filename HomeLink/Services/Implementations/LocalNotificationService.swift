// LocalNotificationService.swift
// Pointward › Services › Implementations

import UserNotifications

final class LocalNotificationService: NotificationServiceProtocol {

    func requestPermission() async throws -> Bool {
        try await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    func scheduleLocalPingNotification(fromName: String, emoji: String) async throws {
        let content      = UNMutableNotificationContent()
        content.title    = "\(fromName) is thinking of you"
        content.body     = emoji
        content.sound    = .default
        content.userInfo = ["pingEmoji": emoji, "fromName": fromName]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString, content: content, trigger: trigger
        )
        try await UNUserNotificationCenter.current().add(request)
    }
}
