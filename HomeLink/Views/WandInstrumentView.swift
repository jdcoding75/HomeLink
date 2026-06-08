// WandInstrumentView.swift
// Pointward › Views
//
// INSTRUMENT 5 — WAND 🪄 (Pro). A dark atmospheric circle with an elegant
// wand at its heart: a tapered dark-wood staff, gold trim rings, and a
// faceted crystal at the tip that points toward the person. Load a thought
// into the crystal, SHAKE to charge the magic (five shakes to full), and at
// full charge within 15° it releases — a burst of sparkles carrying the
// thought away.
//
// Charge comes from the accelerometer (ShakeDetector). Where motion isn't
// available (Simulator), tap the crystal to charge instead — same feel,
// same release.

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
    @State private var orbitPhase: Double = 0     // particles orbiting the wand
    @State private var fullAlignedSeconds = 0.0   // auto-send countdown
    @State private var released = false           // guard against double-send
    @State private var showAimHint = false
    @State private var sparkleSeed = 0            // re-rolls tip sparkles

    private let tick = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    // Wand palette
    private static let wood    = Color(hex: "#2C1810")
    private static let gold     = Color(hex: "#D4AF37")
    private static let crystalP = Color(hex: "#9b7fc0")

    private var rad: Double { bearingDegrees * .pi / 180 }
    private var aligned: Bool { BearingCalculator.isSendAligned(bearingDegrees) }
    private var charge: Double { shake.charge }
    private var loaded: Bool { loadedToken != nil }

    /// The crystal wears the thought's hue once one is loaded.
    private var crystalColor: Color {
        loaded ? EmojiHue.color(for: loadedEmoji ?? "💜") : Self.crystalP
    }

    /// Crystal brightness rises with the charge bands (spec).
    private var crystalGlow: Double {
        switch charge {
        case 0:        return aligned ? 0.45 : 0.3   // idle, brighter aimed
        case ..<0.2:   return 0.4
        case ..<0.4:   return 0.55
        case ..<0.6:   return 0.7
        case ..<0.8:   return 0.85
        default:       return 1.0
        }
    }

    /// Orbiting particle count grows with charge: 8 idle → 4/6/8 bands.
    private var orbitCount: Int {
        switch charge {
        case 0:       return 8
        case ..<0.6:  return 8
        case ..<0.8:  return 4 + 2            // 6
        default:      return 8
        }
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

            // ── Where they are — marker · arc · hint ──
            DirectionIndicator(bearingDegrees: bearingDegrees,
                               personName: personName,
                               personEmoji: personEmoji,
                               ringRadius: 168,
                               showHint: loadedToken == nil)

            // ── Magic particles orbiting the wand ──
            orbitingParticles

            // ── The wand — staff + gold rings + crystal, aimed at them ──
            wand
                .rotationEffect(.radians(rad))   // tip points toward the person

            // ── Instructions ──
            VStack {
                Spacer()
                if showAimHint {
                    Text("aim toward \(personName)")
                        .font(.system(size: 12, design: .serif).italic())
                        .foregroundColor(Color(hex: "#e08a3c"))
                        .transition(.opacity)
                } else if loaded {
                    Text(instruction)
                        .font(.system(size: 12, design: .serif).italic())
                        .foregroundColor(Self.crystalP.opacity(aligned ? 0.95 : 0.7))
                        .transition(.opacity)
                }
            }
            .padding(.bottom, 4)
            .animation(.easeOut(duration: 0.25), value: showAimHint)
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
                fullAlignedSeconds = 0
                shake.onShake = { onShakeCounted($0) }
                shake.onFull  = { HapticEngine.lockOn() }
                shake.start()
            } else {
                shake.stop()
            }
        }
        .onDisappear { shake.stop() }
        .onReceive(tick) { _ in heartbeat() }
    }

    private var instruction: String {
        if charge >= 1 {
            return aligned ? "release to send" : "aim toward \(personName)"
        }
        if charge > 0 { return "keep charging…" }
        return shake.motionAvailable ? "shake to charge" : "tap the crystal to charge"
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

    /// Multi-faceted crystal — a diamond gem with an inner glow that pulses
    /// and brightens with the charge. The loaded thought sits inside it.
    private var crystal: some View {
        ZStack {
            // Outer halo
            Circle()
                .fill(crystalColor.opacity(crystalGlow * 0.5))
                .frame(width: 46, height: 46)
                .blur(radius: 12 + crystalGlow * 10)

            // Faceted gem body — two stacked diamonds
            GemShape()
                .fill(
                    LinearGradient(colors: [crystalColor.opacity(0.95),
                                            crystalColor.opacity(0.55)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .frame(width: 22, height: 30)
                .overlay(
                    GemShape().stroke(Color.white.opacity(0.5), lineWidth: 0.8)
                )
                .shadow(color: crystalColor.opacity(crystalGlow), radius: 6 + crystalGlow * 12)

            // The loaded thought, glowing inside the gem
            if let loadedSymbol {
                loadedSymbol
                    .scaleEffect(0.6)
            }

            // Tip sparkles — 4–6 tiny stars drifting up from the crystal
            ForEach(0..<6, id: \.self) { i in
                Image(systemName: "sparkle")
                    .font(.system(size: i % 2 == 0 ? 5 : 7))
                    .foregroundColor(Self.gold.opacity(crystalPulse ? 0.0 : 0.8))
                    .offset(x: CGFloat((i * 13 + sparkleSeed * 7) % 20) - 10,
                            y: -10 - CGFloat((i * 9 + sparkleSeed * 5) % 18)
                               - (crystalPulse ? 8 : 0))
                    .animation(AnimationSystem.easeInOutSine(1.4 + Double(i) * 0.2)
                                .repeatForever(autoreverses: true), value: crystalPulse)
            }
        }
        .scaleEffect(crystalPulse ? 1.05 : 0.95)
        // Keep the crystal upright as the wand rotates, so it reads as a gem
        // and the thought inside it is never upside down.
        .rotationEffect(.radians(-rad))
        .contentShape(Circle())
        .onTapGesture { tapCrystal() }
    }

    // ── Orbiting magic particles ──────────────────────────────────────────

    private var orbitingParticles: some View {
        ZStack {
            ForEach(0..<orbitCount, id: \.self) { i in
                let a = orbitPhase + Double(i) / Double(orbitCount) * 2 * .pi
                let r = 70.0 + sin(orbitPhase * 1.3 + Double(i)) * 10
                Circle()
                    .fill(Self.gold.opacity(0.3 + crystalGlow * 0.5))
                    .frame(width: 3 + CGFloat(charge) * 2, height: 3 + CGFloat(charge) * 2)
                    .blur(radius: 0.6)
                    .shadow(color: Self.crystalP.opacity(crystalGlow * 0.6), radius: 3)
                    .offset(x: CGFloat(cos(a)) * r, y: CGFloat(sin(a)) * r)
            }
        }
        .animation(.linear(duration: 0.1), value: orbitPhase)
    }

    // ── Mechanic ──────────────────────────────────────────────────────────

    /// Each counted shake: brighter crystal, light tap, magical shimmer,
    /// a fresh burst of tip sparkles. Bands add a heavier haptic.
    private func onShakeCounted(_ shakes: Int) {
        sparkleSeed += 1
        SoundEngine.shared.play(for: "style.shimmer")
        switch shakes {
        case 4:  HapticEngine.send()        // 80 % — medium
        case 5:  break                      // 100 % handled by onFull (strong)
        default: HapticEngine.sendSoft()    // light tap
        }
    }

    /// 10 Hz: orbit the particles (faster when aimed/charged), run the
    /// full-charge auto-send countdown, and drive the no-motion fallback.
    private func heartbeat() {
        // Orbit speed: gentle idle, quicker within 15°, quicker still charged.
        let speed = (aligned ? 0.22 : 0.10) + charge * 0.25
        orbitPhase += speed

        guard loaded, !released else { return }

        // No accelerometer (Simulator): drift a little charge so it's still
        // reachable — but the real path is the tap-to-charge below.
        // (Intentionally no auto-charge — keeps the Simulator deliberate.)

        // Full charge + aimed → auto-send after 1 second of holding aligned.
        if charge >= 1 {
            if aligned {
                fullAlignedSeconds += 0.1
                if fullAlignedSeconds >= 1.0 { release() }
            } else {
                fullAlignedSeconds = 0   // charge holds; countdown waits
            }
        }
    }

    /// Tapping the crystal: charge it where there's no accelerometer, or
    /// release early once it's full and aimed.
    private func tapCrystal() {
        guard loaded, !released else { return }

        if charge >= 1 {
            if aligned {
                release()
            } else {
                flashAimHint()
            }
            return
        }

        // Below full: shake normally charges. Without motion hardware, the
        // crystal accepts taps so the wand still works in the Simulator.
        if !shake.motionAvailable {
            shake.holdCharge(1.0 / Double(ShakeDetector.shakesToFull))
        }
    }

    private func release() {
        guard !released else { return }
        released = true
        fullAlignedSeconds = 0
        HapticEngine.send()
        shake.stop()
        onSend()
    }

    private func flashAimHint() {
        HapticEngine.sendSoft()
        withAnimation { showAimHint = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { showAimHint = false }
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
