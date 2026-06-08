// PointwardApp.swift
// Pointward
// Bundle ID: com.jdcoding75.pointward

import SwiftUI
import SwiftData

@main
struct PointwardApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var container = ServiceContainer()

    init() {
        // ── TESTING DEFAULTS — revert before App Store submission ────────
        // Default tier .pro, Pro features on. (Skin default is .vintage in
        // SkinStore.) Remove this register block to restore .free defaults.
        UserDefaults.standard.register(defaults: [
            "subscriptionTier": "unlocked",      // SubscriptionTier.pro
            ProFeatures.storageKey: true,        // proFeaturesEnabled
        ])

        // Carry "Expressive Mode" users into the renamed Pro key
        ProFeatures.migrateLegacyKey()
        // Carry sender-style users into the instrument architecture
        Instrument.migrateLegacySelection()
        // Unified picker: derive the one selection from the old two
        InstrumentOption.migrateLegacySelection()

        #if DEBUG
        // [1/4] -skipOnboarding launch arg → straight to the compass with mock
        // data (no onboarding, no Apple Sign In). Consumed by RootView, which
        // has the configured model context. DEBUG only — never ships.
        if DevTools.wantsSkipOnboarding {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            UserDefaults.standard.set(true, forKey: DevTools.injectFlagKey)
            // [4/6] Drop any queue persisted from an earlier mock-history run so
            // a stale catch can't bury the compass on launch — skip-onboarding
            // lands on a clean compass pointing at Sarah.
            UserDefaults.standard.removeObject(forKey: "pendingThoughtQueue")
        }
        #endif

        // Backend housekeeping — prune our own stale presence/token rows on a
        // background task so it never blocks launch or touches the main thread. [3/8]
        Task.detached(priority: .background) {
            await SupabaseService.shared.cleanupStaleData()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container.compassManager)
                .environmentObject(container.peopleManager)
                .environmentObject(container.pingManager)
                .environmentObject(container.subscriptionManager)
                .environmentObject(container.notificationHandler)
                .environmentObject(container.skinStore)
                .environmentObject(container.instrumentStore)
                .environmentObject(container.brandManager)
                .environmentObject(container.appStateManager)
                .environmentObject(AppEnvironment(geocodingService: container.geocodingService))
                .modelContainer(container.modelContainer)
                .preferredColorScheme(.dark)
        }
    }
}
