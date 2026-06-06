// NotificationServiceProtocol.swift
// Pointward › Services › Protocols

import UserNotifications

protocol NotificationServiceProtocol {
    func requestPermission() async throws -> Bool
    func scheduleLocalPingNotification(fromName: String, emoji: String) async throws
}
