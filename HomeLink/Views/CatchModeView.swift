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

    /// 10 Hz heartbeat: haptic bands, jitter drift, hold-to-confirm.
    private let tick = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    private var hue: Color { EmojiHue.color(for: ping.emoji) }
    private static let lavender = Color(hex: "#c4a8d4")

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
                        .animation(AnimationSystem.easeInOutCubic(style.catchTravelDuration),
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
            // A soft wandering light — drift grows directional as you align
            Circle()
                .fill(RadialGradient(colors: [Color(hex: "#90EE90").opacity(0.9),
                                              Color(hex: "#90EE90").opacity(0.3), .clear],
                                     center: .center, startRadius: 3, endRadius: 16))
                .frame(width: 28, height: 28)
                .blur(radius: 2)
                .opacity(orbBrightness * (orbPulse ? 1.0 : 0.8))
                .shadow(color: Color(hex: "#90EE90").opacity(0.4),
                        radius: AnimationSystem.Glow.radiusMax)

        case .fingerFlick:
            // A bouncing orb — the bounce is the personality. It quickens
            // with alignment (the shared pulse does), steadies inside 5°.
            Circle()
                .fill(RadialGradient(colors: [hue.opacity(0.95), hue.opacity(0.35), .clear],
                                     center: .center, startRadius: 4, endRadius: 20))
                .frame(width: 36, height: 36)
                .blur(radius: 1.5)
                .offset(y: angleError < 5 ? 0 : (orbPulse ? -4 : 4))
                .scaleEffect(angleError < 5 ? 1.0 : (orbPulse ? 1.05 : 0.95))
                .opacity(orbBrightness)
                .shadow(color: hue.opacity(AnimationSystem.Glow.opacityMax),
                        radius: AnimationSystem.Glow.radiusMax)

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
        }
    }

    // ── Sequencing ────────────────────────────────────────────────────────

    /// 1 Hz alignment trace (the 10 Hz heartbeat is too chatty for Console).
    @State private var lastAlignmentLog = Date.distantPast

    private func begin() {
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
    /// it releases and flies home.
    private func beginCatch() {
        Self.log.info("catch: CAUGHT — flying home (style=\(style.rawValue, privacy: .public))")
        phase = .flying
        jitter = .zero
        if style == .bowArrow {
            let rad = compass.state.bearingDegrees * .pi / 180
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
        flightProgress = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + style.catchTravelDuration) {
            reveal()
        }
    }

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
