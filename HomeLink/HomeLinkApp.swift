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
