// WindInstrumentView.swift
// Pointward › Views
//
// INSTRUMENT 3 — WIND 🌬️ (Pro). SKY REDESIGN: a bright window onto a warm
// sunny sky — soft blue gradient, fluffy parallax clouds drifting, a gentle
// sun, and white dandelion seeds floating on the breeze. [4/7] The loaded
// thought rides on a LEAF that sways on the breeze; [3/7] a slow steady exhale
// into the microphone lifts the leaf away — NO AIMING, ever: the wind finds
// them. Breathing visibly moves the leaf and streams the seeds in real time.
//
// Graceful degradation: if mic permission is denied (or the engine can't
// start), hold for ~2 seconds instead — still no direction required.

import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

struct WindInstrumentView: View {

    let loadedToken: String?
    let loadedSymbol: AnyView?
    let bearingDegrees: Double
    let personName: String
    var personEmoji: String = "💜"
    let onSend: () -> Void

    @StateObject private var breath = BreathDetector()

    /// A drifting dandelion seed.
    private struct Seed: Identifiable {
        let id = UUID()
        var offset: CGSize
        var size: CGFloat
        var opacity: Double
        var spin: Double          // each seed tumbles a little differently
    }

    @State private var seeds: [Seed] = []
    @State private var holdProgress: Double = 0      // fallback hold-to-send
    @State private var lastPulseHaptic = Date.distantPast
    @State private var lifting = false               // [4/7] leaf lifts on send

    private let driftTick = Timer.publish(every: 0.7, on: .main, in: .common).autoconnect()
    private let holdTick  = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    // Sky palette
    private static let skyTop    = Color(hex: "#87CEEB")
    private static let skyMid    = Color(hex: "#B8D4E8")
    private static let skyLow    = Color(hex: "#E8F4F8")
    private static let cloud     = Color(hex: "#FFFAF0")
    private static let sun       = Color(hex: "#FFF3A3")
    private static let slate     = Color(hex: "#3a5a72")   // text on light sky

    private static let clouds: [Cloud] = [
        Cloud(y:  -86, scale: 0.62, period: 17, phase: 0.10),   // small, high, faster (near)
        Cloud(y:  -18, scale: 1.05, period: 24, phase: 0.55),   // large, mid, slow (far)
        Cloud(y:   62, scale: 0.80, period: 20, phase: 0.30),   // medium, low
        Cloud(y:  118, scale: 0.50, period: 15, phase: 0.78),   // small, very low, fastest
    ]

    private var rad: Double { bearingDegrees * .pi / 180 }
    // [3/7] No `aligned` — the wind needs no aim; magic finds them.
    /// Breath when we can hear it; the steady hold when we can't.
    private var usingBreath: Bool { breath.isListening && !breath.micDenied }
    /// How gathered everything is — breath progress or hold progress.
    private var charge: Double { usingBreath ? breath.exhaleProgress : holdProgress }
    /// The instantaneous, smoothed mic loudness — drives the listening arc
    /// and the live "seeds stream with your breath" response.
    private var liveLevel: Double { usingBreath ? breath.level : 0 }

    var body: some View {
        ZStack {
            // ── The sky window — clipped to the circle ──
            skyWindow
                .frame(width: 360, height: 360)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.55), lineWidth: 1.5))
                .shadow(color: Self.skyTop.opacity(0.4), radius: 18)

            // ── [3/7] NO direction marker / arc / scope — the wind needs no
            // aim. (DirectionIndicator removed.) ──

            // ── The breath-level arc — the instrument listening ──
            if loadedToken != nil && usingBreath {
                breathArc
            }

            // ── [4/7] The loaded thought rides on a LEAF, swaying on the
            // breeze — and swaying MORE as your breath is detected (live). ──
            if let loadedSymbol {
                leafUnit(loadedSymbol)
            }

            // [4/7] In-instrument instruction REMOVED — single instruction at
            // the bottom of the compass screen only (sendControl). The mic
            // permission prompt below stays (it's not an instruction line).
            micPermissionPrompt
        }
        .frame(width: 370, height: 370)
        .onAppear {
            seedSeeds()
        }
        // The mic listens only while a thought is loaded
        .onChange(of: loadedToken) { _, token in
            if token != nil {
                breath.onExhale = { exhaleDetected() }
                breath.start()
            } else {
                breath.stop()
                holdProgress = 0
            }
        }
        .onDisappear { breath.stop() }
        .onReceive(driftTick) { _ in driftSeeds() }
        .onReceive(holdTick) { _ in fallbackHoldTick() }
    }

    // ── The sky window ────────────────────────────────────────────────────

    private var skyWindow: some View {
        ZStack {
            // Sky gradient — bright blue up top to near-white at the bottom
            LinearGradient(colors: [Self.skyTop, Self.skyMid, Self.skyLow],
                           startPoint: .top, endPoint: .bottom)

            // The sun — small, warm, gentle rays, upper-left
            sunView
                .offset(x: -84, y: -104)

            // Fluffy clouds, drifting with parallax
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(Self.clouds) { cloud in
                        cloudShape
                            .scaleEffect(cloud.scale)
                            .offset(x: cloudX(cloud, t: t), y: cloud.y)
                            // Nearer (faster) clouds sit a touch more opaque
                            .opacity(0.55 + cloud.scale * 0.18)
                    }
                }
            }

            // [4/7] Background leaves — 3 small leaves drifting slowly, very
            // subtle (20 %), for depth and atmosphere
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        let p = (t / (26 + Double(i) * 7) + Double(i) * 0.37)
                            .truncatingRemainder(dividingBy: 1)
                        LeafShape()
                            .fill(Self.leafGreen)
                            .frame(width: 24 - CGFloat(i) * 4, height: 16 - CGFloat(i) * 2)
                            .rotationEffect(.degrees(t * 12 + Double(i) * 90))
                            .opacity(0.20)
                            .offset(x: CGFloat(p) * 420 - 210,
                                    y: CGFloat([-70, 40, 120][i]))
                    }
                }
            }

            // Dandelion seeds floating on the breeze
            ForEach(seeds) { seed in
                DandelionSeed(size: seed.size * (1 + CGFloat(liveLevel) * 0.3),
                              opacity: seed.opacity * (0.75 + charge * 0.25))
                    .rotationEffect(.degrees(seed.spin))
                    .offset(gatheredOffset(seed))
                    .animation(AnimationSystem.easeInOutSine(0.7), value: seed.offset)
                    .animation(AnimationSystem.easeInOutSine(0.4), value: charge)
            }
        }
    }

    /// A fluffy cloud — overlapping soft circles for organic edges.
    private var cloudShape: some View {
        ZStack {
            Circle().frame(width: 46, height: 46).offset(x: -30, y: 6)
            Circle().frame(width: 64, height: 64).offset(x: 0, y: 0)
            Circle().frame(width: 50, height: 50).offset(x: 30, y: 4)
            Circle().frame(width: 38, height: 38).offset(x: 14, y: -16)
            Capsule().frame(width: 96, height: 30).offset(y: 14)
        }
        .foregroundColor(Self.cloud.opacity(0.75))
        .blur(radius: 3)
    }

    /// Seamless horizontal drift: a sawtooth that wraps off-screen (clipped),
    /// so the loop is invisible. Parallax comes from each cloud's period.
    private func cloudX(_ cloud: Cloud, t: TimeInterval) -> CGFloat {
        let span: CGFloat = 460        // off left edge → off right edge
        let progress = (t / cloud.period + cloud.phase).truncatingRemainder(dividingBy: 1)
        return CGFloat(progress) * span - span / 2
    }

    /// The sun — a soft warm disc with eight gentle rays.
    private var sunView: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                Capsule()
                    .fill(Self.sun.opacity(0.55))
                    .frame(width: 2, height: 14)
                    .offset(y: -22)
                    .rotationEffect(.degrees(Double(i) / 8 * 360))
            }
            Circle()
                .fill(RadialGradient(colors: [Self.sun, Self.sun.opacity(0.4)],
                                     center: .center, startRadius: 2, endRadius: 18))
                .frame(width: 28, height: 28)
                .blur(radius: 0.5)
        }
        .opacity(0.85)
    }

    // ── [4/7] The leaf carrying the emoji ───────────────────────────────────

    private static let leafGreen = Color(hex: "#5a8a3a")

    /// The emoji sits on a swaying leaf — together one unit. The sway grows
    /// with the live breath level, so the user can SEE the breath working.
    private func leafUnit(_ symbol: AnyView) -> some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let phase = t * 2 * .pi / 3.0                 // 3 s cycle
            let boost = 1 + liveLevel * 1.6 + charge * 0.6   // sways more on breath
            let dx = CGFloat(sin(phase)) * 8 * boost          // ±8 px (× boost)
            let dy = CGFloat(sin(phase + 1.2)) * 4 * boost    // ±4 px
            let rot = sin(phase) * 5 * boost                  // ±5°

            ZStack {
                // The leaf — pointed-tip oval, soft green with vein lines
                LeafShape()
                    .fill(LinearGradient(colors: [Self.leafGreen,
                                                  Color(hex: "#4a7a2e")],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 60, height: 40)
                    .overlay(LeafVeins().stroke(Color(hex: "#7aa85a").opacity(0.7),
                                                lineWidth: 0.8)
                        .frame(width: 60, height: 40))
                    .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                // The emoji, sitting just above the leaf's center
                symbol
                    .scaleEffect(0.85 + charge * 0.18)
                    .offset(y: -8)
                    .shadow(color: Self.sun.opacity(0.6 + charge * 0.4),
                            radius: 6 + charge * 14)
            }
            .scaleEffect(1.0 + charge * 0.15)
            .offset(x: dx, y: dy - CGFloat(charge) * 10)
            .rotationEffect(.degrees(rot))
            .opacity(lifting ? 0 : 1)
        }
    }

    // ── Instructions ──────────────────────────────────────────────────────

    /// [4/7] The instruction line was removed (it duplicated the bottom one);
    /// only the mic-permission prompt remains — not an instruction, a setup cue.
    private var micPermissionPrompt: some View {
        VStack {
            Spacer()
            if breath.micDenied {
                Button(action: openSettings) {
                    VStack(spacing: 2) {
                        Text("allow microphone for breath sending")
                            .font(.system(size: 11, design: .serif).italic())
                            .foregroundColor(Self.slate.opacity(0.75))
                        Text("tap to enable in Settings")
                            .font(.system(size: 10))
                            .foregroundColor(Self.slate.opacity(0.55))
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
                .transition(.opacity)
            }
        }
        .padding(.bottom, 4)
        .animation(.easeOut(duration: 0.3), value: breath.micDenied)
    }

    private var instruction: String {
        if usingBreath {
            if charge > 0.1 { return "keep breathing…" }
            return "breathe to send to \(personName)"
        } else {
            if charge > 0.05 { return "keep holding…" }
            return "hold to send to \(personName)"
        }
    }

    // ── The listening arc ────────────────────────────────────────────────

    /// A soft arc cradling the window's bottom that shows the live mic level —
    /// sky-blue dim in silence, brightening to a warm white glow on a strong
    /// steady exhale. The window feels like it's listening.
    private var breathArc: some View {
        Circle()
            .trim(from: 0.34, to: 0.66)
            .stroke(
                Color(hex: "#5a9fd0").opacity(0.3 + liveLevel * 0.6),
                style: StrokeStyle(lineWidth: 3 + CGFloat(liveLevel) * 4, lineCap: .round)
            )
            .frame(width: 320, height: 320)
            .blur(radius: 1.0)
            .shadow(color: Color.white.opacity(liveLevel * 0.9),
                    radius: 6 + liveLevel * 16)
            .animation(AnimationSystem.easeInOutSine(0.25), value: liveLevel)
            .allowsHitTesting(false)
    }

    /// Open the iOS Settings page for Pointward so the user can grant the mic.
    private func openSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }

    // ── Seeds ─────────────────────────────────────────────────────────────

    private func seedSeeds() {
        seeds = (0..<16).map { _ in
            Seed(offset: CGSize(width: .random(in: -150...150),
                                height: .random(in: -150...150)),
                 size: .random(in: 7...12),
                 opacity: .random(in: 0.4...0.8),
                 spin: .random(in: 0...360))
        }
    }

    /// While charging, seeds pull in toward the loaded thought.
    private func gatheredOffset(_ seed: Seed) -> CGSize {
        let pull = CGFloat(charge) * (loadedToken != nil ? 0.7 : 0)
        return CGSize(width: seed.offset.width * (1 - pull),
                      height: seed.offset.height * (1 - pull))
    }

    /// Seeds drift on the breeze. With no breath they float nearly at random;
    /// a light breath nudges them one way; a strong breath streams them
    /// purposefully toward the person's bearing.
    private func driftSeeds() {
        let strength = 2 + CGFloat(liveLevel) * 36        // bearing pull grows
        let randomness = 12 * (1 - CGFloat(liveLevel) * 0.75)
        let lean = CGSize(width: CGFloat(sin(rad)) * strength,
                          height: -CGFloat(cos(rad)) * strength)
        for index in seeds.indices {
            var next = CGSize(
                width: seeds[index].offset.width + lean.width + .random(in: -randomness...randomness),
                height: seeds[index].offset.height + lean.height + .random(in: -randomness...randomness)
            )
            let distance = sqrt(next.width * next.width + next.height * next.height)
            if distance > 168 {
                next = CGSize(width: -next.width * 0.85 + .random(in: -20...20),
                              height: -next.height * 0.85 + .random(in: -20...20))
            }
            withAnimation(AnimationSystem.easeInOutSine(0.7)) {
                seeds[index].offset = next
                seeds[index].spin += Double.random(in: -25...25)
            }
        }
    }

    // ── Release paths ─────────────────────────────────────────────────────

    /// [3/7] Breath path: ANY detected exhale releases — no aim needed.
    /// The leaf lifts off and the magic carries the thought to the person.
    private func exhaleDetected() {
        guard loadedToken != nil, !lifting else { return }
        HapticEngine.windSend()             // very soft double tap
        withAnimation(.easeIn(duration: 0.5)) { lifting = true }
        onSend()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { lifting = false }
    }

    /// [3/7] Fallback path (mic denied): just hold for ~2 seconds — still no
    /// direction required.
    private func fallbackHoldTick() {
        guard loadedToken != nil, breath.micDenied, !lifting else {
            if !usingBreath && holdProgress > 0 && !lifting { holdProgress = 0 }
            return
        }
        holdProgress = min(1, holdProgress + 0.075 / 2.0)   // [6/7] hold reduced 1/3
        if Date.now.timeIntervalSince(lastPulseHaptic) >= 0.5 {
            lastPulseHaptic = .now
            HapticEngine.windBreath()       // whisper
        }
        if holdProgress >= 1 {
            holdProgress = 0
            HapticEngine.windSend()         // soft double tap
            withAnimation(.easeIn(duration: 0.5)) { lifting = true }
            onSend()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { lifting = false }
        }
    }
}

// ════════════════════════════════════════════════════════════════════════
// MARK: - Sky pieces
// ════════════════════════════════════════════════════════════════════════

/// One drifting cloud's parameters. `period` is seconds to cross; smaller =
/// faster = nearer (parallax).
struct Cloud: Identifiable {
    let id = UUID()
    let y: CGFloat
    let scale: CGFloat
    let period: TimeInterval
    let phase: Double
}

/// [4/7] A leaf — a pointed-tip oval. Tip at the top, rounded base, drawn
/// symmetric so it reads cleanly at any rotation.
struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: w / 2, y: 0))                                  // tip
        p.addQuadCurve(to: CGPoint(x: w / 2, y: h),
                       control: CGPoint(x: w * 1.05, y: h * 0.30))           // right belly
        p.addQuadCurve(to: CGPoint(x: w / 2, y: 0),
                       control: CGPoint(x: -w * 0.05, y: h * 0.30))          // left belly
        p.closeSubpath()
        return p
    }
}

/// Central vein + two side veins, for a hint of leaf texture.
struct LeafVeins: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        // Midrib
        p.move(to: CGPoint(x: w / 2, y: h * 0.06))
        p.addLine(to: CGPoint(x: w / 2, y: h * 0.94))
        // Side veins
        for s in [0.34, 0.54, 0.74] {
            p.move(to: CGPoint(x: w / 2, y: h * s))
            p.addLine(to: CGPoint(x: w * 0.82, y: h * (s - 0.12)))
            p.move(to: CGPoint(x: w / 2, y: h * s))
            p.addLine(to: CGPoint(x: w * 0.18, y: h * (s - 0.12)))
        }
        return p
    }
}

/// A dandelion seed — a tiny central dot with thin filaments radiating, the
/// little parachute that rides the wind.
struct DandelionSeed: View {
    let size: CGFloat
    let opacity: Double

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                Capsule()
                    .fill(Color.white.opacity(opacity))
                    .frame(width: 0.8, height: size * 0.5)
                    .offset(y: -size * 0.25)
                    .rotationEffect(.degrees(Double(i) / 8 * 360))
            }
            Circle()
                .fill(Color.white.opacity(min(1, opacity * 1.4)))
                .frame(width: 2.2, height: 2.2)
        }
        .frame(width: size, height: size)
        .shadow(color: Color(hex: "#6aa6d0").opacity(0.35), radius: 1)
    }
}

// ════════════════════════════════════════════════════════════════════════
// MARK: - ACT 1 — WIND COMPASS FACE (approved prototype)
// ════════════════════════════════════════════════════════════════════════
//
// A sky window inside the compass circle, a leaf carrying the 🤗 emoji
// breathing at the centre, lifted and spiralled out by the user's breath.
//
//   · Sky fill (InstrumentBackground.daySkyCompassFace) + drifting clouds,
//     clipped INSIDE the circle — no sky outside it.
//   · NO needle · NO cardinal labels · NO person marker — the wind is
//     non-directional; the wind finds them.
//   · Driven by CompassFaceStateMachine(.firefly): idle → triggered →
//     charging → ready → exiting. On exit it records the leaf's angle and
//     fires an InstrumentTransition into the send animation (ACT 2).
//   · NO sound during the compass face — the user's breath is the sound.
//
// (The live, shipping breath mechanic remains WindInstrumentView above; this
//  is the ACT 1 face the new state-machine pipeline drives.)
struct WindCompassFace: View {

    /// What is being sent — carried through to the InstrumentTransition.
    var selectedEmoji:   String  = "🤗"
    var selectedMessage: String? = nil
    var selectedTagline: String? = nil
    /// The hand-off to ACT 2 when the leaf leaves the circle.
    var onTransition: ((InstrumentTransition) -> Void)? = nil

    @StateObject private var machine = CompassFaceStateMachine(instrument: .firefly)
    @StateObject private var breath  = BreathDetector()

    private struct FaceSeed: Identifiable {
        let id = UUID()
        var angle:  Double
        var radius: CGFloat
        var size:   CGFloat
        var drift:  Double
    }

    @State private var seeds: [FaceSeed] = []
    @State private var spiralAngle: Double = 0      // leaf angle around centre (rad)
    @State private var leafRadius:  CGFloat = 0     // leaf distance from centre
    @State private var trembling = false            // ready-state shiver
    @State private var exiting   = false            // leaf leaving the circle
    @State private var breatheRing = false          // outer ring breathing

    private static let faceSize: CGFloat = 360
    private static let edgeR:    CGFloat = 150       // the leaf at the circle edge

    private let tick     = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()
    private let seedTick = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private static let lavender  = Color(hex: "#c4a8d4")
    private static let leafGreen = Color(hex: "#5a8a3a")
    private static let sunGlow   = Color(hex: "#FFF3A3")

    /// 0…1 charge while the breath builds.
    private var charge: Double { machine.chargeProgress }

    private static let faceClouds: [Cloud] = [
        Cloud(y: -70, scale: 0.6,  period: 18, phase: 0.15),
        Cloud(y:  10, scale: 0.95, period: 25, phase: 0.55),
        Cloud(y:  84, scale: 0.55, period: 16, phase: 0.80),
    ]

    var body: some View {
        ZStack {
            skyCircle
            ringStructure
            seedLayer
            leaf
        }
        .frame(width: 370, height: 370)
        .onAppear { begin() }
        .onDisappear { breath.stop() }
        .onReceive(tick)     { _ in drive() }
        .onReceive(seedTick) { _ in driftSeeds() }
    }

    // ── The sky window — sky + clouds, clipped INSIDE the circle ────────────

    private var skyCircle: some View {
        ZStack {
            InstrumentBackground.daySkyCompassFace
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(Self.faceClouds) { cloud in
                        windCloud
                            .scaleEffect(cloud.scale)
                            .offset(x: cloudX(cloud, t: t), y: cloud.y)
                            .opacity(0.6 + cloud.scale * 0.2)
                    }
                }
            }
        }
        .frame(width: Self.faceSize, height: Self.faceSize)
        .clipShape(Circle())     // sky + clouds ONLY inside the circle
    }

    private var windCloud: some View {
        ZStack {
            Circle().frame(width: 40, height: 40).offset(x: -26, y: 5)
            Circle().frame(width: 56, height: 56)
            Circle().frame(width: 44, height: 44).offset(x: 26, y: 4)
            Capsule().frame(width: 84, height: 26).offset(y: 12)
        }
        .foregroundColor(Color(hex: "#FFFAF0").opacity(0.7))
        .blur(radius: 3)
    }

    private func cloudX(_ cloud: Cloud, t: TimeInterval) -> CGFloat {
        let span: CGFloat = 440
        let p = (t / cloud.period + cloud.phase).truncatingRemainder(dividingBy: 1)
        return CGFloat(p) * span - span / 2
    }

    // ── Rings — structural only, no direction meaning ───────────────────────

    private var ringStructure: some View {
        ZStack {
            // Outer breathing ring — subtle lavender
            Circle()
                .stroke(Self.lavender.opacity(breatheRing ? 0.35 : 0.14),
                        lineWidth: 2)
                .frame(width: breatheRing ? 374 : 362, height: breatheRing ? 374 : 362)
            // Main compass ring border
            Circle()
                .stroke(Color.white.opacity(0.55), lineWidth: 1.5)
                .frame(width: Self.faceSize, height: Self.faceSize)
            // Inner dashed ring
            Circle()
                .stroke(Self.lavender.opacity(0.22),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
                .frame(width: 312, height: 312)
            // Minimal tick marks every 30° — structural, NOT directional
            ForEach(0..<12, id: \.self) { i in
                Capsule()
                    .fill(Self.lavender.opacity(0.3))
                    .frame(width: 1.5, height: 8)
                    .offset(y: -(Self.faceSize / 2 - 4))
                    .rotationEffect(.degrees(Double(i) * 30))
            }
        }
        .allowsHitTesting(false)
    }

    // ── Seeds drifting on the breeze ────────────────────────────────────────

    private var seedLayer: some View {
        ZStack {
            ForEach(seeds) { seed in
                DandelionSeed(size: seed.size, opacity: 0.45 + charge * 0.45)
                    .offset(x: CGFloat(cos(seed.angle)) * seed.radius,
                            y: CGFloat(sin(seed.angle)) * seed.radius)
                    .animation(AnimationSystem.easeInOutSine(0.5), value: seed.radius)
            }
        }
        .frame(width: Self.faceSize, height: Self.faceSize)
        .clipShape(Circle())
        .allowsHitTesting(false)
    }

    // ── The leaf carrying the emoji — always visible, breathing ─────────────

    private var leaf: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            // Idle: gentle sway + breathe (per the spec).
            let sway = sin(t * 0.65) * 5                       // ±5°
            let breatheScale = 1 + sin(t * 1.0) * 0.06         // ±6 %
            let lifted = machine.state != .idle
            let leafOffset = CGSize(width: CGFloat(cos(spiralAngle)) * leafRadius,
                                    height: CGFloat(sin(spiralAngle)) * leafRadius)
            ZStack {
                // Soft glow under the leaf once the breath is felt.
                if lifted {
                    Circle()
                        .fill(Self.sunGlow.opacity(0.28 + charge * 0.45))
                        .frame(width: 74, height: 74)
                        .blur(radius: 18)
                }
                // The leaf — ~68×40.
                LeafShape()
                    .fill(LinearGradient(colors: [Self.leafGreen, Color(hex: "#4a7a2e")],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 68, height: 40)
                    .overlay(LeafVeins().stroke(Color(hex: "#7aa85a").opacity(0.7), lineWidth: 0.8)
                        .frame(width: 68, height: 40))
                    .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                // The 🤗 emoji sitting ON the leaf — always visible, 28 pt.
                Text(selectedEmoji)
                    .font(.system(size: 28))
                    .offset(y: -6)
                    .shadow(color: Self.sunGlow.opacity(0.5 + charge * 0.4),
                            radius: 6 + charge * 12)
            }
            .scaleEffect(breatheScale * (1 + charge * 0.14))
            .rotationEffect(.degrees(sway + (trembling ? Double.random(in: -3.5...3.5) : 0)))
            .offset(leafOffset)
            .opacity(exiting ? 0 : 1)
            .animation(.easeOut(duration: 0.3), value: exiting)
        }
    }

    // ── State machine driver (breath → idle/triggered/charging/ready/exit) ──

    private func begin() {
        machine.onExit = onTransition
        seeds = (0..<10).map { _ in
            FaceSeed(angle: .random(in: 0...(2 * .pi)),
                     radius: .random(in: 28...140),
                     size: .random(in: 6...11),
                     drift: .random(in: -1...1))
        }
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            breatheRing = true
        }
        breath.start()   // the breath drives the states (no sound here)
    }

    /// The live breath progress when we can hear it; 0 otherwise.
    private var breathProgress: Double {
        (breath.isListening && !breath.micDenied) ? breath.exhaleProgress : 0
    }

    private func drive() {
        guard !exiting else { return }
        let p = breathProgress
        switch machine.state {
        case .idle:
            if leafRadius != 0 { leafRadius = 0 }
            if p > 0.03 {
                machine.trigger()                          // breath detected
                HapticPattern.singleSoft.fire()            // soft single pulse
            }
        case .triggered, .charging:
            machine.charge(progress: p)
            // Leaf spirals organically outward — NO fixed direction; the radius
            // follows charge² (cos/sin of time × charge²), per the spec.
            spiralAngle += 0.05 + charge * 0.16
            leafRadius = Self.edgeR * CGFloat(charge * charge)
            if p >= 0.999 { becomeReady() }
        case .ready:
            spiralAngle += 0.18                            // keep drifting at the edge
        case .exiting:
            break
        }
    }

    /// Leaf at the circle edge — a brief trembling pause, then it flies.
    private func becomeReady() {
        guard machine.state == .charging else { return }
        machine.markReady()
        HapticPattern.doubleSoft.fire()                    // double soft pulse
        withAnimation(.easeInOut(duration: 0.1).repeatCount(4, autoreverses: true)) {
            trembling = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + CompassFaceStateDurations.ready) {
            fireExit()
        }
    }

    /// The leaf exits past the boundary; record the exit angle and fire the
    /// transition into the send animation.
    private func fireExit() {
        guard machine.state == .ready, !exiting else { return }
        exiting   = true
        trembling = false
        // The leaf's offset is relative to the circle centre, so the exit angle
        // is atan2(leafY − centre, leafX − centre) with the centre at the origin.
        let leafX = cos(spiralAngle) * Double(Self.edgeR)
        let leafY = sin(spiralAngle) * Double(Self.edgeR)
        let exitAngle = atan2(leafY, leafX)
        let exitBearing = (exitAngle * 180 / .pi).truncatingRemainder(dividingBy: 360)
        let exitPoint = CGPoint(x: Self.faceSize / 2 + CGFloat(leafX),
                                y: Self.faceSize / 2 + CGFloat(leafY))
        withAnimation(.easeIn(duration: CompassFaceStateDurations.exiting)) {
            leafRadius = Self.edgeR * 1.7                   // past the circle
        }
        machine.exit(bearing: exitBearing < 0 ? exitBearing + 360 : exitBearing,
                     point: exitPoint,
                     emoji: selectedEmoji,
                     message: selectedMessage,
                     tagline: selectedTagline)
        // Reset to idle once the hand-off completes.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            machine.reset()
            leafRadius = 0; spiralAngle = 0; exiting = false
        }
    }

    /// Seeds wander gently in idle and stream off increasingly with charge.
    private func driftSeeds() {
        let streaming = charge > 0.05
        for i in seeds.indices {
            seeds[i].angle += seeds[i].drift * 0.2 + (streaming ? 0.12 : 0)
            let dr: CGFloat = streaming ? CGFloat(8 + charge * 30)
                                        : CGFloat.random(in: -6...6)
            var r = seeds[i].radius + dr
            if r > 150 { r = CGFloat.random(in: 18...60) }   // recycle inward
            withAnimation(AnimationSystem.easeInOutSine(0.5)) {
                seeds[i].radius = max(10, r)
            }
        }
    }
}

// MARK: - ACT 1 state machine factory — Wind
//
// NOTE: the wind instrument is backed by the .firefly enum case
// (displayName "wind") — see Instrument.swift.
extension CompassFaceStateMachine {
  /// A fresh state machine for the wind compass face (.firefly).
  static func windFace() -> CompassFaceStateMachine { .init(instrument: .firefly) }
}
