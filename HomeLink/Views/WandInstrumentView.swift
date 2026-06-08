// WandInstrumentView.swift
// Pointward › Views
//
// INSTRUMENT — WAND 🪄 (Pro). A dark magical night with an elegant wand at
// its heart: a tapered dark-wood staff, gold trim rings, and a large faceted
// crystal at the tip. The wand is MAGIC — no aiming, no direction, ever. Load
// a thought into the crystal, SHAKE to charge (five shakes to full), and at
// full charge it releases all on its own: the crystal implodes then explodes
// and the magic carries the thought to the person. Direction is irrelevant —
// magic finds them.
//
// Charge comes from the accelerometer (ShakeDetector). Where motion isn't
// available (Simulator), tap the crystal to charge instead — same feel,
// same release. [3/6] All alignment removed; the crystal now physically
// swings (lags) as the wand moves, and the orbital system runs two speeds.

import SwiftUI
import Combine

struct WandInstrumentView: View {

    let loadedToken: String?
    let loadedSymbol: AnyView?
    /// Resolved emoji for the loaded thought — tints the crystal's glow.
    var loadedEmoji: String? = nil
    let bearingDegrees: Double
    let personName: String
    var personEmoji: String = "💜"
    let onSend: () -> Void

    @StateObject private var shake = ShakeDetector()

    @State private var crystalPulse = false      // 0.95–1.05 gentle pulse
    @State private var orbitPhase: Double = 0     // fast orbital ring
    @State private var orbitPhaseSlow: Double = 0 // slow outer orbital ring
    @State private var fullChargeSeconds = 0.0    // auto-send countdown
    @State private var released = false           // guard against double-send
    @State private var sparkleSeed = 0            // re-rolls tip sparkles
    @State private var crystalSwing: CGSize = .zero   // physics lag on shake
    @State private var crystalFlare = 0.0         // 0…1 bright flare per shake
    @State private var imploding = false          // release: crystal collapses
    // [2/7] DIRECTIONAL MOMENT — the wand swings to face the person for 500 ms
    // before the explosion fires, so the magic feels intentional.
    @State private var pointing = false           // wand rotates to the bearing
    @State private var showSendingLabel = false   // "sending to [name] ✦"

    /// The person's bearing in radians — the wand swings here at release.
    private var bearingRad: Double { bearingDegrees * .pi / 180 }

    private let tick = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    // Wand palette
    private static let wood    = Color(hex: "#2C1810")
    private static let gold     = Color(hex: "#D4AF37")
    private static let crystalP = Color(hex: "#9b7fc0")

    private var charge: Double { shake.charge }
    private var loaded: Bool { loadedToken != nil }
    private var full: Bool { charge >= 1 }

    /// The crystal wears the thought's hue once one is loaded.
    private var crystalColor: Color {
        loaded ? EmojiHue.color(for: loadedEmoji ?? "💜") : Self.crystalP
    }

    /// Crystal brightness rises with the charge bands, flaring on each shake.
    private var crystalGlow: Double {
        let base: Double
        switch charge {
        case 0:        base = 0.35
        case ..<0.2:   base = 0.45
        case ..<0.4:   base = 0.6
        case ..<0.6:   base = 0.72
        case ..<0.8:   base = 0.85
        default:       base = 1.0
        }
        return min(1.0, base + crystalFlare * 0.6)
    }

    var body: some View {
        ZStack {
            // ── The atmosphere — a dark magical night ──
            Circle()
                .fill(
                    RadialGradient(colors: [Color(hex: "#171022"),
                                            Color(hex: "#0d0d14")],
                                   center: .center, startRadius: 30, endRadius: 185)
                )
                .overlay(Circle().stroke(Color.white.opacity(0.06), lineWidth: 1))
                .frame(width: 360, height: 360)

            // ── [3/6] NO direction marker / arc / scope — magic needs no aim ──

            // ── Two-speed orbital system — a little solar system charging up ──
            orbitingParticles

            // ── The wand — stands upright while charging; at release it
            // swings to face the person (the [2/7] directional moment) before
            // the explosion fires in their direction. ──
            wand
                .rotationEffect(.radians(pointing ? bearingRad : 0))
                .animation(.easeInOut(duration: 0.5), value: pointing)

            // ── [2/7] "sending to [name] ✦" — the directional beat ──
            if showSendingLabel {
                VStack {
                    Text("sending to \(personName) ✦")
                        .font(.system(size: 18, weight: .semibold, design: .serif).italic())
                        .foregroundColor(Color(hex: "#e0ccee"))
                        .shadow(color: Self.crystalP.opacity(0.8), radius: 10)
                        .padding(.top, 70)
                    Spacer()
                }
                .transition(.opacity)
            }

            // ── Instruction — bold, large, names the direction at release ──
            VStack {
                Spacer()
                if loaded {
                    Text(instruction)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(full ? Color(hex: "#e0ccee")
                                              : Self.crystalP.opacity(0.85))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .shadow(color: Self.crystalP.opacity(0.5), radius: 6)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
        .frame(width: 370, height: 370)
        .onAppear {
            withAnimation(AnimationSystem.easeInOutSine(1.6)
                            .repeatForever(autoreverses: true)) {
                crystalPulse = true
            }
        }
        .onChange(of: loadedToken) { _, token in
            if token != nil {
                released = false
                imploding = false
                fullChargeSeconds = 0
                shake.onShake = { onShakeCounted($0) }
                shake.onFull  = { HapticEngine.wandFull() }   // [5/5] rapid triple
                shake.start()
            } else {
                shake.stop()
            }
        }
        .onDisappear { shake.stop() }
        .onReceive(tick) { _ in heartbeat() }
    }

    /// Magic — but the release names the direction for a satisfying beat.
    private var instruction: String {
        if pointing { return "releasing toward \(personName) ✦" }
        if full { return "magic ready ✦" }
        if charge > 0 { return "keep shaking…" }
        return "load · shake · release"          // [4/5] canonical wand phrase
    }

    // ── The wand ──────────────────────────────────────────────────────────

    /// A vertical staff (crystal up); the parent rotates the whole thing so
    /// the crystal points along the bearing.
    private var wand: some View {
        ZStack {
            // Staff — tapered dark wood, 4 px → narrowing toward the tip,
            // 180 px long, reaching up from center toward the crystal.
            WandStaffShape()
                .fill(
                    LinearGradient(colors: [Self.wood.opacity(0.6), Self.wood],
                                   startPoint: .top, endPoint: .bottom)
                )
                .frame(width: 8, height: 180)
                .overlay(
                    // Gold trim rings along the staff
                    VStack(spacing: 0) {
                        Spacer().frame(height: 44)
                        goldRing
                        Spacer().frame(height: 30)
                        goldRing
                        Spacer()
                    }
                )
                .offset(y: -20)   // crystal end reaches the upper rim region

            // The crystal at the tip — a faceted gem, glowing, holding the
            // thought once one is loaded.
            crystal
                .offset(y: -110)
        }
    }

    private var goldRing: some View {
        Capsule()
            .fill(Self.gold.opacity(0.85))
            .frame(width: 9, height: 3)
            .shadow(color: Self.gold.opacity(0.5), radius: 2)
    }

    /// Multi-faceted crystal — a LARGE diamond gem with an inner glow that
    /// pulses and brightens with the charge, flares on each shake, swings on
    /// the staff with physics lag, and implodes at release. The loaded
    /// thought sits inside it.
    private var crystal: some View {
        ZStack {
            // Outer halo — bigger, brighter
            Circle()
                .fill(crystalColor.opacity(crystalGlow * 0.55))
                .frame(width: 62, height: 62)
                .blur(radius: 14 + crystalGlow * 14)

            // Faceted gem body — larger (30 × 42), brighter on flare
            GemShape()
                .fill(
                    LinearGradient(colors: [Color.white.opacity(0.4 + crystalFlare * 0.6),
                                            crystalColor.opacity(0.95),
                                            crystalColor.opacity(0.55)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .frame(width: 30, height: 42)
                .overlay(
                    GemShape().stroke(Color.white.opacity(0.55), lineWidth: 0.9)
                )
                .shadow(color: crystalColor.opacity(crystalGlow), radius: 8 + crystalGlow * 16)

            // The loaded thought, glowing inside the gem
            if let loadedSymbol {
                loadedSymbol
                    .scaleEffect(0.7)
            }

            // Tip sparkles — tiny stars drifting up from the crystal
            ForEach(0..<6, id: \.self) { i in
                let sx: CGFloat = CGFloat((i * 13 + sparkleSeed * 7) % 22) - 11
                let sy: CGFloat = -12 - CGFloat((i * 9 + sparkleSeed * 5) % 20) - (crystalPulse ? 8 : 0)
                let sparkleSize: CGFloat = i % 2 == 0 ? 5 : 7
                Image(systemName: "sparkle")
                    .font(.system(size: sparkleSize))
                    .foregroundColor(Self.gold.opacity(crystalPulse ? 0.0 : 0.8))
                    .offset(x: sx, y: sy)
                    .animation(AnimationSystem.easeInOutSine(1.4 + Double(i) * 0.2)
                                .repeatForever(autoreverses: true), value: crystalPulse)
            }
        }
        // Release implosion → 0.3; otherwise breathe; flare adds a quick swell
        .scaleEffect(crystalScale)
        // Physics lag — the heavy crystal swings as the wand is shaken
        .offset(crystalSwing)
        .animation(.spring(response: 0.35, dampingFraction: 0.45), value: crystalSwing)
        .animation(.easeOut(duration: 0.18), value: imploding)
        .contentShape(Circle())
        .onTapGesture { tapCrystal() }
    }

    /// Crystal scale: implodes on release, breathes otherwise, flares on shake.
    private var crystalScale: CGFloat {
        if imploding { return 0.3 }
        let breathe: CGFloat = crystalPulse ? 1.05 : 0.95
        return breathe + CGFloat(crystalFlare) * 0.18
    }

    // ── Two-speed orbital system — a little solar system charging up ───────

    /// Fast inner ring: 6 idle → 12 at full charge.
    private var fastCount: Int {
        switch charge {
        case ..<0.3:  return 6
        case ..<0.6:  return 8
        case ..<0.85: return 10
        default:      return 12
        }
    }
    /// Slow outer ring of larger bodies — only once fully charged (6).
    private var slowCount: Int { full ? 6 : 0 }

    private var orbitingParticles: some View {
        ZStack {
            // Fast inner ring — small bright sparks
            ForEach(0..<fastCount, id: \.self) { i in
                let a: Double = orbitPhase + Double(i) / Double(fastCount) * 2 * .pi
                let r: Double = 62.0 + sin(orbitPhase * 1.3 + Double(i)) * 8
                let dot: CGFloat = 3 + CGFloat(charge) * 2
                let ox: CGFloat = CGFloat(cos(a)) * CGFloat(r)
                let oy: CGFloat = CGFloat(sin(a)) * CGFloat(r)
                Circle()
                    .fill(Self.gold.opacity(0.35 + crystalGlow * 0.55))
                    .frame(width: dot, height: dot)
                    .blur(radius: 0.6)
                    .shadow(color: Self.crystalP.opacity(crystalGlow * 0.7), radius: 3)
                    .offset(x: ox, y: oy)
            }
            // Slow outer ring — larger bodies, opposite direction (full only)
            ForEach(0..<slowCount, id: \.self) { i in
                let a: Double = orbitPhaseSlow + Double(i) / Double(max(1, slowCount)) * 2 * .pi
                let r: Double = 98.0 + sin(orbitPhaseSlow * 1.1 + Double(i)) * 6
                let ox: CGFloat = CGFloat(cos(a)) * CGFloat(r)
                let oy: CGFloat = CGFloat(sin(a)) * CGFloat(r)
                Circle()
                    .fill(crystalColor.opacity(0.5 + crystalGlow * 0.4))
                    .frame(width: 7, height: 7)
                    .blur(radius: 0.8)
                    .shadow(color: crystalColor.opacity(0.8), radius: 5)
                    .offset(x: ox, y: oy)
            }
        }
        // On release everything rushes inward to the crystal center
        .scaleEffect(imploding ? 0.0 : 1.0)
        .opacity(imploding ? 0.0 : 1.0)
        .animation(.easeIn(duration: 0.2), value: imploding)
        .animation(.linear(duration: 0.1), value: orbitPhase)
    }

    // ── Mechanic ──────────────────────────────────────────────────────────

    /// Each counted shake: the crystal flares bright then settles, swings on
    /// the staff (physics lag), a magical shimmer, fresh tip sparkles, and a
    /// haptic that strengthens with the band.
    private func onShakeCounted(_ shakes: Int) {
        sparkleSeed += 1
        SoundEngine.shared.play(for: "style.shimmer")
        // Flare bright, then settle back to glow
        withAnimation(.easeOut(duration: 0.08)) { crystalFlare = 1.0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            withAnimation(.easeIn(duration: 0.35)) { crystalFlare = 0.0 }
        }
        // Physics swing — the heavy crystal lags the wand's motion
        let amp: CGFloat = 7
        crystalSwing = CGSize(width: .random(in: -amp...amp),
                              height: .random(in: -amp ... 1))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            crystalSwing = .zero
        }
        // [5/5] Each shake — a rhythmic light tap (the explosion is onFull).
        if shakes < 5 { HapticEngine.wandShake() }
    }

    /// 10 Hz: spin both orbital rings (faster as charge climbs) and run the
    /// full-charge auto-release countdown. No alignment, ever — magic finds
    /// them.
    private func heartbeat() {
        // Dramatic speed-up with charge; the two rings counter-rotate.
        orbitPhase     += 0.10 + charge * 0.45
        orbitPhaseSlow -= 0.05 + charge * 0.18

        guard loaded, !released else { return }

        // Full charge → release on its own after a held beat. Direction is
        // irrelevant; the magic simply goes.
        if full {
            fullChargeSeconds += 0.1
            if fullChargeSeconds >= 1.0 { release() }
        }
    }

    /// Tapping the crystal: charge it where there's no accelerometer, or
    /// release early once it's full.
    private func tapCrystal() {
        guard loaded, !released else { return }
        if full { release(); return }
        // Without motion hardware, taps charge so the wand works in the Sim.
        if !shake.motionAvailable {
            shake.holdCharge(1.0 / Double(ShakeDetector.shakesToFull))
        }
    }

    /// The most magical send in the app. [2/7] First a 500 ms DIRECTIONAL
    /// MOMENT — the tip glows and the wand swings to face the person, "sending
    /// to [name] ✦" appears — then the crystal IMPLODES and the full-screen
    /// .wand send fires the explosion toward them.
    private func release() {
        guard !released else { return }
        released = true
        fullChargeSeconds = 0
        // 1 · the wand points at the person, tip brightening, label in
        HapticEngine.lockOn()
        SoundEngine.shared.play(for: "style.shimmer")
        withAnimation(.easeInOut(duration: 0.5)) { pointing = true }
        withAnimation(.easeIn(duration: 0.3)) { showSendingLabel = true }
        // 2 · after the swing settles, implode → explode toward them
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeIn(duration: 0.18)) { imploding = true }
            withAnimation(.easeOut(duration: 0.2)) { showSendingLabel = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                HapticEngine.wandRelease()       // heavy burst
                shake.stop()
                onSend()   // → full-screen wand explosion (SenderAnimationView)
            }
        }
    }
}

// ════════════════════════════════════════════════════════════════════════
// MARK: - Wand shapes
// ════════════════════════════════════════════════════════════════════════

/// The staff — a slim shaft that tapers toward the crystal tip (top).
struct WandStaffShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let topHalf = rect.width * 0.32     // narrow at the tip
        let botHalf = rect.width * 0.5      // fuller at the base
        p.move(to: CGPoint(x: rect.midX - topHalf, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX + topHalf, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX + botHalf, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX - botHalf, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// A faceted gem — a tall diamond with a girdle, two triangles meeting.
struct GemShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let girdle = h * 0.38
        p.move(to: CGPoint(x: w / 2, y: 0))            // top point
        p.addLine(to: CGPoint(x: w, y: girdle))        // right girdle
        p.addLine(to: CGPoint(x: w / 2, y: h))         // bottom point
        p.addLine(to: CGPoint(x: 0, y: girdle))        // left girdle
        p.closeSubpath()
        // Inner facet lines
        p.move(to: CGPoint(x: 0, y: girdle))
        p.addLine(to: CGPoint(x: w, y: girdle))
        return p
    }
}
