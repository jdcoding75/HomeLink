// SceneDelegate.swift
// Pointward
//
// [double-tap fix · Layer 1] Captures an inbound pointward.app/m/<id> universal
// link at the SCENE-CONNECTION boundary so a COLD-launch first tap is never
// dropped (the cause of the "needs two taps" bug — see
// reports/double_tap_link_audit.md).
//
// The app is otherwise pure SwiftUI lifecycle; this minimal UIWindowSceneDelegate
// is wired in via AppDelegate.application(_:configurationForConnecting:options:).
// It DOES NOT manage the window — SwiftUI's WindowGroup still hosts RootView. It
// only reads the launch/continue activities and stashes any /m/<id> into the
// shared PendingLink holder, which RootView drains when its router is ready.

import UIKit
import os

final class SceneDelegate: NSObject, UIWindowSceneDelegate {

    private static let log = Logger(subsystem: "com.jdcoding75.pointward", category: "scene")

    // COLD launch: the launch user-activities / url-contexts arrive here, often
    // BEFORE SwiftUI attaches RootView's .onContinueUserActivity. Capture them so
    // the FIRST tap routes. (We do NOT create a UIWindow — SwiftUI owns it.)
    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        for activity in connectionOptions.userActivities {
            if activity.activityType == NSUserActivityTypeBrowsingWeb,
               let url = activity.webpageURL {
                captureIfMessage(url, from: "willConnectTo.userActivity")
            }
        }
        for ctx in connectionOptions.urlContexts {
            captureIfMessage(ctx.url, from: "willConnectTo.urlContext")
        }
    }

    // WARM continuation (app already running). SwiftUI's .onContinueUserActivity
    // also fires for these; routing both through the same holder keeps ONE funnel.
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = userActivity.webpageURL {
            captureIfMessage(url, from: "continue.userActivity")
        }
    }

    // Custom-scheme opens while connected (universal links normally arrive as
    // user-activities; included for completeness — harmless for non-/m/ urls).
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for ctx in URLContexts {
            captureIfMessage(ctx.url, from: "openURLContexts")
        }
    }

    private func captureIfMessage(_ url: URL, from source: String) {
        guard let id = MessageLink.messageID(from: url) else { return }
        Self.log.info("scene capture (\(source, privacy: .public)): /m/\(id.uuidString, privacy: .public)")
        Task { @MainActor in PendingLink.shared.set(id) }
    }
}
