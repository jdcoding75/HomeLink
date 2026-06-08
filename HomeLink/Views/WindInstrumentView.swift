// WindInstrumentView.swift
// Pointward › Views
//
// INSTRUMENT 3 — WIND 🌬️ (Pro). SKY REDESIGN: a bright window onto a warm
// sunny sky — soft blue gradient, fluffy parallax clouds drifting, a gentle
// sun, and white dandelion seeds floating on the breeze. Load a thought and
// it bobs in the sky; a slow steady exhale into the microphone streams the
// seeds and the thought toward the person.
//
// Graceful degradation: if mic permission is denied (or the engine can't
// start), hold the phone within 15° for 2 seconds instead.

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
    @State private var showAimHint = false           // exhaled while off-target
    @State private var bob = false                   // emoji vertical bob
    @State private var sway = false                  // emoji rotation sway

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
    private var aligned: Bool { BearingCalculator.isSendAligned(bearingDegrees) }
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

            // ── Where they are — marker · arc (not clipped) ──
            DirectionIndicator(bearingDegrees: bearingDegrees,
                               personName: personName,
                               personEmoji: personEmoji,
                               ringRadius: 168,
                               showHint: loadedToken == nil)

            // ── The breath-level arc — the instrument listening ──
            if loadedToken != nil && usingBreath {
                breathArc
            }

            // ── The loaded thought — floating on the breeze ──
            if let loadedSymbol {
                loadedSymbol
                    .scaleEffect(1.0 + charge * 0.22)
                    .shadow(color: Color.white.opacity(0.8), radius: 8 + charge * 12)
                    .shadow(color: Self.sun.opacity(0.6 + charge * 0.4),
                            radius: 6 + charge * 16)
                    .offset(y: bob ? -5 : 5)                       // ±5 px, 3 s
                    .rotationEffect(.degrees(sway ? 3 : -3))       // ±3°, 4 s
            }

            // ── Instructions ──
            instructions
        }
        .frame(width: 370, height: 370)
        .onAppear {
            seedSeeds()
            withAnimation(AnimationSystem.easeInOutSine(3.0).repeatForever(autoreverses: true)) {
                bob = true
            }
            withAnimation(AnimationSystem.easeInOutSine(4.0).repeatForever(autoreverses: true)) {
                sway = true
            }
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

    // ── Instructions ──────────────────────────────────────────────────────

    private var instructions: some View {
        VStack {
            Spacer()
            if showAimHint {
                Text("point toward \(personName) first")
                    .font(.system(size: 12, design: .serif).italic())
                    .foregroundColor(Color(hex: "#d2691e"))
                    .transition(.opacity)
            } else if loadedToken != nil {
                Text(instruction)
                    .font(.system(size: 12, design: .serif).italic())
                    .foregroundColor(Self.slate.opacity(aligned ? 0.95 : 0.7))
                    .transition(.opacity)
            }

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
        .animation(.easeOut(duration: 0.25), value: showAimHint)
        .animation(.easeOut(duration: 0.3), value: breath.micDenied)
    }

    private var instruction: String {
        if usingBreath {
            if charge > 0.1 { return "keep breathing…" }
            return aligned ? "breathe toward \(personName)"
                           : "point toward \(personName), then breathe"
        } else {
            if charge > 0.05 { return "keep holding…" }
            return "hold toward \(personName)"
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

    /// Breath path: a detected exhale releases — if aimed.
    private func exhaleDetected() {
        guard loadedToken != nil else { return }
        guard aligned else {
            showAimHint = true
            HapticEngine.sendSoft()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation { showAimHint = false }
            }
            return
        }
        HapticEngine.send()
        onSend()
    }

    /// Fallback path (mic denied): hold steady within 15° for 2 seconds.
    private func fallbackHoldTick() {
        guard loadedToken != nil, breath.micDenied else {
            if !usingBreath && holdProgress > 0 { holdProgress = 0 }
            return
        }
        if aligned {
            holdProgress = min(1, holdProgress + 0.05 / 2.0)
            if Date.now.timeIntervalSince(lastPulseHaptic) >= 0.5 {
                lastPulseHaptic = .now
                HapticEngine.sendSoft()
            }
            if holdProgress >= 1 {
                holdProgress = 0
                HapticEngine.send()
                onSend()
            }
        } else if holdProgress > 0 {
            withAnimation(.easeOut(duration: 0.5)) { holdProgress = 0 }
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
