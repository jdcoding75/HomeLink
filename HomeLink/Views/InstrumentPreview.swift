// InstrumentPreview.swift
// Pointward › Views
//
// Looping mini previews of the four instruments — each one a tiny living
// echo of its mechanic. Sized by the caller; loops itself, no tap needed.
// Used by ProSetupView ("your instrument"), PaywallView ("see what Pro
// feels like"), and the onboarding instrument carousel.
//
//   🧭 compass   a needle wanders, then settles true
//   🏹 bow       the string draws, trembles, releases — a bolt flies
//   🫧 firefly   a green orb drifts organically, glowing
//   👆 flick     a dot is pressed down, then flicked across on a curve

import SwiftUI

struct InstrumentPreview: View {

    let instrument: Instrument

    private static let lavender = Color(hex: "#c4a8d4")
    private static let gold     = Color(hex: "#FFD700")
    private static let amber    = Color(hex: "#D4A017")
    private static let green    = Color(hex: "#90EE90")

    var body: some View {
        switch instrument {
        case .compass: CompassNeedlePreview()
        case .bow:     BowDrawPreview()
        case .firefly: FireflyDriftPreview()
        case .flick:   FlickLaunchPreview()
        }
    }

    // ── 🧭 The needle slowly settles ─────────────────────────────────────

    struct CompassNeedlePreview: View {
        @State private var bearing: Double = 130
        @State private var settled = false

        var body: some View {
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                ZStack {
                    Circle()
                        .stroke(InstrumentPreview.lavender.opacity(0.35), lineWidth: 1)
                        .frame(width: side * 0.82, height: side * 0.82)
                    // The needle — north lavender, south muted
                    VStack(spacing: 0) {
                        Triangle()
                            .fill(InstrumentPreview.lavender)
                            .frame(width: side * 0.07, height: side * 0.30)
                        Triangle()
                            .fill(Color(hex: "#7c6b8e").opacity(0.7))
                            .frame(width: side * 0.06, height: side * 0.20)
                            .rotationEffect(.degrees(180))
                    }
                    .rotationEffect(.degrees(bearing))
                    .shadow(color: InstrumentPreview.lavender.opacity(settled ? 0.6 : 0.15),
                            radius: 5)
                    Circle()
                        .fill(InstrumentPreview.lavender.opacity(0.9))
                        .frame(width: 4, height: 4)
                }
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
            .onAppear { loop() }
        }

        private func loop() {
            settled = false
            var snap = Transaction(); snap.disablesAnimations = true
            withTransaction(snap) { bearing = Double.random(in: 90...170) }
            withAnimation(.spring(response: 1.5, dampingFraction: 0.55).delay(0.4)) {
                bearing = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation(.easeIn(duration: 0.4)) { settled = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) { loop() }
        }
    }

    // ── 🏹 The string pulls and releases ─────────────────────────────────

    struct BowDrawPreview: View {
        @State private var pull: CGFloat = 0
        @State private var flightProgress: CGFloat = 0
        @State private var boltVisible = false

        var body: some View {
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                ZStack {
                    ZStack {
                        BowArchShape(tension: pull * 0.6)
                            .stroke(Color(hex: "#ece4f5").opacity(0.8),
                                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        BowStringShape(pull: pull)
                            .stroke(Color(hex: "#ece4f5").opacity(0.8), lineWidth: 1.2)
                    }
                    .frame(width: side * 0.62, height: side * 0.62)
                    .rotationEffect(.degrees(-90))   // aims right

                    // The bolt — a small amber capsule flying out on release
                    if boltVisible {
                        Capsule()
                            .fill(InstrumentPreview.amber)
                            .frame(width: side * 0.18, height: 2.5)
                            .shadow(color: InstrumentPreview.gold.opacity(0.7), radius: 4)
                            .offset(x: -side * 0.12 + flightProgress * side * 0.62)
                            .opacity(1 - Double(flightProgress) * 0.9)
                    }
                }
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
            .onAppear { loop() }
        }

        private func loop() {
            var snap = Transaction(); snap.disablesAnimations = true
            withTransaction(snap) {
                pull = 0; flightProgress = 0; boltVisible = false
            }
            // Draw…
            withAnimation(AnimationSystem.easeInOutSine(0.9).delay(0.3)) { pull = 9 }
            // …hold… release
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation(.easeOut(duration: 0.08)) { pull = 0 }
                boltVisible = true
                withAnimation(AnimationSystem.easeOutCubic(0.55)) { flightProgress = 1 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) { loop() }
        }
    }

    // ── 🫧 The orb drifts organically ────────────────────────────────────

    struct FireflyDriftPreview: View {
        @State private var progress: CGFloat = 0
        @State private var pulse = false
        @State private var wanderSeed = 0   // varies the path each loop

        var body: some View {
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                let flip: CGFloat = wanderSeed % 2 == 0 ? 1 : -1
                let start   = CGSize(width: -w * 0.28, height: h * 0.18 * flip)
                let end     = CGSize(width: w * 0.28, height: -h * 0.14 * flip)
                let c1      = CGSize(width: -w * 0.05, height: -h * 0.30 * flip)
                let c2      = CGSize(width: w * 0.14, height: h * 0.26 * flip)

                Circle()
                    .fill(RadialGradient(colors: [InstrumentPreview.green.opacity(0.95),
                                                  InstrumentPreview.green.opacity(0.35), .clear],
                                         center: .center, startRadius: 1, endRadius: 8))
                    .frame(width: 14, height: 14)
                    .blur(radius: 1)
                    .scaleEffect(pulse ? 1.12 : 0.9)
                    .shadow(color: InstrumentPreview.green.opacity(0.7), radius: 6)
                    .modifier(WanderingFlightEffect(progress: progress, start: start,
                                                    control1: c1, control2: c2, end: end))
                    .position(x: w / 2, y: h / 2)
            }
            .onAppear {
                withAnimation(AnimationSystem.easeInOutSine(0.6)
                                .repeatForever(autoreverses: true)) {
                    pulse = true
                }
                loop()
            }
        }

        private func loop() {
            var snap = Transaction(); snap.disablesAnimations = true
            withTransaction(snap) { progress = 0; wanderSeed += 1 }
            withAnimation(AnimationSystem.easeInOutSine(2.6)) { progress = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) { loop() }
        }
    }

    // ── 👆 The flick — pressed, then launched ────────────────────────────

    struct FlickLaunchPreview: View {
        @State private var pressed = false
        @State private var progress: CGFloat = 0

        var body: some View {
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                let start   = CGSize(width: -w * 0.22, height: h * 0.22)
                let end     = CGSize(width: w * 0.34, height: -h * 0.24)
                let control = CGSize(width: 0, height: -h * 0.40)

                ZStack {
                    // The fingertip beneath the launch point
                    Circle()
                        .fill(Color(hex: "#ece4f5").opacity(0.55))
                        .frame(width: 13, height: 13)
                        .offset(x: start.width, y: start.height + 10)
                        .scaleEffect(pressed ? 0.86 : 1.0, anchor: .bottom)

                    // The thought — pressed down, then flicked on a curve
                    Circle()
                        .fill(InstrumentPreview.lavender)
                        .frame(width: 9, height: 9)
                        .shadow(color: InstrumentPreview.lavender.opacity(0.8), radius: 5)
                        .scaleEffect(pressed ? 0.8 : 1.0)
                        .offset(y: pressed ? 3 : 0)
                        .opacity(1 - Double(progress) * 0.85)
                        .modifier(CurvedFlightEffect(progress: progress, start: start,
                                                     control: control, end: end))
                }
                .position(x: w / 2, y: h / 2)
            }
            .onAppear { loop() }
        }

        private func loop() {
            var snap = Transaction(); snap.disablesAnimations = true
            withTransaction(snap) { progress = 0; pressed = false }
            withAnimation(AnimationSystem.easeInOutSine(0.25).delay(0.5)) { pressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
                withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) { pressed = false }
                withAnimation(AnimationSystem.easeOutCubic(0.7)) { progress = 1 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { loop() }
        }
    }
}

// MARK: - Legacy selection migration

extension Instrument {
    /// One-time migration: users who picked a sender style before the
    /// instrument architecture keep the equivalent instrument.
    static func migrateLegacySelection() {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: InstrumentStore.storageKey) == nil else { return }
        let instrument: Instrument
        switch SenderStyle.selected {
        case .glow, .shootingStar: instrument = .compass
        case .firefly:             instrument = .firefly
        case .fingerFlick:         instrument = .flick
        case .bowArrow:            instrument = .bow
        }
        defaults.set(instrument.rawValue, forKey: InstrumentStore.storageKey)
    }
}
