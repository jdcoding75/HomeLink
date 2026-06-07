// RootView.swift
// Pointward › Views
//
// The navigation spine. Shows OnboardingView on first launch,
// MainTabView once onboarding is complete.
// Configures PeopleManager with the SwiftData model context.

import SwiftUI
import CoreLocation
import UserNotifications
import os

private let rootLog = Logger(subsystem: "com.jdcoding75.pointward", category: "root")

struct RootView: View {

    @EnvironmentObject var people:       PeopleManager
    @EnvironmentObject var compass:      CompassManager
    @EnvironmentObject var pings:        PingManager
    @EnvironmentObject var subscription: SubscriptionManager
    @EnvironmentObject var skinStore:    SkinStore
    @EnvironmentObject var instrumentStore: InstrumentStore

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @Environment(\.modelContext) private var modelContext

    // Geocoding service — injected from ServiceContainer via environment
    // We use an EnvironmentObject wrapper so views deep in the tree can access it
    // without prop drilling. See AppEnvironment.swift.
    @EnvironmentObject var appEnv: AppEnvironment

    @State private var showSplash = true
    @State private var pairRequest: PairRequest? = nil   // from universal links
    @AppStorage("postOnboardConnectPromptShown") private var connectPromptShown = false
    @State private var showConnectPrompt = false
    @Environment(\.scenePhase) private var scenePhase

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
            skinStore.enforceTier(subscription.tier)   // free = Minimal, always
            instrumentStore.enforceTier(subscription.tier)   // free = compass, always
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeOut(duration: 0.6)) { showSplash = false }
            }
        }
        .onChange(of: hasCompletedOnboarding) { _, done in
            people.configure(with: modelContext)
            startCompassIfNeeded()
            // One-time gentle nudge after first setup
            if done && !connectPromptShown {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    showConnectPrompt = true
                    connectPromptShown = true
                }
            }
        }
        .sheet(isPresented: $showConnectPrompt) {
            PostOnboardConnectPrompt()
                .presentationDetents([.medium, .large])
        }
        // Realtime lives only in the foreground — reopen on activate,
        // close gracefully when backgrounding.
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                startRealtimePings()
                // The badge counts unread thoughts server-side; opening the
                // app is the moment to clear it.
                UNUserNotificationCenter.current().setBadgeCount(0)
                // Replay a device token that arrived signed-out or failed
                // to upload — keeps push delivery alive across sign-ins.
                Task { await SupabaseService.shared.registerCachedDeviceTokenIfNeeded() }
            case .background:
                Task { await SupabaseService.shared.stopListening() }
            default:
                break
            }
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
        rootLog.info("deeplink: incoming URL \(url.absoluteString, privacy: .public)")
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count >= 2,
              ["pair", "join"].contains(parts[0].lowercased()) else {
            rootLog.warning("deeplink: not a pair/join link — ignored")
            return
        }
        let code = SupabaseService.normalizePairingCode(parts[1])
        guard SupabaseService.isValidPairingCode(code) else {
            rootLog.warning("deeplink: malformed code '\(parts[1], privacy: .public)' — ignored")
            return
        }
        rootLog.info("deeplink: pair request for \(code, privacy: .public)")
        pairRequest = PairRequest(code: code)
    }

    /// Phase 2: discover pairings, stamp presence, and open the single
    /// consolidated realtime channel. No-op when signed out.
    private func startRealtimePings() {
        guard SupabaseService.localUserID != nil else {
            rootLog.info("realtime: skipped — not signed in")
            return
        }
        Task { await SupabaseService.shared.touchLastSeen() }   // "active recently"
        Task {
            // Discover connections made from either side and bind them to
            // the correct person cards (owner_person_id when known).
            var partner = SupabaseService.connectedFriendID
            do {
                let connections = try await SupabaseService.shared.refreshConnections()
                await MainActor.run {
                    for connection in connections {
                        people.bindConnection(friendID: connection.partnerID,
                                              toPersonID: connection.myPersonID)
                    }
                }
                partner = connections.first?.partnerID ?? partner
            } catch {
                // Offline at launch — realtime still opens (it reconnects);
                // bindings refresh on the next foreground.
                rootLog.error("realtime: connection discovery failed: \(error.localizedDescription, privacy: .public)")
            }

            await SupabaseService.shared.startRealtime(
                partner: partner,
                onPing: { event in
                    Task { @MainActor in
                        let fromName = people.people.first {
                            $0.pairedUserID == event.fromUser.uuidString
                        }?.name ?? "someone who loves you"
                        pings.receivePing(fromName: fromName, emoji: event.emoji,
                                          remoteID: event.id,
                                          senderStyle: event.senderStyle)
                    }
                },
                onFelt: { event in
                    Task { @MainActor in
                        // Caught confirmation — the emoji we sent reappears
                        // briefly at the compass center. No text, no receipt.
                        // (Text toast retired; showFelt kept for reuse.)
                        // let name = people.people.first {
                        //     $0.pairedUserID == event.toUser.uuidString
                        // }?.name ?? "they"
                        // pings.showFelt(name: name)
                        pings.showCaught(emoji: event.emoji)
                    }
                },
                onPointed: {
                    Task { @MainActor in
                        let name = partner.flatMap { p in
                            people.people.first { $0.pairedUserID == p.uuidString }?.name
                        } ?? "someone"
                        // Ambient presence — the compass edge glows, nothing else
                        pings.presenceFelt(name: name)
                    }
                }
            )
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

// MARK: - Post-onboarding connect prompt (shown once, ever)

struct PostOnboardConnectPrompt: View {

    @Environment(\.dismiss) private var dismiss
    @State private var showFullConnect = false

    var body: some View {
        ZStack {
            DesignTokens.Color.background.ignoresSafeArea()

            if showFullConnect {
                ConnectView()
            } else {
                VStack(spacing: 14) {
                    Spacer()
                    Text("🧭")
                        .font(.system(size: 40))
                    Text("want to connect with someone?")
                        .font(.system(size: 20, weight: .semibold, design: .serif))
                        .foregroundColor(DesignTokens.Color.textPrimary)
                    Text("paired compasses feel each other's thoughts")
                        .font(.system(size: 13, design: .serif).italic())
                        .foregroundColor(DesignTokens.Color.textMuted)

                    Button {
                        withAnimation(.easeOut(duration: 0.3)) { showFullConnect = true }
                    } label: {
                        Text("connect now →")
                            .font(DesignTokens.Font.label)
                            .foregroundColor(DesignTokens.Color.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(DesignTokens.Spacing.md)
                            .background(DesignTokens.Color.accentStrong)
                            .cornerRadius(DesignTokens.Radius.button)
                    }
                    .padding(.horizontal, 36)
                    .padding(.top, 8)

                    Button("maybe later") { dismiss() }
                        .font(DesignTokens.Font.caption)
                        .foregroundColor(DesignTokens.Color.textMuted)
                    Spacer()
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Pair request (universal link)

struct PairRequest: Identifiable {
    let code: String
    var id: String { code }
}

/// Confirmation sheet for a tapped pairing link — shows who the invite is
/// from (the identity stored with the connection), one Accept pairs AND
/// auto-adds them to the People list.
struct PairRequestView: View {

    let code: String
    let onDone: () -> Void

    @EnvironmentObject var people: PeopleManager
    @EnvironmentObject var compass: CompassManager

    @State private var isBusy = false
    @State private var connected = false
    @State private var errorMessage: String?
    @State private var inviteName: String?
    @State private var inviteEmoji: String?

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

                Text(inviteEmoji ?? "🧭")
                    .font(.system(size: 48))
                    .padding(.bottom, 16)

                Text(connected
                     ? "connected ✓"
                     : "\(inviteName ?? "someone") wants to connect with you")
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .foregroundColor(connected ? Color(hex: "#5dcaa5")
                                               : DesignTokens.Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
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
        .onAppear {
            // Show who the invite came from before asking to accept
            Task {
                if let info = try? await SupabaseService.shared.lookupInvite(code) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        inviteName  = info.name
                        inviteEmoji = info.emoji
                    }
                }
            }
        }
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
                let result = try await SupabaseService.shared.redeem(code)
                // Auto-add them to the People list with the invite's identity
                people.addFromInvite(
                    name:  result.personName  ?? inviteName  ?? "Someone",
                    emoji: result.personEmoji ?? inviteEmoji ?? "💜",
                    friendID: result.ownerID,
                    near: compass.userLocation?.coordinate
                )
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

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            CompassView()
                .tabItem {
                    Label("compass", systemImage: "compass.drawing")
                }
                .tag(0)

            // Thoughts tab retired — sending lives ON the compass now
            // PingView()
            //     .tabItem {
            //         Label("thoughts", systemImage: "paperplane")
            //     }

            PeopleListView(geocodingService: geocodingService)
                .tabItem {
                    Label("people", systemImage: "person.2")
                }
                .tag(1)

            // Skin selection lives in Settings → compass only
            // SkinPickerView()
            //     .tabItem {
            //         Label("skins", systemImage: "paintpalette")
            //     }

            SettingsView()
                .tabItem {
                    Label("settings", systemImage: "gearshape")
                }
                .tag(2)
        }
        .tint(DesignTokens.Color.accentSoft)
        .preferredColorScheme(.dark)
        // The "✦ Pro" badge on the compass jumps here
        .onReceive(NotificationCenter.default.publisher(for: .pointwardOpenSettings)) { _ in
            selectedTab = 2
        }
        // (thoughts tab retired — the pill/notification path is gone)
        // .onReceive(NotificationCenter.default.publisher(for: .pointwardOpenThoughts)) { _ in
        //     selectedTab = 1
        // }
    }
}
