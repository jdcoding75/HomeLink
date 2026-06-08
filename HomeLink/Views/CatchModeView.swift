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

    private enum Phase { case seeking, locked, flying, revealed }
    @State private var phase: Phase = .seeking

    // Step 1 — orb life
    @State private var orbPulse  = false       // 0.8–1.0 opacity breathing
    @State private var jitter    = CGSize.zero // 1–3 px random drift
    // Step 3 — lock-on
    @State private var lockSnap  = false       // +10 % easeOutBack snap
    @State private var lockHeldSince: Date? = nil
    // Step 4 — catch flight
    @State private var flightProgress: CGFloat = 0
    // Step 5 — reveal
    @State private var bloomed     = false
    @State private var glowRadiate = false
    @State private var revealFlash = false     // shooting star variant
    // Step 6 — sender info
    @State private var named       = false
    @State private var debugBypass = false
    @State private var arrivalLine = false   // "A feeling is coming your way…"

    /// 10 Hz heartbeat: haptic bands, jitter drift, hold-to-confirm.
    private let tick = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    private var hue: Color { EmojiHue.color(for: ping.emoji) }
    private static let lavender = Color(hex: "#c4a8d4")
    private static let wandGold = Color(hex: "#D4AF37")
    private static let wandPurple = Color(hex: "#9b7fc0")

    // ── Alignment ─────────────────────────────────────────────────────────

    private var angleError: Double {
        // Indoors / Simulator: no heading means the catch can never happen —
        // treat as aligned rather than trapping the thought.
        guard compass.isHeadingAvailable else { return 0 }
        if debugBypass { return 0 }
        return BearingCalculator.alignmentError(relativeBearing: compass.state.bearingDegrees)
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

    var body: some View {
        GeometryReader { geo in
            let rad   = compass.state.bearingDegrees * .pi / 180
            let reach = min(geo.size.width, geo.size.height) * 0.46
            let edge  = CGSize(width: CGFloat(sin(rad)) * reach,
                               height: -CGFloat(cos(rad)) * reach)
            let control = CGSize(width: edge.width * 0.45 + CGFloat(cos(rad)) * 50,
                                 height: edge.height * 0.45 + CGFloat(sin(rad)) * 50 - 30)

            ZStack {
                // The room dims; the direction glows
                Color.black.opacity(0.45).ignoresSafeArea()
                RadialGradient(
                    colors: [hue.opacity(phase == .revealed ? 0.10 : 0.20), .clear],
                    center: UnitPoint(x: 0.5 + 0.62 * sin(rad),
                                      y: 0.5 - 0.62 * cos(rad)),
                    startRadius: 10, endRadius: 420
                )
                .ignoresSafeArea()

                // The arrival line — gentle, fades once you start aligning
                if phase == .seeking {
                    VStack {
                        Text("a feeling is coming your way…")
                            .font(.system(size: 14, design: .serif).italic())
                            .foregroundColor(Self.lavender.opacity(0.85))
                            .opacity(arrivalLine ? 1 : 0)
                            .padding(.top, 92)
                        Spacer()
                    }
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }

                // ── Steps 1–4: the orb (or streak, or firefly) ────────────
                if phase != .revealed {
                    orbView
                        .scaleEffect(phase == .flying ? 0.72 : orbGrowth * (lockSnap ? 1.1 : 1.0))
                        .animation(AnimationSystem.easeOutBack(AnimationSystem.Timing.lockOn),
                                   value: lockSnap)
                        .animation(AnimationSystem.easeInOutSine(0.3), value: orbGrowth)
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
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }

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

                        VStack(spacing: 16) {
                            Text(ping.emoji)
                                .font(.system(size: 76))
                                .scaleEffect(bloomed ? 1.0 : 0.3)
                                .opacity(bloomed ? 1 : 0)
                                .shadow(color: hue.opacity(0.55),
                                        radius: AnimationSystem.Glow.radiusMax)
                                .animation(AnimationSystem.easeOutBack(
                                    AnimationSystem.Timing.catchReveal), value: bloomed)

                            // Step 6 — sender info, serif italic
                            Text("\(ping.fromName) sent you something")
                                .font(.system(size: 15, design: .serif).italic())
                                .foregroundColor(Self.lavender)
                                .opacity(named ? 1 : 0)
                                .animation(.easeIn(duration: 0.4), value: named)
                        }
                    }
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }

                // Quiet guidance while seeking
                if phase == .seeking || phase == .locked {
                    VStack {
                        VStack(spacing: 4) {
                            Text("\(ping.fromName) sent you something")
                                .font(.system(size: 14, design: .serif).italic())
                                .foregroundColor(Self.lavender)
                            Text(phase == .locked
                                 ? "hold steady…"
                                 : "turn toward them to catch it")
                                .font(.system(size: 11))
                                .foregroundColor(DesignTokens.Color.textMuted)
                            #if DEBUG
                            Button("⚙︎ align (sim)") { debugBypass = true }
                                .font(.system(size: 9))
                                .foregroundColor(DesignTokens.Color.textDim)
                            #endif
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(DesignTokens.Color.backgroundLift.opacity(0.92))
                                .overlay(Capsule().stroke(Self.lavender.opacity(0.4), lineWidth: 1))
                        )
                        .padding(.top, 84)

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
        case .glow:
            // 40 px circle, warm glow matching the emoji hue,
            // 60 % opacity breathing 0.8–1.0, 900 ms cycle
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
                // The embedding point — a dark recess, glowing from within
                Circle()
                    .fill(Color.black.opacity(0.45))
                    .frame(width: 44, height: 44)
                Circle()
                    .stroke(hue.opacity(0.3 + orbBrightness * 0.5), lineWidth: 1.5)
                    .frame(width: 44, height: 44)
                    .shadow(color: hue.opacity(orbBrightness * 0.8),
                            radius: AnimationSystem.Glow.radiusMin)

                // Loose dust — small particles shake free as the grip loosens
                if angleError < 15 {
                    ForEach(0..<5, id: \.self) { i in
                        Circle()
                            .fill(hue.opacity(0.55))
                            .frame(width: 3, height: 3)
                            .offset(x: CGFloat(i - 2) * 9 + (orbPulse ? 2 : -2),
                                    y: CGFloat((i * 7) % 11) - 5 + (orbPulse ? -3 : 1))
                            .opacity(orbPulse ? 0.9 : 0.4)
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
        withAnimation(.easeIn(duration: 1.2).delay(0.4)) { arrivalLine = true }
        Self.log.info("catch: ACTIVATED — from=\(ping.fromName, privacy: .public) emoji=\(ping.emoji, privacy: .public) style=\(style.rawValue, privacy: .public) senderBearing=\(Int(compass.state.bearingDegrees), privacy: .public)° headingAvailable=\(compass.isHeadingAvailable, privacy: .public)")
        // Step 1 — the orb breathes (900 ms easeInOutSine cycle)
        withAnimation(AnimationSystem.easeInOutSine(AnimationSystem.Timing.glowPulseSlow)
                        .repeatForever(autoreverses: true)) {
            orbPulse = true
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

        // Step 3 — lock-on inside 5°, hold 0.5 s to confirm
        if angleError < 5 {
            if phase == .seeking {
                phase = .locked
                lockHeldSince = .now
                lockSnap = true                       // easeOutBack +10 %
                Self.log.info("catch: LOCKED ON (error=\(Int(angleError), privacy: .public)°) — holding 0.5 s")
                HapticEngine.lockOn()                 // clean medium tap
                DispatchQueue.main.asyncAfter(deadline: .now()
                                              + AnimationSystem.Timing.lockOn) {
                    lockSnap = false
                }
            } else if let since = lockHeldSince,
                      Date.now.timeIntervalSince(since) >= 0.5 {
                beginCatch()                          // Step 4
            }
        } else if phase == .locked {
            phase = .seeking                          // drifted off — try again
            lockHeldSince = nil
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

    /// Step 5 — the bloom. opened_at is set here: felt means felt.
    private func reveal() {
        Self.log.info("catch: REVEALED — marking felt (opened_at)")
        phase = .revealed
        onRevealed()
        HapticEngine.reveal()                          // success, as it blooms
        SoundEngine.shared.play(for: "style.bell")     // soft bell with shimmer
        SoundEngine.shared.play(for: ping.emoji)       // the thought's own voice

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

        // Step 6 — sender info fades in 200 ms after the reveal, stays 3 s
        DispatchQueue.main.asyncAfter(deadline: .now()
                                      + AnimationSystem.Timing.catchReveal + 0.2) {
            named = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now()
                                      + AnimationSystem.Timing.catchReveal + 0.2 + 3.0) {
            named = false
            onFinished()                               // Step 7 — rest in history
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
