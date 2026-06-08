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
    // wind took the firefly slot — warm lavender-white breath
    private static let green    = Color(hex: "#d9cce8")

    var body: some View {
        switch instrument {
        case .compass: CompassNeedlePreview()
        case .bow:     BowDrawPreview()
        case .firefly: FireflyDriftPreview()
        case .flick:   FlickLaunchPreview()
        case .rocket:  RocketLaunchPreview()
        case .wand:    WandChargePreview()
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
                    // The launch pocket beneath the dot — clean, no finger
                    Circle()
                        .stroke(InstrumentPreview.lavender.opacity(0.55), lineWidth: 1)
                        .background(Circle().fill(Color.black.opacity(0.25)))
                        .frame(width: 14, height: 14)
                        .offset(x: start.width, y: start.height + 9)
                        .scaleEffect(pressed ? 0.88 : 1.0)

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

    // ── 🚀 The rocket — fuels, then blasts off, every 4 s ────────────────

    struct RocketLaunchPreview: View {
        @State private var fuel: CGFloat = 0        // 0…1 gauge fill
        @State private var liftoff: CGFloat = 0     // 0…1 climb
        @State private var flame = false
        @State private var launching = false

        var body: some View {
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                ZStack {
                    // Fuel gauge — a tiny vertical bar on the left
                    ZStack(alignment: .bottom) {
                        Capsule()
                            .fill(Color.black.opacity(0.3))
                            .frame(width: 3, height: h * 0.34)
                        Capsule()
                            .fill(LinearGradient(colors: [Color(hex: "#FFD700"),
                                                          Color(hex: "#e0622c")],
                                                 startPoint: .top, endPoint: .bottom))
                            .frame(width: 3, height: h * 0.34 * fuel)
                    }
                    .position(x: w * 0.24, y: h / 2)

                    // The rocket — climbs on liftoff, fades at the top
                    VStack(spacing: 0) {
                        // Nose + body
                        RocketBodyMini()
                            .frame(width: w * 0.16, height: h * 0.40)
                        // Flame
                        Capsule()
                            .fill(LinearGradient(colors: [Color(hex: "#FFD700"),
                                                          Color(hex: "#e0622c"), .clear],
                                                 startPoint: .top, endPoint: .bottom))
                            .frame(width: w * 0.09,
                                   height: flame ? h * (launching ? 0.34 : 0.10) : h * 0.04)
                            .blur(radius: 1)
                            .opacity(flame ? 1 : 0)
                    }
                    .offset(y: -liftoff * h * 0.7)
                    .opacity(1 - Double(liftoff) * 0.85)
                    .position(x: w * 0.58, y: h * 0.55)
                }
            }
            .onAppear { loop() }
        }

        private func loop() {
            var snap = Transaction(); snap.disablesAnimations = true
            withTransaction(snap) {
                fuel = 0; liftoff = 0; flame = false; launching = false
            }
            // Fuel fills in five quick steps
            for step in 1...5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 + Double(step) * 0.22) {
                    withAnimation(.easeOut(duration: 0.18)) { fuel = CGFloat(step) / 5 }
                    flame = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        if !launching { flame = step >= 2 }   // idle flicker after 40%
                    }
                }
            }
            // Blast off
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                launching = true
                flame = true
                withAnimation(.easeIn(duration: 1.1)) { liftoff = 1 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { loop() }
        }
    }
}

/// A minimal rocket silhouette — nose cone, body, porthole, fins.
struct RocketBodyMini: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                // Body
                RoundedRectangle(cornerRadius: w * 0.3)
                    .fill(LinearGradient(colors: [.white, Color(hex: "#c8c8d0")],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: w * 0.6, height: h * 0.8)
                // Nose cone
                Triangle()
                    .fill(Color(hex: "#b0b0b8"))
                    .frame(width: w * 0.6, height: h * 0.28)
                    .offset(y: -h * 0.34)
                // Porthole
                Circle()
                    .fill(Color(hex: "#7c6b8e"))
                    .frame(width: w * 0.26, height: w * 0.26)
                    .offset(y: -h * 0.05)
                // Fins
                ForEach([-1.0, 1.0], id: \.self) { side in
                    Triangle()
                        .fill(Color(hex: "#e0622c"))
                        .frame(width: w * 0.22, height: h * 0.22)
                        .rotationEffect(.degrees(side > 0 ? 150 : 210))
                        .offset(x: CGFloat(side) * w * 0.32, y: h * 0.30)
                }
            }
            .frame(width: w, height: h)
        }
    }
}

// ── 🪄 The crystal charges, then bursts ──────────────────────────────

struct WandChargePreview: View {
        @State private var charge: CGFloat = 0
        @State private var burst = false
        @State private var sparkleSeed = 0

        private static let gold     = Color(hex: "#D4AF37")
        private static let crystalP = Color(hex: "#9b7fc0")
        private static let wood     = Color(hex: "#2C1810")

        var body: some View {
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                ZStack {
                    // Staff — tapered wand, crystal toward upper-right
                    WandStaffShape()
                        .fill(Self.wood)
                        .frame(width: side * 0.05, height: side * 0.5)
                        .rotationEffect(.degrees(35))

                    // Crystal — brightens with the charge, bursts at full
                    GemShape()
                        .fill(LinearGradient(colors: [Self.crystalP.opacity(0.95),
                                                      Self.crystalP.opacity(0.5)],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: side * 0.12, height: side * 0.16)
                        .shadow(color: Self.crystalP.opacity(0.3 + charge * 0.7),
                                radius: 4 + charge * 12)
                        .scaleEffect(burst ? 1.3 : (0.9 + charge * 0.2))
                        .opacity(burst ? 0 : 1)
                        .offset(x: side * 0.16, y: -side * 0.16)

                    // Burst sparkles
                    if burst {
                        ForEach(0..<10, id: \.self) { i in
                            let a = Double(i) / 10 * 2 * .pi
                            Circle()
                                .fill(i % 2 == 0 ? Self.gold : Self.crystalP)
                                .frame(width: 3, height: 3)
                                .offset(x: side * 0.16 + CGFloat(cos(a)) * side * 0.18,
                                        y: -side * 0.16 + CGFloat(sin(a)) * side * 0.18)
                                .opacity(burst ? 0 : 1)
                        }
                    }
                }
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
            .onAppear { loop() }
        }

        private func loop() {
            var snap = Transaction(); snap.disablesAnimations = true
            withTransaction(snap) { charge = 0; burst = false; sparkleSeed += 1 }
            // Charge up in shake-like steps
            withAnimation(AnimationSystem.easeInOutSine(1.4).delay(0.3)) { charge = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.4)) { burst = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) { loop() }
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
        case .rocket:              instrument = .rocket
        case .wand:                instrument = .wand
        }
        defaults.set(instrument.rawValue, forKey: InstrumentStore.storageKey)
    }
}
