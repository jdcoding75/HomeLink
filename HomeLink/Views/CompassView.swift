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

struct CompassView: View {

    @EnvironmentObject var compass:  CompassManager
    @EnvironmentObject var people:   PeopleManager
    @EnvironmentObject var pings:    PingManager
    @EnvironmentObject var skinStore: SkinStore
    @EnvironmentObject var appEnv:   AppEnvironment

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
    @AppStorage(ExpressionMode.storageKey) private var expressiveOn = false

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
                    Spacer(minLength: 0)

                    // ── Person header ────────────────────────────────────────
                    personHeader
                        .padding(.bottom, 4)

                    // ── Compass face — the hero of the screen ────────────────
                    // Skins render at a fixed 240pt design size; scale the whole
                    // composition so every face grows together. 370pt — near
                    // edge-to-edge, matching the Send a Thought immersion.
                    compassFace
                        .frame(width: 240, height: 240)
                        .scaleEffect(370.0 / 240.0)
                        .frame(width: 370, height: 370)
                        // STEADY LOCK (5 s+): warm breathing halo behind the face
                        .background(
                            Circle()
                                .fill(Color(hex: "#c4845a").opacity(steadyLock ? (breathePulse ? 0.16 : 0.09) : 0))
                                .frame(width: 330, height: 330)
                                .scaleEffect(breathePulse ? 1.05 : 0.97)
                                .blur(radius: 42)
                                .allowsHitTesting(false)
                        )

                    // ── Lock badge ───────────────────────────────────────────
                    lockBadge
                        .padding(.top, 2)

                    // ── Bearing readout ──────────────────────────────────────
                    bearingReadout

                    Spacer(minLength: 0)
                }
            }

            // ── Thought queue badge — expressive mode only (core mode
            // reveals thoughts automatically through the compass itself) ──────
            if expressiveOn && !pings.queue.isEmpty && pings.nowPlaying == nil {
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

            // ── Arrival ───────────────────────────────────────────────────────
            // Core: direction reveals content — the edge glows from their
            // direction, and you must physically turn toward them to feel it.
            // Expressive: the immediate dramatic shooting animation.
            if let playing = pings.nowPlaying {
                if expressiveOn {
                    ThoughtArrivalView(
                        ping: playing,
                        incomingBearing: compass.state.bearingDegrees,
                        onFinished: { pings.finishedPlaying(playing) },
                        onSkip: { pings.skip(playing) }
                    )
                    .transition(.opacity)
                    .onAppear { pings.markOpened(playing) }
                } else {
                    RevealArrivalView(
                        ping: playing,
                        onRevealed: { pings.markOpened(playing) },
                        onContinue: { pings.skip(playing) }
                    )
                    .transition(.opacity)
                    .onAppear {
                        // Swing the needle to the sender so "turn toward
                        // them" means something
                        if let sender = people.people.first(where: { $0.name == playing.fromName }),
                           people.selectedPerson?.id != sender.id {
                            people.select(sender)
                            compass.start(tracking: sender)
                        }
                    }
                }
            }

            // ── Ambient presence — their needle is resting on us ──────────────
            if presenceGlowVisible {
                presenceGlow
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            // ── "✦ expressive" indicator — top right, tap → Settings ──────────
            if expressiveOn {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            NotificationCenter.default.post(name: .pointwardOpenSettings, object: nil)
                        } label: {
                            Text("✦ expressive")
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
                    Text("tap the words to change them")
                        .font(.system(size: 12, design: .serif).italic())
                        .foregroundColor(DesignTokens.Color.accentMid.opacity(0.8))
                        .padding(.bottom, 18)
                }
                .allowsHitTesting(false)
                .transition(.opacity)
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
        .onChange(of: compass.state.personID)        { _, _      in handlePersonChange() }
        .onChange(of: pings.queue.isEmpty)           { _, empty  in
            withAnimation(AnimationSystem.pingGlow) { pingRingActive = !empty }
        }
        .onAppear {
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

    private var personHeader: some View {
        VStack(spacing: 4) {
            // Warm Editorial: refined overline with generous tracking
            Text("pointing toward")
                .font(.system(size: 11, weight: .medium))
                .kerning(2.5)
                .foregroundColor(DesignTokens.Color.textMuted)

            // The name — a dedication in a book. Serif, larger, crossfades.
            // Tap to switch who you point toward (hidden with one person).
            HStack(spacing: 6) {
                Text(compass.state.personName)
                    .font(.system(size: 30, weight: .semibold, design: .serif))
                    .foregroundColor(DesignTokens.Color.textPrimary)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.35), value: compass.state.personName)
                if people.people.count > 1 {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
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

            // CORE distance: one clean muted line — "88 mi · 142 km"
            Text(compass.state.formattedDistance)
                .font(.system(size: 15, weight: .light))
                .foregroundColor(DesignTokens.Color.textSecondary)
                .monospacedDigit()

            // EXPRESSIVE: the distance playground — random unit per launch,
            // tap cycles through all seven (hidden in core mode)
            if expressiveOn {
                HStack(spacing: 5) {
                    Text(DistanceFun.funnyText(km: compass.state.distanceKm, index: funnyIndex))
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Color.textMuted)
                        .contentTransition(.opacity)
                    Text("✦")
                        .font(.system(size: 7))
                        .foregroundColor(DesignTokens.Color.textDim.opacity(0.7))
                }
                .onTapGesture {
                    HapticEngine.personSelected()
                    withAnimation(.easeInOut(duration: 0.25)) {
                        funnyIndex = (funnyIndex + 1) % DistanceFun.funnyCount
                    }
                }
            }

            // (Light-speed line retired from core — kept for possible return:)
            // if showLightSpeed {
            //     Text(DistanceFun.lightSpeedText(km: compass.state.distanceKm))
            //         .font(.system(size: 11))
            //         .foregroundColor(DesignTokens.Color.textDim)
            //         .monospacedDigit()
            //         .onTapGesture { withAnimation { showLightSpeed = false } }
            // }

            // The ONE tagline — the emotional anchor. Tap to cycle through
            // the library with a crossfade; never repeats until all shown.
            HStack(spacing: 5) {
                Text(TaglineSystem.poeticLibrary[taglineIndex])
                    .font(.system(size: 13, design: .serif).italic())
                    .foregroundColor(DesignTokens.Color.accentMid)
                Text("✦")
                    .font(.system(size: 8))
                    .foregroundColor(DesignTokens.Color.accentMid.opacity(0.55))
            }
            .padding(.top, 1)
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

            // ONE tagline only — the per-person custom tagline line is
            // retired from this screen (kept below for reference).
            // Group {
            //     if hasCustomTagline {
            //         Text(compass.state.resolvedTagline)
            //             .font(.system(size: 15, design: .serif).italic())
            //             .foregroundColor(DesignTokens.Color.accentMid)
            //             .multilineTextAlignment(.center)
            //             .padding(.horizontal, DesignTokens.Spacing.xl)
            //             .id(taglineKey)
            //     } else
            if compass.state.isFarFromHome {
                Text("across the distance")
                    .font(.system(size: 12, design: .serif).italic())
                    .foregroundColor(Color(hex: "#c4845a"))
                    .transition(.opacity)
                    .padding(.top, 2)
                    .animation(.easeInOut(duration: 0.45), value: compass.state.isFarFromHome)
            }
        }
    }

    /// True only when the person has their own tagline — skin defaults don't count.
    private var hasCustomTagline: Bool {
        guard let t = compass.state.tagline else { return false }
        return !t.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Compass face

    private var compassFace: some View {
        ZStack {
            // Skin-specific rings and decorations
            SkinFaceView(
                skin: compass.state.activeSkin,
                bearing: compass.state.bearingDegrees,
                locked: compass.state.isLocked,
                quietMode: quietMode,
                pingRingActive: pingRingActive
            )

            // Subtle fixed cardinal markers at the rim — orientation reference
            // while the needle moves (just inside the breathing ring)
            ForEach(0..<4, id: \.self) { i in
                let rad = Double(i) * 90 * .pi / 180
                Text(["N", "E", "S", "W"][i])
                    .font(.system(size: 9, weight: i == 0 ? .semibold : .regular, design: .rounded))
                    .foregroundColor(i == 0
                                     ? DesignTokens.Color.accentSoft.opacity(0.9)
                                     : DesignTokens.Color.textDim.opacity(0.7))
                    .offset(x: CGFloat(sin(rad)) * 113, y: -CGFloat(cos(rad)) * 113)
            }

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
    /// Posted by the "✦ expressive" badge — MainTabView jumps to Settings.
    static let pointwardOpenSettings = Notification.Name("pointwardOpenSettings")
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

// MARK: - RevealArrivalView

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

/// EXPRESSIVE arrival — the full dramatic shooting animation.
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
        .preferredColorScheme(.dark)
}
