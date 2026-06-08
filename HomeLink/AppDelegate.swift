// AppDelegate.swift
// Pointward

import UIKit
import UserNotifications
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
        // [1/5] Diagnose the FIRST link in the push chain on every launch —
        // permission + registration state, so a broken link is obvious in
        // Console (the rest of the chain logs server-side in the Edge Function).
        logPushState()
        return true
    }

    /// [1/5] Logs the local end of the push chain and re-requests permission
    /// if it was never determined — surfaces "DENIED" or "notDetermined" so a
    /// silent-notifications report is diagnosable without a device round-trip.
    private func logPushState() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }
            let auth: String
            switch settings.authorizationStatus {
            case .authorized:    auth = "authorized"
            case .denied:        auth = "DENIED — banners will NOT show (Settings → Pointward → Notifications)"
            case .notDetermined: auth = "notDetermined — requesting now"
            case .provisional:   auth = "provisional"
            case .ephemeral:     auth = "ephemeral"
            @unknown default:    auth = "unknown"
            }
            let registered = UIApplication.shared.isRegisteredForRemoteNotifications
            self.log.info("push chain ① device: authorization=\(auth, privacy: .public) registeredForRemote=\(registered, privacy: .public) alertsEnabled=\(settings.alertSetting == .enabled, privacy: .public)")
            if settings.authorizationStatus == .notDetermined {
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    self.log.info("push chain ① device: permission request → granted=\(granted, privacy: .public)")
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
            }
        }
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
