// CompassView.swift
// Pointward › Views
//
// The emotional core of the app. Every system converges here:
//   - Skin system (NeedleView dispatches to the active skin's ring/face renderer)
//   - Emoji Presence System (center emoji, glow, scale-up on lock)
//   - Compass Lock Moment (±5° haptic + glow + lock badge)
//   - Breathing Ring (always-on ambient animation)
//   - Ping Overlay (emoji burst + ring pulse on ping receipt)
//   - Return Home Glow (warm background when > 500 km away)
//   - Tagline (per-person or skin default, fades in on person change)
//   - Quiet Mode (read from environment, slows all animations + dims glows)
//
// Rule from spec: the compass is always visible. This view is never pushed
// off-screen — other screens are sheets or overlays on top of it.

import SwiftUI
import CoreLocation
import Combine

struct CompassView: View {

    @EnvironmentObject var compass:  CompassManager
    @EnvironmentObject var people:   PeopleManager
    @EnvironmentObject var pings:    PingManager
    @EnvironmentObject var skinStore: SkinStore
    @EnvironmentObject var subscription: SubscriptionManager
    @EnvironmentObject var instrumentStore: InstrumentStore
    @EnvironmentObject var appEnv:   AppEnvironment
    @EnvironmentObject var appState: AppStateManager

    // @AppStorage("quietMode") private var quietMode = false   // retired
    private let quietMode = false

    // Lock moment — fires once per lock edge, resets when unlocked
    @State private var lockGlowActive = false
    @State private var emojiScaled    = false
    @State private var lockBadgeShown = false

    // Ping animation
    @State private var pingRingActive  = false
    @State private var badgePulse      = false

    // Empty state
    @State private var showAddPerson = false

    // Tagline animation trigger
    @State private var taglineKey: UUID = UUID()

    // Layered distance system — random per launch, lockable in Settings
    @AppStorage("funnyUnitLocked")      private var funnyUnitLocked      = -1
    @AppStorage("thoughtTaglineLocked") private var thoughtTaglineLocked = -1
    @AppStorage("showLightSpeed")       private var showLightSpeed       = true
    @State private var funnyIndex   = Int.random(in: 0..<DistanceFun.funnyCount)
    @AppStorage(ProFeatures.storageKey) private var proOn = false

    // Tagline: shuffled walk through the library — never repeats until
    // the whole library has been seen, then reshuffles
    @State private var taglineOrder: [Int] = TaglineSystem.poeticLibrary.indices.shuffled()
    @State private var taglinePosition = 0
    private var taglineIndex: Int { taglineOrder[taglinePosition] }

    // Discovery hint — "tap the words to change them", first three launches
    @AppStorage("discoveryHintCount") private var discoveryHintCount = 0
    @State private var showDiscoveryHint = false

    // Person switcher sheet (tap the name)
    @State private var showPersonSwitcher = false

    // Ambient presence — partner's needle resting on us → edge glow
    @State private var presenceGlowVisible = false

    // Needle emotional state — steady lock breathes warmer
    @State private var steadyLock = false
    @State private var breathePulse = false

    // Shareable compass moment
    @State private var showShareMoment = false
    @State private var shareCard: Image? = nil

    // Bottom-zone distance line: 0 standard · 1 funny (Pro) · 2 light speed
    @State private var distanceMode = 0

    // Face interactions — tap pulse + brief bearing readout, long-press skins
    @State private var faceTapPulse = false
    @State private var bearingFlash = false
    @State private var showSkinOverlay = false
    @State private var showSkinPaywall = false
    @State private var showConnectSheet = false
    // (subscription env object already declared at the top)

    // ── Send a thought — merged onto the compass (thoughts tab retired) ──
    @ObservedObject private var customStore = CustomThoughtStore.shared
    @AppStorage("holdToSendEnabled") private var holdToSendEnabled = false
    @State private var personalSixRow: [String] = PersonalSet.load()
    @State private var selectedToken: String? = nil
    @State private var flightToken: String? = nil
    // Full-compass sender styles dim the skin to 20 % while they play
    @State private var faceDimmedForInstrument = false
    @State private var flightFly = false
    @State private var holdProgress: Double = 0
    private let holdDuration = 2.0
    private let holdTick = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    private var holdToSendActive: Bool {
        holdToSendEnabled && subscription.tier != .free
    }
    private var sendAlignDiff: Double {
        let bearing = compass.state.bearingDegrees
        return min(bearing, 360 - bearing)
    }

    var body: some View {
        ZStack {
            // ── Background ──────────────────────────────────────────────────
            // Phase 1: steady deep purple — the far-from-home colour shift is
            // gone, only the text label remains.
            DesignTokens.Color.background
                .ignoresSafeArea()

            if people.people.isEmpty {
                // ── Warm empty state — no one to point toward yet ────────────
                emptyState
            } else {
                VStack(spacing: 0) {
                    // ── TOP ZONE: name, then distance right under it ──────────
                    nameHeader
                        .padding(.top, 16)

                    distanceLine
                        .padding(.top, 6)

                    Spacer(minLength: 12)

                    // ── MIDDLE ZONE: the compass, dominant, nothing on it ─────
                    // Skins render at a fixed 240pt design size; scale the whole
                    // composition so every face grows together.
                    // ── FOUR INSTRUMENTS: only the middle changes ─────────
                    Group {
                        switch instrumentStore.selected {
                        case .compass:
                            compassFace
                                .frame(width: 240, height: 240)
                                .scaleEffect(370.0 / 240.0)
                                .frame(width: 370, height: 370)
                                // Full-compass send styles dim the skin
                                .opacity(faceDimmedForInstrument ? 0.2 : 1.0)
                                .animation(faceDimmedForInstrument
                                           ? .easeOut(duration: 0.3)
                                           : .easeIn(duration: 0.4),
                                           value: faceDimmedForInstrument)
                        case .bow:
                            BowInstrumentView(
                                loadedToken: selectedToken,
                                loadedSymbol: selectedToken.map { AnyView(sendSymbol($0, size: 26)) },
                                bearingDegrees: compass.state.bearingDegrees,
                                personName: compass.state.personName,
                                onSend: { if let token = selectedToken { sendThought(token) } }
                            )
                        case .firefly:
                            FireflyInstrumentView(
                                loadedToken: selectedToken,
                                loadedSymbol: selectedToken.map { AnyView(sendSymbol($0, size: 26)) },
                                bearingDegrees: compass.state.bearingDegrees,
                                personName: compass.state.personName,
                                onSend: { if let token = selectedToken { sendThought(token) } }
                            )
                        case .flick:
                            FlickInstrumentView(
                                loadedToken: selectedToken,
                                loadedSymbol: selectedToken.map { AnyView(sendSymbol($0, size: 26)) },
                                bearingDegrees: compass.state.bearingDegrees,
                                personName: compass.state.personName,
                                onSend: { _ in if let token = selectedToken { sendThought(token) } }
                            )
                        }
                    }
                    .id(instrumentStore.selected)              // crossfade on switch
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: instrumentStore.selected)
                        // STEADY LOCK (5 s+): warm breathing halo behind the face
                        .background(
                            Circle()
                                .fill(Color(hex: "#c4845a").opacity(steadyLock ? (breathePulse ? 0.16 : 0.09) : 0))
                                .frame(width: 330, height: 330)
                                .scaleEffect(breathePulse ? 1.05 : 0.97)
                                .blur(radius: 42)
                                .allowsHitTesting(false)
                        )
                        // Tap: alive — pulse, brief bearing readout, soft haptic
                        .scaleEffect(faceTapPulse ? 1.015 : 1.0)
                        .overlay(
                            Text("\(Int(compass.state.bearingDegrees.rounded()))°")
                                .font(.system(size: 22, weight: .light))
                                .foregroundColor(DesignTokens.Color.textSecondary.opacity(0.9))
                                .monospacedDigit()
                                .offset(y: -52)
                                .opacity(bearingFlash ? 1 : 0)
                                .allowsHitTesting(false)
                        )
                        .contentShape(Circle())
                        .onTapGesture { tapFace() }
                        .onLongPressGesture(minimumDuration: 0.45) {
                            HapticEngine.personSelected()
                            withAnimation(.easeOut(duration: 0.3)) { showSkinOverlay = true }
                        }

                    Spacer(minLength: 12)

                    // ── BOTTOM ZONE: distance · funny · tagline · emojis ──────
                    bottomZone
                        .padding(.top, 24)

                    // The six, always visible — sending lives right here.
                    // The gap above equals one tagline line height (26pt):
                    // the tagline breathes clearly, not crowded, not far.
                    emojiRow
                        .padding(.top, 26)

                    sendControl
                        .padding(.top, 10)
                        .padding(.bottom, 12)

                    // (connect link removed — connection UI lives in the
                    //  People tab only; the compass stays clean)

                    // (send pill retired — the row replaced it; view kept)
                    // sendPill

                    // (lock badge + always-on bearing readout retired from the
                    //  layout — bearing now appears on face tap; views kept)
                    // lockBadge
                    // bearingReadout
                }
            }

            // ── The flight — the chosen sender style carries the thought
            // out in the real compass direction (glow · star · firefly) ──────
            if let token = flightToken {
                SenderAnimationView(
                    style: instrumentStore.selected.senderStyle,
                    emoji: sendRemoteEmoji(for: token),
                    bearingDegrees: compass.state.bearingDegrees,
                    symbol: sendSymbol(token, size: 30)
                ) {
                    flightToken = nil
                    flightFly   = false
                    appState.transition(to: .idle)
                }
                .zIndex(6)
            }
            // (previous straight-line flight retired — curves only now)
            // if let token = flightToken {
            //     let rad  = compass.state.bearingDegrees * .pi / 180
            //     let edge = CGSize(width: CGFloat(sin(rad)) * 430,
            //                       height: -CGFloat(cos(rad)) * 430)
            //
            //     ForEach(0..<4, id: \.self) { i in
            //         sendSymbol(token, size: 13)
            //             .opacity(flightFly ? 0 : 0.65 - Double(i) * 0.14)
            //             .offset(flightFly ? edge : .zero)
            //             .animation(.easeIn(duration: 1.1).delay(0.10 + Double(i) * 0.08),
            //                        value: flightFly)
            //     }
            //     sendSymbol(token, size: 30)
            //         .scaleEffect(flightFly ? 1.7 : 0.7)
            //         .opacity(flightFly ? 0 : 1)
            //         .offset(flightFly ? edge : .zero)
            //         .animation(.easeIn(duration: 1.2).delay(0.05), value: flightFly)
            //         .shadow(color: Color(hex: "#9b7fc0").opacity(0.8), radius: 12)
            //         .allowsHitTesting(false)
            // }

            // ── Sender caught confirmation — the emoji they sent appears
            // briefly at the compass center. No text. No timestamp. No read
            // receipt. Just a warm symbolic moment (600 ms, then gone). ──────
            if let caught = pings.caughtMoment {
                CaughtConfirmationView(emoji: caught.emoji)
                    .id(caught.at)
                    .zIndex(6)
            }

            // (felt-receipt text capsule retired — replaced by the symbolic
            //  caught confirmation above; view kept for reference)
            // if let notice = pings.feltNotice {
            //     VStack {
            //         HStack(spacing: 6) {
            //             Image(systemName: "heart.fill")
            //                 .font(.system(size: 10))
            //             Text(notice)
            //                 .font(.system(size: 12, design: .serif).italic())
            //         }
            //         .foregroundColor(Color(hex: "#5dcaa5"))
            //         .padding(.horizontal, 14)
            //         .padding(.vertical, 8)
            //         .background(
            //             Capsule()
            //                 .fill(DesignTokens.Color.background.opacity(0.85))
            //                 .overlay(Capsule().stroke(Color(hex: "#5dcaa5").opacity(0.35), lineWidth: 1))
            //         )
            //         .padding(.top, 64)
            //         Spacer()
            //     }
            //     .transition(.opacity.combined(with: .move(edge: .top)))
            //     .animation(.easeInOut(duration: 0.4), value: pings.feltNotice)
            // }

            // ── Thought queue badge — pro mode only (core mode
            // reveals thoughts automatically through the compass itself) ──────
            if proOn && !pings.queue.isEmpty && pings.nowPlaying == nil {
                VStack {
                    Button {
                        pings.playNext()
                    } label: {
                        HStack(spacing: 6) {
                            Text(pings.queue.count == 1
                                 ? "a thought for you"
                                 : "thoughts for you")
                                .font(.system(size: 13, design: .serif).italic())
                            Text("✦")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(DesignTokens.Color.accentSoft)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(DesignTokens.Color.backgroundLift.opacity(0.95))
                                .overlay(Capsule().stroke(DesignTokens.Color.accentMid.opacity(0.5), lineWidth: 1))
                        )
                        .shadow(color: Color(hex: "#9b7fc0").opacity(badgePulse ? 0.5 : 0.2), radius: 10)
                        .scaleEffect(badgePulse ? 1.04 : 1.0)
                    }
                    .padding(.top, 52)
                    Spacer()
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                .onAppear {
                    guard !quietMode else { return }
                    withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                        badgePulse = true
                    }
                }
            }

            // ── Arrival → CATCH MODE ──────────────────────────────────────────
            // Only the newest thought triggers the catch; the orb waits at
            // the sender's edge until you physically turn toward them.
            // opened_at is set at the reveal — felt means felt.
            if let playing = pings.nowPlaying {
                CatchModeView(
                    ping: playing,
                    // The RECEIVER's instrument shapes the catch — the
                    // experience matches the instrument in your hand:
                    // compass → glow orb · bow → arrow stuck at the edge ·
                    // firefly → wandering orb · flick → bouncing emoji.
                    // (was: SenderStyle.from(playing.senderStyle))
                    style: instrumentStore.selected.senderStyle,
                    onRevealed: { pings.markOpened(playing) },
                    onFinished: {
                        pings.finishedPlaying(playing)
                        appState.transition(to: .idle)
                    }
                )
                .transition(.opacity)
                .zIndex(7)
                .onAppear {
                    appState.transition(to: .catchMode)
                    // Swing the needle to the sender so the catch direction
                    // is real, not whoever was selected before
                    if let sender = people.people.first(where: { $0.name == playing.fromName }),
                       people.selectedPerson?.id != sender.id {
                        people.select(sender)
                        compass.start(tracking: sender)
                    }
                }
            }
            // (previous arrival flows retired — views kept for reference:
            //  proOn → ThoughtArrivalView, core → DirectionalArrivalView)

            // ── Ambient presence — their needle is resting on us ──────────────
            if presenceGlowVisible {
                presenceGlow
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            // ── "✦ Pro" indicator — top right, tap → Settings ──────────
            if proOn {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            NotificationCenter.default.post(name: .pointwardOpenSettings, object: nil)
                        } label: {
                            Text("✦ Pro")
                                .font(.system(size: 10, design: .serif).italic())
                                .foregroundColor(DesignTokens.Color.accentMid.opacity(0.75))
                        }
                        .padding(.trailing, 18)
                        .padding(.top, 10)
                    }
                    Spacer()
                }
            }

            // ── Shareable compass moment — appears briefly after lock ─────────
            if showShareMoment, let card = shareCard {
                VStack {
                    Spacer()
                    ShareLink(
                        item: card,
                        preview: SharePreview("Pointward — \(compass.state.personName)", image: card)
                    ) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 10))
                            Text("share this moment")
                                .font(.system(size: 11, design: .serif).italic())
                        }
                        .foregroundColor(DesignTokens.Color.accentMid)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(DesignTokens.Color.backgroundLift.opacity(0.9))
                                .overlay(Capsule().stroke(DesignTokens.Color.border, lineWidth: 1))
                        )
                    }
                    .padding(.bottom, 46)
                }
                .transition(.opacity)
            }

            // ── Discovery hint — first three launches only ────────────────────
            if showDiscoveryHint {
                VStack {
                    Spacer()
                    Text("tap the words to explore")
                        .font(.system(size: 12, design: .serif).italic())
                        .foregroundColor(DesignTokens.Color.accentMid.opacity(0.8))
                        .padding(.bottom, 18)
                }
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            // ── Skin picker — long-press the face, switch right here ──────────
            if showSkinOverlay {
                SkinQuickPicker(
                    isPro: subscription.tier != .free,
                    onLockedTap: {
                        showSkinOverlay = false
                        showSkinPaywall = true
                    },
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.25)) { showSkinOverlay = false }
                    }
                )
                .transition(.opacity)
                .zIndex(5)
            }

            // ── Pointing toast retired — ambient presence glow replaced it ────
            // if let notice = pings.pointingNotice {
            //     VStack {
            //         HStack(spacing: 7) {
            //             Text("🧭").font(.system(size: 14))
            //             Text(notice)
            //                 .font(.system(size: 13, design: .serif).italic())
            //                 .foregroundColor(DesignTokens.Color.textPrimary)
            //         }
            //         .padding(.horizontal, 16).padding(.vertical, 10)
            //         .background(Capsule().fill(DesignTokens.Color.backgroundLift.opacity(0.95)))
            //         .padding(.top, 14)
            //         Spacer()
            //     }
            // }
        }
        // ── Reactions to state changes ────────────────────────────────────────
        .onChange(of: pings.partnerPointingAt) { _, stamp in
            guard stamp != nil else { return }
            withAnimation(.easeIn(duration: 1.2)) { presenceGlowVisible = true }
            // The glow breathes for a while, then drifts away
            DispatchQueue.main.asyncAfter(deadline: .now() + 9.0) {
                withAnimation(.easeOut(duration: 2.0)) { presenceGlowVisible = false }
            }
            // Mutual: we're locked on them while they rest on us
            if compass.state.isLocked {
                HapticEngine.connectionFelt()
            }
        }
        .onChange(of: compass.state.isLocked)        { _, locked in handleLock(locked) }
        .sheet(isPresented: $showSkinPaywall) { PaywallView() }
        // Hold to Send (Pro, opt-in): the ring fills while aligned within 15°
        .onReceive(holdTick) { _ in
            guard holdToSendActive, let token = selectedToken, flightToken == nil else {
                if holdProgress > 0 { holdProgress = 0 }
                return
            }
            if sendAlignDiff <= 15 {
                holdProgress += 0.05 / holdDuration
                if holdProgress >= 1.0 {
                    holdProgress = 0
                    HapticEngine.thoughtLaunched()
                    sendThought(token)
                }
            } else if holdProgress > 0 {
                withAnimation(.easeOut(duration: 0.3)) { holdProgress = 0 }
            }
        }
        .onChange(of: compass.state.personID)        { _, _      in handlePersonChange() }
        .onChange(of: pings.queue.isEmpty)           { _, empty  in
            withAnimation(AnimationSystem.pingGlow) { pingRingActive = !empty }
        }
        .onAppear {
            // Hard guard — free tier renders Minimal only. Silent and
            // immediate, before the compass face appears.
            skinStore.enforceTier(subscription.tier)
            if let person = people.selectedPerson {
                compass.start(tracking: person)
            }
            // Locked favourites override the per-launch randomization
            if funnyUnitLocked >= 0 && funnyUnitLocked < DistanceFun.funnyCount {
                funnyIndex = funnyUnitLocked
            }
            if thoughtTaglineLocked >= 0 && thoughtTaglineLocked < TaglineSystem.poeticLibrary.count {
                // Locked favourite leads; the rest still cycle behind it
                taglineOrder = [thoughtTaglineLocked]
                    + TaglineSystem.poeticLibrary.indices.filter { $0 != thoughtTaglineLocked }.shuffled()
                taglinePosition = 0
            }
            // Discovery hint — first three launches only
            if discoveryHintCount < 3 {
                discoveryHintCount += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeIn(duration: 0.6)) { showDiscoveryHint = true }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                    withAnimation(.easeOut(duration: 0.8)) { showDiscoveryHint = false }
                }
            }
        }
        .onChange(of: people.selectedPerson) { _, newPerson in
            if let person = newPerson {
                compass.start(tracking: person)
            }
        }
        .sheet(isPresented: $showAddPerson) {
            AddPersonView(geocodingService: appEnv.geocodingService)
        }
    }

    // MARK: - Empty state

    @State private var emptyGlowPulse = false

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()

            // Compass emoji with a soft pulsing glow
            ZStack {
                Circle()
                    .fill(Color(hex: "#9b7fc0").opacity(emptyGlowPulse ? 0.30 : 0.14))
                    .frame(width: 110, height: 110)
                    .blur(radius: 22)
                Circle()
                    .stroke(DesignTokens.Color.accentMid.opacity(0.3), lineWidth: 1)
                    .frame(width: 124, height: 124)
                Circle()
                    .stroke(DesignTokens.Color.accentMid.opacity(0.12), lineWidth: 1)
                    .frame(width: 148, height: 148)
                Text("🧭")
                    .font(.system(size: 52))
                    .scaleEffect(emptyGlowPulse ? 1.04 : 1.0)
            }
            .padding(.bottom, 32)
            .onAppear {
                guard !quietMode else { return }
                withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                    emptyGlowPulse = true
                }
            }

            Text("the needle is ready")
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundColor(DesignTokens.Color.textPrimary)
                .padding(.bottom, 6)

            Text("add someone to point toward")
                .font(DesignTokens.Font.compassDistance)
                .foregroundColor(DesignTokens.Color.textMuted)
                .padding(.bottom, 10)

            Text("Love has a direction.")
                .font(.system(size: 14, design: .serif).italic())
                .foregroundColor(DesignTokens.Color.accentMid)
                .padding(.bottom, 28)

            Button {
                showAddPerson = true
            } label: {
                Text("who do you point toward?")
                    .font(DesignTokens.Font.label)
                    .foregroundColor(DesignTokens.Color.textPrimary)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 13)
                    .background(DesignTokens.Color.accentStrong)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(DesignTokens.Color.accentMid, lineWidth: 1))
            }

            Spacer()
        }
    }

    // MARK: - Person header

    // ── TOP ZONE ──────────────────────────────────────────────────────────

    /// The name — largest text on screen, a dedication in a book.
    /// ✦ marks it tappable when there's more than one person.
    private var nameHeader: some View {
        HStack(spacing: 7) {
            Text(compass.state.personName)
                .font(.system(size: 34, weight: .semibold, design: .serif))
                .foregroundColor(DesignTokens.Color.textPrimary)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.35), value: compass.state.personName)
            if people.people.count > 1 {
                Text("✦")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Color.accentMid.opacity(0.7))
            }
        }
        .onTapGesture {
            guard people.people.count > 1 else { return }
            HapticEngine.personSelected()
            showPersonSwitcher = true
        }
        .sheet(isPresented: $showPersonSwitcher) {
            PersonSwitcherSheet()
                .presentationDetents([.height(min(420, CGFloat(people.people.count) * 64 + 90))])
                .presentationDragIndicator(.visible)
        }
    }

    // ── BOTTOM ZONE ───────────────────────────────────────────────────────

    /// The mode line 1 cycles through: standard → funny (Pro) → light speed.
    private var distanceLineText: String {
        switch distanceMode {
        case 1:  return DistanceFun.funnyText(km: compass.state.distanceKm, index: funnyIndex)
        case 2:  return DistanceFun.lightSpeedText(km: compass.state.distanceKm)
        default: return compass.state.formattedDistance
        }
    }

    /// TOP ZONE line 2 — the distance, tap cycles: standard → funny (Pro)
    /// → light speed. Number only, clean crossfade, free skips funny.
    private var distanceLine: some View {
        HStack(spacing: 5) {
            Text(distanceLineText)
                // Halfway between the old distance (15) and the name (34) —
                // important information, not a footnote
                .font(.system(size: 24, weight: .light))
                .foregroundColor(DesignTokens.Color.textSecondary)
                .monospacedDigit()
                .contentTransition(.opacity)
            Text("✦")
                .font(.system(size: 8))
                .foregroundColor(DesignTokens.Color.textDim.opacity(0.7))
        }
        .onTapGesture {
            HapticEngine.personSelected()
            withAnimation(.easeInOut(duration: 0.3)) {
                let next = (distanceMode + 1) % 3
                distanceMode = (next == 1 && !proOn) ? 2 : next
            }
        }
        .animation(.easeInOut(duration: 0.3), value: distanceMode)
    }

    private var bottomZone: some View {
        VStack(spacing: 12) {
            // (distance moved to the top zone; the "unit:" cycler retired —
            //  the funny unit comes from Pro setup's lock or per-launch random)

            // The poetic tagline, never repeats until all shown —
            // doubled (13 → 26) so the words carry their weight
            HStack(spacing: 5) {
                Text(TaglineSystem.poeticLibrary[taglineIndex])
                    .font(.system(size: 26, design: .serif).italic())
                    .foregroundColor(DesignTokens.Color.accentMid)
                    .minimumScaleFactor(0.6)   // long lines stay on one line
                    .lineLimit(1)
                Text("✦")
                    .font(.system(size: 8))
                    .foregroundColor(DesignTokens.Color.accentMid.opacity(0.55))
            }
            .contentTransition(.opacity)
            .onTapGesture {
                HapticEngine.personSelected()
                withAnimation(.easeInOut(duration: 0.4)) {
                    if taglinePosition + 1 >= taglineOrder.count {
                        taglineOrder = TaglineSystem.poeticLibrary.indices.shuffled()
                        taglinePosition = 0
                    } else {
                        taglinePosition += 1
                    }
                }
            }

            if compass.state.isFarFromHome {
                Text("across the distance")
                    .font(.system(size: 12, design: .serif).italic())
                    .foregroundColor(Color(hex: "#c4845a"))
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.45), value: compass.state.isFarFromHome)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: distanceMode)
    }

    /// Line 4 — the thin pill that opens the emoji drawer (thoughts tab).
    private var sendPill: some View {
        Button {
            HapticEngine.personSelected()
            NotificationCenter.default.post(name: .pointwardOpenThoughts, object: nil)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .medium))
                Text("send a thought")
                    .font(.system(size: 13, design: .serif).italic())
            }
            .foregroundColor(DesignTokens.Color.accentSoft)
            .padding(.horizontal, 22)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(DesignTokens.Color.backgroundLift.opacity(0.9))
                    .overlay(Capsule().stroke(DesignTokens.Color.border, lineWidth: 1))
            )
        }
        // Swipe up on the pill also opens the drawer
        .gesture(
            DragGesture(minimumDistance: 18)
                .onEnded { value in
                    if value.translation.height < -18 {
                        NotificationCenter.default.post(name: .pointwardOpenThoughts, object: nil)
                    }
                }
        )
    }

    /// Tap the face: it answers — pulse, brief bearing readout, soft haptic.
    private func tapFace() {
        HapticEngine.personSelected()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { faceTapPulse = true }
        withAnimation(.easeIn(duration: 0.3)) { bearingFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeOut(duration: 0.4)) { faceTapPulse = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.6)) { bearingFlash = false }
        }
    }

    /// True only when the person has their own tagline — skin defaults don't count.
    private var hasCustomTagline: Bool {
        guard let t = compass.state.tagline else { return false }
        return !t.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Send a thought (merged from the thoughts tab)

    /// Free users carry the core six; Pro users their curated set.
    private var rowTokens: [String] {
        subscription.tier == .free ? PersonalSet.coreDefault : personalSixRow
    }

    /// The six, always visible in soft cards. Selection glows and stays.
    private var emojiRow: some View {
        HStack(spacing: 10) {
            ForEach(rowTokens, id: \.self) { token in
                let isSelected = selectedToken == token
                Button {
                    HapticEngine.personSelected()
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.6)) {
                        selectedToken = isSelected ? nil : token
                    }
                } label: {
                    sendSymbol(token, size: 26)
                        .frame(width: 50, height: 50)
                        .background(DesignTokens.Color.backgroundCard.opacity(isSelected ? 1 : 0.7))
                        .cornerRadius(15)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(isSelected ? DesignTokens.Color.accentMid
                                                   : DesignTokens.Color.border.opacity(0.6),
                                        lineWidth: 1)
                        )
                        .shadow(color: Color(hex: "#c4a8d4").opacity(isSelected ? 0.55 : 0),
                                radius: 10)
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear { personalSixRow = PersonalSet.load() }
    }

    /// Below the row: tap-send button, or the hold ring (Pro opt-in).
    @ViewBuilder
    private var sendControl: some View {
        // The other instruments carry their own send mechanic (draw / hold /
        // flick) — the button belongs to the compass alone.
        if instrumentStore.selected != .compass {
            Color.clear.frame(height: 1)
        } else if let token = selectedToken, flightToken == nil {
            if holdToSendActive {
                VStack(spacing: 5) {
                    ZStack {
                        Circle()
                            .stroke(DesignTokens.Color.borderMid, lineWidth: 3)
                            .frame(width: 40, height: 40)
                        Circle()
                            .trim(from: 0, to: holdProgress)
                            .stroke(Color(hex: "#e0ccee"),
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 40, height: 40)
                            .rotationEffect(.degrees(-90))
                    }
                    Text(sendAlignDiff <= 15
                         ? "hold toward \(compass.state.personName)"
                         : "point toward \(compass.state.personName) first")
                        .font(.system(size: 11, design: .serif).italic())
                        .foregroundColor(sendAlignDiff <= 15
                                         ? Color(hex: "#e0ccee")
                                         : DesignTokens.Color.textMuted)
                }
                .transition(.opacity)
            } else {
                Button {
                    sendThought(token)
                } label: {
                    Text("send →")
                        .font(DesignTokens.Font.label)
                        .foregroundColor(DesignTokens.Color.textPrimary)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 10)
                        .background(DesignTokens.Color.accentStrong)
                        .cornerRadius(DesignTokens.Radius.button)
                        .shadow(color: Color(hex: "#9b7fc0").opacity(0.4), radius: 8)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        } else {
            // Keeps the layout from jumping when nothing is selected
            Color.clear.frame(height: 1)
        }
    }

    /// Renders an emoji token, the gecko, or a custom thought's emoji.
    @ViewBuilder
    private func sendSymbol(_ token: String, size: CGFloat) -> some View {
        if token == "gecko" {
            LeopardGeckoView(size: size * 1.2)
        } else if token.hasPrefix("yours:"),
                  let id = UUID(uuidString: String(token.dropFirst(6))),
                  let thought = customStore.thought(id: id) {
            Text(thought.emoji).font(.system(size: size))
        } else {
            Text(token).font(.system(size: size))
        }
    }

    private func sendRemoteEmoji(for token: String) -> String {
        if token == "gecko" { return "🦎" }
        if token.hasPrefix("yours:"),
           let id = UUID(uuidString: String(token.dropFirst(6))),
           let thought = customStore.thought(id: id) {
            return thought.emoji
        }
        return token
    }

    private func playSendSound(_ token: String) {
        if token.hasPrefix("yours:"),
           let id = UUID(uuidString: String(token.dropFirst(6))),
           let thought = customStore.thought(id: id) {
            customStore.play(thought)
        } else {
            SoundEngine.shared.play(for: token)
        }
    }

    /// The send: styled flight in the real compass direction, sound, clear.
    /// SenderAnimationView owns the haptics and the style voice; the
    /// thought's own sound still plays here.
    private func sendThought(_ token: String) {
        // One state at a time — a catch in progress owns the screen
        guard appState.transition(to: .sending) else { return }
        withAnimation(.easeOut(duration: 0.25)) { selectedToken = nil }
        flightToken = token
        flightFly = true   // legacy flag (the style view drives its own motion)

        // ONE SELECTION DEFINES EVERYTHING: the flight personality follows
        // the chosen instrument (compass→glow, bow→bowArrow, firefly→firefly,
        // flick→fingerFlick). Free users hold the compass, so glow.
        let style = instrumentStore.selected.senderStyle
        if style == .fingerFlick || style == .bowArrow {
            faceDimmedForInstrument = true
            let restoreDelay = style == .bowArrow ? 1.5 : 1.2
            DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) {
                faceDimmedForInstrument = false
            }
        }
        // HapticEngine.thoughtReleased()   // retired — style haptic fires at launch

        // Real delivery when paired
        if let friend = SupabaseService.connectedFriendID {
            let emoji = sendRemoteEmoji(for: token)
            Task { try? await SupabaseService.shared.sendPing(to: friend, emoji: emoji) }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            playSendSound(token)
            // HapticEngine.thoughtLaunched()   // retired — single .light at launch
        }
        // Cleanup moved to SenderAnimationView.onComplete (duration varies by style)
        // DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
        //     flightToken = nil
        //     flightFly = false
        // }
    }

    // MARK: - Compass face

    private var compassFace: some View {
        ZStack {
            // ── The rose is STATIC: N at top, always. Real-world
            // orientation comes from the fixed face; emotional direction
            // from the needle (bearing - heading) alone.
            Group {
                // Skin-specific rings and decorations
                SkinFaceView(
                    skin: compass.state.activeSkin,
                    bearing: compass.state.bearingDegrees,
                    locked: compass.state.isLocked,
                    quietMode: quietMode,
                    pingRingActive: pingRingActive
                )

                // Cardinal markers ride the rose (just inside the ring)
                ForEach(0..<4, id: \.self) { i in
                    let rad = Double(i) * 90 * .pi / 180
                    Text(["N", "E", "S", "W"][i])
                        .font(.system(size: 9, weight: i == 0 ? .semibold : .regular, design: .rounded))
                        .foregroundColor(i == 0
                                         ? DesignTokens.Color.accentSoft.opacity(0.9)
                                         : DesignTokens.Color.textDim.opacity(0.7))
                        .offset(x: CGFloat(sin(rad)) * 113, y: -CGFloat(cos(rad)) * 113)
                }
            }
            // .rotationEffect(.degrees(compass.state.faceRotationDegrees))
            //   — face rotation removed: the rose never turns

            // Emoji presence system — always at center
            emojiPresence

            // Needle — shared geometry, skin-tinted colours
            NeedleView(
                bearing: compass.state.bearingDegrees,
                skin: compass.state.activeSkin,
                locked: compass.state.isLocked,
                quietMode: quietMode
            )

            // Pivot dot — soft glow on the heart skin
            Circle()
                .fill(pivotColor)
                .frame(width: 10, height: 10)
                .shadow(color: pivotGlow, radius: 4)
                .zIndex(4)
        }
    }

    // MARK: - Emoji presence

    private var emojiPresence: some View {
        ZStack {
            // Glow disc behind emoji
            Circle()
                .fill(glowColor.opacity(glowOpacity))
                .frame(width: 68, height: 68)
                .animation(
                    quietMode
                        ? .easeInOut(duration: 1.0)
                        : AnimationSystem.pingGlow,
                    value: lockGlowActive || pingRingActive
                )
                .zIndex(2)

            // Emoji — scales up on lock, crossfades on person switch
            Text(compass.state.personEmoji)
                .font(.system(size: 28))
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.35), value: compass.state.personEmoji)
                .scaleEffect(emojiScaled ? 1.2 : 1.0)
                .animation(
                    quietMode
                        ? .easeInOut(duration: 0.6)
                        : AnimationSystem.pingBurst,
                    value: emojiScaled
                )
                .zIndex(3)
        }
    }

    // MARK: - Lock badge

    private var lockBadge: some View {
        HStack(spacing: 4) {
            if lockBadgeShown {
                Text("locked ✦")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Color.accentSoft)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Color(hex: "#c4a8d4").opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color(hex: "#c4a8d4").opacity(0.3), lineWidth: 1))
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .animation(.easeOut(duration: 0.4), value: lockBadgeShown)
        .frame(height: 22)
    }

    // MARK: - Bearing readout

    private var bearingReadout: some View {
        Text("\(Int(compass.state.bearingDegrees.rounded()))°")
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(DesignTokens.Color.textDim)
            .monospacedDigit()
    }

    // MARK: - Computed styling

    private var glowColor: Color {
        switch compass.state.activeSkin {
        case .aurora:    return Color(hex: "#5dcaa5")
        case .heart:     return Color(hex: "#c4a8d4")
        default:         return Color(hex: "#9b7fc0")
        }
    }

    private var glowOpacity: Double {
        if pingRingActive          { return quietMode ? 0.18 : 0.35 }
        if lockGlowActive          { return quietMode ? 0.12 : 0.25 }
        return 0
    }

    private var pivotColor: Color {
        switch compass.state.activeSkin {
        case .aurora: return Color(hex: "#1D9E75")
        case .heart:  return Color(hex: "#e0a8c8")
        default:      return DesignTokens.Color.accentMid
        }
    }

    private var pivotGlow: Color {
        compass.state.activeSkin == .heart
            ? Color(hex: "#e0a8c8").opacity(0.8)
            : .clear
    }

    // MARK: - Event handlers

    private func handleLock(_ locked: Bool) {
        guard !quietMode || locked else { return } // quiet mode: allow lock-on, skip unlock animation
        withAnimation(AnimationSystem.pingBurst) {
            emojiScaled    = locked
            lockGlowActive = locked
        }
        withAnimation(.easeOut(duration: 0.4).delay(locked ? 0.15 : 0)) {
            lockBadgeShown = locked
        }
        // Auto-dismiss lock glow after 4 seconds so it doesn't linger
        // (the brief-point flash: lock → quick glow → fades)
        if locked {
            Task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                withAnimation { lockGlowActive = false }
            }
            // STEADY LOCK: held for 5+ seconds → the needle breathes warmer
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if compass.state.isLocked {
                    withAnimation(.easeIn(duration: 1.0)) { steadyLock = true }
                    withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                        breathePulse = true
                    }
                }
            }
            // Shareable moment — offer briefly after the needle settles
            shareCard = renderShareCard()
            withAnimation(.easeIn(duration: 0.5).delay(0.8)) { showShareMoment = true }
            Task {
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                withAnimation(.easeOut(duration: 0.6)) { showShareMoment = false }
            }
        } else {
            withAnimation(.easeOut(duration: 0.5)) { steadyLock = false }
            withAnimation(.easeOut(duration: 0.3)) {
                showShareMoment = false
                breathePulse = false
            }
        }
    }

    // MARK: - Ambient presence glow

    /// Warm lavender light breathing in from the partner's edge of the
    /// screen — they're pointing at us right now. No text, no badge…
    /// unless we're pointing back: then the moment is named.
    private var presenceGlow: some View {
        let rad = compass.state.bearingDegrees * .pi / 180
        return ZStack {
            RadialGradient(
                colors: [Color(hex: "#c4a8d4").opacity(steadyLock ? 0.34 : 0.22), .clear],
                center: UnitPoint(x: 0.5 + 0.60 * sin(rad),
                                  y: 0.5 - 0.60 * cos(rad)),
                startRadius: 10,
                endRadius: 380
            )
            .ignoresSafeArea()

            // Both needles resting on each other — a shared moment
            if compass.state.isLocked {
                VStack {
                    Spacer()
                    Text("pointing at each other ✦")
                        .font(.system(size: 13, design: .serif).italic())
                        .foregroundColor(Color(hex: "#e0ccee"))
                        .shadow(color: Color(hex: "#9b7fc0").opacity(0.8), radius: 8)
                        .padding(.bottom, 64)
                }
                .transition(.opacity)
            }
        }
    }

    // MARK: - Share card

    /// Renders the shareable compass moment as an image.
    private func renderShareCard() -> Image? {
        guard let person = people.selectedPerson else { return nil }
        let card = ShareCardView(
            personName: person.name,
            emoji: person.emoji,
            bearing: compass.state.bearingDegrees,
            distance: compass.state.formattedDistance,
            tagline: TaglineSystem.poeticLibrary[taglineIndex]
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        guard let uiImage = renderer.uiImage else { return nil }
        return Image(uiImage: uiImage)
    }

    private func handlePersonChange() {
        // Re-trigger tagline fade-out → fade-in
        withAnimation {
            taglineKey = UUID()
        }
        // Reset lock state for new person
        withAnimation {
            lockGlowActive = false
            emojiScaled    = false
            lockBadgeShown = false
        }
    }

}

// MARK: - Notifications

extension Notification.Name {
    /// Posted by the "✦ Pro" badge — MainTabView jumps to Settings.
    static let pointwardOpenSettings = Notification.Name("pointwardOpenSettings")
    /// Posted by the send-a-thought pill — MainTabView jumps to Thoughts.
    static let pointwardOpenThoughts = Notification.Name("pointwardOpenThoughts")
}

// MARK: - SkinQuickPicker

/// Long-press the compass face → switch skins right here, no Settings trip.
struct SkinQuickPicker: View {

    let isPro: Bool
    let onLockedTap: () -> Void
    let onDismiss: () -> Void

    @EnvironmentObject var skinStore: SkinStore

    private static let lavender = Color(hex: "#c4a8d4")

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 16) {
                Text("compass skin")
                    .font(.system(size: 15, design: .serif).italic())
                    .foregroundColor(DesignTokens.Color.textMuted)

                HStack(spacing: 14) {
                    card(.minimal, locked: false)
                    card(.vintage, locked: !isPro)
                    card(.heart,   locked: !isPro)
                }
            }
            .padding(22)
            .background(DesignTokens.Color.backgroundCard)
            .cornerRadius(22)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(DesignTokens.Color.borderMid, lineWidth: 1)
            )
            .shadow(color: Color(hex: "#9b7fc0").opacity(0.3), radius: 24)
            .padding(.horizontal, 36)
        }
    }

    private func card(_ skin: CompassSkin, locked: Bool) -> some View {
        let isActive = skinStore.activeSkin == skin
        return Button {
            if locked {
                HapticEngine.paywallReached()
                onLockedTap()
            } else {
                skinStore.activeSkin = skin
                HapticEngine.skinSelected()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onDismiss() }
            }
        } label: {
            VStack(spacing: 7) {
                ZStack {
                    Circle()
                        .stroke(isActive ? Self.lavender : DesignTokens.Color.borderMid,
                                lineWidth: isActive ? 2 : 1)
                        .frame(width: 56, height: 56)
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 15))
                            .foregroundColor(Self.lavender.opacity(0.8))
                    } else {
                        Image(systemName: "location.north.fill")
                            .font(.system(size: 18))
                            .foregroundColor(isActive ? Self.lavender : DesignTokens.Color.textDim)
                    }
                    if isActive {
                        VStack { HStack { Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Self.lavender)
                        }; Spacer() }
                        .frame(width: 62, height: 62)
                    }
                }
                .shadow(color: isActive ? Self.lavender.opacity(0.55) : .clear, radius: 9)
                Text(skin.displayName)
                    .font(.system(size: 11))
                    .foregroundColor(isActive ? DesignTokens.Color.textPrimary
                                              : DesignTokens.Color.textMuted)
            }
            .frame(width: 76)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - PersonSwitcherSheet

/// Tap the name on the compass → choose who to point toward.
/// emoji + name + distance per row; selection swings the needle immediately.
struct PersonSwitcherSheet: View {

    @EnvironmentObject var people: PeopleManager
    @EnvironmentObject var compass: CompassManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            DesignTokens.Color.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Text("point toward…")
                        .font(.system(size: 15, design: .serif).italic())
                        .foregroundColor(DesignTokens.Color.textMuted)
                        .padding(.top, 22)
                        .padding(.bottom, 12)

                    ForEach(people.people) { person in
                        Button {
                            people.select(person)
                            compass.start(tracking: person)
                            HapticEngine.personSelected()
                            dismiss()
                        } label: {
                            HStack(spacing: 14) {
                                Text(person.emoji)
                                    .font(.system(size: 26))
                                Text(person.name)
                                    .font(.system(size: 17, weight: .medium, design: .serif))
                                    .foregroundColor(DesignTokens.Color.textPrimary)
                                Spacer()
                                if let distance = distanceText(for: person) {
                                    Text(distance)
                                        .font(.system(size: 12))
                                        .foregroundColor(DesignTokens.Color.textMuted)
                                        .monospacedDigit()
                                }
                                if people.selectedPerson?.id == person.id {
                                    Circle()
                                        .fill(Color(hex: "#c4a8d4"))
                                        .frame(width: 6, height: 6)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 13)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if person.id != people.people.last?.id {
                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 1)
                                .padding(.leading, 64)
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func distanceText(for person: Person) -> String? {
        guard let location = compass.userLocation else { return nil }
        let km = BearingCalculator.distanceKm(from: location.coordinate, to: person.coordinate)
        return BearingCalculator.formattedDistance(km)
    }
}

// MARK: - DirectionalArrivalView

/// DIRECTIONAL ARRIVAL — direction feels physical, requires nothing.
/// The emoji blooms in FROM the screen edge matching the sender's bearing
/// (north → top, east → right…), travels to center, and settles. Fully
/// received on arrival. Pointing toward them within 30 s replays the bloom
/// warmer — bonus magic, never a requirement.
struct DirectionalArrivalView: View {

    let ping: PingManager.ReceivedPing
    let onContinue: () -> Void

    @EnvironmentObject var compass: CompassManager

    @State private var arrived    = false   // edge → center travel + bloom
    @State private var named      = false
    @State private var breathing  = false
    @State private var hintShown  = false   // "turn toward them…" (3 s)
    @State private var replayGlow = false   // warmer second bloom
    @State private var mutualNote = false   // "pointing toward them ✦"
    @State private var replayArmed = true   // 30 s window
    @State private var replaying  = false

    private static let lavender = Color(hex: "#c4a8d4")
    private static let warm     = Color(hex: "#d4b08c")

    private var alignmentDiff: Double {
        let bearing = compass.state.bearingDegrees
        return min(bearing, 360 - bearing)
    }
    private var isAligned: Bool { alignmentDiff <= 15 }

    var body: some View {
        GeometryReader { geo in
            let rad   = compass.state.bearingDegrees * .pi / 180
            let reach = max(geo.size.width, geo.size.height) * 0.62
            let start = CGSize(width: CGFloat(sin(rad)) * reach,
                               height: -CGFloat(cos(rad)) * reach)

            ZStack {
                // Quiet veil
                Color.black.opacity(0.45).ignoresSafeArea()

                // Glow anchored at the sender's edge — warms on replay
                RadialGradient(
                    colors: [(replayGlow ? Self.warm : Self.lavender)
                                .opacity(replayGlow ? 0.36 : 0.28), .clear],
                    center: UnitPoint(x: 0.5 + 0.62 * sin(rad),
                                      y: 0.5 - 0.62 * cos(rad)),
                    startRadius: 10,
                    endRadius: 420
                )
                .ignoresSafeArea()

                VStack(spacing: 14) {
                    if named {
                        VStack(spacing: 3) {
                            Text("\(ping.fromName) sent you this")
                                .font(.system(size: 15, design: .serif).italic())
                                .foregroundColor(Self.lavender)
                            Text(PoeticTime.string(for: ping.timestamp))
                                .font(.system(size: 11))
                                .foregroundColor(DesignTokens.Color.textMuted)
                        }
                        .transition(.opacity)
                    }

                    // The bloom — travels in from the sender's edge,
                    // settles at center. Same easeOut, no bounce.
                    Text(ping.emoji)
                        .font(.system(size: 76))
                        .opacity(arrived ? 1 : 0.25)
                        .scaleEffect((arrived ? 1.0 : 0.35) * (breathing ? 1.03 : 1.0))
                        .offset(arrived ? .zero : start)
                        .shadow(color: (replayGlow ? Self.warm : Self.lavender).opacity(0.55),
                                radius: replayGlow ? 24 : 18)

                    if mutualNote {
                        Text("pointing toward them ✦")
                            .font(.system(size: 12, design: .serif).italic())
                            .foregroundColor(Self.warm)
                            .transition(.opacity)
                    } else if hintShown {
                        Text("turn toward them to feel it again")
                            .font(.system(size: 10, design: .serif).italic())
                            .foregroundColor(Self.lavender.opacity(0.75))
                            .transition(.opacity)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onContinue() }
            .onAppear { arrive() }
            .onChange(of: isAligned) { _, aligned in
                // Optional replay — bonus magic within the 30 s window
                if aligned && replayArmed && !replaying && arrived {
                    replayFromDirection()
                }
            }
        }
    }

    private func arrive() {
        HapticEngine.thoughtArrived()
        SoundEngine.shared.play(for: ping.emoji)
        withAnimation(.easeOut(duration: 1.2)) { arrived = true }
        withAnimation(.easeOut(duration: 0.6).delay(1.1)) { named = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                breathing = true
            }
            // The soft optional hint — fades after 3 s, no consequence
            withAnimation(.easeIn(duration: 0.5)) { hintShown = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.easeOut(duration: 0.8)) { hintShown = false }
            }
        }
        // Replay window closes after 30 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { replayArmed = false }
    }

    private func replayFromDirection() {
        replaying = true
        HapticEngine.thoughtArrived()
        SoundEngine.shared.play(for: ping.emoji)
        withAnimation(.easeIn(duration: 0.4)) {
            replayGlow = true
            mutualNote = true
        }
        // Pull back toward the edge and bloom in again
        breathing = false
        withAnimation(.easeIn(duration: 0.35)) { arrived = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeOut(duration: 1.0)) { arrived = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeOut(duration: 0.8)) {
                mutualNote = false
                replayGlow = false
            }
            replaying = false
        }
    }
}

// MARK: - RevealArrivalView (superseded by DirectionalArrivalView; kept)

/// DIRECTION REVEALS CONTENT — the compass IS the inbox.
/// A thought arrives: no emoji shown. The screen edge glows from the
/// sender's direction, "[name] sent you something". Physically turn the
/// phone toward them (within 15°) and the emoji blooms with its sound.
struct RevealArrivalView: View {

    let ping: PingManager.ReceivedPing
    let onRevealed: () -> Void
    let onContinue: () -> Void

    @EnvironmentObject var compass: CompassManager

    @State private var revealed  = false
    @State private var bloomed   = false
    @State private var named     = false
    @State private var breathing = false
    @State private var debugBypass = false

    private static let lavender = Color(hex: "#c4a8d4")

    private var alignmentDiff: Double {
        let bearing = compass.state.bearingDegrees
        return min(bearing, 360 - bearing)
    }
    private var isAligned: Bool { debugBypass || alignmentDiff <= 15 }

    var body: some View {
        ZStack {
            if !revealed {
                // ── Waiting: the pull. Edge glow + the invitation to turn ──
                let rad = compass.state.bearingDegrees * .pi / 180
                RadialGradient(
                    colors: [Self.lavender.opacity(0.28), .clear],
                    center: UnitPoint(x: 0.5 + 0.62 * sin(rad),
                                      y: 0.5 - 0.62 * cos(rad)),
                    startRadius: 10,
                    endRadius: 400
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

                VStack {
                    VStack(spacing: 4) {
                        Text("\(ping.fromName) sent you something")
                            .font(.system(size: 14, design: .serif).italic())
                            .foregroundColor(Self.lavender)
                        Text("turn toward them to feel it")
                            .font(.system(size: 11))
                            .foregroundColor(DesignTokens.Color.textMuted)
                        #if DEBUG
                        Button("⚙︎ reveal (sim)") { debugBypass = true }
                            .font(.system(size: 9))
                            .foregroundColor(DesignTokens.Color.textDim)
                        #endif
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(DesignTokens.Color.backgroundLift.opacity(0.92))
                            .overlay(Capsule().stroke(Self.lavender.opacity(0.4), lineWidth: 1))
                    )
                    .padding(.top, 84)
                    Spacer()
                }
            } else {
                // ── Revealed: the bloom ─────────────────────────────────────
                Color.black.opacity(0.45).ignoresSafeArea()
                RadialGradient(
                    colors: [Self.lavender.opacity(0.25), .clear],
                    center: .center, startRadius: 20, endRadius: 320
                )
                .ignoresSafeArea()

                VStack(spacing: 14) {
                    if named {
                        VStack(spacing: 3) {
                            Text("\(ping.fromName) sent you this")
                                .font(.system(size: 15, design: .serif).italic())
                                .foregroundColor(Self.lavender)
                            Text(PoeticTime.string(for: ping.timestamp))
                                .font(.system(size: 11))
                                .foregroundColor(DesignTokens.Color.textMuted)
                        }
                        .transition(.opacity)
                    }

                    Text(ping.emoji)
                        .font(.system(size: 76))
                        .opacity(bloomed ? 1 : 0)
                        .scaleEffect((bloomed ? 1.0 : 0.3) * (breathing ? 1.03 : 1.0))
                        .shadow(color: Self.lavender.opacity(0.5), radius: 18)
                        .onTapGesture { replayBloom() }

                    if named {
                        Text("tap to feel again")
                            .font(.system(size: 10))
                            .foregroundColor(DesignTokens.Color.textDim)
                            .transition(.opacity)
                    }
                }
                // Tap anywhere else → continue to the next thought
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { onContinue() }
                    .allowsHitTesting(true)
                    .zIndex(-1)
            }
        }
        .onAppear {
            HapticEngine.thoughtArrived()   // the directional pull
        }
        .onChange(of: isAligned) { _, aligned in
            if aligned && !revealed { reveal() }
        }
        .onAppear {
            // Already pointing at them when it arrives → instant bloom
            if isAligned { reveal() }
        }
    }

    private func reveal() {
        withAnimation(.easeOut(duration: 0.4)) { revealed = true }
        onRevealed()   // opened_at — felt at the moment of reveal
        playBloom()
    }

    private func playBloom() {
        SoundEngine.shared.play(for: ping.emoji)
        HapticEngine.thoughtArrived()
        withAnimation(.easeOut(duration: 1.2)) { bloomed = true }
        withAnimation(.easeOut(duration: 0.6).delay(1.0)) { named = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
    }

    private func replayBloom() {
        breathing = false
        bloomed   = false
        named     = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { playBloom() }
    }
}

// MARK: - ShareCardView

/// The shareable compass moment — skin-toned face, real bearing, the words.
struct ShareCardView: View {

    let personName: String
    let emoji: String
    let bearing: Double
    let distance: String
    let tagline: String

    var body: some View {
        VStack(spacing: 14) {
            Text("pointing toward")
                .font(.system(size: 10, weight: .medium))
                .kerning(2.2)
                .foregroundColor(Color(hex: "#7c6b8e"))
                .padding(.top, 26)

            Text(personName)
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundColor(Color(hex: "#e8e0f0"))

            // The face — ring, cardinal ticks, needle at the real bearing
            ZStack {
                Circle()
                    .stroke(Color(hex: "#3a3050"), lineWidth: 1.5)
                    .frame(width: 170, height: 170)
                Circle()
                    .fill(Color(hex: "#9b7fc0").opacity(0.10))
                    .frame(width: 170, height: 170)
                    .blur(radius: 12)
                ForEach(0..<4, id: \.self) { i in
                    Text(["N", "E", "S", "W"][i])
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color(hex: "#7c6b8e"))
                        .offset(y: -94)
                        .rotationEffect(.degrees(Double(i) * 90))
                }
                // The needle
                VStack(spacing: 0) {
                    Triangle()
                        .fill(Color(hex: "#c4a8d4"))
                        .frame(width: 13, height: 56)
                    Rectangle()
                        .fill(Color(hex: "#7c6b8e").opacity(0.6))
                        .frame(width: 2.5, height: 42)
                }
                .offset(y: -7)
                .rotationEffect(.degrees(bearing))
                .shadow(color: Color(hex: "#9b7fc0").opacity(0.7), radius: 8)
                Text(emoji)
                    .font(.system(size: 20))
                    .offset(y: 0)
            }
            .frame(width: 200, height: 200)

            Text(distance)
                .font(.system(size: 14, weight: .light))
                .foregroundColor(Color(hex: "#a89bb8"))
                .monospacedDigit()

            Text(tagline)
                .font(.system(size: 13, design: .serif).italic())
                .foregroundColor(Color(hex: "#c4a8d4"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Text("pointward.app")
                .font(.system(size: 9))
                .foregroundColor(Color(hex: "#5a4f6e"))
                .padding(.top, 6)
                .padding(.bottom, 22)
        }
        .frame(width: 320)
        .background(
            LinearGradient(colors: [Color(hex: "#16121f"), Color(hex: "#0d0d14")],
                           startPoint: .top, endPoint: .bottom)
        )
        .cornerRadius(24)
    }
}

// MARK: - CoreArrivalView (superseded by RevealArrivalView; kept)

/// CORE arrival — intimate, not loud. A single soft pulse, light blooming
/// from the edge of the screen in the sender's direction (like light through
/// a curtain), the emoji blooming gently at center, then the sender's name.
/// No particles. No bounce. Tap the emoji to feel it again; tap anywhere
/// else to continue.
struct CoreArrivalView: View {

    let ping: PingManager.ReceivedPing
    let incomingBearing: Double      // where they are, relative to us
    let onContinue: () -> Void

    @State private var bloomed   = false   // emoji bloom
    @State private var glow      = false   // directional edge light
    @State private var named     = false   // sender line
    @State private var breathing = false   // gentle rest state

    private static let lavender = Color(red: 196/255, green: 168/255, blue: 212/255)

    var body: some View {
        ZStack {
            // Quiet veil — the room dims, nothing shouts
            Color.black.opacity(0.45).ignoresSafeArea()

            // Directional glow from the sender's edge of the screen,
            // fading inward — warm lavender, light through a curtain
            let rad = incomingBearing * .pi / 180
            RadialGradient(
                colors: [Self.lavender.opacity(0.30), .clear],
                center: UnitPoint(x: 0.5 + 0.62 * sin(rad),
                                  y: 0.5 - 0.62 * cos(rad)),
                startRadius: 10,
                endRadius: 420
            )
            .ignoresSafeArea()
            .opacity(glow ? 1 : 0)

            VStack(spacing: 14) {
                // Sender — appears after the emoji settles
                if named {
                    VStack(spacing: 3) {
                        Text("\(ping.fromName) sent you something")
                            .font(.system(size: 15, design: .serif).italic())
                            .foregroundColor(Self.lavender)
                        Text(PoeticTime.string(for: ping.timestamp))
                            .font(.system(size: 11))
                            .foregroundColor(DesignTokens.Color.textMuted)
                    }
                    .transition(.opacity)
                }

                // The bloom — pure easeOut, no spring, no bounce
                Text(ping.emoji)
                    .font(.system(size: 76))
                    .opacity(bloomed ? 1 : 0)
                    .scaleEffect((bloomed ? 1.0 : 0.3) * (breathing ? 1.03 : 1.0))
                    .shadow(color: Self.lavender.opacity(0.5), radius: 18)
                    .onTapGesture { replay() }   // tap to feel again

                if named {
                    Text("tap to feel again")
                        .font(.system(size: 10))
                        .foregroundColor(DesignTokens.Color.textDim)
                        .transition(.opacity)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onContinue() }
        .onAppear { play() }
    }

    private func play() {
        HapticEngine.thoughtArrived()
        SoundEngine.shared.play(for: ping.emoji)

        withAnimation(.easeOut(duration: 1.2)) { bloomed = true }
        withAnimation(.easeOut(duration: 0.5)) { glow = true }
        withAnimation(.easeIn(duration: 1.0).delay(0.5)) { glow = false }
        withAnimation(.easeOut(duration: 0.6).delay(1.0)) { named = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
    }

    private func replay() {
        breathing = false
        bloomed   = false
        named     = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { play() }
    }
}

/// PRO arrival — the full dramatic shooting animation.
struct ThoughtArrivalView: View {

    let ping: PingManager.ReceivedPing
    let incomingBearing: Double          // where they are, relative to us
    let onFinished: () -> Void           // animation ran its course
    let onSkip: () -> Void               // user tapped through

    @State private var fly     = false   // edge → center travel
    @State private var settled = false   // the reveal

    private static let glow = Color(hex: "#9b7fc0")

    var body: some View {
        GeometryReader { geo in
            let rad   = incomingBearing * .pi / 180
            let reach = max(geo.size.width, geo.size.height) * 0.62
            let start = CGSize(width: CGFloat(sin(rad)) * reach,
                               height: -CGFloat(cos(rad)) * reach)

            ZStack {
                // Dim the world; let the thought own the screen
                Color.black.opacity(0.55).ignoresSafeArea()
                RadialGradient(
                    colors: [Self.glow.opacity(settled ? 0.30 : 0.12), .clear],
                    center: .center, startRadius: 20, endRadius: 320
                )
                .ignoresSafeArea()

                // Trail — smaller copies chasing in from their direction
                ForEach(0..<5, id: \.self) { i in
                    Text(ping.emoji)
                        .font(.system(size: 22))
                        .opacity(fly ? 0 : 0.75 - Double(i) * 0.13)
                        .offset(fly ? .zero : start)
                        .animation(.easeOut(duration: 1.2).delay(0.12 + Double(i) * 0.09), value: fly)
                }

                // The thought itself, flying in
                if !settled {
                    Text(ping.emoji)
                        .font(.system(size: 34))
                        .scaleEffect(fly ? 2.0 : 0.7)
                        .offset(fly ? .zero : start)
                        .animation(.easeOut(duration: 1.2), value: fly)
                        .shadow(color: Self.glow.opacity(0.8), radius: 14)
                }

                // The reveal — an event, not a footnote
                if settled {
                    VStack(spacing: 10) {
                        Text(ping.emoji)
                            .font(.system(size: 72))
                            .shadow(color: Self.glow.opacity(0.9), radius: 22)
                        Text("from \(ping.fromName)")
                            .font(.system(size: 27, weight: .semibold, design: .serif))
                            .foregroundColor(DesignTokens.Color.textPrimary)
                        Text(Self.relativeTime(ping.timestamp))
                            .font(.system(size: 13, design: .serif).italic())
                            .foregroundColor(DesignTokens.Color.textMuted)
                    }
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onSkip() }
            .onAppear {
                SoundEngine.shared.play(for: ping.emoji)
                HapticEngine.pingReceived()
                withAnimation { fly = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        settled = true
                    }
                    HapticEngine.connectionFelt()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
                    onFinished()
                }
            }
        }
    }

    static func relativeTime(_ date: Date) -> String {
        let interval = Date.now.timeIntervalSince(date)
        if interval < 90 { return "just now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

// MARK: - Preview

#Preview {
    CompassView()
        .environmentObject(ServiceContainer().compassManager)
        .environmentObject(ServiceContainer().peopleManager)
        .environmentObject(ServiceContainer().pingManager)
        .environmentObject(ServiceContainer().skinStore)
        .environmentObject(ServiceContainer().subscriptionManager)
        .environmentObject(ServiceContainer().appStateManager)
        .preferredColorScheme(.dark)
}
