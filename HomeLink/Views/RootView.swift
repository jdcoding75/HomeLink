// RootView.swift
// HomeLink › Views
//
// The navigation spine. Shows OnboardingView on first launch,
// MainTabView once onboarding is complete.
// Configures PeopleManager with the SwiftData model context.

import SwiftUI

struct RootView: View {

    @EnvironmentObject var people:       PeopleManager
    @EnvironmentObject var subscription: SubscriptionManager
    @EnvironmentObject var skinStore:    SkinStore

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @Environment(\.modelContext) private var modelContext

    // Geocoding service — injected from ServiceContainer via environment
    // We use an EnvironmentObject wrapper so views deep in the tree can access it
    // without prop drilling. See AppEnvironment.swift.
    @EnvironmentObject var appEnv: AppEnvironment

    var body: some View {
        Group {
            if hasCompletedOnboarding && !people.people.isEmpty {
                MainTabView(geocodingService: appEnv.geocodingService)
            } else {
                OnboardingView(geocodingService: appEnv.geocodingService)
            }
        }
        .onAppear {
            people.configure(with: modelContext)
        }
        .onChange(of: hasCompletedOnboarding) { _, _ in
            people.configure(with: modelContext)
        }
    }
}

// MARK: - MainTabView

struct MainTabView: View {

    let geocodingService: GeocodingServiceProtocol

    @EnvironmentObject var compass:      CompassManager
    @EnvironmentObject var people:       PeopleManager
    @EnvironmentObject var pings:        PingManager
    @EnvironmentObject var subscription: SubscriptionManager
    @EnvironmentObject var skinStore:    SkinStore

    var body: some View {
        TabView {
            CompassView()
                .tabItem {
                    Label("compass", systemImage: "compass.drawing")
                }

            PeopleListView(geocodingService: geocodingService)
                .tabItem {
                    Label("people", systemImage: "person.2")
                }

            PingView()
                .tabItem {
                    Label("ping", systemImage: "heart.circle")
                }

            SkinPickerView()
                .tabItem {
                    Label("skins", systemImage: "paintpalette")
                }

            SettingsView()
                .tabItem {
                    Label("settings", systemImage: "gearshape")
                }
        }
        .tint(DesignTokens.Color.accentSoft)
        .preferredColorScheme(.dark)
        // Badge the ping tab when a ping is pending
        .onChange(of: pings.pendingPing != nil) { _, hasPing in
            // UITabBarItem badge is set imperatively
            // In a real build you'd use UITabBar.appearance() or
            // the .badge() modifier on the TabItem
        }
    }
}
