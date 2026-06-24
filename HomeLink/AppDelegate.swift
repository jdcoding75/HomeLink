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
        // [ci-test-safe] Under XCTest (CI / unit-test host) skip the APNs launch work.
        // A clean simulator has no aps-environment entitlement, so registration fails
        // AND logPushState()'s getNotificationSettings completion reads UIApplication.shared
        // off the main thread → the host app crashes before any test runs. The env var is
        // set by the test runner in the host process and is nil in EVERY normal launch
        // (Debug + Release), so PATH-1 push is untouched in real runs.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            log.info("launch: running under XCTest — skipping APNs registration")
            return true
        }

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

    // [double-tap fix · Layer 1] Point new scenes at our minimal SceneDelegate so
    // it can capture a COLD-launch /m/<id> universal link from the scene's
    // connectionOptions (which SwiftUI's .onContinueUserActivity can miss on first
    // launch). SwiftUI's WindowGroup still hosts the UI — SceneDelegate never
    // touches the window. See reports/double_tap_link_audit.md.
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
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
            case .notDetermined: auth = "notDetermined — onboarding will request (NOT at launch)"
            case .provisional:   auth = "provisional"
            case .ephemeral:     auth = "ephemeral"
            @unknown default:    auth = "unknown"
            }
            // [ci-test-safe] `UIApplication.shared` is main-thread-only, but
            // getNotificationSettings' completion runs OFF the main thread → hop to
            // main for the read + log. Fixes a latent main-thread-checker crash on
            // device too (not just CI). Logged values are unchanged (`alertsEnabled`
            // is captured from `settings` before the hop).
            let alertsEnabled = settings.alertSetting == .enabled
            DispatchQueue.main.async {
                let registered = UIApplication.shared.isRegisteredForRemoteNotifications
                self.log.info("push chain ① device: authorization=\(auth, privacy: .public) registeredForRemote=\(registered, privacy: .public) alertsEnabled=\(alertsEnabled, privacy: .public)")
            }
            // [perm-defer] Launch-time notification request REMOVED so it never fires over the
            // received-thought animation. The ask now lives ONLY in onboarding `saveAboutYou`
            // (the final "continue →" tap, after the animation). Logging above is unchanged;
            // `registerForRemoteNotifications()` in didFinishLaunching (:19) still registers the
            // APNs token route (no prompt). Original preserved:
            // if settings.authorizationStatus == .notDetermined {
            //     center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            //         self.log.info("push chain ① device: permission request → granted=\(granted, privacy: .public)")
            //         DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
            //     }
            // }
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
