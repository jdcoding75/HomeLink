// PlaneInstrumentView.swift
// Pointward › Views
//
// INSTRUMENT (COMING SOON) — RUBBER BAND PLANE ✈️. A classic balsa-wood toy
// plane at the heart of the circle: elongated fuselage, swept-back wings, a
// classic tail, a two-blade propeller, and a twisted rubber band slung under
// the belly. WIND the propeller with a finger-spin (eight winds to max), the
// rubber band twists tighter and the plane begins to shudder, and at full
// tension it LAUNCHES toward the person — banking gently, leaving a spiral
// wake. The most charming send in the app.
//
// [5/6] Shipped as a Coming-Soon placeholder: the main visual + winding
// mechanic are real and demonstrable (PlaneInstrumentView), and a looping
// preview (PlaneLaunchPreview) advertises it on the instrument card. The
// full send/receive story is wired when the plane graduates from teaser.

import SwiftUI
import Combine

struct PlaneInstrumentView: View {

    let loadedToken: String?
    let loadedSymbol: AnyView?
    var loadedEmoji: String? = nil
    let bearingDegrees: Double
    let personName: String
    var personEmoji: String = "💜"
    /// Fired when a fully-wound plane launches (no-op while Coming Soon).
    var onLaunch: () -> Void = {}

    // ── Winding state ──────────────────────────────────────────────────────
    @State private var winds: Int = 0            // 0…8 tension
    @State private var windAngle: Double = 0     // accumulated spin (degrees)
    @State private var windBase: Double = 0
    @State private var propSpin: Double = 0      // propeller rotation
    @State private var shudder: CGFloat = 0      // ±px at high tension
    @State private var launching = false
    @State private var liftoff: CGFloat = 0      // 0…1 launch travel
    @State private var bankPhase: Double = 0     // gentle left/right roll
    @State private var showRelease = false

    private let tick = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    private static let balsa     = Color(hex: "#DEB887")
    private static let balsaDark = Color(hex: "#C19A6B")
    private static let rubber    = Color(hex: "#3a1a0a")
    private static let lavender  = Color(hex: "#c4a8d4")

    static let maxWinds = 8

    private var rad: Double { bearingDegrees * .pi / 180 }
    private var tension: Double { Double(winds) / Double(Self.maxWinds) }
    private var maxed: Bool { winds >= Self.maxWinds }

    var body: some View {
        ZStack {
            // ── Dark sky circle ──
            Circle()
                .fill(RadialGradient(colors: [Color(hex: "#14161f"), Color(hex: "#0b0d12")],
                                     center: .center, startRadius: 30, endRadius: 185))
                .overlay(Circle().stroke(Color.white.opacity(0.06), lineWidth: 1))
                .frame(width: 360, height: 360)

            // ── Where they are — person-initial marker on the ring ──
            DirectionIndicator(bearingDegrees: bearingDegrees,
                               personName: personName,
                               personEmoji: personEmoji,
                               ringRadius: 168,
                               showHint: false)

            // ── Tension gauge — twist indicator on the left ──
            tensionGauge.offset(x: -150, y: 0)

            // ── The plane — banks slightly as it climbs on launch ──
            plane
                .rotationEffect(.radians(rad))               // nose toward person
                .rotationEffect(.degrees(launching ? sin(bankPhase) * 8 : 0))
                .offset(x: launching ? CGFloat(sin(rad)) * liftoff * 220 : shudder,
                        y: launching ? -CGFloat(cos(rad)) * liftoff * 220 : 0)
                .scaleEffect(launching ? 1.0 + liftoff * 0.3 - liftoff * liftoff * 1.0 : 1.0)
                .opacity(launching ? Double(1 - liftoff * 0.9) : 1)

            // ── Instruction ──
            VStack {
                Spacer()
                instruction
                    .padding(.bottom, 2)
            }
            .allowsHitTesting(false)
        }
        .frame(width: 370, height: 370)
        .contentShape(Circle())
        .gesture(windGesture)
        .onReceive(tick) { _ in heartbeat() }
    }

    // ── The plane drawing ───────────────────────────────────────────────────

    private var plane: some View {
        ZStack {
            // Rubber band under the belly — twists tighter with tension
            RubberBandShape(twist: tension)
                .stroke(Self.rubber, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 14, height: 96)
                .offset(x: 6)

            // Horizontal stabilizer (tail)
            TailHStabShape()
                .fill(Self.balsaDark)
                .frame(width: 38, height: 16)
                .offset(y: 64)
            // Vertical stabilizer
            TailVStabShape()
                .fill(Self.balsa)
                .frame(width: 16, height: 24)
                .offset(y: 58)

            // Wings — swept back, darker tips
            WingShape(mirrored: false)
                .fill(LinearGradient(colors: [Self.balsa, Self.balsaDark],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 78, height: 26)
                .offset(x: -2, y: -4)

            // Fuselage — elongated oval body with grain
            FuselageShape()
                .fill(LinearGradient(colors: [Self.balsa, Self.balsaDark],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 22, height: 150)
                .overlay(
                    VStack(spacing: 7) {
                        ForEach(0..<6, id: \.self) { _ in
                            Capsule().fill(Self.balsaDark.opacity(0.4))
                                .frame(width: 12, height: 0.8)
                        }
                    }
                )
                // The loaded thought rides in a little window
                .overlay {
                    if let loadedSymbol {
                        loadedSymbol.scaleEffect(0.5).offset(y: -6)
                    }
                }

            // Propeller at the nose — two blades, blurs at high speed
            propeller
                .offset(y: -80)
        }
        .frame(width: 110, height: 200)
    }

    private var propeller: some View {
        ZStack {
            // Hub
            Circle().fill(Self.rubber).frame(width: 6, height: 6)
            // Two blades
            ForEach(0..<2, id: \.self) { i in
                Capsule()
                    .fill(LinearGradient(colors: [Self.balsaDark, Self.balsa],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 4, height: 34)
                    .rotationEffect(.degrees(Double(i) * 90))
            }
        }
        .rotationEffect(.degrees(propSpin))
        // The faster it spins the more it blurs into a disc
        .blur(radius: maxed ? 2.0 : (winds >= 6 ? 1.0 : 0))
        .overlay(
            Circle()
                .stroke(Self.balsa.opacity(maxed ? 0.25 : 0), lineWidth: 1)
                .frame(width: 36, height: 36)
        )
    }

    // ── Tension gauge ────────────────────────────────────────────────────────

    private var tensionGauge: some View {
        VStack(spacing: 6) {
            Text("WIND")
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .tracking(1.5)
                .foregroundColor(DesignTokens.Color.textMuted)
            VStack(spacing: 3) {
                ForEach((0..<Self.maxWinds).reversed(), id: \.self) { i in
                    let filled = winds > i
                    RoundedRectangle(cornerRadius: 2)
                        .fill(filled
                              ? AnyShapeStyle(LinearGradient(colors: [Self.balsa, Self.balsaDark],
                                                             startPoint: .top, endPoint: .bottom))
                              : AnyShapeStyle(Color(hex: "#1a1622")))
                        .frame(width: 10, height: 9)
                        .overlay(RoundedRectangle(cornerRadius: 2)
                            .stroke(filled ? Self.balsa.opacity(0.8) : Color.white.opacity(0.1),
                                    lineWidth: 1))
                        .animation(.easeOut(duration: 0.18), value: filled)
                }
            }
            .padding(5)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.black.opacity(0.3)))
        }
    }

    @ViewBuilder
    private var instruction: some View {
        if showRelease {
            Text("RELEASE")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .tracking(3)
                .foregroundColor(Self.balsa)
                .shadow(color: Self.balsa.opacity(0.7), radius: 8)
                .transition(.scale(scale: 0.7).combined(with: .opacity))
        } else if loadedToken != nil {
            Text("wind the propeller · \(winds)/\(Self.maxWinds)")
                .font(.system(size: 12, design: .serif).italic())
                .foregroundColor(Self.lavender.opacity(0.8))
        } else {
            Text("a thought, then wind it up ✈️")
                .font(.system(size: 12, design: .serif).italic())
                .foregroundColor(Self.lavender.opacity(0.7))
        }
    }

    // ── Winding mechanic ─────────────────────────────────────────────────────

    /// Spin the propeller area to wind. Each full turn adds a wind (to 8).
    private var windGesture: some Gesture {
        RotationGesture()
            .onChanged { angle in
                guard !launching else { return }
                let total = windBase + angle.degrees
                let newWinds = min(Self.maxWinds, max(0, Int(total / 360)))
                if newWinds != winds {
                    winds = newWinds
                    SoundEngine.shared.play(for: "plane.wind")
                    HapticEngine.rocketFuel(segment: winds)   // click strengthens
                }
                windAngle = total
            }
            .onEnded { _ in
                windBase = Double(winds) * 360   // snap the base to the wind count
                if maxed { armLaunch() }
            }
    }

    private func armLaunch() {
        guard !launching, !showRelease else { return }
        withAnimation { showRelease = true }
        HapticEngine.rocketReady()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if maxed && !launching { launch() }
        }
    }

    private func launch() {
        launching = true
        withAnimation { showRelease = false }
        SoundEngine.shared.play(for: "rocket.blast")
        HapticEngine.rocketLaunch()
        withAnimation(.easeIn(duration: 2.0)) { liftoff = 1 }
        onLaunch()
        // Reset for the next wind once the takeover clears.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            winds = 0; windBase = 0; windAngle = 0
            launching = false; liftoff = 0; shudder = 0
        }
    }

    /// 30 Hz: spin the prop at a speed set by tension, shudder near max.
    private func heartbeat() {
        let speed = launching ? 60.0 : (2.0 + Double(winds) * 5.0)   // idle → fast
        propSpin += speed
        bankPhase += 0.15

        guard !launching else { return }
        // Shudder ±2 px at max tension
        if maxed {
            shudder = CGFloat.random(in: -2...2)
        } else if shudder != 0 {
            shudder = 0
        }
    }
}

// ════════════════════════════════════════════════════════════════════════
// MARK: - Plane shapes
// ════════════════════════════════════════════════════════════════════════

/// An elongated fuselage — a long rounded oval, nose up.
struct FuselageShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(roundedRect: rect, cornerRadius: rect.width / 2)
    }
}

/// A swept-back wing pair drawn as one shape spanning the fuselage.
struct WingShape: Shape {
    var mirrored: Bool
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        // Left wing
        p.move(to: CGPoint(x: w * 0.5, y: 0))
        p.addLine(to: CGPoint(x: 0, y: h))                 // swept back tip
        p.addLine(to: CGPoint(x: w * 0.12, y: h))
        p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.35))
        // Right wing
        p.addLine(to: CGPoint(x: w * 0.88, y: h))
        p.addLine(to: CGPoint(x: w, y: h))
        p.addLine(to: CGPoint(x: w * 0.5, y: 0))
        p.closeSubpath()
        return p
    }
}

/// Horizontal stabilizer — a small swept tailplane.
struct TailHStabShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: w * 0.5, y: 0))
        p.addLine(to: CGPoint(x: 0, y: h))
        p.addLine(to: CGPoint(x: w, y: h))
        p.closeSubpath()
        return p
    }
}

/// Vertical stabilizer — the classic angled fin.
struct TailVStabShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: w * 0.5, y: 0))
        p.addLine(to: CGPoint(x: w, y: h))
        p.addLine(to: CGPoint(x: 0, y: h))
        p.closeSubpath()
        return p
    }
}

/// The rubber band slung under the belly — a double strand that twists into
/// a tighter braid as `twist` (0…1) grows.
struct RubberBandShape: Shape {
    var twist: Double
    var animatableData: Double {
        get { twist }
        set { twist = newValue }
    }
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let crossings = 1 + twist * 7           // 1 → 8 twists
        let steps = 60
        for strand in 0..<2 {
            for s in 0...steps {
                let t = Double(s) / Double(steps)
                let y = h * CGFloat(t)
                let phase = t * crossings * 2 * .pi + Double(strand) * .pi
                let amp = w * 0.5 * (1 - twist * 0.4)   // braid tightens
                let x = w * 0.5 + CGFloat(sin(phase)) * amp
                let pt = CGPoint(x: x, y: y)
                if s == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
        }
        return p
    }
}

// ════════════════════════════════════════════════════════════════════════
// MARK: - PlaneLaunchPreview — the looping card animation
// ════════════════════════════════════════════════════════════════════════

/// A tiny balsa plane that winds, shudders, and launches across the card,
/// looping every ~4 s. Used by the Coming-Soon instrument card.
struct PlaneLaunchPreview: View {
    @State private var propSpin: Double = 0
    @State private var winding = false
    @State private var fly: CGFloat = 0

    private static let balsa     = Color(hex: "#DEB887")
    private static let balsaDark = Color(hex: "#C19A6B")

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                // Fuselage
                Capsule().fill(Self.balsa)
                    .frame(width: w * 0.10, height: h * 0.42)
                // Wings
                Capsule().fill(Self.balsaDark)
                    .frame(width: w * 0.42, height: h * 0.07)
                    .offset(y: -h * 0.02)
                // Tail
                Capsule().fill(Self.balsaDark)
                    .frame(width: w * 0.16, height: h * 0.05)
                    .offset(y: h * 0.17)
                // Propeller
                ForEach(0..<2, id: \.self) { i in
                    Capsule().fill(Self.balsa)
                        .frame(width: w * 0.02, height: h * 0.16)
                        .rotationEffect(.degrees(Double(i) * 90 + propSpin))
                }
                .offset(y: -h * 0.22)
                .blur(radius: winding ? 1 : 0)
            }
            .rotationEffect(.degrees(-35))   // climbing pose
            .offset(x: fly * w * 0.5, y: -fly * h * 0.5)
            .opacity(1 - Double(fly) * 0.85)
            .position(x: w * 0.4, y: h * 0.6)
        }
        .onAppear { loop() }
    }

    private func loop() {
        var snap = Transaction(); snap.disablesAnimations = true
        withTransaction(snap) { fly = 0; winding = true }
        withAnimation(.linear(duration: 1.6)) { propSpin += 360 * 4 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.linear(duration: 0.5)) { propSpin += 360 * 6 }
            withAnimation(.easeIn(duration: 0.9)) { fly = 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { loop() }
    }
}
