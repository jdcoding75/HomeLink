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

struct CompassView: View {

    @EnvironmentObject var compass:  CompassManager
    @EnvironmentObject var people:   PeopleManager
    @EnvironmentObject var pings:    PingManager
    @EnvironmentObject var skinStore: SkinStore
    @EnvironmentObject var appEnv:   AppEnvironment

    @AppStorage("quietMode") private var quietMode = false

    // Lock moment — fires once per lock edge, resets when unlocked
    @State private var lockGlowActive = false
    @State private var emojiScaled    = false
    @State private var lockBadgeShown = false

    // Ping animation
    @State private var pingRingActive  = false
    @State private var pingOverlayVisible = false

    // Empty state
    @State private var showAddPerson = false

    // Tagline animation trigger
    @State private var taglineKey: UUID = UUID()

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

                    // ── Lock badge ───────────────────────────────────────────
                    lockBadge
                        .padding(.top, 2)

                    // ── Bearing readout ──────────────────────────────────────
                    bearingReadout

                    Spacer(minLength: 0)
                }
            }

            // ── Ping overlay (floats above everything) ───────────────────────
            if pingOverlayVisible, let ping = pings.pendingPing {
                PingOverlayView(ping: ping) {
                    dismissPingOverlay()
                }
                .transition(.scale(scale: 0.1).combined(with: .opacity))
            }

            // ── Pointing toast — quieter than a ping: just a compass whisper ──
            if let notice = pings.pointingNotice {
                VStack {
                    HStack(spacing: 7) {
                        Text("🧭").font(.system(size: 14))
                        Text(notice)
                            .font(.system(size: 13, design: .serif).italic())
                            .foregroundColor(DesignTokens.Color.textPrimary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(DesignTokens.Color.backgroundLift.opacity(0.95))
                            .overlay(Capsule().stroke(DesignTokens.Color.accentMid.opacity(0.5), lineWidth: 1))
                    )
                    .shadow(color: Color(hex: "#9b7fc0").opacity(0.3), radius: 10)
                    .padding(.top, 14)
                    Spacer()
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.45), value: pings.pointingNotice)
        // ── Reactions to state changes ────────────────────────────────────────
        .onChange(of: compass.state.isLocked)        { _, locked in handleLock(locked) }
        .onChange(of: compass.state.personID)        { _, _      in handlePersonChange() }
        .onChange(of: pings.pendingPing != nil)      { _, hasPing in handlePing(hasPing) }
        .onAppear {
            if let person = people.selectedPerson {
                compass.start(tracking: person)
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

            Text("your compass is waiting")
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
                Text("add your first person")
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
            Text(compass.state.personName)
                .font(.system(size: 30, weight: .semibold, design: .serif))
                .foregroundColor(DesignTokens.Color.textPrimary)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.35), value: compass.state.personName)

            // Functional data: clean sans, light, dot-separated with direction
            Text("\(compass.state.formattedDistance) · \(BearingCalculator.cardinalDirection(compass.state.bearingDegrees))")
                .font(.system(size: 15, weight: .light))
                .foregroundColor(DesignTokens.Color.textSecondary)
                .monospacedDigit()

            // Below the numbers, exactly one idea at a time:
            //   custom tagline → ONLY the tagline (it always takes priority)
            //   no tagline     → emotional distance (+ "far from home" if > 500 km)
            Group {
                if hasCustomTagline {
                    // Custom tagline — warm serif italic, fades out then in
                    // on person switch
                    Text(compass.state.resolvedTagline)
                        .font(.system(size: 15, design: .serif).italic())
                        .foregroundColor(DesignTokens.Color.accentMid)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignTokens.Spacing.xl)
                        .id(taglineKey)
                        .transition(.asymmetric(
                            insertion: .opacity.animation(.easeIn(duration: 0.4).delay(0.3)),
                            removal:   .opacity.animation(.easeOut(duration: 0.25))
                        ))
                } else {
                    VStack(spacing: 2) {
                        if compass.state.isFarFromHome {
                            Text("far from home")
                                .font(.system(size: 12, design: .serif).italic())
                                .foregroundColor(Color(hex: "#c4845a"))
                                .transition(.opacity)
                        }
                        Text(BearingCalculator.emotionalDistance(compass.state.distanceKm))
                            .font(.system(size: 13, design: .serif).italic())
                            .foregroundColor(DesignTokens.Color.textMuted)
                            .contentTransition(.opacity)
                    }
                    .transition(.opacity)
                }
            }
            .padding(.top, 2)
            .animation(.easeInOut(duration: 0.45), value: hasCustomTagline)
            .animation(.easeInOut(duration: 0.45), value: compass.state.isFarFromHome)
            .animation(.easeInOut(duration: 0.5), value: compass.state.distanceKm < 5)
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
        if locked {
            Task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                withAnimation { lockGlowActive = false }
            }
        }
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

    private func handlePing(_ hasPing: Bool) {
        if hasPing {
            withAnimation(AnimationSystem.pingGlow) { pingRingActive = true }
            withAnimation(AnimationSystem.pingBurst.delay(0.1)) { pingOverlayVisible = true }
        }
    }

    private func dismissPingOverlay() {
        // Read receipt — tell the sender their thought was felt
        if let remoteID = pings.pendingPing?.remoteID {
            Task { await SupabaseService.shared.markPingOpened(remoteID) }
        }
        withAnimation(AnimationSystem.softAppear) {
            pingOverlayVisible = false
            pingRingActive     = false
        }
        pings.clearPendingPing()
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
