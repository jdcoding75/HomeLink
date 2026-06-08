// CatchModeView.swift
// Pointward › Views
//
// THE CATCH — receiving becomes physical. Only the NEWEST incoming thought
// triggers catch mode (older ones rest in History).
//
//   1 · ORB APPEARS      a glowing orb at the compass edge, in the sender's
//                        direction — 40 px, emoji-hued, breathing, drifting
//   2 · ALIGNMENT        turn the phone toward them; the orb brightens and
//                        grows as the angle error shrinks (30° → 15° → 5°)
//                        with haptic pulses quickening underneath
//   3 · LOCK-ON          within 5°: easeOutBack snap +10 %, medium haptic,
//                        hold for 0.5 s to confirm
//   4 · CATCH            the orb flies edge → center on a curved arc
//   5 · REVEAL           the emoji blooms 0.3 → 1.0 easeOutBack, success
//                        haptic, warm glow radiates, soft bell
//   6 · SENDER INFO      "[name] sent you something" — serif italic, 3 s
//   7 · HISTORY          already saved (Supabase) — nothing to do
//
// Style variants: glow (free) follows the flow exactly; shooting star (pro)
// shows a streak and catches faster with a bright flash; firefly (pro)
// wanders near the edge, grows directional as you align, drifts home slowly.

import SwiftUI
import Combine
import os

struct CatchModeView: View {

    private static let log = Logger(subsystem: "com.jdcoding75.pointward", category: "catch")

    let ping: PingManager.ReceivedPing
    let style: SenderStyle
    /// Fired at the reveal moment — "felt" means felt (sets opened_at).
    let onRevealed: () -> Void
    /// The moment has fully landed (or the user chose later).
    let onFinished: () -> Void

    @EnvironmentObject var compass: CompassManager

    // [1/5] `.arriving` is the new dramatic entrance before the search begins.
    private enum Phase { case arriving, seeking, locked, flying, revealed }
    @State private var phase: Phase = .arriving

    // [1/5] Arrival — the full-screen entrance
    @State private var arrivalPulse  = false   // lavender wash 0 → 0.2 → 0
    @State private var arrivalDim    = false   // screen dims to ~85 %
    @State private var arrivalTextIn = false   // "something is coming your way ✦"
    @State private var orbEntered    = false   // orb scale 0 → 1 easeOutBack
    @State private var entranceGlow  = false   // glow radiates as the orb forms

    // Step 1 — orb life
    @State private var orbPulse  = false       // 0.8–1.0 opacity breathing
    @State private var jitter    = CGSize.zero // 1–3 px random drift
    // Step 3 — lock-on
    @State private var lockSnap  = false       // +10 % easeOutBack snap
    @State private var lockHeldSince: Date? = nil
    @State private var lockFlash   = false     // [3/5] white flash 0 → 0.6 → 0
    @State private var showLockStar = false    // [3/5] large ✦ at lock
    @State private var dimOthers   = false     // [3/5] everything but the orb → 60 %
    @State private var energyBuild = false     // [3/5] orb charges while held
    @State private var holdProgress: Double = 0
    // Step 4 — catch flight
    @State private var flightProgress: CGFloat = 0
    // Step 5 — reveal
    @State private var bloomed     = false
    @State private var glowRadiate = false
    @State private var revealFlash = false     // shooting star variant
    @State private var revealFlood = false     // [4/5] warm light flood
    @State private var revealScatter = false   // [4/5] particles scatter out
    // Step 6 — sender info
    @State private var named       = false
    @State private var debugBypass = false
    @State private var arrivalLine = false   // (legacy seeking line — kept)

    // 🪄 WAND full-screen sparkle storm (most dramatic receive)
    private struct StormSpark: Identifiable {
        let id = UUID()
        var scatter: CGSize
        var gold: Bool
        var size: CGFloat
    }
    @State private var sparks: [StormSpark] = []
    @State private var stormActive = false
    @State private var sparksScattered = false
    @State private var sparksConverged = false

    /// 10 Hz heartbeat: haptic bands, jitter drift, hold-to-confirm.
    private let tick = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    private var hue: Color { EmojiHue.color(for: ping.emoji) }
    private static let lavender = Color(hex: "#c4a8d4")
    private static let wandGold = Color(hex: "#D4AF37")
    private static let wandPurple = Color(hex: "#9b7fc0")
    private static let slingAmber = Color(hex: "#E8B64C")
    private static let slingOrange = Color(hex: "#e08a3c")

    // ── Alignment ─────────────────────────────────────────────────────────

    private var angleError: Double {
        // Indoors / Simulator: no heading means the catch can never happen —
        // treat as aligned rather than trapping the thought.
        guard compass.isHeadingAvailable else { return 0 }
        if debugBypass { return 0 }
        return BearingCalculator.alignmentError(relativeBearing: compass.state.bearingDegrees)
    }

    /// [2/5] The big bold catch instruction — encouraging directional guidance
    /// that updates as the user turns toward the sender: cardinal direction
    /// far out → "keep turning right" closer → "hold steady" on lock.
    private var catchInstruction: String {
        if phase == .locked { return "hold steady ✦" }
        switch angleError {
        case ..<15: return "nearly locked — hold steady"
        case ..<45: return "almost there — keep turning \(turnRight ? "right" : "left")"
        default:
            if let absolute = compass.rawBearingToTarget {
                return "\(ping.fromName) is to your \(Self.fullCardinal(absolute))"
            }
            return "turn \(turnRight ? "right" : "left") to find \(ping.fromName)"
        }
    }

    /// Which way to rotate the phone: the sender clockwise of straight-ahead
    /// (relative bearing 0…180) means turn right.
    private var turnRight: Bool {
        var b = compass.state.bearingDegrees.truncatingRemainder(dividingBy: 360)
        if b < 0 { b += 360 }
        return b < 180
    }

    /// A friendly full-word compass direction ("Northeast").
    private static func fullCardinal(_ degrees: Double) -> String {
        let words = ["North", "North-Northeast", "Northeast", "East-Northeast",
                     "East", "East-Southeast", "Southeast", "South-Southeast",
                     "South", "South-Southwest", "Southwest", "West-Southwest",
                     "West", "West-Northwest", "Northwest", "North-Northwest"]
        let i = ((Int((degrees / 22.5).rounded()) % 16) + 16) % 16
        return words[i]
    }

    /// Step 2 — visual feedback as the angle decreases.
    private var orbBrightness: Double {
        switch angleError {
        case ..<5:   return 1.0     // full brightness
        case ..<15:  return 0.78    // brightens more
        case ..<30:  return 0.62    // brightens slightly
        default:     return 0.42    // dim
        }
    }

    private var orbGrowth: CGFloat {
        switch angleError {
        case ..<5:   return 1.10    // grows 10 %
        case ..<15:  return 1.05    // grows 5 %
        default:     return 1.0
        }
    }

    /// How dark the room is. Gentle on arrival (85 % bright), the usual dim
    /// while searching, deep on lock (only the orb stays bright).
    private var bgDark: Double {
        if phase == .revealed { return 0.40 }
        if dimOthers          { return 0.72 }   // [3/5] lock: dim everything else
        if phase == .arriving { return arrivalDim ? 0.15 : 0 }
        return 0.45
    }

    var body: some View {
        GeometryReader { geo in
            let rad   = compass.state.bearingDegrees * .pi / 180
            let reach = min(geo.size.width, geo.size.height) * 0.46
            let edge  = CGSize(width: CGFloat(sin(rad)) * reach,
                               height: -CGFloat(cos(rad)) * reach)
            let control = CGSize(width: edge.width * 0.45 + CGFloat(cos(rad)) * 50,
                                 height: edge.height * 0.45 + CGFloat(sin(rad)) * 50 - 30)

            ZStack {
                // The room dims; the direction glows. The dim deepens on lock
                // so only the orb stays bright.
                Color.black.opacity(bgDark).ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.4), value: bgDark)
                RadialGradient(
                    colors: [hue.opacity(phase == .revealed ? 0.10 : 0.20), .clear],
                    center: UnitPoint(x: 0.5 + 0.62 * sin(rad),
                                      y: 0.5 - 0.62 * cos(rad)),
                    startRadius: 10, endRadius: 420
                )
                .ignoresSafeArea()

                // [1/5] ARRIVAL — a warm lavender wash floods the whole screen,
                // 0 → 0.2 → 0 over 800 ms. Impossible to miss.
                Color(hex: "#c4a8d4").opacity(arrivalPulse ? 0.2 : 0)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                // [1/5] ARRIVAL TEXT — large serif, dead center, 2 s, fades.
                if phase == .arriving {
                    Text("something is coming your way ✦")
                        .font(.system(size: 28, design: .serif))
                        .foregroundColor(Color(hex: "#e8e0f0"))
                        .multilineTextAlignment(.center)
                        .shadow(color: Self.lavender.opacity(0.6), radius: 12)
                        .padding(.horizontal, 30)
                        .opacity(arrivalTextIn ? 1 : 0)
                        .scaleEffect(arrivalTextIn ? 1 : 0.92)
                        .animation(.easeInOut(duration: 0.6), value: arrivalTextIn)
                        .allowsHitTesting(false)
                }

                // [1/5] ORB ENTRANCE GLOW — a warm ring radiates outward as
                // the orb materializes at the sender's edge.
                if phase == .seeking || phase == .locked {
                    Circle()
                        .stroke(hue.opacity(entranceGlow ? 0 : 0.6), lineWidth: 3)
                        .frame(width: 60, height: 60)
                        .scaleEffect(entranceGlow ? 3.0 : 0.4)
                        .animation(.easeOut(duration: 0.6), value: entranceGlow)
                        .position(x: geo.size.width / 2 + edge.width,
                                  y: geo.size.height / 2 + edge.height)
                        .allowsHitTesting(false)
                }

                // ── Steps 1–4: the orb (or streak, or firefly) ────────────
                // The orb makes a dramatic entrance (scale 0 → 1, easeOutBack),
                // grows as you approach, freezes + charges on lock, then flies.
                if phase != .revealed && phase != .arriving {
                    orbView
                        .scaleEffect(phase == .flying ? 0.72 : orbGrowth * (lockSnap ? 1.1 : 1.0))
                        .scaleEffect(energyBuild ? 1.18 : 1.0)            // [3/5] charge swell
                        .scaleEffect(orbEntered ? 1 : 0.01)              // [1/5] entrance
                        .animation(AnimationSystem.easeOutBack(0.5), value: orbEntered)
                        .animation(AnimationSystem.easeOutBack(AnimationSystem.Timing.lockOn),
                                   value: lockSnap)
                        .animation(AnimationSystem.easeInOutSine(0.3), value: orbGrowth)
                        .animation(AnimationSystem.easeInOutSine(0.5), value: energyBuild)
                        .offset(jitter)
                        .modifier(CurvedFlightEffect(progress: flightProgress,
                                                     start: edge, control: control,
                                                     end: .zero))
                        // The flick stages its own flight (pull free →
                        // bounce → land), so it animates explicitly
                        .animation(style == .fingerFlick
                                   ? nil
                                   : AnimationSystem.easeInOutCubic(style.catchTravelDuration),
                                   value: flightProgress)
                        // CurvedFlightEffect already places the orb at the edge
                        // (start) and flies it to center (end) via progress.
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }

                // ── 🪄 WAND sparkle storm — over everything, then converges
                // to the sender edge to become the catch orb ──
                if stormActive {
                    ForEach(sparks) { spark in
                        let pos: CGSize = sparksConverged ? edge
                                        : (sparksScattered ? spark.scatter : .zero)
                        Circle()
                            .fill(spark.gold ? Self.wandGold : Self.wandPurple)
                            .frame(width: spark.size, height: spark.size)
                            .shadow(color: (spark.gold ? Self.wandGold : Self.wandPurple).opacity(0.8),
                                    radius: 3)
                            .position(x: geo.size.width / 2 + pos.width,
                                      y: geo.size.height / 2 + pos.height)
                            .opacity(sparksConverged ? 0.35 : 0.95)
                    }
                    .zIndex(10)
                }

                // [4/5] WARM LIGHT FLOOD — the whole screen floods with warm
                // light as the emoji blooms, 0 → 0.15 → 0 over 400 ms.
                Color(hex: "#fff3d8").opacity(revealFlood ? 0.15 : 0)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                // ── Step 5: the reveal ────────────────────────────────────
                if phase == .revealed {
                    ZStack {
                        // Warm glow radiating outward and fading
                        Circle()
                            .stroke(hue.opacity(glowRadiate ? 0 : 0.5), lineWidth: 2)
                            .frame(width: 90, height: 90)
                            .scaleEffect(glowRadiate ? 2.8 : 0.5)
                            .animation(AnimationSystem.easeOutCubic(0.9), value: glowRadiate)
                        Circle()
                            .fill(hue.opacity(glowRadiate ? 0 : 0.25))
                            .frame(width: 110, height: 110)
                            .blur(radius: AnimationSystem.Glow.radiusMax)
                            .animation(.easeOut(duration: 1.1), value: glowRadiate)

                        // [4/5] Bloom particle scatter — 16 hued/gold sparks
                        // bursting outward as the emoji appears.
                        ForEach(0..<16, id: \.self) { i in
                            let a = Double(i) / 16 * 2 * .pi
                            let dist: CGFloat = revealScatter ? 150 + CGFloat(i % 4) * 22 : 0
                            Circle()
                                .fill(i % 2 == 0 ? hue : Color(hex: "#FFD700"))
                                .frame(width: 5, height: 5)
                                .offset(x: CGFloat(cos(a)) * dist, y: CGFloat(sin(a)) * dist)
                                .opacity(revealScatter ? 0 : 0.9)
                                .animation(.easeOut(duration: 0.9), value: revealScatter)
                        }

                        // Shooting star: 100 ms bright flash, then the emoji
                        if style == .shootingStar {
                            Circle()
                                .fill(RadialGradient(colors: [.white.opacity(0.9), .clear],
                                                     center: .center,
                                                     startRadius: 4, endRadius: 60))
                                .frame(width: 120, height: 120)
                                .opacity(revealFlash ? 0 : 1)
                                .animation(.easeOut(duration: 0.1), value: revealFlash)
                        }

                        VStack(spacing: 14) {
                            // [4/5] The emoji stays LARGE — 72 pt, the peak.
                            Text(ping.emoji)
                                .font(.system(size: 72))
                                .scaleEffect(bloomed ? 1.0 : 0.3)
                                .opacity(bloomed ? 1 : 0)
                                .shadow(color: hue.opacity(0.6),
                                        radius: AnimationSystem.Glow.radiusMax)
                                .animation(AnimationSystem.easeOutBack(
                                    AnimationSystem.Timing.catchReveal), value: bloomed)

                            // The sender's tagline — their voice, italic lavender.
                            if let tagline = ping.tagline, !tagline.isEmpty {
                                Text(tagline)
                                    .font(.system(size: 16, design: .serif).italic())
                                    .foregroundColor(Self.lavender.opacity(0.85))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                                    .opacity(bloomed ? 1 : 0)
                                    .animation(.easeIn(duration: 0.5).delay(0.15), value: bloomed)
                            }

                            // [5/5] The attached message — prominent, 18 pt serif.
                            if let message = ping.message, !message.isEmpty {
                                Text("“\(message)”")
                                    .font(.system(size: 18, design: .serif).italic())
                                    .foregroundColor(DesignTokens.Color.textPrimary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                                    .opacity(bloomed ? 1 : 0)
                                    .animation(.easeIn(duration: 0.5).delay(0.3), value: bloomed)
                            }

                            // Aftermath — "from [name] ✦" rests beneath it all.
                            Text("from \(ping.fromName) ✦")
                                .font(.system(size: 17, design: .serif).italic())
                                .foregroundColor(Self.lavender)
                                .opacity(named ? 1 : 0)
                                .animation(.easeIn(duration: 0.5), value: named)
                        }
                    }
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }

                // [3/5] LOCK FLASH — a bright white flash at the lock moment,
                // 0 → 0.6 → 0 over ~100 ms.
                Color.white.opacity(lockFlash ? 0.6 : 0)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                // [3/5] The big ✦ that appears and fades at the lock.
                if showLockStar {
                    Text("✦")
                        .font(.system(size: 120, weight: .thin))
                        .foregroundColor(.white)
                        .shadow(color: Self.lavender.opacity(0.9), radius: 20)
                        .scaleEffect(showLockStar ? 1.0 : 0.4)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        .allowsHitTesting(false)
                }

                // [4/5] Big, bold guidance — tells you exactly what to do,
                // 2× the old size, updating as you turn toward the sender.
                if phase == .seeking || phase == .locked {
                    VStack {
                        VStack(spacing: 6) {
                            Text("\(ping.fromName) sent you something")
                                .font(.system(size: 13, design: .serif).italic())
                                .foregroundColor(Self.lavender.opacity(0.8))
                            Text(catchInstruction)
                                .font(.system(size: 24, weight: .bold, design: .serif))
                                .foregroundColor(angleError < 15 ? Self.lavender : DesignTokens.Color.textPrimary)
                                .multilineTextAlignment(.center)
                                .shadow(color: Self.lavender.opacity(angleError < 5 ? 0.7 : 0), radius: 10)
                                .animation(.easeInOut(duration: 0.25), value: catchInstruction)
                            #if DEBUG
                            Button("⚙︎ align (sim)") { debugBypass = true }
                                .font(.system(size: 9))
                                .foregroundColor(DesignTokens.Color.textDim)
                            #endif
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(DesignTokens.Color.backgroundLift.opacity(0.92))
                                .overlay(RoundedRectangle(cornerRadius: 18)
                                    .stroke(Self.lavender.opacity(0.4), lineWidth: 1))
                        )
                        .padding(.top, 76)
                        .padding(.horizontal, 24)

                        Spacer()

                        // The escape hatch — the thought rests in History
                        Button("later · it keeps") { onFinished() }
                            .font(.system(size: 11, design: .serif).italic())
                            .foregroundColor(DesignTokens.Color.textMuted)
                            .padding(.bottom, 30)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                // After the moment lands a tap moves on; before that the
                // catch is physical, not tappable.
                if phase == .revealed { onFinished() }
            }
        }
        .onAppear { begin() }
        .onReceive(tick) { _ in heartbeat() }
    }

    // ── The orb, per style ────────────────────────────────────────────────

    @ViewBuilder
    private var orbView: some View {
        switch style {
        case .glow, .plane:
            // 40 px circle, warm glow matching the emoji hue,
            // 60 % opacity breathing 0.8–1.0, 900 ms cycle (plane shares it)
            Circle()
                .fill(RadialGradient(colors: [hue.opacity(0.9), hue.opacity(0.3), .clear],
                                     center: .center, startRadius: 4, endRadius: 22))
                .frame(width: 40, height: 40)
                .blur(radius: 2)
                .opacity(orbBrightness * (orbPulse ? 1.0 : 0.8))
                .shadow(color: hue.opacity(AnimationSystem.Glow.opacityMax),
                        radius: AnimationSystem.Glow.radiusMax)

        case .shootingStar:
            // A streak of light, elongated comet shape, pulsing brightness
            Capsule()
                .fill(LinearGradient(colors: [.white, Color(hex: "#FFD700").opacity(0.8), .clear],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 46, height: 10)
                .blur(radius: 1.5)
                .rotationEffect(.radians(compass.state.bearingDegrees * .pi / 180 - .pi / 2))
                .opacity(orbBrightness * (orbPulse ? 1.0 : 0.75))
                .shadow(color: Color(hex: "#FFD700").opacity(0.4),
                        radius: AnimationSystem.Glow.radiusMax)

        case .firefly:
            // 🌬️ WIND — not one light but a soft cloud of breath. Barely
            // visible dots at the edge gather and brighten as you align,
            // swirl inward on lock, and converge into the bloom. Like
            // breath on cold air.
            WindCatchCloud(angleError: angleError,
                           pulse: orbPulse,
                           locked: phase == .locked || phase == .flying)
                .opacity(orbBrightness)

        case .fingerFlick:
            // EMBEDDED — the thought arrived so fast it's stuck in the wall
            // at the sender's edge. It loosens as you align, strains and
            // vibrates inside 5°, and the catch PULLS it free.
            // (previous bouncing orb retired)
            ZStack {
                // Slingshot energy — it hit the wall like a launched stone,
                // ringed in an orange/amber glow.
                Circle()
                    .fill(RadialGradient(colors: [Self.slingAmber.opacity(0.5 * orbBrightness),
                                                  .clear],
                                         center: .center, startRadius: 2, endRadius: 34))
                    .frame(width: 68, height: 68)
                    .blur(radius: 3)

                // The embedding point — a dark recess, glowing from within
                Circle()
                    .fill(Color.black.opacity(0.45))
                    .frame(width: 44, height: 44)
                Circle()
                    .stroke(Self.slingAmber.opacity(0.4 + orbBrightness * 0.5), lineWidth: 1.5)
                    .frame(width: 44, height: 44)
                    .shadow(color: Self.slingOrange.opacity(orbBrightness * 0.8),
                            radius: AnimationSystem.Glow.radiusMin)

                // Elastic snap particles — flicked free, amber/orange embers
                if angleError < 15 {
                    ForEach(0..<6, id: \.self) { i in
                        Circle()
                            .fill((i % 2 == 0 ? Self.slingAmber : Self.slingOrange).opacity(0.7))
                            .frame(width: i % 2 == 0 ? 3 : 4, height: i % 2 == 0 ? 3 : 4)
                            .offset(x: CGFloat(i - 3) * 9 + (orbPulse ? 3 : -3),
                                    y: CGFloat((i * 7) % 13) - 6 + (orbPulse ? -4 : 2))
                            .opacity(orbPulse ? 0.95 : 0.4)
                            .transition(.opacity)
                    }
                }

                // The thought — recessed, half-swallowed, straining
                Text(ping.emoji)
                    .font(.system(size: 26))
                    .scaleEffect(0.9)
                    .opacity(0.55 + orbBrightness * 0.45)
                    // STRAIN — visible vibration inside 5°, dying to be free
                    .offset(x: angleError < 5 ? (orbPulse ? 1.5 : -1.5) : 0,
                            y: angleError < 5 ? (orbPulse ? -1.0 : 1.0) : 0)
                    .shadow(color: hue.opacity(orbBrightness),
                            radius: AnimationSystem.Glow.radius)
            }

        case .bowArrow:
            // An arrow stuck in the compass face — shaft showing more as
            // you align, gold-bright inside 5°.
            HStack(spacing: 0) {
                Capsule()
                    .fill(Color(hex: "#E8B64C").opacity(angleError < 15 ? 0.9 : 0.45))
                    .frame(width: angleError < 15 ? 22 : 13, height: 3)
                Triangle()
                    .fill(angleError < 5 ? Color(hex: "#FFD700") : Color(hex: "#E8B64C"))
                    .frame(width: 9, height: 11)
                    .rotationEffect(.degrees(90))
            }
            // Embedded pointing inward, toward the center
            .rotationEffect(.radians(compass.state.bearingDegrees * .pi / 180 + .pi / 2))
            .opacity(orbBrightness * (orbPulse ? 1.0 : 0.7))
            .shadow(color: Color(hex: "#FFD700").opacity(angleError < 5 ? 0.7 : 0.3),
                    radius: AnimationSystem.Glow.radiusMax)

        case .rocket:
            // 🚀 An incoming rocket — nose pointed inward along the bearing,
            // flame and brightness swelling as you align, gold inside 5°.
            VStack(spacing: 0) {
                Text("🚀")
                    .font(.system(size: 30))
                Capsule()
                    .fill(LinearGradient(colors: [Color(hex: "#FFD700"),
                                                  Color(hex: "#e0622c"), .clear],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 8, height: angleError < 5 ? 18 : (angleError < 15 ? 11 : 5))
                    .blur(radius: 1)
                    .opacity(orbPulse ? 1.0 : 0.6)
            }
            .rotationEffect(.radians(compass.state.bearingDegrees * .pi / 180))
            .opacity(orbBrightness * (orbPulse ? 1.0 : 0.7))
            .shadow(color: Color(hex: "#FFD700").opacity(angleError < 5 ? 0.7 : 0.3),
                    radius: AnimationSystem.Glow.radiusMax)

        case .wand:
            // 🪄 An incoming trail of magic — a soft gold/purple glow with
            // sparkles that gather and brighten as you align, rushing to a
            // bright point inside 5°.
            ZStack {
                // The core glow — emoji-hued, swelling toward lock
                Circle()
                    .fill(RadialGradient(colors: [hue.opacity(0.9),
                                                  Self.wandPurple.opacity(0.4), .clear],
                                         center: .center, startRadius: 2,
                                         endRadius: angleError < 5 ? 24 : 14))
                    .frame(width: 44, height: 44)
                    .blur(radius: 2)

                // Gold/purple sparkles — more appear and tighten as you align
                let sparkleCount = angleError < 5 ? 8 : (angleError < 15 ? 5 : 3)
                let sparkleR: CGFloat = angleError < 5 ? 9 : (angleError < 15 ? 16 : 24)
                ForEach(0..<sparkleCount, id: \.self) { i in
                    let a = Double(i) / Double(sparkleCount) * 2 * .pi
                        + (orbPulse ? 0.2 : -0.2)
                    Circle()
                        .fill(i % 2 == 0 ? Self.wandGold : Self.wandPurple)
                        .frame(width: 3, height: 3)
                        .blur(radius: 0.5)
                        .offset(x: CGFloat(cos(a)) * sparkleR,
                                y: CGFloat(sin(a)) * sparkleR)
                        .shadow(color: Self.wandGold.opacity(0.5), radius: 2)
                }
            }
            .opacity(orbBrightness * (orbPulse ? 1.0 : 0.75))
            .shadow(color: Self.wandPurple.opacity(angleError < 5 ? 0.8 : 0.4),
                    radius: AnimationSystem.Glow.radiusMax)
        }
    }

    // ── Sequencing ────────────────────────────────────────────────────────

    /// 1 Hz alignment trace (the 10 Hz heartbeat is too chatty for Console).
    @State private var lastAlignmentLog = Date.distantPast

    private func begin() {
        Self.log.info("catch: ACTIVATED — from=\(ping.fromName, privacy: .public) emoji=\(ping.emoji, privacy: .public) style=\(style.rawValue, privacy: .public) senderBearing=\(Int(compass.state.bearingDegrees), privacy: .public)° headingAvailable=\(compass.isHeadingAvailable, privacy: .public)")

        // [1/5] ARRIVAL — strong double haptic + a warm welcoming chime fire
        // immediately, the whole screen washes lavender, and "something is
        // coming your way ✦" fades in for 2 seconds.
        phase = .arriving
        HapticEngine.catchArrival()
        SoundEngine.shared.play(for: "catch.arrival")
        // Full-screen lavender pulse: 0 → 0.2 (400 ms) → 0 (400 ms)
        withAnimation(.easeOut(duration: 0.4)) { arrivalPulse = true }
        withAnimation(.easeInOut(duration: 0.5)) { arrivalDim = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeIn(duration: 0.4)) { arrivalPulse = false }
        }
        // The arrival text blooms in, holds, then fades
        withAnimation(.easeInOut(duration: 0.6).delay(0.15)) { arrivalTextIn = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeInOut(duration: 0.5)) { arrivalTextIn = false }
        }
        // After the text fades, the orb makes its dramatic entrance and the
        // search begins.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { enterSeeking() }
    }

    /// [1/5] The orb's dramatic entrance + the start of the search.
    private func enterSeeking() {
        guard phase == .arriving else { return }
        phase = .seeking
        withAnimation(.easeInOut(duration: 0.4)) { arrivalDim = false }
        // The orb breathes (900 ms easeInOutSine cycle)
        withAnimation(AnimationSystem.easeInOutSine(AnimationSystem.Timing.glowPulseSlow)
                        .repeatForever(autoreverses: true)) {
            orbPulse = true
        }
        // Dramatic entrance — the orb expands from nothing with a radiating
        // glow ring + a soft arrival pop.
        SoundEngine.shared.play(for: "catch.lock")
        withAnimation(.easeOut(duration: 0.6)) { entranceGlow = true }
        withAnimation(AnimationSystem.easeOutBack(0.5)) { orbEntered = true }
        // 🪄 WAND — a full-screen sparkle storm bursts everywhere, then the
        // sparks converge to the sender's edge and form the catch orb.
        if style == .wand { beginWandStorm() }
    }

    /// 50+ gold/purple sparks scatter across the whole screen for ~2 s, then
    /// stream to the sender's bearing edge where the catch orb waits.
    private func beginWandStorm() {
        HapticEngine.thoughtArrived()
        SoundEngine.shared.play(for: "style.shimmer")
        sparks = (0..<72).map { _ in
            StormSpark(scatter: CGSize(width: .random(in: -300...300),
                                       height: .random(in: -540...540)),
                       gold: Bool.random(),
                       size: .random(in: 3...7))
        }
        stormActive = true
        withAnimation(.easeOut(duration: 0.45)) { sparksScattered = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            HapticEngine.lockOn()
            withAnimation(.easeIn(duration: 0.55)) { sparksConverged = true }   // converge faster
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeOut(duration: 0.35)) { stormActive = false }
        }
    }

    /// 10 Hz: haptic bands, drift, lock-hold confirmation.
    private func heartbeat() {
        guard phase == .seeking || phase == .locked else { return }

        // Real-time alignment trace, throttled to 1 Hz
        if Date.now.timeIntervalSince(lastAlignmentLog) >= 1.0 {
            lastAlignmentLog = .now
            Self.log.debug("catch: aligning — bearing=\(Int(compass.state.bearingDegrees), privacy: .public)° error=\(Int(angleError), privacy: .public)° phase=\(String(describing: phase), privacy: .public)")
        }

        // Step 2 — haptic pulses quicken as the angle error shrinks
        HapticEngine.catchAlignment(angleError: angleError)

        // Slight random drift — fireflies wander further until you align
        if Int.random(in: 0..<5) == 0 {
            let amplitude: CGFloat = style == .firefly
                ? max(2, 9 * CGFloat(min(angleError, 30) / 30))   // directional as you close in
                : 3
            withAnimation(AnimationSystem.easeInOutSine(0.5)) {
                jitter = CGSize(width: .random(in: -amplitude...amplitude),
                                height: .random(in: -amplitude...amplitude))
            }
        }

        // [3/5] LOCK-ON inside 5° — the most satisfying click in the app.
        // Everything happens at once: a strong snap, the orb freezes, a white
        // flash, a big ✦, a clean click, and everything else dims to 60 % so
        // only the locked orb glows. Hold 0.5 s while it charges → the catch.
        if angleError < 5 {
            if phase == .seeking {
                phase = .locked
                lockHeldSince = .now
                holdProgress = 0
                lockSnap = true                       // easeOutBack snap
                Self.log.info("catch: LOCKED ON (error=\(Int(angleError), privacy: .public)°) — holding 0.5 s")
                HapticEngine.catchLock()              // the satisfying snap
                SoundEngine.shared.play(for: "catch.lock")
                withAnimation(.easeOut(duration: 0.05)) { lockFlash = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeOut(duration: 0.1)) { lockFlash = false }
                }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { showLockStar = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    withAnimation(.easeOut(duration: 0.3)) { showLockStar = false }
                }
                withAnimation(.easeOut(duration: 0.3)) { dimOthers = true }
                withAnimation(.easeInOut(duration: 0.6)) { energyBuild = true }
                DispatchQueue.main.asyncAfter(deadline: .now()
                                              + AnimationSystem.Timing.lockOn) {
                    lockSnap = false
                }
            } else if let since = lockHeldSince {
                // Hold to confirm — the orb charges with quickening pulses.
                holdProgress = min(1, Date.now.timeIntervalSince(since) / 0.5)
                HapticEngine.catchHold(holdProgress)
                if holdProgress >= 1 { beginCatch() }   // Step 4
            }
        } else if phase == .locked {
            phase = .seeking                          // drifted off — try again
            lockHeldSince = nil
            holdProgress = 0
            withAnimation(.easeOut(duration: 0.3)) {
                dimOthers = false
                energyBuild = false
            }
        }
    }

    /// Step 4 — the orb flies home on a curved arc, shrinking slightly.
    /// Bow & arrow first gets PULLED OUT — a 5 px outward slide — before
    /// it releases and flies home. The flick gets the full PULL-FREE:
    /// strain outward 10 px, pop loose, fly home with one mid-flight
    /// bounce, land with an easeOutBack pop.
    private func beginCatch() {
        Self.log.info("catch: CAUGHT — flying home (style=\(style.rawValue, privacy: .public))")
        phase = .flying
        jitter = .zero
        let rad = compass.state.bearingDegrees * .pi / 180

        if style == .bowArrow {
            withAnimation(.easeOut(duration: 0.12)) {
                jitter = CGSize(width: CGFloat(sin(rad)) * 5,
                                height: -CGFloat(cos(rad)) * 5)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                jitter = .zero
                flightProgress = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15 + style.catchTravelDuration) {
                reveal()
            }
            return
        }

        if style == .fingerFlick {
            // PULL FREE — strains 10 px outward…
            withAnimation(.easeOut(duration: 0.16)) {
                jitter = CGSize(width: CGFloat(sin(rad)) * 10,
                                height: -CGFloat(cos(rad)) * 10)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                // …then POPS loose
                HapticEngine.sendImpact()                 // the satisfying pop
                jitter = .zero
                withAnimation(AnimationSystem.easeOutCubic(0.22)) {
                    flightProgress = 0.55                 // first leg, fast
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.44) {
                withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) {
                    flightProgress = 0.47                 // one bounce mid-flight
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.64) {
                withAnimation(AnimationSystem.easeInOutCubic(0.26)) {
                    flightProgress = 1                    // lands at center
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.94) {
                reveal()                                  // easeOutBack pop bloom
            }
            return
        }

        if style == .rocket {
            // 🚀 LANDING SEQUENCE — engines roar on lock, the rocket descends
            // to the pad with retro 3·2·1 beeps, the flame cuts out just
            // before touchdown, then a soft thud as it sets down.
            HapticEngine.rocketLaunch()                    // engines roar
            withAnimation(AnimationSystem.easeInOutCubic(style.catchTravelDuration)) {
                flightProgress = 1
            }
            for k in 0..<3 {                               // retro beeps 3 · 2 · 1
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(k) * 0.22) {
                    SoundEngine.shared.play(for: "rocket.countdown")
                    HapticEngine.rocketCountdown()
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + style.catchTravelDuration - 0.2) {
                SoundEngine.shared.play(for: "rocket.landing")   // flame cuts → glide
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + style.catchTravelDuration) {
                HapticEngine.rocketLanding()               // touchdown thud
                reveal()                                   // porthole glows, emoji ejects
            }
            return
        }

        flightProgress = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + style.catchTravelDuration) {
            reveal()
        }
    }

    // (WindCatchCloud lives below the main view)

    /// [4/5] THE REVEAL — the emotional peak. The emoji blooms, the screen
    /// floods warm light, the strongest haptic in the app fires, the warmest
    /// sound plays, and particles burst outward. opened_at is set here: felt
    /// means felt.
    private func reveal() {
        Self.log.info("catch: REVEALED — marking felt (opened_at)")
        phase = .revealed
        onRevealed()
        withAnimation(.easeOut(duration: 0.3)) { dimOthers = false }   // lift the lock dim
        HapticEngine.catchReveal()                     // the strongest moment
        SoundEngine.shared.play(for: "style.bell")     // warm bell with shimmer
        SoundEngine.shared.play(for: ping.emoji)       // the thought's own voice

        // [4/5] Warm light floods the screen, 0 → 0.15 → 0 over 400 ms.
        withAnimation(.easeOut(duration: 0.2)) { revealFlood = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeIn(duration: 0.2)) { revealFlood = false }
        }

        if style == .shootingStar {
            // Bright flash 100 ms, then the emoji appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                revealFlash = true
                bloomed = true
            }
        } else {
            bloomed = true
        }
        glowRadiate = true
        revealScatter = true                           // particles burst outward

        // [5/5] AFTERMATH — "from [name]" fades in beneath the large emoji,
        // which rests on screen so the moment can land. Tap (or wait) to keep.
        DispatchQueue.main.asyncAfter(deadline: .now()
                                      + AnimationSystem.Timing.catchReveal + 0.25) {
            named = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now()
                                      + AnimationSystem.Timing.catchReveal + 0.25 + 4.2) {
            named = false
            onFinished()                               // rest in history
        }
    }
}

// ════════════════════════════════════════════════════════════════════════
// MARK: - WindCatchCloud
// ════════════════════════════════════════════════════════════════════════

/// The wind instrument's catch — a soft cloud of breath rather than a single
/// orb. Six faint dots hang at the edge; as the angle closes more appear and
/// brighten, drifting directionally toward center; on lock they swirl inward
/// in a slow circle. Lavender and warm white, barely-there — breath on cold
/// air. The surrounding catch machinery flies the whole cloud home and
/// blooms the emoji at center.
private struct WindCatchCloud: View {

    let angleError: Double
    let pulse: Bool
    let locked: Bool

    private static let lavender  = Color(hex: "#c4a8d4")
    private static let warmWhite = Color(hex: "#f2ecf8")

    /// More breath gathers as you align: 6 far out, up to 12 once close.
    private var count: Int {
        switch angleError {
        case ..<5:  return 12
        case ..<15: return 9
        default:    return 6
        }
    }

    /// The cloud tightens as you align and swirls in on lock.
    private var radius: CGFloat {
        if locked { return 9 }
        switch angleError {
        case ..<5:  return 16
        case ..<15: return 22
        default:    return 30
        }
    }

    @State private var swirl = false

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                let base = Double(i) / Double(count) * 2 * .pi
                // On lock the whole ring rotates (the inward swirl); before
                // that each dot breathes gently in place.
                let angle = base + (swirl ? .pi * 1.4 : 0) + (pulse ? 0.18 : -0.18)
                let r = radius * (pulse ? 1.05 : 0.92)
                Circle()
                    .fill((i % 2 == 0 ? Self.warmWhite : Self.lavender)
                            .opacity(locked ? 0.9 : (0.32 + (pulse ? 0.18 : 0))))
                    .frame(width: i % 3 == 0 ? 4 : 3, height: i % 3 == 0 ? 4 : 3)
                    .blur(radius: 1)
                    .offset(x: CGFloat(cos(angle)) * r,
                            y: CGFloat(sin(angle)) * r)
                    .shadow(color: Self.lavender.opacity(locked ? 0.6 : 0.2),
                            radius: locked ? 5 : 2)
                    .animation(AnimationSystem.easeInOutSine(locked ? 0.4 : 0.8),
                               value: angle)
                    .animation(AnimationSystem.easeInOutSine(0.4), value: radius)
            }
        }
        .onChange(of: locked) { _, isLocked in
            if isLocked {
                withAnimation(AnimationSystem.easeInOutSine(0.7)
                                .repeatForever(autoreverses: false)) {
                    swirl = true
                }
            } else {
                swirl = false
            }
        }
    }
}
