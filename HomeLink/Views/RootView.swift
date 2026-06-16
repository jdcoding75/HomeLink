// RootView.swift
// Pointward › Views
//
// The navigation spine. Shows OnboardingView on first launch,
// MainTabView once onboarding is complete.
// Configures PeopleManager with the SwiftData model context.

import SwiftUI
import SwiftData          // [fix] explicit — \.modelContext (line below) is a
                          // SwiftData environment key; was resolving transitively
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
    // [build8] pairing UI stripped (comment-out, reversible) — /pair deep link no
    // longer routes; build 9 removes the data layer. See reports/build8_report.md.
    // @State private var pairRequest: PairRequest? = nil   // from universal links
    @State private var messageOpenRequest: MessageOpenRequest? = nil   // /m/<id> links (4a)
    // [double-tap fix · Layer 2] The shared cold-launch pending slot. handleIncomingURL,
    // the short-code path, the DEBUG -openMessageID path, AND the SceneDelegate's
    // cold-launch capture all write a message id here; presentPendingMessageIfReady()
    // promotes it to `messageOpenRequest` once the root is stable. Observed so a
    // SceneDelegate capture that lands after onAppear still triggers a re-check.
    @ObservedObject private var pendingLink = PendingLink.shared
    #if DEBUG
    @State private var didDebugOpenMessage = false   // one-shot scaffold guard
    #endif
    // [build8] post-onboarding connect nudge stripped (pairing-era).
    // @AppStorage("postOnboardConnectPromptShown") private var connectPromptShown = false
    // @State private var showConnectPrompt = false
    /// Inviter-side celebration — someone just claimed one of our codes
    /// (detected over realtime; both phones celebrate together).
    // [build8] inviter-celebration render stripped (realtime plumbing kept for build 9).
    // @State private var celebratePerson: Person? = nil
    // @State private var showInviterCelebration = false
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

            // ── The mutual moment — both needles resting on each other.
            // Golden glow over whatever is on screen, 3 s, then gone. ──────
            // [build8] mutual-moment render stripped (pairing-era). The
            // checkMutualPointing trigger still fires harmlessly; the data layer
            // (mutualMoment / partnerPointing) is removed in build 9.
            // if pings.mutualMoment != nil {
            //     MutualMomentView(partnerName: pings.partnerPointingName)
            //         .transition(.opacity)
            //         .zIndex(9)
            // }

            // Branded launch moment — 1.5s, then fades into the app
            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        // [build8] mutual-moment render stripped → its animation hook too.
        // .animation(.easeOut(duration: 0.8), value: pings.mutualMoment != nil)
        // Our own lock edge can complete the mutual moment too — their
        // pointing report may have arrived seconds before we settled.
        // [build9] mutual-pointing retired (pure pairing) — the lock no longer
        // feeds checkMutualPointing.
        // .onChange(of: compass.state.isLocked) { _, locked in
        //     guard locked, let raw = compass.rawBearingToTarget else { return }
        //     pings.checkMutualPointing(
        //         myAbsoluteBearing: raw,
        //         myAlignmentError: BearingCalculator.alignmentError(
        //             relativeBearing: compass.state.bearingDegrees))
        // }
        .onAppear {
            people.configure(with: modelContext)
            #if DEBUG
            applySkipOnboardingIfNeeded()
            maybeDebugOpenMessage()   // -openMessageID <uuid> → drive the real /m flow
            #endif
            ensureDemoPersonIfAppropriate()   // [5/6] Alex when no one's added yet
            startCompassIfNeeded()
            startRealtimePings()
            syncConnections()   // [phase2 stage B] drain (S2) + stamp connected contacts
            skinStore.enforceTier(subscription.tier)   // free = Minimal, always
            instrumentStore.enforceTier(subscription.tier)   // free = compass, always
            // [double-tap fix · Layer 2] (a) data layer is configured — try now
            // (presents immediately for a WARM launch; no-ops while the splash is up).
            presentPendingMessageIfReady()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeOut(duration: 0.6)) { showSplash = false }
                // [double-tap fix · Layer 2] (b) splash cleared → the hierarchy can
                // host the cover. A COLD-launch pending /m/ id presents HERE, on the
                // first tap (replaces the DEBUG path's one-off +1.0s defer).
                presentPendingMessageIfReady()
            }
        }
        .onChange(of: hasCompletedOnboarding) { _, done in
            people.configure(with: modelContext)
            if done { ensureDemoPersonIfAppropriate() }   // [5/6] no one added → Alex
            startCompassIfNeeded()
            // [build8] post-onboarding "want to connect?" nudge stripped (pairing-era).
            // // One-time gentle nudge after first setup
            // if done && !connectPromptShown {
            //     DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            //         showConnectPrompt = true
            //         connectPromptShown = true
            //     }
            // }
        }
        // [build8] post-onboarding connect-prompt sheet stripped (pairing-era).
        // .sheet(isPresented: $showConnectPrompt) {
        //     PostOnboardConnectPrompt()
        //         .presentationDetents([.medium, .large])
        // }
        // Realtime lives only in the foreground — reopen on activate,
        // close gracefully when backgrounding.
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                startRealtimePings()
                syncConnections()   // [phase2 stage B] drain (S2) + stamp on foreground
                compass.resumeFromForeground()   // battery: sensors back on [5/8]
                // The badge counts unread thoughts server-side; opening the
                // app is the moment to clear it.
                // [unread-badge fix · Option A] Drive the SERVER count to 0 too —
                // otherwise the next push re-inflates the badge to the (ever-growing)
                // unopened-pings count. Mark all my unopened pings opened on
                // foreground ("seen/acknowledged on open"), then clear the local
                // badge. Only when signed in. Fire-and-forget.
                if SupabaseService.localUserID != nil {
                    Task { await SupabaseService.shared.markAllMyPingsOpened() }
                }
                UNUserNotificationCenter.current().setBadgeCount(0)
                // Replay a device token that arrived signed-out or failed
                // to upload — keeps push delivery alive across sign-ins.
                Task { await SupabaseService.shared.registerCachedDeviceTokenIfNeeded() }
            case .background:
                compass.pauseForBackground()     // battery: stop heading/GPS [5/8]
                Task { await SupabaseService.shared.stopListening() }
            default:
                break
            }
        }
        // [7/8] LAUNCH PERFORMANCE — warm the programmatic sound cache off the
        // main thread once at launch. Building ~40 audio buffers is the one
        // heavy bit of work on the send path; doing it in the background here
        // keeps the compass instant to open and the first send stutter-free.
        .task(priority: .background) {
            // [concurrency 2026-06-13] SoundEngine.shared is main-actor isolated
            // (default actor isolation), so it can't be touched from a detached
            // task — warm it on the main actor instead. The surrounding .task still
            // runs at background priority, keeping launch responsive.
            await Task { @MainActor in _ = SoundEngine.shared }.value
        }
        // Universal links: pointward.app/pair/POINT-XXXX (and /join/ fallback).
        // SwiftUI delivers them via user activity; onOpenURL covers scheme opens.
        .onOpenURL { handleIncomingURL($0) }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            if let url = activity.webpageURL { handleIncomingURL(url) }
        }
        // [build8] /pair accept sheet stripped (pairing-era). The /m/ message
        // cover below is the link-era path and is UNTOUCHED.
        // .sheet(item: $pairRequest) { request in
        //     // The acceptance flow: who wants to connect → add as new person
        //     // or link to someone already here → celebration.
        //     PairAcceptView(code: request.code) {
        //         pairRequest = nil
        //     }
        // }
        // [phase2 4a] /m/<id> link → incoming beat → receipt → opened-on-completion.
        // Full-screen, over onboarding OR the main app (cold + warm launch).
        .fullScreenCover(item: $messageOpenRequest) { request in
            IncomingMessageView(messageID: request.id) {
                messageOpenRequest = nil
            }
        }
        // [phase2 4b] short-code claim → play the NEWEST through the SAME 4a chain.
        // (Posted by ShortCodeEntryView with object: the message UUID.)
        .onReceive(NotificationCenter.default.publisher(for: .pointwardOpenMessage)) { note in
            if let id = note.object as? UUID {
                // [double-tap fix · Layer 2] same single funnel as /m/ links.
                // [pre-fix] messageOpenRequest = MessageOpenRequest(id: id)
                PendingLink.shared.set(id)
                presentPendingMessageIfReady()
            }
        }
        // [double-tap fix · Layer 2] Re-check readiness whenever the pending slot
        // changes — covers a SceneDelegate cold-launch capture that lands AFTER
        // onAppear has already run (the slot is set from outside the SwiftUI funnels).
        .onChange(of: pendingLink.messageID) { _, id in
            if id != nil { presentPendingMessageIfReady() }
        }
        // ([5/6] replay cover moved onto the TabView in MainTabView —
        //  presenting from here failed while a child sheet was up)
        // ── Inviter-side celebration — their phone learns over realtime ───
        // [build8] inviter-celebration render stripped (pairing-era). The realtime
        // discover/bindConnection plumbing stays (data layer = build 9).
        // .fullScreenCover(isPresented: $showInviterCelebration) {
        //     PairingCelebrationView(person: celebratePerson) {
        //         showInviterCelebration = false
        //     }
        // }
    }

    /// pointward.app/pair/POINT-GP2S → confirmation sheet with the code filled in.
    private func handleIncomingURL(_ url: URL) {
        rootLog.info("deeplink: incoming URL \(url.absoluteString, privacy: .public)")
        let parts = url.pathComponents.filter { $0 != "/" }
        // [phase2 4a] NEW sibling route: /m/<id> message links. Checked BEFORE the
        // pair guard; the pair/join path below is completely unchanged.
        if let messageID = MessageLink.messageID(from: url) {
            rootLog.info("deeplink: message open \(messageID.uuidString, privacy: .public)")
            // [double-tap fix · Layer 2] Funnel through the pending slot + the
            // ready-gate instead of presenting directly — so a COLD-launch first
            // tap presents as soon as the root is stable (not too early → dropped).
            // [pre-fix] messageOpenRequest = MessageOpenRequest(id: messageID)
            PendingLink.shared.set(messageID)
            presentPendingMessageIfReady()
            return
        }
        // [build8] /pair + /join deep-link routing stripped (pairing-era). The /m/
        // branch above is the link-era path and stays live. AASA still lists
        // /pair/* + /join/* (left intact) so old links just no-op here now.
        _ = parts   // keep `parts` referenced; the pair branch below is disabled.
        // guard parts.count >= 2,
        //       ["pair", "join"].contains(parts[0].lowercased()) else {
        //     rootLog.warning("deeplink: not a pair/join link — ignored")
        //     return
        // }
        // let code = SupabaseService.normalizePairingCode(parts[1])
        // guard SupabaseService.isValidPairingCode(code) else {
        //     rootLog.warning("deeplink: malformed code '\(parts[1], privacy: .public)' — ignored")
        //     return
        // }
        // rootLog.info("deeplink: pair request for \(code, privacy: .public)")
        // pairRequest = PairRequest(code: code)
    }

    /// [phase2 stage B] The sender-side connection reconciliation: drain any (S2)
    /// pending connection writes (backstop for the on-sign-in drain), then read my
    /// connections and stamp the matching local contacts' senderID (enables Stage-C
    /// PATH 1). No-op when signed out. Idempotent — safe to run on every active.
    private func syncConnections() {
        guard SupabaseService.localUserID != nil else { return }
        Task { @MainActor in
            await SupabaseService.shared.drainPendingConnections()
            let rows = await SupabaseService.shared.fetchMyConnections()
            people.stampConnections(rows)
            // [phase2 stage C] read-receipt poll (messages isn't realtime) — which of
            // my sent thoughts the recipient has opened in full → "opened ✦" indicator.
            let opened = await SupabaseService.shared.fetchOpenedSentMessageIDs()
            people.refreshReadReceipts(openedMessageIDs: opened)
        }
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
            // [build9] pairing DISCOVER retired (refreshConnections + bindConnection).
            // `partner` is now just the cached connectedFriendID (delivery fallback
            // for the pings realtime — left intact).
            let partner = SupabaseService.connectedFriendID
            // do {
            //     let connections = try await SupabaseService.shared.refreshConnections()
            //     await MainActor.run {
            //         for connection in connections {
            //             people.bindConnection(friendID: connection.partnerID,
            //                                   toPersonID: connection.myPersonID)
            //         }
            //     }
            //     partner = connections.first?.partnerID ?? partner
            // } catch {
            //     rootLog.error("realtime: connection discovery failed: …")
            // }

            // OFFLINE CATCH-UP: sweep every paired person for thoughts that
            // arrived while we were away — newest becomes the catch, the
            // rest are already resting in History. Quiet on failure.
            for person in people.people {
                guard let pid = person.pairedUserID.flatMap(UUID.init) else { continue }
                await pings.syncMissedThoughts(partnerID: pid, partnerName: person.name)
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
                                          senderStyle: event.senderStyle,
                                          message: event.message,
                                          tagline: event.tagline)
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
                        // History views listening flip their dot to "felt"
                        pings.lastFeltAt = .now
                    }
                },
                // [build9] mutual-pointing + pairing-claim retired → no-op closures
                // (kept in the signature; the realtime pairing streams that fired
                // them are commented in SupabaseService.startRealtime).
                onPointed: { _ in },
                onPaired: { _ in }
            )
        }
    }

    /// [5/6] When there's no one to point toward yet, create the friendly demo
    /// person (Alex) so the compass feels alive from the first launch. Skipped
    /// during -skipOnboarding (Sarah owns that path) and while onboarding is
    /// still in progress (the user is adding their own first real person).
    private func ensureDemoPersonIfAppropriate() {
        #if DEBUG
        if DevTools.wantsSkipOnboarding { return }
        #endif
        guard hasCompletedOnboarding else { return }
        people.ensureDemoPersonIfNeeded()
    }

    /// Launching with a saved person should immediately show that person on the
    /// compass — don't rely on child-view onAppear ordering.
    private func startCompassIfNeeded() {
        if let person = people.selectedPerson {
            compass.start(tracking: person)
        }
    }

    #if DEBUG
    // ════════════════════════════════════════════════════════════════════
    // ⚠️ DO NOT REMOVE — the PERMANENT skip-onboarding entry point.
    // This is the SINGLE source of truth, checked here in RootView (which has
    // the configured SwiftData context) rather than relying on a UserDefaults
    // flag set in App.init that a concurrent build can stomp. It reads the
    // launch argument DIRECTLY every launch, so `-skipOnboarding` always lands
    // straight on the compass with Sarah — independent of any other change.
    // ════════════════════════════════════════════════════════════════════
    private func applySkipOnboardingIfNeeded() {
        // The launch argument is authoritative and re-checked every launch.
        if DevTools.wantsSkipOnboarding {
            if !hasCompletedOnboarding { hasCompletedOnboarding = true }
            // No stale mock catch should bury the compass.
            UserDefaults.standard.removeObject(forKey: "pendingThoughtQueue")
            // Idempotent — injectMockData re-selects an existing Sarah or
            // creates her (name 💜 / NYC / paired / tagline) and connects.
            DevTools.injectMockData(people: people, pings: pings, withHistory: false)
            rootLog.info("skip-onboarding: launch arg present → Sarah injected, compass ready")
            return
        }
        // The "Skip to compass (mock data)" dev button sets this flag instead.
        if UserDefaults.standard.bool(forKey: DevTools.injectFlagKey) {
            UserDefaults.standard.removeObject(forKey: DevTools.injectFlagKey)
            DevTools.injectMockData(people: people, pings: pings, withHistory: false)
        }
    }

    /// DEBUG-ONLY throwaway scaffold (4a sim testing). Launch with
    ///   -openMessageID <uuid>
    /// to drive the REAL /m receive flow: this sets the SAME `messageOpenRequest`
    /// the universal-link handler sets, so fetch → incoming beat → receipt →
    /// opened-flip all run through the real path — no AASA / link routing needed.
    /// Reads the launch ARGUMENT only (volatile, per-launch), so it can never
    /// fire on a normal launch, and the whole thing is compiled out of release.
    private func maybeDebugOpenMessage() {
        guard !didDebugOpenMessage,
              let i = CommandLine.arguments.firstIndex(of: "-openMessageID"),
              i + 1 < CommandLine.arguments.count,
              let id = UUID(uuidString: CommandLine.arguments[i + 1]) else { return }
        didDebugOpenMessage = true
        rootLog.info("DEBUG: open message via -openMessageID \(id.uuidString, privacy: .public)")
        // [double-tap fix · Layer 2] Route through the SAME pending slot + ready-gate
        // as the real link path (the event-driven settle now handles the "wait for
        // splash + data layer" the old one-off +1.0s defer did by hand).
        // [pre-fix]
        // DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        //     messageOpenRequest = MessageOpenRequest(id: id)
        // }
        PendingLink.shared.set(id)
        presentPendingMessageIfReady()
    }
    #endif

    // [double-tap fix · Layer 2] Promote the cold-launch pending /m/ id to the
    // presented cover ONLY when the root can host it: splash gone, no cover already
    // up. Idempotent + re-entrant — safe to call from onAppear, the splash flip, the
    // pending-slot onChange, and each funnel. The atomic take() means a not-yet-ready
    // call never consumes the id (it returns early before taking).
    private func presentPendingMessageIfReady() {
        guard !showSplash else { return }               // wait for the launch splash
        guard messageOpenRequest == nil else { return }  // don't stomp an open cover
        guard let id = PendingLink.shared.take() else { return }
        rootLog.info("deeplink: presenting pending message \(id.uuidString, privacy: .public)")
        messageOpenRequest = MessageOpenRequest(id: id)
    }
}

// MARK: - Post-onboarding connect prompt (shown once, ever)

// [build8] pairing-era nudge stripped (no longer presented). Reversible: remove
// the #if false / #endif to restore. Full removal is the build-9 cleanup pass.
#if false
struct PostOnboardConnectPrompt: View {

    @Environment(\.dismiss) private var dismiss
    @State private var showFullConnect = false

    var body: some View {
        ZStack {
            DesignTokens.Color.background.ignoresSafeArea()

            // (ConnectView unrouted — the prompt now leads to the person's
            //  own card in People, where connecting lives)
            if false, showFullConnect {
                ConnectView()
            } else {
                VStack(spacing: 14) {
                    Spacer()
                    Text("🧭")
                        .font(.system(size: 40))
                    Text("want to connect with someone?")
                        .font(.system(size: 20, weight: .semibold, design: .serif))
                        .foregroundColor(DesignTokens.Color.textPrimary)
                    Text("open their card in People and tap\n“connect with them”")
                        .font(.system(size: 13, design: .serif).italic())
                        .foregroundColor(DesignTokens.Color.textMuted)
                        .multilineTextAlignment(.center)

                    Button {
                        dismiss()
                        NotificationCenter.default.post(name: .pointwardOpenPeople, object: nil)
                    } label: {
                        Text("take me there →")
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
#endif

// MARK: - Pair request (universal link)

struct PairRequest: Identifiable {
    let code: String
    var id: String { code }
}

/// A tapped /m/<id> link awaiting open (Phase 2 Build 4a). The deep-link sibling
/// of PairRequest — set by handleIncomingURL, presented by RootView.
struct MessageOpenRequest: Identifiable {
    let id: UUID
}

/// Confirmation sheet for a tapped pairing link — shows who the invite is
/// from (the identity stored with the connection), one Accept pairs AND
/// auto-adds them to the People list.
// [build8] DEAD pairing view (never presented) — stripped. Reversible via #if.
#if false
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
                do {
                    let info = try await SupabaseService.shared.lookupInvite(code)
                    withAnimation(.easeOut(duration: 0.3)) {
                        inviteName  = info.name
                        inviteEmoji = info.emoji
                    }
                } catch let error as SupabaseServiceError where error == .codeNotFound {
                    // Dead link — tell them now, before they hit Accept.
                    rootLog.warning("pair-link: code \(code, privacy: .public) not found")
                    errorMessage = error.localizedDescription
                } catch {
                    // Network hiccup — Accept will retry the lookup anyway.
                    rootLog.error("pair-link: invite lookup failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    private func accept() {
        guard SupabaseService.localUserID != nil else {
            rootLog.warning("pair-link: accept blocked — not signed in")
            errorMessage = "Sign in first — Settings → account — then tap the link again."
            return
        }
        isBusy = true
        errorMessage = nil
        rootLog.info("pair-link: accepting \(code, privacy: .public)")
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
                rootLog.info("pair-link: paired ✓ partner=\(result.ownerID.uuidString, privacy: .public)")
                HapticEngine.connectionFelt()
                withAnimation(.easeOut(duration: 0.4)) { connected = true }
            } catch {
                rootLog.error("pair-link: accept failed — \(error.localizedDescription, privacy: .public)")
                errorMessage = error.localizedDescription
            }
        }
    }
}
#endif

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
    @EnvironmentObject var pings:        PingManager
    @EnvironmentObject var appState:     AppStateManager

    @State private var selectedTab = 0
    // The compass "✦ Pro" badge opens the paywall directly now that the Pro tab
    // is retired (status + upgrade also live in Settings → account).
    @State private var showPaywall = false

    var body: some View {
        TabView(selection: $selectedTab) {
            CompassView()
                .tabItem {
                    Label("compass", systemImage: "compass.drawing")
                }
                .tag(0)

            // removed — see SESSION_LOG.md for history
            // Pro screen retired as a standalone tab. ProSetupView kept (not
            // deleted); its instrument/skin selection still lives in the
            // compass long-press picker. Tab bar is now Compass · People · Settings.
            // ProSetupView(isTab: true)
            //     .tabItem {
            //         Label("pro", systemImage: "sparkles")
            //     }
            //     .tag(1)

            PeopleListView(geocodingService: geocodingService)
                .tabItem {
                    Label("people", systemImage: "person.2")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label("settings", systemImage: "gearshape")
                }
                .tag(2)
        }
        .tint(DesignTokens.Color.accentSoft)
        .preferredColorScheme(.dark)
        // ── [5/6] Replay, app-wide — ON the TabView so it covers every
        // tab and survives child sheets. Tap anywhere dismisses; returns
        // to the original tab (selection untouched). ──
        .fullScreenCover(item: $pings.replayRequest) { request in
            ZStack {
                // [swipe] The container handles single OR a swipeable list.
                ReplaySwipeContainer(request: request) {
                    pings.replayRequest = nil
                    appState.transition(to: .idle)   // never strand .replay
                }
                VStack {
                    Spacer()
                    Text(request.siblings.count > 1 ? "swipe ‹ › · tap to dismiss" : "tap to dismiss")
                        .font(.system(size: 11, design: .serif).italic())
                        .foregroundColor(DesignTokens.Color.textDim)
                        .padding(.bottom, 28)
                }
                .allowsHitTesting(false)
            }
        }
        // ── THE RECEIPT — a dedicated full-screen receive experience over the
        // TabView (tab bar hidden, no compass). Replaces the inline catch. ──
        .fullScreenCover(item: $pings.nowPlaying) { playing in
            ReceiptView(
                ping: playing,
                style: SenderStyle.from(playing.senderStyle),
                onRevealed: { pings.markOpened(playing) },
                onFinished: {
                    pings.finishedPlaying(playing)
                    appState.transition(to: .idle)
                }
            )
            .onAppear {
                appState.transition(to: .catchMode)
                // Swing the needle to the sender so the alignment is real.
                if let sender = people.people.first(where: { $0.name == playing.fromName }),
                   people.selectedPerson?.id != sender.id {
                    people.select(sender)
                    compass.start(tracking: sender)
                }
            }
        }
        // The "✦ Pro" badge on the compass now opens the paywall directly
        // (the Pro tab was retired; upgrade + status live in Settings → account).
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .onReceive(NotificationCenter.default.publisher(for: .pointwardOpenPro)) { _ in
            showPaywall = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .pointwardOpenSettings)) { _ in
            selectedTab = 2   // Settings is tab 2 now (Pro tab removed)
        }
        // A notification-opened catch needs the compass visible
        .onReceive(NotificationCenter.default.publisher(for: .pointwardOpenCompass)) { _ in
            selectedTab = 0
        }
        // The post-onboarding prompt leads here — connecting lives on cards
        .onReceive(NotificationCenter.default.publisher(for: .pointwardOpenPeople)) { _ in
            selectedTab = 1   // People is tab 1 now (Pro tab removed)
        }
        // (thoughts tab retired — the pill/notification path is gone)
        // .onReceive(NotificationCenter.default.publisher(for: .pointwardOpenThoughts)) { _ in
        //     selectedTab = 1
        // }
    }
}
