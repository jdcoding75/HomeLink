// CompassView.swift
// HomeLink › Views
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

    @AppStorage("quietMode") private var quietMode = false

    // Lock moment — fires once per lock edge, resets when unlocked
    @State private var lockGlowActive = false
    @State private var emojiScaled    = false
    @State private var lockBadgeShown = false

    // Ping animation
    @State private var pingRingActive  = false
    @State private var pingOverlayVisible = false

    // Far-from-home
    @State private var farGlowActive = false

    // Tagline animation trigger
    @State private var taglineKey: UUID = UUID()

    var body: some View {
        ZStack {
            // ── Background ──────────────────────────────────────────────────
            backgroundLayer

            VStack(spacing: 0) {
                Spacer()

                // ── Person header ────────────────────────────────────────────
                personHeader
                    .padding(.bottom, 20)

                // ── Compass face ─────────────────────────────────────────────
                compassFace
                    .frame(width: 240, height: 240)

                // ── Lock badge ───────────────────────────────────────────────
                lockBadge
                    .padding(.top, 8)

                // ── Bearing readout ──────────────────────────────────────────
                bearingReadout
                    .padding(.top, 4)

                Spacer()
            }

            // ── Ping overlay (floats above everything) ───────────────────────
            if pingOverlayVisible, let ping = pings.pendingPing {
                PingOverlayView(ping: ping) {
                    dismissPingOverlay()
                }
                .transition(.scale(scale: 0.1).combined(with: .opacity))
            }
        }
        // ── Reactions to state changes ────────────────────────────────────────
        .onChange(of: compass.state.isLocked)        { _, locked in handleLock(locked) }
        .onChange(of: compass.state.isFarFromHome)   { _, far    in handleFar(far) }
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
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundLayer: some View {
        if compass.state.isFarFromHome && !quietMode {
            // Warm amber-brown tint when far from home
            Color(hex: "#1a0f0a")
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 1.2), value: compass.state.isFarFromHome)
        } else {
            DesignTokens.Color.background
                .ignoresSafeArea()
        }
    }

    // MARK: - Person header

    private var personHeader: some View {
        VStack(spacing: 4) {
            Text("pointing toward")
                .font(DesignTokens.Font.overline)
                .foregroundColor(DesignTokens.Color.textMuted)

            Text(compass.state.personName)
                .font(DesignTokens.Font.compassName)
                .foregroundColor(DesignTokens.Color.textPrimary)

            Text(compass.state.formattedDistance)
                .font(DesignTokens.Font.compassDistance)
                .foregroundColor(DesignTokens.Color.textSecondary)

            // Far-from-home label
            if compass.state.isFarFromHome {
                Text("far from home")
                    .font(DesignTokens.Font.caption)
                    .foregroundColor(Color(hex: "#c4845a"))
                    .transition(.opacity)
            }

            // Tagline — re-animates on person switch via id key
            Text(compass.state.resolvedTagline)
                .font(.system(size: 13).italic())
                .foregroundColor(DesignTokens.Color.accentMid)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.xl)
                .id(taglineKey)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.easeOut(duration: 0.4), value: taglineKey)
                .padding(.top, 2)
        }
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

            // Emoji presence system — always at center
            emojiPresence

            // Needle — shared geometry, skin-tinted colours
            NeedleView(
                bearing: compass.state.bearingDegrees,
                skin: compass.state.activeSkin,
                locked: compass.state.isLocked,
                quietMode: quietMode
            )

            // Pivot dot
            Circle()
                .fill(pivotColor)
                .frame(width: 10, height: 10)
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

            // Emoji — scales up on lock
            Text(compass.state.personEmoji)
                .font(.system(size: 28))
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
        compass.state.activeSkin == .aurora
            ? Color(hex: "#1D9E75")
            : DesignTokens.Color.accentMid
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

    private func handleFar(_ far: Bool) {
        withAnimation(.easeInOut(duration: 1.2)) {
            farGlowActive = far
        }
    }

    private func handlePersonChange() {
        // Re-trigger tagline fade animation
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
