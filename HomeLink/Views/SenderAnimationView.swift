// SenderAnimationView.swift
// Pointward › Views
//
// The send made visible — three personalities for one gesture:
//
//   GLOW (free)          350 ms · curved arc · soft hue-derived trail
//   SHOOTING STAR (pro)  300 ms · dramatic sweep · gold comet tail · edge flash
//   FIREFLY (pro)        ~1.2 s · organic wandering drift · pulsing orb
//
// Every path is a curve (never a straight line), every glow is soft and
// diffused, every particle is a circle (never a star). Also home to the
// replay overlay (history → memory) and the sender-caught confirmation
// (a warm symbolic moment, no text).

import SwiftUI

// ════════════════════════════════════════════════════════════════════════
// MARK: - Curved flight geometry
// ════════════════════════════════════════════════════════════════════════

/// Moves a view along a quadratic Bézier — the "always curved, never
/// straight" rule lives here. Offsets are relative to the view's resting
/// position.
struct CurvedFlightEffect: GeometryEffect {
    var progress: CGFloat
    var start:   CGSize
    var control: CGSize
    var end:     CGSize

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let t  = progress
        let mt = 1 - t
        let x = mt * mt * start.width  + 2 * mt * t * control.width  + t * t * end.width
        let y = mt * mt * start.height + 2 * mt * t * control.height + t * t * end.height
        return ProjectionTransform(CGAffineTransform(translationX: x, y: y))
    }
}

/// Cubic variant for the firefly's wandering, two-bend drift.
struct WanderingFlightEffect: GeometryEffect {
    var progress: CGFloat
    var start:    CGSize
    var control1: CGSize
    var control2: CGSize
    var end:      CGSize

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let t  = progress
        let mt = 1 - t
        let x = mt * mt * mt * start.width
              + 3 * mt * mt * t * control1.width
              + 3 * mt * t * t * control2.width
              + t * t * t * end.width
        let y = mt * mt * mt * start.height
              + 3 * mt * mt * t * control1.height
              + 3 * mt * t * t * control2.height
              + t * t * t * end.height
        return ProjectionTransform(CGAffineTransform(translationX: x, y: y))
    }
}

// ════════════════════════════════════════════════════════════════════════
// MARK: - SenderAnimationView
// ════════════════════════════════════════════════════════════════════════

/// Plays one send from the compass center toward the screen edge in the
/// real compass direction, in the chosen style, then calls `onComplete`.
struct SenderAnimationView<Symbol: View>: View {

    let style: SenderStyle
    /// Resolved emoji (custom thoughts/gecko already mapped) — drives the
    /// hue of every glow and trail so the light belongs to the thought.
    let emoji: String
    let bearingDegrees: Double
    /// What actually flies (emoji text, gecko view, custom thought…).
    let symbol: Symbol
    let onComplete: () -> Void

    @State private var progress: CGFloat = 0
    @State private var squashed   = true     // 105 % on launch → 100 %
    @State private var faded      = false
    @State private var orbPulse   = false    // firefly breathing
    @State private var edgeFlash  = false    // shooting star landing

    // Wander offsets are frozen once per flight so the drift doesn't reroll
    @State private var wander1 = CGSize(width: .random(in: -70...70),
                                        height: .random(in: -70...10))
    @State private var wander2 = CGSize(width: .random(in: -70...70),
                                        height: .random(in: -60...20))

    private var hue: Color { EmojiHue.color(for: emoji) }

    private var rad: Double { bearingDegrees * .pi / 180 }

    /// Where the flight ends — past the visible edge along the bearing.
    private func endOffset(in geo: GeometryProxy) -> CGSize {
        let reach = max(geo.size.width, geo.size.height) * 0.62
        return CGSize(width: CGFloat(sin(rad)) * reach,
                      height: -CGFloat(cos(rad)) * reach)
    }

    /// Slight upward curve then to the edge — never a straight line.
    private func controlOffset(for end: CGSize, drama: CGFloat) -> CGSize {
        // Perpendicular to the travel direction, plus a small upward bias.
        let perp = CGSize(width: CGFloat(cos(rad)), height: CGFloat(sin(rad)))
        return CGSize(width: end.width * 0.45 + perp.width * drama,
                      height: end.height * 0.45 + perp.height * drama - 36)
    }

    var body: some View {
        GeometryReader { geo in
            let end = endOffset(in: geo)
            ZStack {
                switch style {
                case .glow:         glowSend(end: end)
                case .shootingStar: shootingStarSend(end: end)
                case .firefly:      fireflySend(end: end)
                }
            }
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .allowsHitTesting(false)
        .onAppear { launch() }
    }

    // ── GLOW SEND (free default) — 350 ms ────────────────────────────────
    // Curved arc, 6 soft trail circles, 16 px hue glow at 20 %,
    // 105 % squash on launch, max 8° rotation.

    @ViewBuilder
    private func glowSend(end: CGSize) -> some View {
        let control = controlOffset(for: end, drama: 50)

        // Trail: 6 soft circles chasing behind, fading over 250 ms
        ForEach(0..<6, id: \.self) { i in
            Circle()
                .fill(hue.opacity(AnimationSystem.Trail.opacity))
                .frame(width: AnimationSystem.Trail.width,
                       height: AnimationSystem.Trail.width)
                .blur(radius: 2)   // no hard edges
                .opacity(faded ? 0 : 1)
                .modifier(CurvedFlightEffect(progress: progress, start: .zero,
                                             control: control, end: end))
                .animation(AnimationSystem.easeOutCubic(AnimationSystem.Timing.send)
                            .delay(0.025 * Double(i + 1)), value: progress)
                .animation(.easeOut(duration: AnimationSystem.Trail.fade)
                            .delay(0.05 * Double(i)), value: faded)
        }

        symbol
            .scaleEffect(x: squashed ? AnimationSystem.EmojiMotion.squash : 1.0,
                         y: squashed ? 0.96 : 1.0)
            .rotationEffect(.degrees(AnimationSystem.EmojiMotion.maxRotation
                                     * (progress > 0 ? sin(rad) : 0)))
            .shadow(color: hue.opacity(AnimationSystem.Glow.opacity),
                    radius: AnimationSystem.Glow.radius)
            .opacity(faded ? 0 : 1)
            .modifier(CurvedFlightEffect(progress: progress, start: .zero,
                                         control: control, end: end))
            .animation(AnimationSystem.easeOutCubic(AnimationSystem.Timing.send),
                       value: progress)
            .animation(.easeOut(duration: 0.15).delay(AnimationSystem.Timing.send - 0.1),
                       value: faded)
    }

    // ── SHOOTING STAR SEND (pro) — 300 ms ────────────────────────────────
    // More dramatic sweep, bright leading point, 12-particle gold tail
    // fading over 200 ms, 100 ms white landing flash at the edge.

    private static var gold: Color { Color(hex: "#FFD700") }

    @ViewBuilder
    private func shootingStarSend(end: CGSize) -> some View {
        let control = controlOffset(for: end, drama: 90)   // more dramatic curve

        // Tail: 12 elongated soft particles, bright → nothing over 200 ms
        ForEach(0..<AnimationSystem.Particles.maxCount, id: \.self) { i in
            Capsule()
                .fill(
                    LinearGradient(colors: [Self.gold.opacity(0.8), .clear],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .frame(width: 14, height: 4)
                .blur(radius: 1.5)
                .rotationEffect(.radians(rad - .pi / 2))
                .opacity(faded ? 0 : 0.9 - Double(i) * 0.06)
                .modifier(CurvedFlightEffect(progress: progress, start: .zero,
                                             control: control, end: end))
                .animation(AnimationSystem.easeOutCubic(AnimationSystem.Timing.sendFast)
                            .delay(0.012 * Double(i + 1)), value: progress)
                .animation(.easeOut(duration: 0.2).delay(0.01 * Double(i)), value: faded)
        }

        // The comet — bright leading point with the emoji still readable
        ZStack {
            Circle()
                .fill(
                    RadialGradient(colors: [.white, Self.gold.opacity(0.7), .clear],
                                   center: .center, startRadius: 1, endRadius: 14)
                )
                .frame(width: 26, height: 26)
                .blur(radius: 1)
            symbol
                .scaleEffect(0.8)
        }
        .shadow(color: Self.gold.opacity(AnimationSystem.Glow.opacityMax),
                radius: AnimationSystem.Glow.radiusMax)
        .opacity(faded ? 0 : 1)
        .modifier(CurvedFlightEffect(progress: progress, start: .zero,
                                     control: control, end: end))
        .animation(AnimationSystem.easeOutCubic(AnimationSystem.Timing.sendFast),
                   value: progress)
        .animation(.easeOut(duration: 0.1), value: faded)

        // Landing — brief white flash at the screen edge, 100 ms fade
        Circle()
            .fill(
                RadialGradient(colors: [.white.opacity(0.85), .clear],
                               center: .center, startRadius: 2, endRadius: 36)
            )
            .frame(width: 72, height: 72)
            .offset(end)
            .opacity(edgeFlash ? 0 : (progress >= 1 ? 0.9 : 0))
            .animation(.easeOut(duration: 0.1), value: edgeFlash)
    }

    // ── FIREFLY SEND (pro) — slow, drifting (~1.2 s) ─────────────────────
    // Organic wandering curve, warm yellow-green pulsing orb, very faint
    // trail, soft fade at the edge. Gentle floating feeling throughout.

    private static var fireflyGreen: Color { Color(hex: "#90EE90") }

    @ViewBuilder
    private func fireflySend(end: CGSize) -> some View {
        let c1 = CGSize(width: end.width * 0.30 + wander1.width,
                        height: end.height * 0.30 + wander1.height)
        let c2 = CGSize(width: end.width * 0.70 + wander2.width,
                        height: end.height * 0.70 + wander2.height)

        // Very faint light trail — 4 particles, extremely subtle, 400 ms fade
        ForEach(0..<4, id: \.self) { i in
            Circle()
                .fill(Self.fireflyGreen.opacity(0.12))
                .frame(width: 6, height: 6)
                .blur(radius: 2)
                .opacity(faded ? 0 : 1)
                .modifier(WanderingFlightEffect(progress: progress, start: .zero,
                                                control1: c1, control2: c2, end: end))
                .animation(AnimationSystem.easeInOutSine(style.sendDuration)
                            .delay(0.06 * Double(i + 1)), value: progress)
                .animation(.easeOut(duration: 0.4).delay(0.05 * Double(i)), value: faded)
        }

        // The orb — the emoji becomes a soft glowing light
        ZStack {
            Circle()
                .fill(
                    RadialGradient(colors: [Self.fireflyGreen.opacity(0.9),
                                            Self.fireflyGreen.opacity(0.35), .clear],
                                   center: .center, startRadius: 2, endRadius: 16)
                )
                .frame(width: 30, height: 30)
                .blur(radius: 2)
            symbol
                .scaleEffect(0.55)
                .opacity(0.35)   // a memory of the emoji inside the light
        }
        .scaleEffect(orbPulse ? 1.05 : 0.95)   // 600 ms easeInOutSine pulse
        .shadow(color: Self.fireflyGreen.opacity(AnimationSystem.Glow.opacityMax),
                radius: AnimationSystem.Glow.radiusMax)
        .opacity(faded ? 0 : 1)   // fades softly at the edge, 300 ms
        .modifier(WanderingFlightEffect(progress: progress, start: .zero,
                                        control1: c1, control2: c2, end: end))
        .animation(AnimationSystem.easeInOutSine(style.sendDuration), value: progress)
        .animation(.easeOut(duration: 0.3), value: faded)
    }

    // ── Launch sequencing ─────────────────────────────────────────────────

    private func launch() {
        switch style {
        case .glow:
            HapticEngine.send()                              // .light at launch
        case .shootingStar:
            HapticEngine.send()                              // .light at launch
            SoundEngine.shared.play(for: "style.whoosh")     // whoosh + shimmer
        case .firefly:
            HapticEngine.sendSoft()                          // soft, slightly delayed
            SoundEngine.shared.play(for: "style.chime")      // soft, gentle, airy
            withAnimation(AnimationSystem.easeInOutSine(0.6)
                            .repeatForever(autoreverses: true)) {
                orbPulse = true
            }
        }

        progress = 1   // per-layer .animation() drives the easing

        // Squash returns to 100 % over 150 ms
        withAnimation(.easeOut(duration: AnimationSystem.EmojiMotion.squashReturn)) {
            squashed = false
        }

        let flight = style.sendDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, flight - 0.12)) {
            faded = true
        }
        if style == .shootingStar {
            // The flash blinks on as the comet lands, off 100 ms later
            DispatchQueue.main.asyncAfter(deadline: .now() + flight) {
                edgeFlash = true
            }
        }
        // Trail stragglers get their fade time before the view is removed
        DispatchQueue.main.asyncAfter(deadline: .now() + flight
                                      + AnimationSystem.Trail.fadeMax + 0.15) {
            onComplete()
        }
    }
}

// ════════════════════════════════════════════════════════════════════════
// MARK: - ReplayOverlayView
// ════════════════════════════════════════════════════════════════════════

/// A memory, not a new message. Background dims 30 %, the emoji re-enters
/// from its original direction at 70–80 % of the original duration, blooms,
/// rests 1.5 s, and fades. easeInOutQuad throughout.
struct ReplayOverlayView: View {

    let emoji: String
    let bearingDegrees: Double
    let style: SenderStyle
    let onDone: () -> Void

    @State private var dimmed   = false
    @State private var progress: CGFloat = 0   // edge → center
    @State private var bloomed  = false
    @State private var fadingOut = false

    private var hue: Color { EmojiHue.color(for: emoji) }
    private var rad: Double { bearingDegrees * .pi / 180 }

    /// 70–80 % of the original send duration.
    private var travelDuration: Double { style.sendDuration * 0.75 }

    var body: some View {
        GeometryReader { geo in
            let reach = max(geo.size.width, geo.size.height) * 0.62
            let edge  = CGSize(width: CGFloat(sin(rad)) * reach,
                               height: -CGFloat(cos(rad)) * reach)
            let control = CGSize(width: edge.width * 0.45 + CGFloat(cos(rad)) * 44,
                                 height: edge.height * 0.45 + CGFloat(sin(rad)) * 44 - 30)

            ZStack {
                // 1 · Background dims slightly — 30 % black, 200 ms
                Color.black.opacity(dimmed ? 0.30 : 0)
                    .ignoresSafeArea()
                    .animation(AnimationSystem.easeInOutQuad(0.2), value: dimmed)

                // 2–4 · Edge → center in the original direction, then bloom
                Text(emoji)
                    .font(.system(size: 54))
                    .scaleEffect(bloomed ? 1.0 : 0.55)
                    .shadow(color: hue.opacity(AnimationSystem.Glow.opacity),
                            radius: AnimationSystem.Glow.radius)
                    .opacity(fadingOut ? 0 : (dimmed ? 1 : 0))
                    .modifier(CurvedFlightEffect(progress: progress,
                                                 start: edge, control: control,
                                                 end: .zero))
                    .animation(AnimationSystem.easeInOutQuad(travelDuration), value: progress)
                    .animation(AnimationSystem.easeInOutQuad(AnimationSystem.Timing.replay),
                               value: bloomed)
                    .animation(.easeOut(duration: 0.3), value: fadingOut)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
        .onAppear { play() }
        .onTapGesture { finish() }   // a memory shouldn't trap anyone
    }

    private func play() {
        dimmed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            progress = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 + travelDuration) {
            bloomed = true
            SoundEngine.shared.play(for: emoji)
        }
        // 5 · stays 1.5 s · 6 · fades 300 ms · 7 · background returns 200 ms
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 + travelDuration + 1.5) {
            finish()
        }
    }

    private func finish() {
        guard !fadingOut else { return }
        fadingOut = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dimmed = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onDone()
        }
    }
}

// ════════════════════════════════════════════════════════════════════════
// MARK: - CaughtConfirmationView
// ════════════════════════════════════════════════════════════════════════

/// The sender's quiet moment when their thought is caught. The emoji they
/// sent appears briefly at the compass center — scale 0.8, opacity 0.6 —
/// the glow pulses once, a ripple expands and fades. 600 ms, then gone.
/// No text. No timestamp. No read receipt. Just warmth.
struct CaughtConfirmationView: View {

    let emoji: String

    @State private var shown      = false
    @State private var glowPulse  = false
    @State private var rippleOut  = false
    @State private var gone       = false

    private var hue: Color { EmojiHue.color(for: emoji) }

    var body: some View {
        ZStack {
            // Ripple — expands from center and fades
            Circle()
                .stroke(hue.opacity(rippleOut ? 0 : 0.45), lineWidth: 1.5)
                .frame(width: 70, height: 70)
                .scaleEffect(rippleOut ? 2.6 : 0.6)
                .animation(AnimationSystem.easeOutCubic(0.6), value: rippleOut)

            // Soft glow that pulses once
            Circle()
                .fill(hue.opacity(glowPulse ? 0.30 : 0.10))
                .frame(width: 64, height: 64)
                .blur(radius: AnimationSystem.Glow.radiusMax)
                .animation(AnimationSystem.easeInOutSine(0.3), value: glowPulse)

            Text(emoji)
                .font(.system(size: 34))
                .scaleEffect(0.8)
                .opacity(0.6)
        }
        .opacity(gone ? 0 : (shown ? 1 : 0))
        .animation(.easeIn(duration: 0.12), value: shown)
        .animation(.easeOut(duration: 0.25), value: gone)
        .allowsHitTesting(false)
        .onAppear {
            HapticEngine.caughtConfirmation()                // very soft .light
            SoundEngine.shared.play(for: "style.shimmer")    // 80 ms shimmer
            shown = true
            glowPulse = true
            rippleOut = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                glowPulse = false                            // …pulses once
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.60) {
                gone = true                                  // 600 ms total
            }
        }
    }
}
