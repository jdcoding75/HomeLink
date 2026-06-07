// AppDelegate.swift
// Pointward

import UIKit
import os

final class AppDelegate: NSObject, UIApplicationDelegate {

    private let log = Logger(subsystem: "com.jdcoding75.pointward", category: "apns")

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Phase 2: pings arrive as pushes when the app is closed.
        // Called on EVERY launch so the token stays fresh server-side.
        log.info("launch: registering for remote notifications")
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        log.info("apns: token received (\(token.prefix(8), privacy: .public)…)")
        // Stored server-side so the Edge Function can target this device.
        // SupabaseService caches it locally too — if the user isn't signed
        // in yet, registration is replayed right after sign-in.
        Task { await SupabaseService.shared.registerDeviceToken(token) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        log.error("apns: registration FAILED: \(error.localizedDescription, privacy: .public)")
    }
}
