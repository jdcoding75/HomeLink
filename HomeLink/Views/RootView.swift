// RootView.swift
// Pointward › Views
//
// The navigation spine. Shows OnboardingView on first launch,
// MainTabView once onboarding is complete.
// Configures PeopleManager with the SwiftData model context.

import SwiftUI

struct RootView: View {

    @EnvironmentObject var people:       PeopleManager
    @EnvironmentObject var compass:      CompassManager
    @EnvironmentObject var pings:        PingManager
    @EnvironmentObject var subscription: SubscriptionManager
    @EnvironmentObject var skinStore:    SkinStore

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @Environment(\.modelContext) private var modelContext

    // Geocoding service — injected from ServiceContainer via environment
    // We use an EnvironmentObject wrapper so views deep in the tree can access it
    // without prop drilling. See AppEnvironment.swift.
    @EnvironmentObject var appEnv: AppEnvironment

    @State private var showSplash = true

    var body: some View {
        ZStack {
            Group {
                if hasCompletedOnboarding {
                    // Even with no people (e.g. all deleted), stay in the main app —
                    // CompassView shows a warm empty state instead of re-running onboarding.
                    MainTabView(geocodingService: appEnv.geocodingService)
                } else {
                    OnboardingView(geocodingService: appEnv.geocodingService)
                }
            }

            // Branded launch moment — 1.5s, then fades into the app
            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .onAppear {
            people.configure(with: modelContext)
            startCompassIfNeeded()
            startRealtimePings()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeOut(duration: 0.6)) { showSplash = false }
            }
        }
        .onChange(of: hasCompletedOnboarding) { _, _ in
            people.configure(with: modelContext)
            startCompassIfNeeded()
        }
    }

    /// Phase 2: live pings over Supabase realtime → the existing in-app
    /// ping animation. No-op until the user is signed in.
    private func startRealtimePings() {
        guard SupabaseService.localUserID != nil else { return }
        Task {
            await SupabaseService.shared.startListeningForPings { payload in
                Task { @MainActor in
                    // Name the sender if they match a saved person, else stay warm
                    let fromName = people.people.first {
                        $0.pairedUserID == payload.fromUser.uuidString
                    }?.name ?? "someone who loves you"
                    pings.receivePing(fromName: fromName, emoji: payload.emoji)
                }
            }
        }
    }

    /// Launching with a saved person should immediately show that person on the
    /// compass — don't rely on child-view onAppear ordering.
    private func startCompassIfNeeded() {
        if let person = people.selectedPerson {
            compass.start(tracking: person)
        }
    }
}

// MARK: - SplashView

/// The quiet branded breath before the app appears.
struct SplashView: View {

    @State private var breathe = false

    var body: some View {
        ZStack {
            Color(hex: "#0d0d14").ignoresSafeArea()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#9b7fc0").opacity(breathe ? 0.28 : 0.16))
                        .frame(width: 100, height: 100)
                        .blur(radius: 24)
                    Text("🧭")
                        .font(.system(size: 56))
                        .scaleEffect(breathe ? 1.06 : 1.0)
                }

                Text("Pointward")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "#e8e0f0"))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
    }
}

// MARK: - MainTabView

struct MainTabView: View {

    let geocodingService: GeocodingServiceProtocol

    @EnvironmentObject var compass:      CompassManager
    @EnvironmentObject var people:       PeopleManager
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

            // "send a thought" — symbolic, backend-free, free for everyone
            PingView()
                .tabItem {
                    Label("thought", systemImage: "paperplane")
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
    }
}
