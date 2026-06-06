// PointwardApp.swift
// Pointward
// Bundle ID: com.jdcoding75.pointward

import SwiftUI
import SwiftData

@main
struct PointwardApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var container = ServiceContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container.compassManager)
                .environmentObject(container.peopleManager)
                .environmentObject(container.pingManager)
                .environmentObject(container.subscriptionManager)
                .environmentObject(container.notificationHandler)
                .environmentObject(container.skinStore)
                .environmentObject(container.brandManager)
                .environmentObject(AppEnvironment(geocodingService: container.geocodingService))
                .modelContainer(container.modelContainer)
                .preferredColorScheme(.dark)
        }
    }
}
