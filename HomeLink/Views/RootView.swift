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
    @State private var pairRequest: PairRequest? = nil   // from universal links

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
        // Universal links: pointward.app/pair/POINT-XXXX (and /join/ fallback).
        // SwiftUI delivers them via user activity; onOpenURL covers scheme opens.
        .onOpenURL { handleIncomingURL($0) }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            if let url = activity.webpageURL { handleIncomingURL(url) }
        }
        .sheet(item: $pairRequest) { request in
            PairRequestView(code: request.code) {
                pairRequest = nil
            }
        }
    }

    /// pointward.app/pair/POINT-GP2S → confirmation sheet with the code filled in.
    private func handleIncomingURL(_ url: URL) {
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count >= 2,
              ["pair", "join"].contains(parts[0].lowercased()) else { return }
        let code = SupabaseService.normalizePairingCode(parts[1])
        guard code.count == 10 else { return }
        pairRequest = PairRequest(code: code)
    }

    /// Phase 2: live pings over Supabase realtime → the existing in-app
    /// ping animation, plus felt receipts and presence. No-op when signed out.
    private func startRealtimePings() {
        guard SupabaseService.localUserID != nil else { return }
        Task { await SupabaseService.shared.touchLastSeen() }   // "active recently"
        Task {
            await SupabaseService.shared.startListeningForPings { event in
                Task { @MainActor in
                    // Name the sender if they match a saved person, else stay warm
                    let fromName = people.people.first {
                        $0.pairedUserID == event.fromUser.uuidString
                    }?.name ?? "someone who loves you"
                    pings.receivePing(fromName: fromName, emoji: event.emoji,
                                      remoteID: event.id)
                }
            }
        }
        Task {
            await SupabaseService.shared.startListeningForFeltReceipts { event in
                Task { @MainActor in
                    let name = people.people.first {
                        $0.pairedUserID == event.toUser.uuidString
                    }?.name ?? people.selectedPerson?.name ?? "they"
                    pings.showFelt(name: name)
                }
            }
        }
        // Discover pairings made from the other side (the code owner never
        // redeems anything), bind them to a person, then listen for pointing.
        Task {
            var partner = SupabaseService.connectedFriendID
            if let fresh = try? await SupabaseService.shared.refreshConnection() {
                partner = fresh
                await MainActor.run { people.bindConnection(friendID: fresh) }
            }
            guard let partner else { return }
            await SupabaseService.shared.startListeningForPointing(partner: partner) {
                Task { @MainActor in
                    let name = people.people.first {
                        $0.pairedUserID == partner.uuidString
                    }?.name ?? "someone"
                    pings.showPointing(name: name)
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

// MARK: - Pair request (universal link)

struct PairRequest: Identifiable {
    let code: String
    var id: String { code }
}

/// Confirmation sheet for a tapped pairing link — the code arrives pre-filled;
/// one Accept completes the connection.
struct PairRequestView: View {

    let code: String
    let onDone: () -> Void

    @EnvironmentObject var people: PeopleManager

    @State private var isBusy = false
    @State private var connected = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            DesignTokens.Color.background.ignoresSafeArea()
            RadialGradient(
                colors: [Color(hex: "#9b7fc0").opacity(0.15), .clear],
                center: .center, startRadius: 20, endRadius: 300
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Text("🧭")
                    .font(.system(size: 48))
                    .padding(.bottom, 16)

                Text(connected ? "connected ✓" : "someone wants to connect")
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .foregroundColor(connected ? Color(hex: "#5dcaa5")
                                               : DesignTokens.Color.textPrimary)
                    .padding(.bottom, 8)

                Text(connected
                     ? "your compasses are now linked"
                     : "accept to link your compasses")
                    .font(.system(size: 13, design: .serif).italic())
                    .foregroundColor(DesignTokens.Color.textMuted)
                    .padding(.bottom, 20)

                // The code from the link, for transparency
                Text(code.replacingOccurrences(of: "-", with: " · "))
                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
                    .foregroundColor(DesignTokens.Color.accentSoft)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(DesignTokens.Color.backgroundCard)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(DesignTokens.Color.accentMid.opacity(0.5), lineWidth: 1)
                    )
                    .padding(.bottom, 24)

                if let errorMessage {
                    Text(errorMessage)
                        .font(DesignTokens.Font.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .padding(.bottom, 14)
                }
                if isBusy {
                    ProgressView()
                        .tint(DesignTokens.Color.accentSoft)
                        .padding(.bottom, 14)
                }

                if connected {
                    Button(action: onDone) {
                        Text("open your compass")
                            .font(DesignTokens.Font.label)
                            .foregroundColor(DesignTokens.Color.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(DesignTokens.Spacing.md)
                            .background(DesignTokens.Color.accentStrong)
                            .cornerRadius(DesignTokens.Radius.button)
                    }
                    .padding(.horizontal, 28)
                } else {
                    Button(action: accept) {
                        Text("accept")
                            .font(DesignTokens.Font.label)
                            .foregroundColor(DesignTokens.Color.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(DesignTokens.Spacing.md)
                            .background(DesignTokens.Color.accentStrong)
                            .cornerRadius(DesignTokens.Radius.button)
                    }
                    .disabled(isBusy)
                    .padding(.horizontal, 28)

                    Button("not now", action: onDone)
                        .font(DesignTokens.Font.caption)
                        .foregroundColor(DesignTokens.Color.textMuted)
                        .padding(.top, 12)
                }

                Spacer()
            }
        }
        .presentationDetents([.medium])
    }

    private func accept() {
        guard SupabaseService.localUserID != nil else {
            errorMessage = "Sign in first — Settings → account — then tap the link again."
            return
        }
        isBusy = true
        errorMessage = nil
        Task {
            defer { isBusy = false }
            do {
                let friend = try await SupabaseService.shared.redeemCode(code)
                people.bindConnection(friendID: friend)
                HapticEngine.connectionFelt()
                withAnimation(.easeOut(duration: 0.4)) { connected = true }
            } catch {
                errorMessage = error.localizedDescription
            }
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
