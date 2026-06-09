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
    @State private var propSpin: Double = 0      // propeller rotation
    @State private var propBoost: Double = 0     // transient whir on each tap
    @State private var shudder: CGFloat = 0      // ±px at high tension
    @State private var launching = false
    @State private var liftoff: CGFloat = 0      // 0…1 launch travel
    @State private var bankPhase: Double = 0     // gentle left/right roll
    @State private var showRelease = false
    // [1/5] CIRCULAR SWIRL — track the finger's accumulated rotation around the
    // propeller centre; each full 360° = one wind, four to full.
    @State private var totalRotation: Double = 0
    @State private var lastAngle: Double? = nil

    private let tick = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    // [6/7] Bright toy palette — cheerful, chunky, kid-friendly.
    private static let bodyRed   = Color(hex: "#CC2200")
    private static let bodyHi    = Color(hex: "#FF5533")
    private static let wingYellow = Color(hex: "#FFD700")
    private static let wingHi     = Color(hex: "#FFE869")
    private static let propGrey   = Color(hex: "#4a4a4a")
    private static let propHi     = Color(hex: "#7a7a7a")
    private static let rubber    = Color(hex: "#3a1a0a")
    private static let lavender  = Color(hex: "#c4a8d4")

    static let maxWinds = 4          // [1/5] four full finger-circles to full

    private var rad: Double { bearingDegrees * .pi / 180 }
    /// [1/5] Continuous twist straight from the accumulated swirl — the rubber
    /// band tightens smoothly as the finger circles, not in discrete steps.
    private var tension: Double { min(1, abs(totalRotation) / (360 * Double(Self.maxWinds))) }
    private var maxed: Bool { winds >= Self.maxWinds }

    var body: some View {
        ZStack {
            // ── Bright cheerful sky circle ──
            Circle()
                .fill(RadialGradient(colors: [Color(hex: "#aee0ff"), Color(hex: "#7cc0ec")],
                                     center: .center, startRadius: 30, endRadius: 185))
                .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1.5))
                .frame(width: 360, height: 360)

            // ── Where they are — person-initial marker on the ring ──
            DirectionIndicator(bearingDegrees: bearingDegrees,
                               personName: personName,
                               personEmoji: personEmoji,
                               ringRadius: 168,
                               showHint: false)

            // ── Tension gauge — twist indicator on the left ──
            tensionGauge.offset(x: -150, y: 0)

            // ── The toy plane — banks slightly as it climbs on launch ──
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
        // [1/5] SWIRL your finger in circles to wind the propeller — each full
        // 360° loop twists the band one more turn (four to full), then it lets
        // fly toward the person on its own.
        .contentShape(Circle())
        .gesture(swirlGesture)
        .onReceive(tick) { _ in heartbeat() }
    }

    // ── The toy plane drawing ───────────────────────────────────────────────

    private var plane: some View {
        ZStack {
            // Rubber band under the belly — twists tighter with tension
            RubberBandShape(twist: tension)
                .stroke(Self.rubber, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .frame(width: 16, height: 86)
                .offset(x: 7, y: 6)

            // Tail — bright yellow fin + stubby stabilizer
            TailVStabShape()
                .fill(Self.wingYellow)
                .frame(width: 20, height: 26)
                .offset(y: 56)
            TailHStabShape()
                .fill(LinearGradient(colors: [Self.wingHi, Self.wingYellow],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 44, height: 16)
                .offset(y: 62)

            // Stubby wings — short, wide, bright yellow, rounded
            Capsule()
                .fill(LinearGradient(colors: [Self.wingHi, Self.wingYellow],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 104, height: 20)
                .overlay(Capsule().stroke(.white.opacity(0.35), lineWidth: 1))
                .offset(y: 2)
                .shadow(color: .black.opacity(0.15), radius: 3, y: 2)

            // Chubby fuselage — fat red capsule
            Capsule()
                .fill(LinearGradient(colors: [Self.bodyHi, Self.bodyRed],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 40, height: 124)
                .overlay(
                    // Cockpit window with the emoji
                    Circle()
                        .fill(Color(hex: "#bfe8ff"))
                        .frame(width: 26, height: 26)
                        .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 1.5))
                        .overlay {
                            if let loadedSymbol { loadedSymbol.scaleEffect(0.55) }
                        }
                        .offset(y: -16)
                )
                .shadow(color: .black.opacity(0.2), radius: 5, y: 3)

            // Big round nose — a chunky red ball with a highlight
            Circle()
                .fill(RadialGradient(colors: [Self.bodyHi, Self.bodyRed],
                                     center: UnitPoint(x: 0.35, y: 0.3),
                                     startRadius: 2, endRadius: 26))
                .frame(width: 38, height: 38)
                .offset(y: -58)

            // Big propeller at the nose
            propeller.offset(y: -64)
        }
        .frame(width: 120, height: 190)
    }

    /// A BIG two-blade propeller, dark grey, that whirs faster as it's wound.
    private var propeller: some View {
        ZStack {
            ForEach(0..<2, id: \.self) { i in
                Capsule()
                    .fill(LinearGradient(colors: [Self.propHi, Self.propGrey],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 7, height: 52)
                    .rotationEffect(.degrees(Double(i) * 90))
            }
            Circle().fill(Self.propGrey).frame(width: 10, height: 10)   // hub
        }
        .rotationEffect(.degrees(propSpin))
        .blur(radius: maxed ? 2.5 : (winds >= 6 ? 1.2 : 0))
        .overlay(
            Circle().stroke(Self.propGrey.opacity(maxed ? 0.3 : 0), lineWidth: 1.5)
                .frame(width: 54, height: 54)
        )
    }

    // ── Wind gauge ─────────────────────────────────────────────────────────

    private var tensionGauge: some View {
        VStack(spacing: 6) {
            Text("WIND")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundColor(Color(hex: "#2c4a5e"))
            VStack(spacing: 3) {
                ForEach((0..<Self.maxWinds).reversed(), id: \.self) { i in
                    let filled = winds > i
                    RoundedRectangle(cornerRadius: 2)
                        .fill(filled
                              ? AnyShapeStyle(LinearGradient(colors: [Self.wingHi, Self.wingYellow],
                                                             startPoint: .top, endPoint: .bottom))
                              : AnyShapeStyle(Color.white.opacity(0.35)))
                        .frame(width: 11, height: 9)
                        .overlay(RoundedRectangle(cornerRadius: 2)
                            .stroke(filled ? Self.bodyRed.opacity(0.6) : Color.white.opacity(0.5),
                                    lineWidth: 1))
                        .animation(.easeOut(duration: 0.18), value: filled)
                }
            }
            .padding(5)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.25)))
        }
    }

    @ViewBuilder
    private var instruction: some View {
        // [7/7] bold, large, step-by-step.
        if showRelease {
            Text("LET FLY ✈️")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .tracking(2)
                .foregroundColor(Self.bodyRed)
                .shadow(color: .white.opacity(0.7), radius: 8)
                .transition(.scale(scale: 0.7).combined(with: .opacity))
        } else {
            Text(stepText)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#2c4a5e"))
                .minimumScaleFactor(0.7).lineLimit(1)
                .shadow(color: .white.opacity(0.6), radius: 4)
        }
    }

    /// [1/5] "swirl to wind · let fly" — the plane auto-aims, so no aim step.
    private var stepText: String {
        if loadedToken == nil { return "load · swirl · let fly" }
        if maxed { return "let fly ✦" }
        return "swirl to wind · let fly · \(winds)/\(Self.maxWinds)"
    }

    // ── [1/5] Circular-swirl winding ─────────────────────────────────────────

    /// The finger's angle around the propeller centre (frame is 370 → centre
    /// (185,185)). 0° = up, clockwise positive.
    private func angleFromCenter(_ p: CGPoint) -> Double {
        atan2(Double(p.x - 185), -Double(p.y - 185)) * 180 / .pi
    }

    private var swirlGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard loadedToken != nil, !launching, !maxed else {
                    if loadedToken == nil { HapticEngine.personSelected() }
                    return
                }
                let angle = angleFromCenter(value.location)
                if let last = lastAngle {
                    var delta = angle - last
                    if delta > 180 { delta -= 360 }
                    if delta < -180 { delta += 360 }
                    totalRotation += delta
                    propSpin += delta * 1.6              // the prop follows the finger
                    let newWinds = min(Self.maxWinds, Int(abs(totalRotation) / 360))
                    if newWinds > winds {
                        winds = newWinds
                        circleCompleted(winds)
                    }
                }
                lastAngle = angle
            }
            .onEnded { _ in
                lastAngle = nil
                if maxed { armLaunch() }                 // safety: arm on lift too
            }
    }

    /// One full circle just completed — a satisfying click (a heavy rumble at
    /// the final circle), a whir burst, and at full it arms the auto-launch.
    private func circleCompleted(_ n: Int) {
        propBoost = 42
        SoundEngine.shared.play(for: "plane.wind")
        if n >= Self.maxWinds {
            HapticEngine.rocketLaunch()                  // strong rumble at full wind
            armLaunch()                                  // "let fly" → auto-launch in 1 s
        } else {
            HapticEngine.planeWind()                     // crisp click per circle
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
            winds = 0
            totalRotation = 0; lastAngle = nil          // [1/5] reset the swirl
            launching = false; liftoff = 0; shudder = 0
        }
    }

    /// 30 Hz: spin the prop (idle slow → fast when wound, plus tap whirs),
    /// shudder near max.
    private func heartbeat() {
        let idle = 4.0 + Double(winds) * 2.0             // ~3 s/rev idle → faster
        let speed = launching ? 60.0 : (idle + propBoost)
        propSpin += speed
        propBoost *= 0.85                                 // whir decays
        bankPhase += 0.15

        guard !launching else { return }
        if maxed {
            shudder = CGFloat.random(in: -2...2)          // shudder at max tension
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

    private static let bodyRed    = Color(hex: "#CC2200")
    private static let wingYellow = Color(hex: "#FFD700")
    private static let propGrey   = Color(hex: "#4a4a4a")

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                // Chubby red fuselage
                Capsule().fill(Self.bodyRed)
                    .frame(width: w * 0.14, height: h * 0.44)
                // Stubby yellow wings
                Capsule().fill(Self.wingYellow)
                    .frame(width: w * 0.46, height: h * 0.09)
                    .offset(y: -h * 0.01)
                // Yellow tail
                Capsule().fill(Self.wingYellow)
                    .frame(width: w * 0.18, height: h * 0.06)
                    .offset(y: h * 0.18)
                // Big round nose
                Circle().fill(Self.bodyRed)
                    .frame(width: w * 0.16, height: w * 0.16)
                    .offset(y: -h * 0.20)
                // Big grey propeller
                ForEach(0..<2, id: \.self) { i in
                    Capsule().fill(Self.propGrey)
                        .frame(width: w * 0.03, height: h * 0.20)
                        .rotationEffect(.degrees(Double(i) * 90 + propSpin))
                }
                .offset(y: -h * 0.24)
                .blur(radius: winding ? 1.2 : 0)
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
