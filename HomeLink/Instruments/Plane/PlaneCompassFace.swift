// PlaneInstrumentView.swift
// Pointward › Views
//
// INSTRUMENT — PROPELLER PLANE ✈️ (visual bible: plane_4screens_APPROVED).
// Screens 1 & 2 of the bible: a clean TOP-DOWN, front-facing plane sits at the
// heart of the ring on a dark night sky (#1a2d4a → #080e1e, clipped to the
// circle). A white/light fuselage with swept wings, a tail fin, and a brass-hub
// propeller on the nose. SPIN the propeller with a finger-swirl — the prop
// blurs into a charging disk, a gold charge glow blooms, particles scatter and
// dashed charge rings appear — and at full charge the plane LAUNCHES toward the
// person, firing the send pipeline.
//
// The interactive winding mechanic is preserved exactly (swirl → charge →
// auto-launch); only the visual world is the approved dark-sky redesign.
// A looping preview (PlaneLaunchPreview) advertises the instrument on its card.

import SwiftUI
import Combine

struct PlaneInstrumentView: View {

    let loadedToken: String?
    let loadedSymbol: AnyView?
    var loadedEmoji: String? = nil
    let bearingDegrees: Double
    let personName: String
    var personEmoji: String = "💜"
    /// Fired when a fully-wound plane launches.
    var onLaunch: () -> Void = {}

    // ── Winding state ──────────────────────────────────────────────────────
    @State private var winds: Int = 0            // 0…maxWinds charge level
    @State private var propSpin: Double = 0      // propeller rotation
    @State private var propBoost: Double = 0     // transient whir on each tap
    @State private var shudder: CGFloat = 0      // ±px at high tension
    @State private var launching = false
    @State private var liftoff: CGFloat = 0      // 0…1 launch travel
    @State private var bankPhase: Double = 0     // gentle left/right roll
    @State private var showRelease = false
    // CIRCULAR SWIRL — track the finger's accumulated rotation around the
    // propeller centre; each full 360° = one charge step.
    @State private var totalRotation: Double = 0
    @State private var lastAngle: Double? = nil

    private let tick = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    // ── Visual-bible palette — clean white plane on dark sky, brass prop ──────
    private static let skyTop    = Color(hex: "#1a2d4a")   // dark night sky (bible)
    private static let skyBottom = Color(hex: "#080e1e")
    private static let bodyLight = Color(hex: "#e8e0f0")   // white/light body (bible)
    private static let bodyShade = Color(hex: "#b6aecb")   // soft under-shade
    private static let bodyEdge  = Color(hex: "#cfc6e0")
    private static let brass     = Color(hex: "#e8c060")   // propeller hub (bible)
    private static let brassDark = Color(hex: "#b9923a")
    private static let propBlade = Color(hex: "#d8d0e6")
    private static let gold      = Color(hex: "#e8c060")
    private static let lavender  = Color(hex: "#c4a8d4")

    static let maxWinds = 3          // three full finger-circles to full charge

    private var rad: Double { bearingDegrees * .pi / 180 }
    /// Continuous charge straight from the accumulated swirl.
    private var tension: Double { min(1, abs(totalRotation) / (360 * Double(Self.maxWinds))) }
    private var maxed: Bool { winds >= Self.maxWinds }
    private var charging: Bool { abs(totalRotation) > 12 && !maxed && !launching }

    var body: some View {
        ZStack {
            // ── Dark night sky inside the ring (clipped to circle) ──
            Circle()
                .fill(LinearGradient(colors: [Self.skyTop, Self.skyBottom],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1.5))
                .frame(width: 360, height: 360)
                .clipShape(Circle())

            // ── Charge glow behind the plane — gold, blooms while spinning ──
            Circle()
                .fill(Self.gold.opacity(chargeGlowOpacity))
                .frame(width: chargeGlowRadius * 2, height: chargeGlowRadius * 2)
                .blur(radius: 28)
                .animation(.easeOut(duration: 0.4), value: charging)
                .animation(.easeOut(duration: 0.4), value: maxed)

            // ── Dashed charging rings — appear as the prop spins up ──
            if charging || maxed {
                ForEach(0..<2, id: \.self) { i in
                    Circle()
                        .stroke(Self.gold.opacity(maxed ? 0.5 : 0.3),
                                style: StrokeStyle(lineWidth: 1.5, dash: [5, 7]))
                        .frame(width: 150 + CGFloat(i) * 34, height: 150 + CGFloat(i) * 34)
                        .rotationEffect(.degrees(propSpin * (i == 0 ? 0.3 : -0.2)))
                }
                .transition(.opacity)
            }

            // ── Scatter particles around the plane while charging ──
            if charging || maxed { chargeParticles }

            // ── Where they are — person-initial marker on the ring ──
            DirectionIndicator(bearingDegrees: bearingDegrees,
                               personName: personName,
                               personEmoji: personEmoji,
                               ringRadius: 168,
                               showHint: false)

            // ── The plane — top-down, banks slightly as it climbs on launch ──
            plane
                .rotationEffect(.radians(rad))               // nose toward person
                .rotationEffect(.degrees(launching ? sin(bankPhase) * 8 : 0))
                .offset(x: launching ? CGFloat(sin(rad)) * liftoff * 220 : shudder,
                        y: launching ? -CGFloat(cos(rad)) * liftoff * 220 : 0)
                .scaleEffect(launching ? 1.0 + liftoff * 0.3 - liftoff * liftoff * 1.0 : 1.0)
                .opacity(launching ? Double(1 - liftoff * 0.9) : 1)

            // The single instruction lives at the bottom of the compass screen
            // (sendControl) — never duplicated inside the ring.
        }
        .frame(width: 370, height: 370)
        // SWIRL your finger in circles to spin the propeller — each full 360°
        // loop charges one step; at full charge it launches toward the person.
        .contentShape(Circle())
        .gesture(swirlGesture)
        .onReceive(tick) { _ in heartbeat() }
    }

    // ── Charge glow sizing (idle r=45·0.08 → charging r=55) ───────────────────
    private var chargeGlowRadius: CGFloat { maxed ? 60 : (charging ? 55 : 45) }
    private var chargeGlowOpacity: Double { maxed ? 0.22 : (charging ? 0.12 + tension * 0.08 : 0.08) }

    // ── The top-down plane drawing (visual bible) ─────────────────────────────

    private var plane: some View {
        ZStack {
            // Tail fin at the rear (bottom in a nose-up top-down view)
            Capsule()
                .fill(Self.bodyShade)
                .frame(width: 10, height: 30)
                .offset(y: 60)
            // Horizontal stabilizer near the tail
            Capsule()
                .fill(LinearGradient(colors: [Self.bodyLight, Self.bodyShade],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 50, height: 12)
                .offset(y: 56)

            // Main wings — wide, swept, left + right
            Capsule()
                .fill(LinearGradient(colors: [Self.bodyLight, Self.bodyShade],
                                     startPoint: .leading, endPoint: .trailing))
                .overlay(Capsule().stroke(Self.bodyEdge.opacity(0.6), lineWidth: 1))
                .frame(width: 150, height: 26)
                .offset(y: 4)
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

            // Fuselage — central vertical oval, white/light
            Capsule()
                .fill(LinearGradient(colors: [Self.bodyLight, Self.bodyEdge, Self.bodyShade],
                                     startPoint: .leading, endPoint: .trailing))
                .overlay(Capsule().stroke(Self.bodyEdge.opacity(0.7), lineWidth: 1))
                .frame(width: 36, height: 122)
                .shadow(color: .black.opacity(0.35), radius: 5, y: 3)

            // Cockpit / canopy near the nose with the loaded emoji
            Circle()
                .fill(Color(hex: "#243a5c"))
                .frame(width: 24, height: 24)
                .overlay(Circle().stroke(Self.bodyEdge.opacity(0.8), lineWidth: 1.5))
                .overlay {
                    if let loadedSymbol { loadedSymbol.scaleEffect(0.5) }
                }
                .offset(y: -20)

            // Nose cap
            Circle()
                .fill(RadialGradient(colors: [Self.bodyLight, Self.bodyShade],
                                     center: UnitPoint(x: 0.4, y: 0.35),
                                     startRadius: 1, endRadius: 18))
                .frame(width: 30, height: 30)
                .offset(y: -52)

            // Propeller on the front with the brass hub
            propeller.offset(y: -60)

            // [phase3] The duplicate "carried emoji below the plane" is removed —
            // the cockpit emoji (loadedSymbol, above) is the only one. The plane
            // body+prop is symmetric around y:0, so it now reads centred in the
            // ring without the bottom-heavy emoji pulling it down.
        }
        .frame(width: 160, height: 170)
    }

    /// A two-blade propeller with a brass hub: 2 crisp blades when idle, a
    /// blurred charging disk while the finger spins it up.
    private var propeller: some View {
        ZStack {
            if charging || maxed {
                // Charging blur disk — multiple rotated ellipses read as a disk
                ForEach(0..<6, id: \.self) { i in
                    Ellipse()
                        .fill(Self.propBlade.opacity(0.25))
                        .frame(width: 58, height: 9)
                        .rotationEffect(.degrees(Double(i) * 30 + propSpin))
                }
                Circle()
                    .stroke(Self.propBlade.opacity(0.35), lineWidth: 2)
                    .frame(width: 58, height: 58)
            } else {
                // Idle — 2 clean blades
                ForEach(0..<2, id: \.self) { i in
                    Capsule()
                        .fill(LinearGradient(colors: [Self.propBlade, Self.bodyShade],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: 7, height: 56)
                        .rotationEffect(.degrees(Double(i) * 90 + propSpin))
                }
            }
            // Brass hub
            Circle()
                .fill(RadialGradient(colors: [Self.brass, Self.brassDark],
                                     center: .center, startRadius: 0, endRadius: 7))
                .frame(width: 13, height: 13)
                .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 0.8))
        }
        .blur(radius: maxed ? 1.5 : 0)
    }

    /// Gold/white scatter dots that orbit the plane while it charges.
    private var chargeParticles: some View {
        ForEach(0..<10, id: \.self) { i in
            let a = Double(i) / 10 * 2 * .pi + propSpin * .pi / 180
            let r = 70.0 + sin(propSpin * .pi / 180 * 2 + Double(i)) * 10
            Circle()
                .fill(i % 2 == 0 ? Self.gold : Color.white)
                .frame(width: 3, height: 3)
                .opacity(0.7)
                .offset(x: CGFloat(cos(a)) * r, y: CGFloat(sin(a)) * r)
                .allowsHitTesting(false)
        }
    }

    /// "swirl to wind · let fly" — the plane auto-aims, so no aim step.
    private var stepText: String {
        if loadedToken == nil { return "load · swirl · let fly" }
        if maxed { return "let fly ✦" }
        return "swirl to wind · let fly · \(winds)/\(Self.maxWinds)"
    }

    // ── Circular-swirl winding ────────────────────────────────────────────────

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
        // [6/7] Auto-launch faster — 0.5 s, not 1 s — so it feels responsive.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if maxed && !launching { launch() }
        }
    }

    private func launch() {
        launching = true
        withAnimation { showRelease = false }
        // The gentle plane launch whoosh (was rocket.blast — wrong instrument).
        InstrumentSoundPlayer.shared.playCue(file: PlaneSounds.launchFile, duration: 0.6)
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

// MARK: - Naming alias (structural move — zero behavior change)
// The struct keeps its original name so all existing call sites compile
// unchanged; this alias gives the new per-instrument name used by the
// folder system and the animation state-machine work.
typealias PlaneCompassFace = PlaneInstrumentView

// MARK: - ACT 1 state machine — Plane
//
// IDLE: plane on compass face
//   - Propeller spinning slowly; charming gentle bob; ready to wind up
// TRIGGERED: finger on propeller
//   - Propeller responds to finger; wind-up sound begins
//   - Haptic: light mechanical click
// CHARGING: circular swirl gesture
//   - Each circle = one wind; propeller spins faster
//   - Rubber band tightens visually; 3 circles = fully wound
// READY: maximum wind
//   - Propeller blurring; plane vibrating with energy
//   - "let fly ✦" hint appears; auto-launches after 0.5s
// EXITING: LAUNCH
//   - Plane exits toward bearing; wake trail fills circle briefly
//   - InstrumentTransition fires; send animation: banks away
//
// Additive scaffold — the live wind-up gesture in
// PlaneInstrumentView is not yet rewired onto this machine.
extension CompassFaceStateMachine {
  /// A fresh state machine for the plane compass face.
  static func planeFace() -> CompassFaceStateMachine { .init(instrument: .plane) }
}
