// RocketInstrumentView.swift
// Pointward › Views
//
// INSTRUMENT 5 — ROCKET 🚀 (Pro). A dark atmospheric circle: a steel launch
// pad at the bottom, a classic rocket sitting on it, a vertical fuel gauge
// on the left, faint twinkling stars behind. Load an emoji into the porthole,
// then TAP THE ROCKET to pump fuel — five taps fills the tank, the engines
// roar, and within 15° of the person it blasts off (the full-screen blast-off
// itself lives in SenderAnimationView's .rocket style). Off-target it waits,
// fueled and ready, until you aim.

import SwiftUI
import Combine

struct RocketInstrumentView: View {

    let loadedToken: String?
    let loadedSymbol: AnyView?
    /// Resolved emoji for the loaded thought — drives the porthole glow hue.
    var loadedEmoji: String? = nil
    let bearingDegrees: Double
    let personName: String
    var personEmoji: String = "💜"
    /// Fired when a fully-fueled, aligned rocket launches.
    let onLaunch: () -> Void

    // ── Fuel + launch state ────────────────────────────────────────────────
    @State private var fuelSegments = 0          // 0…5
    @State private var shudder: CGFloat = 0       // ±px body shake
    @State private var breathe = false            // 0.98–1.02 idle breath
    @State private var flameFlicker = false       // engine flame wobble
    @State private var smokePuffs: [SmokePuff] = []
    @State private var showLaunchPrompt = false
    @State private var showMissHint = false
    @State private var showFuelHint = false       // "fuel the rocket"
    @State private var launched = false
    @State private var twinkle = false

    /// Drives the auto-launch check + idle flame flicker.
    private let tick = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private static let steel    = Color(hex: "#8a8a8a")
    private static let amber    = Color(hex: "#e08a3c")
    private static let orange   = Color(hex: "#e0622c")
    private static let lavender = Color(hex: "#c4a8d4")

    private var rad: Double { bearingDegrees * .pi / 180 }
    private var alignDiff: Double { BearingCalculator.alignmentError(relativeBearing: bearingDegrees) }
    private var aligned: Bool { BearingCalculator.isSendAligned(bearingDegrees) }   // ≤15°
    private var fueled: Bool { fuelSegments >= 5 }

    /// Steady stars, frozen at first appearance so they don't reroll.
    @State private var stars: [Star] = Star.scatter(count: 10)

    var body: some View {
        ZStack {
            // ── The dark atmospheric circle ──
            Circle()
                .fill(
                    RadialGradient(colors: [Color(hex: "#15111c"), Color(hex: "#0b0910")],
                                   center: .center, startRadius: 20, endRadius: 185)
                )
                .frame(width: 360, height: 360)
            Circle()
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
                .frame(width: 360, height: 360)

            // ── Stars — tiny dots twinkling gently ──
            ForEach(stars) { star in
                Circle()
                    .fill(Color.white)
                    .frame(width: star.size, height: star.size)
                    .opacity(twinkle ? star.brightHi : star.brightLo)
                    .offset(x: star.x, y: star.y)
                    .animation(AnimationSystem.easeInOutSine(star.period)
                                .repeatForever(autoreverses: true), value: twinkle)
            }
            .frame(width: 360, height: 360)

            // ── Where they are — marker on the rim (own hints below) ──
            DirectionIndicator(bearingDegrees: bearingDegrees,
                               personName: personName,
                               personEmoji: personEmoji,
                               ringRadius: 168,
                               showHint: false)

            // ── The fuel gauge — vertical, five segments, left side ──
            fuelGauge
                .offset(x: -150, y: 0)

            // ── Launch pad + rocket — rotated to face the bearing ──
            ZStack {
                launchPad
                rocket
            }
            .rotationEffect(.radians(rad))

            // ── Instructions ──
            VStack {
                Spacer()
                instruction
                    .padding(.bottom, 2)
            }
            .allowsHitTesting(false)
        }
        .frame(width: 370, height: 370)
        .animation(.easeOut(duration: 0.25), value: showMissHint)
        .animation(.easeOut(duration: 0.25), value: showLaunchPrompt)
        .onAppear {
            withAnimation(AnimationSystem.easeInOutSine(1.5)
                            .repeatForever(autoreverses: true)) {
                breathe = true
            }
            withAnimation(AnimationSystem.easeInOutSine(0.4)
                            .repeatForever(autoreverses: true)) {
                flameFlicker = true
            }
            twinkle = true
            refreshFuelHint()
        }
        .onChange(of: loadedToken) { _, _ in
            // Emoji changed (or cleared) → reset the tank, re-show the hint
            if !launched {
                withAnimation(.easeOut(duration: 0.3)) { fuelSegments = 0 }
                showLaunchPrompt = false
            }
            refreshFuelHint()
        }
        .onReceive(tick) { _ in autoLaunchCheck() }
    }

    // ── The vertical fuel gauge ─────────────────────────────────────────────

    private var fuelGauge: some View {
        VStack(spacing: 6) {
            Text("FUEL")
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .tracking(1.5)
                .foregroundColor(DesignTokens.Color.textMuted)

            VStack(spacing: 4) {
                // Top segment first (index 4) → bottom (index 0)
                ForEach((0..<5).reversed(), id: \.self) { i in
                    let filled = fuelSegments > i
                    RoundedRectangle(cornerRadius: 2)
                        .fill(filled
                              ? LinearGradient(colors: [Color(hex: "#FFD27a"), Self.amber],
                                               startPoint: .top, endPoint: .bottom)
                              : LinearGradient(colors: [Color(hex: "#1a1622"), Color(hex: "#1a1622")],
                                               startPoint: .top, endPoint: .bottom))
                        .frame(width: 12, height: 16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(filled ? Self.amber.opacity(0.8)
                                               : Color.white.opacity(0.10),
                                        lineWidth: 1)
                        )
                        .shadow(color: filled ? Self.amber.opacity(0.6) : .clear, radius: 5)
                        .animation(.easeOut(duration: 0.2), value: filled)
                }
            }
            .padding(5)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.black.opacity(0.30))
                    .overlay(RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1))
            )
        }
    }

    // ── The launch pad — steel platform, two struts, steam wisps ───────────

    private var launchPad: some View {
        ZStack {
            // Drifting steam wisps rising from the base
            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 6 + CGFloat(i % 2) * 3, height: 6 + CGFloat(i % 2) * 3)
                    .blur(radius: 3)
                    .offset(x: CGFloat(i - 2) * 11,
                            y: 118 - (flameFlicker ? 16 : 0) - CGFloat(i) * 6)
                    .opacity(flameFlicker ? 0.0 : 0.7)
                    .animation(AnimationSystem.easeInOutSine(2.2 + Double(i) * 0.3)
                                .repeatForever(autoreverses: false), value: flameFlicker)
            }

            // Support struts
            ForEach([-1.0, 1.0], id: \.self) { side in
                Rectangle()
                    .fill(Self.steel.opacity(0.7))
                    .frame(width: 3, height: 26)
                    .rotationEffect(.degrees(side > 0 ? 18 : -18))
                    .offset(x: CGFloat(side) * 26, y: 130)
            }

            // Platform
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(colors: [Color(hex: "#a4a4a4"), Self.steel, Color(hex: "#5e5e5e")],
                                   startPoint: .top, endPoint: .bottom)
                )
                .frame(width: 72, height: 10)
                .overlay(RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.black.opacity(0.25), lineWidth: 1))
                .offset(y: 122)
        }
    }

    // ── The rocket itself ───────────────────────────────────────────────────

    private var rocket: some View {
        ZStack {
            // Engine flames at the base — even at rest they barely flicker,
            // growing with fuel level
            rocketFlame
                .offset(y: 86)

            // Body silhouette
            RocketBodyShape()
                .fill(
                    LinearGradient(colors: [.white, Color(hex: "#dcdce4"), Color(hex: "#b8b8c2")],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .frame(width: 56, height: 150)
                .overlay(
                    // Nose cone — slightly darker cap
                    RocketNoseShape()
                        .fill(Color(hex: "#9a9aa6"))
                        .frame(width: 56, height: 150)
                )
                .overlay(
                    // Fins at the base
                    ZStack {
                        ForEach([-1.0, 1.0], id: \.self) { side in
                            RocketFinShape(mirrored: side > 0)
                                .fill(LinearGradient(colors: [Self.orange, Color(hex: "#b8431f")],
                                                     startPoint: .top, endPoint: .bottom))
                                .frame(width: 22, height: 34)
                                .offset(x: CGFloat(side) * 27, y: 56)
                        }
                    }
                )
                .overlay(porthole)
                .shadow(color: .black.opacity(0.35), radius: 6, y: 3)

            // The loaded emoji glows softly inside the porthole window
            if let loadedSymbol {
                loadedSymbol
                    .scaleEffect(0.9)
                    .shadow(color: EmojiHue.color(for: loadedEmoji ?? "💜")
                                .opacity(0.8), radius: 8)
                    .offset(y: -8)
            }
        }
        .frame(width: 110, height: 200)
        .scaleEffect(breathe ? 1.02 : 0.98)
        .offset(x: shudder)
        .contentShape(Rectangle())
        .onTapGesture { fuelTap() }
    }

    /// The porthole window — a small circle mid-body, glowing when loaded.
    private var porthole: some View {
        Circle()
            .fill(loadedToken != nil
                  ? EmojiHue.color(for: loadedEmoji ?? "💜").opacity(0.25)
                  : Color(hex: "#3a3550"))
            .frame(width: 22, height: 22)
            .overlay(Circle().stroke(Color(hex: "#6a6a76"), lineWidth: 2))
            .shadow(color: loadedToken != nil
                    ? EmojiHue.color(for: loadedEmoji ?? "💜").opacity(0.7) : .clear,
                    radius: 6)
            .offset(y: -8)
    }

    /// Engine flames — height + brightness scale with the fuel level, with
    /// a constant tiny flicker even at rest.
    private var rocketFlame: some View {
        let level = CGFloat(fuelSegments)
        let baseH: CGFloat = 6 + level * 11           // 6 → 61 px
        let flick: CGFloat = flameFlicker ? 1.12 : 0.9
        return ZStack {
            // Outer orange
            FlameShape()
                .fill(LinearGradient(colors: [Self.amber.opacity(0.9), Self.orange, .clear],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 22 + level * 2, height: baseH * flick)
                .blur(radius: 1.5)
            // Inner yellow-white core
            FlameShape()
                .fill(LinearGradient(colors: [.white, Color(hex: "#FFD27a"), .clear],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 11 + level, height: baseH * 0.62 * flick)
                .blur(radius: 0.5)
        }
        .opacity(fuelSegments == 0 ? 0.55 : 1.0)
    }

    // ── Instruction line ────────────────────────────────────────────────────

    @ViewBuilder
    private var instruction: some View {
        if showMissHint {
            Text("aim toward \(personName) first")
                .font(.system(size: 12, design: .serif).italic())
                .foregroundColor(Self.amber)
                .transition(.opacity)
        } else if showLaunchPrompt {
            Text("LAUNCH")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .tracking(3)
                .foregroundColor(Color(hex: "#FFD27a"))
                .shadow(color: Self.orange.opacity(0.8), radius: 8)
                .transition(.scale(scale: 0.7).combined(with: .opacity))
        } else if showFuelHint {
            Text("fuel the rocket")
                .font(.system(size: 12, design: .serif).italic())
                .foregroundColor(Self.lavender.opacity(0.85))
                .transition(.opacity)
        } else if loadedToken != nil {
            Text("tap to fuel · \(fuelSegments)/5")
                .font(.system(size: 12, design: .serif).italic())
                .foregroundColor(Self.lavender.opacity(0.7))
                .transition(.opacity)
        }
    }

    // ── Mechanic ────────────────────────────────────────────────────────────

    private func refreshFuelHint() {
        withAnimation(.easeOut(duration: 0.3)) {
            showFuelHint = loadedToken != nil && fuelSegments == 0
        }
    }

    /// One tap pumps a fuel segment. Each tap: flame burst, smoke puff, body
    /// shudder, mechanical click, and a haptic that strengthens with level.
    private func fuelTap() {
        guard loadedToken != nil else {
            // Nothing loaded — a gentle nudge toward choosing a feeling
            HapticEngine.personSelected()
            return
        }
        guard !fueled, !launched else { return }

        fuelSegments += 1
        withAnimation(.easeOut(duration: 0.2)) { showFuelHint = false }

        // Haptic — light (1–3) · medium (4) · heavy (5)
        HapticEngine.rocketFuel(segment: fuelSegments)
        // Sound — mechanical fuel pump click
        SoundEngine.shared.play(for: "rocket.fuel")

        // Body shudder — grows with fuel (±2px → ±6px)
        let amp: CGFloat = fuelSegments >= 5 ? 6 : fuelSegments >= 4 ? 4 : 2
        withAnimation(.spring(response: 0.12, dampingFraction: 0.25)) { shudder = amp }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { shudder = 0 }
        }

        // Smoke puff at the base
        spawnSmoke()

        if fueled { attemptLaunch() }
    }

    /// Full tank → check alignment. Aligned: prompt + auto-launch in 1 s.
    /// Off-target: keep the fuel, show the aim hint, wait for the turn.
    private func attemptLaunch() {
        if aligned {
            armLaunch()
        } else {
            withAnimation { showMissHint = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                withAnimation { showMissHint = false }
            }
        }
    }

    private func armLaunch() {
        guard !launched else { return }
        withAnimation { showLaunchPrompt = true; showMissHint = false }
        HapticEngine.rocketReady()
        // Auto-launch after a held beat
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard fueled, aligned, !launched else { return }
            launch()
        }
    }

    /// Re-checks alignment on the heartbeat — a rocket that filled while
    /// off-target launches the moment the user turns toward the person.
    private func autoLaunchCheck() {
        guard fueled, !launched else { return }
        if aligned && !showLaunchPrompt {
            armLaunch()
        } else if !aligned && showLaunchPrompt {
            withAnimation { showLaunchPrompt = false }
        }
    }

    private func launch() {
        launched = true
        withAnimation { showLaunchPrompt = false }
        // The full-screen blast-off + delivery is the .rocket sender style.
        onLaunch()
        // Reset for the next send once the takeover has cleared.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.6) {
            fuelSegments = 0
            launched = false
            shudder = 0
        }
    }

    private func spawnSmoke() {
        let puff = SmokePuff(x: CGFloat.random(in: -10...10))
        smokePuffs.append(puff)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            smokePuffs.removeAll { $0.id == puff.id }
        }
    }
}

// MARK: - Smoke puff model

private struct SmokePuff: Identifiable {
    let id = UUID()
    let x: CGFloat
}

// MARK: - Star model

private struct Star: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let brightLo: Double
    let brightHi: Double
    let period: Double

    /// Scatter N stars inside the circle (radius ~170), avoiding the center.
    static func scatter(count: Int) -> [Star] {
        (0..<count).map { i in
            let angle = Double(i) / Double(count) * 2 * .pi + Double(i) * 0.7
            let r = CGFloat(70 + (i * 37) % 95)
            return Star(
                x: CGFloat(cos(angle)) * r,
                y: CGFloat(sin(angle)) * r,
                size: CGFloat(1.5 + Double(i % 3) * 0.8),
                brightLo: 0.3,
                brightHi: 0.7,
                period: 1.4 + Double(i % 4) * 0.5
            )
        }
    }
}

// MARK: - Rocket shapes

/// The rocket silhouette — pointed nose cone tapering into a cylindrical
/// body with a softly rounded base. Drawn as one continuous path.
struct RocketBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let shoulderY = h * 0.26
        let baseY = h * 0.86
        p.move(to: CGPoint(x: w * 0.5, y: 0))
        // Right shoulder of the nose
        p.addQuadCurve(to: CGPoint(x: w * 0.86, y: shoulderY),
                       control: CGPoint(x: w * 0.80, y: h * 0.04))
        // Right body
        p.addLine(to: CGPoint(x: w * 0.86, y: baseY))
        // Rounded base
        p.addQuadCurve(to: CGPoint(x: w * 0.5, y: h),
                       control: CGPoint(x: w * 0.78, y: h))
        p.addQuadCurve(to: CGPoint(x: w * 0.14, y: baseY),
                       control: CGPoint(x: w * 0.22, y: h))
        // Left body
        p.addLine(to: CGPoint(x: w * 0.14, y: shoulderY))
        // Left shoulder of the nose
        p.addQuadCurve(to: CGPoint(x: w * 0.5, y: 0),
                       control: CGPoint(x: w * 0.20, y: h * 0.04))
        p.closeSubpath()
        return p
    }
}

/// Just the nose cone region — used as a darker cap overlay.
struct RocketNoseShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let shoulderY = h * 0.26
        p.move(to: CGPoint(x: w * 0.5, y: 0))
        p.addQuadCurve(to: CGPoint(x: w * 0.86, y: shoulderY),
                       control: CGPoint(x: w * 0.80, y: h * 0.04))
        p.addQuadCurve(to: CGPoint(x: w * 0.14, y: shoulderY),
                       control: CGPoint(x: w * 0.5, y: shoulderY * 0.55))
        p.addQuadCurve(to: CGPoint(x: w * 0.5, y: 0),
                       control: CGPoint(x: w * 0.20, y: h * 0.04))
        p.closeSubpath()
        return p
    }
}

/// A single tail fin — a swept triangle hugging the rocket's base.
struct RocketFinShape: Shape {
    var mirrored: Bool
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        if mirrored {
            p.move(to: CGPoint(x: 0, y: 0))
            p.addLine(to: CGPoint(x: w, y: h))
            p.addQuadCurve(to: CGPoint(x: 0, y: h * 0.7),
                           control: CGPoint(x: w * 0.4, y: h * 0.85))
        } else {
            p.move(to: CGPoint(x: w, y: 0))
            p.addLine(to: CGPoint(x: 0, y: h))
            p.addQuadCurve(to: CGPoint(x: w, y: h * 0.7),
                           control: CGPoint(x: w * 0.6, y: h * 0.85))
        }
        p.closeSubpath()
        return p
    }
}

/// A teardrop flame — wide rounded top, tapering to a point at the bottom.
struct FlameShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: w * 0.5, y: h))           // the point at the bottom
        p.addQuadCurve(to: CGPoint(x: 0, y: h * 0.32),
                       control: CGPoint(x: 0, y: h * 0.85))
        p.addQuadCurve(to: CGPoint(x: w * 0.5, y: 0),
                       control: CGPoint(x: w * 0.15, y: 0))
        p.addQuadCurve(to: CGPoint(x: w, y: h * 0.32),
                       control: CGPoint(x: w * 0.85, y: 0))
        p.addQuadCurve(to: CGPoint(x: w * 0.5, y: h),
                       control: CGPoint(x: w, y: h * 0.85))
        p.closeSubpath()
        return p
    }
}
