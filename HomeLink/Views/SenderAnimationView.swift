// SenderAnimationView.swift
// Pointward › Views
//
// The send made DRAMATIC — every thought is an event, not a blink:
//
//   GLOW (free)          1.2 s · charge → launch → flight → impact
//   SHOOTING STAR (pro)  0.9 s · gold charge → blazing streak → flash
//   FIREFLY (pro)        2.0 s · glow gathers → wandering drift → soft land
//   FINGER FLICK (pro)   ~.8 s · press → snap → playful arc
//   BOW & ARROW (pro)    ~.95 s · draw → trembling hold → release
//
// Global rules (all styles):
//   · launches from the COMPASS RING EDGE, not center — maximum travel
//   · the emoji GROWS in flight (1.0 → 1.5), accelerating toward them
//   · the whole screen reacts — a warm lavender pulse at impact
//   · trails LINGER 0.8–1.2 s — a comet tail, not a sneeze
//   · two-part haptic — light at launch, medium at the screen edge
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
    @State private var squashed   = false    // per-style launch deformation
    @State private var faded      = false    // emoji fade at the screen edge
    @State private var orbPulse   = false    // firefly breathing
    @State private var edgeFlash  = false    // (legacy flag, kept)

    // The dramatic rebuild
    @State private var chargeScale: CGFloat = 1.0   // pre-launch pulse
    @State private var chargeGlow  = false          // glow builds before launch
    @State private var flightScale: CGFloat = 1.0   // grows 1.0 → 1.5 in flight
    @State private var trailFaded  = false          // lingering comet-tail fade
    @State private var bgPulse     = false          // whole-screen lavender wash
    @State private var flashVisible = false         // impact flash at the edge
    @State private var goldRing    = false          // compass: expanding gold ring
    @State private var windSky     = false          // wind: full-screen sky takeover
    @State private var windFloating = false         // [4/5] wind: float-phase wander
    @State private var streakIn    = false          // flick: full-screen light streak
    @State private var wandWhiteFlash = false       // wand: full-screen white flash
    @State private var wandExplode    = false       // wand: implosion → explosion scatter
    @State private var compassExpand  = false       // compass: face expand/contract pulse

    // Full-compass instrument phases (finger flick + bow & arrow)
    @State private var instrumentShown = false   // 300 ms transform in
    @State private var instrumentGone  = false   // 300 ms return fade
    @State private var emojiAtTip      = false   // nocked/ready on the instrument
    // (flightScale is shared with the other styles — declared above)

    // Finger flick phases
    @State private var ffCompress  = false   // 200 ms press-down (12 %)
    @State private var ffFlick     = false   // 80 ms snap, 8 % overshoot
    @State private var ffSparks    = false   // fingertip spark burst

    // Bow & arrow phases
    @State private var baDraw      = false   // 400 ms string pull (25 %)
    @State private var baJitter    = false   // 150 ms hold tremble ±2 px
    @State private var baReleased  = false   // string snap + flight
    @State private var baVibrate   = false   // ±4 px bow ring, dampening
    @State private var baDimmed    = false   // 5 % tension overlay
    @State private var baEdgeFlash = false   // arrival flash + bloom

    // Rocket blast-off phases
    @State private var rkCount: Int?   = nil   // countdown 3 · 2 · 1
    @State private var rkCountShown    = false // current number large + fading
    @State private var rkDarken        = false // instrument fades to ~10 %
    @State private var rkIgnFlash      = false // warm orange ignition wash
    @State private var rkSmoke         = false // ignition smoke billow
    @State private var rkProgress: CGFloat = 0 // pad → screen edge
    @State private var rkScale: CGFloat = 1.0  // grows then recedes (perspective)
    @State private var rkFaded         = false // rocket fades at the edge
    @State private var rkTrailFaded    = false // 2 s lingering trail fade
    @State private var rkExitFlash     = false // bright flash at the exit point
    @State private var rkEmber         = false // small ember glow lingers
    @State private var rkShake: CGFloat = 0     // engine rumble shake pre-launch

    // Wander offsets are frozen once per flight so the drift doesn't reroll
    @State private var wander1 = CGSize(width: .random(in: -70...70),
                                        height: .random(in: -70...10))
    @State private var wander2 = CGSize(width: .random(in: -70...70),
                                        height: .random(in: -60...20))

    private var hue: Color { EmojiHue.color(for: emoji) }

    private var rad: Double { bearingDegrees * .pi / 180 }

    /// LAUNCH POINT — the edge of the compass face (370 pt face → the emoji
    /// center sits at r = 170, just inside the ring). Maximum travel, maximum
    /// drama: ring edge → screen edge.
    private var ringStart: CGSize {
        CGSize(width: CGFloat(sin(rad)) * 170,
               height: -CGFloat(cos(rad)) * 170)
    }

    /// Where the flight ends — past the visible edge along the bearing.
    private func endOffset(in geo: GeometryProxy) -> CGSize {
        let reach = max(geo.size.width, geo.size.height) * 0.62
        return CGSize(width: CGFloat(sin(rad)) * reach,
                      height: -CGFloat(cos(rad)) * reach)
    }

    /// Slight upward curve between launch and landing — never a straight line.
    private func controlOffset(from start: CGSize, to end: CGSize,
                               drama: CGFloat) -> CGSize {
        // Perpendicular to the travel direction, plus a small upward bias.
        let perp = CGSize(width: CGFloat(cos(rad)), height: CGFloat(sin(rad)))
        return CGSize(width: (start.width + end.width) * 0.5 + perp.width * drama,
                      height: (start.height + end.height) * 0.5 + perp.height * drama - 36)
    }

    /// Impact-flash tint, per style.
    private var flashTint: Color {
        switch style {
        case .glow:         return hue
        case .shootingStar: return Self.gold
        case .firefly:      return Self.fireflyGreen
        case .fingerFlick:  return Self.flickGold2
        case .bowArrow:     return Self.amber2
        case .rocket:       return Self.rocketOrange
        case .wand:         return Self.wandGold
        case .plane:        return Self.gold   // ✈️ placeholder flight tint [3/5]
        }
    }

    /// Curve helper for flights measured from the face center — the
    /// instrument styles position their own tip/nock launch points.
    private func controlOffset(for end: CGSize, drama: CGFloat) -> CGSize {
        let perp = CGSize(width: CGFloat(cos(rad)), height: CGFloat(sin(rad)))
        return CGSize(width: end.width * 0.45 + perp.width * drama,
                      height: end.height * 0.45 + perp.height * drama - 36)
    }

    var body: some View {
        ZStack {
            // SCREEN REACTION — a warm lavender wash, 0 → 0.15 → 0 over
            // 600 ms easeInOutSine. The whole compass felt the send.
            Color(hex: "#9b7fc0")
                .opacity(bgPulse ? 0.15 : 0)
                .ignoresSafeArea()

            // 🌬️ WIND — the whole screen becomes sky during the send, then
            // recedes. Fast-drifting clouds carry the thought away.
            if style == .firefly {
                windSkyLayer
            }

            GeometryReader { geo in
                let end = endOffset(in: geo)
                ZStack {
                    switch style {
                    case .glow:         glowSend(end: end)
                    case .shootingStar: shootingStarSend(end: end)
                    case .firefly:      fireflySend(end: end)
                    case .fingerFlick:  fingerFlickSend(end: end)
                    case .bowArrow:     bowArrowSend(end: end)
                    case .rocket:       rocketSend(end: end)
                    case .wand:         wandSend(end: end)
                    case .plane:        glowSend(end: end)   // ✈️ placeholder cross-screen flight [3/5]
                    }

                    // IMPACT — brief flash where the thought leaves the screen
                    // (the firefly lands softly instead; the rocket owns its
                    //  own exit flash + ember)
                    if style != .firefly && style != .rocket {
                        Circle()
                            .fill(RadialGradient(
                                colors: [.white.opacity(0.9),
                                         flashTint.opacity(0.4), .clear],
                                center: .center, startRadius: 2, endRadius: 55))
                            .frame(width: 110, height: 110)
                            .offset(end)
                            .opacity(flashVisible ? 1 : 0)
                    }
                }
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
        .allowsHitTesting(false)
        .onAppear { launch() }
    }

    // ── GLOW SEND (free default) — 1200 ms, four phases ──────────────────
    //   CHARGE 200 ms   pulse 1.0→1.2→1.0 at the ring edge, glow builds
    //   LAUNCH 100 ms   110 % horizontal squash, strong light haptic
    //   FLIGHT 700 ms   curved arc, grows to 1.5, fades the last 200 ms,
    //                   10-circle hue trail at 40 % lingering 1 s
    //   IMPACT 200 ms   edge flash, screen pulse, medium haptic

    private let glowFlight = 0.70

    @ViewBuilder
    private func glowSend(end: CGSize) -> some View {
        let start   = ringStart
        let control = controlOffset(from: start, to: end, drama: 50)

        // [6/6] FULL-SCREEN GLOW PULSE — the whole compass breathes with the
        // send: a hue-true wash expanding and contracting behind everything.
        RadialGradient(colors: [hue.opacity(compassExpand ? 0.32 : 0), .clear],
                       center: .center, startRadius: 20, endRadius: 520)
            .ignoresSafeArea()
            .scaleEffect(compassExpand ? 1.12 : 0.82)
            .animation(.easeInOut(duration: 0.5), value: compassExpand)

        // GOLDEN RING — expands from the compass center as the needle locks,
        // opacity 0.6 → 0 over 400 ms. The compass feels alive and powerful.
        Circle()
            .stroke(Self.gold.opacity(goldRing ? 0 : 0.6), lineWidth: 3)
            .frame(width: 90, height: 90)
            .scaleEffect(goldRing ? 3.2 : 0.35)
            .blur(radius: goldRing ? 2 : 0)
            .animation(.easeOut(duration: 0.4), value: goldRing)

        // Trail: 10 soft circles (10–14 px), emoji hue at 40 %,
        // lingering 1 s after the emoji passes — the visible path
        ForEach(0..<10, id: \.self) { i in
            Circle()
                .fill(hue.opacity(AnimationSystem.Trail.opacityBold))
                .frame(width: 10 + CGFloat(i % 3) * 2,
                       height: 10 + CGFloat(i % 3) * 2)
                .blur(radius: 2)   // no hard edges
                .opacity(trailFaded ? 0 : 1)
                .modifier(CurvedFlightEffect(progress: progress, start: start,
                                             control: control, end: end))
                .animation(AnimationSystem.easeOutCubic(glowFlight)
                            .delay(0.03 * Double(i + 1)), value: progress)
                .animation(.easeOut(duration: AnimationSystem.Trail.linger)
                            .delay(0.05 * Double(i)), value: trailFaded)
        }

        symbol
            .scaleEffect(chargeScale)                       // CHARGE pulse
            .scaleEffect(x: squashed ? 1.10 : 1.0,          // LAUNCH squash 110 %
                         y: squashed ? 0.94 : 1.0)
            .scaleEffect(flightScale)                       // grows 1.0 → 1.5
            .rotationEffect(.degrees(AnimationSystem.EmojiMotion.maxRotation
                                     * (progress > 0 ? sin(rad) : 0)))
            .shadow(color: hue.opacity(chargeGlow ? 0.35 : 0.12),
                    radius: chargeGlow ? 20 : 8)            // glow builds, then rides
            .opacity(faded ? 0 : 1)
            .modifier(CurvedFlightEffect(progress: progress, start: start,
                                         control: control, end: end))
            .animation(AnimationSystem.easeOutCubic(glowFlight), value: progress)
            .animation(AnimationSystem.easeInOutSine(0.1), value: chargeScale)
            .animation(.easeIn(duration: 0.2), value: chargeGlow)
            .animation(.easeOut(duration: 0.2), value: faded)
    }

    // ── SHOOTING STAR SEND (pro) — 900 ms, phased ────────────────────────
    //   CHARGE 150 ms   elongates 120 % at the ring edge, gold glow builds
    //   STREAK 500 ms   blazing easeOutCubic arc, grows to 1.5,
    //                   14 elongated gold particles lingering ~0.9 s
    //   IMPACT          bright edge flash, screen pulse, medium haptic

    private static var gold: Color { Color(hex: "#FFD700") }
    private let starFlight = 0.50

    @ViewBuilder
    private func shootingStarSend(end: CGSize) -> some View {
        let start   = ringStart
        let control = controlOffset(from: start, to: end, drama: 90)   // dramatic curve

        // Tail: 14 elongated gold particles — bright, hanging in the air
        ForEach(0..<14, id: \.self) { i in
            Capsule()
                .fill(
                    LinearGradient(colors: [Self.gold.opacity(0.85), .clear],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .frame(width: 20, height: 5)
                .blur(radius: 1.5)
                .rotationEffect(.radians(rad - .pi / 2))
                .opacity(trailFaded ? 0 : 0.9 - Double(i) * 0.05)
                .modifier(CurvedFlightEffect(progress: progress, start: start,
                                             control: control, end: end))
                .animation(AnimationSystem.easeOutCubic(starFlight)
                            .delay(0.015 * Double(i + 1)), value: progress)
                .animation(.easeOut(duration: 0.9)
                            .delay(0.03 * Double(i)), value: trailFaded)
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
        .scaleEffect(x: squashed ? 1.20 : 1.0)              // CHARGE elongation
        .scaleEffect(flightScale)                           // grows 1.0 → 1.5
        .shadow(color: Self.gold.opacity(chargeGlow ? 0.55 : 0.25),
                radius: chargeGlow ? 24 : 12)               // a star about to streak
        .opacity(faded ? 0 : 1)
        .modifier(CurvedFlightEffect(progress: progress, start: start,
                                     control: control, end: end))
        .animation(AnimationSystem.easeOutCubic(starFlight), value: progress)
        .animation(AnimationSystem.easeInOutSine(0.15), value: squashed)
        .animation(.easeIn(duration: 0.15), value: chargeGlow)
        .animation(.easeOut(duration: 0.15), value: faded)

        // (landing flash now shared — see the impact flash in body)
    }

    // ── FIREFLY SEND (pro) — 2.0 s, slow and intimate ────────────────────
    //   GATHER 300 ms   the light gathers at the ring edge, pulse begins
    //   DRIFT 1400 ms   organic wandering curve, grows gently to 1.3
    //   LAND   300 ms   soft fade at the edge, gentle screen pulse
    // Trail lingers 1.2 s — a path of faint green light.

    // 🌬️ WIND took over the firefly slot — warm lavender/white breath,
    // slow and beautiful (3–4 s total), particles lingering long after.
    private static var fireflyGreen: Color { Color(hex: "#d9cce8") }   // wind lavender-white
    private let fireflyFlight = 2.20    // [4/5] phase-3 send leg (float+gather precede it)

    @ViewBuilder
    private func fireflySend(end: CGSize) -> some View {
        // [4/5] FIX B — the leaf lifts from the BOTTOM of the screen (not the
        // ring), for maximum visual impact and the longest travel.
        let start = CGSize(width: 0, height: 340)
        let c1 = CGSize(width: start.width + (end.width - start.width) * 0.30 + wander1.width,
                        height: start.height + (end.height - start.height) * 0.30 + wander1.height)
        let c2 = CGSize(width: start.width + (end.width - start.width) * 0.70 + wander2.width,
                        height: start.height + (end.height - start.height) * 0.70 + wander2.height)

        // [2/3] A COMET of dandelion seeds streaming behind the leaf — 24,
        // lingering ~2 s after it passes.
        ForEach(0..<24, id: \.self) { i in
            DandelionSeed(size: 8 + CGFloat(i % 3) * 2, opacity: 0.75)
                .opacity(trailFaded ? 0 : 1)
                .modifier(WanderingFlightEffect(progress: progress, start: start,
                                                control1: c1, control2: c2, end: end))
                .animation(AnimationSystem.easeInOutSine(fireflyFlight)
                            .delay(0.05 * Double(i + 1)), value: progress)
                .animation(.easeOut(duration: AnimationSystem.Trail.lingerMax)
                            .delay(0.05 * Double(i)), value: trailFaded)
        }

        // [2/3] The thought rides a BIG leaf (120×80) across the sky — emoji
        // ~48 pt, swaying as it drifts: ±15 px lateral, ±8 px bounce, ±8° roll.
        ZStack {
            // [4/5] FIX B — a BIG leaf (160×100) carrying a 56 pt emoji.
            LeafShape()
                .fill(LinearGradient(colors: [Color(hex: "#a8d672"), Color(hex: "#6fae3e")],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 160, height: 100)
                .shadow(color: Color(hex: "#3d6b22").opacity(0.45), radius: 12)
            symbol
                .scaleEffect(1.25)   // emoji riding the leaf, ~56 pt
        }
        // [4/5] Bigger wander during the FLOAT phase (±40/±20/±10°), settling
        // to the alive sway (±15/±8/±8°) once it gathers to fly.
        .rotationEffect(.degrees(orbPulse ? (windFloating ? 10 : 8)
                                          : (windFloating ? -10 : -8)))
        .offset(x: orbPulse ? (windFloating ? 40 : 15) : (windFloating ? -40 : -15),
                y: orbPulse ? (windFloating ? -20 : -8) : (windFloating ? 20 : 8))
        .animation(AnimationSystem.easeInOutSine(windFloating ? 1.5 : 0.6)
                    .repeatForever(autoreverses: true), value: orbPulse)
        .scaleEffect(flightScale)
        .shadow(color: .white.opacity(0.7), radius: 12)
        .shadow(color: Color(hex: "#FFF3A3").opacity(0.5), radius: 18)   // sunlight
        .opacity(faded ? 0 : 1)
        .modifier(WanderingFlightEffect(progress: progress, start: start,
                                        control1: c1, control2: c2, end: end))
        .animation(AnimationSystem.easeInOutSine(fireflyFlight), value: progress)
        .animation(.easeOut(duration: 0.3), value: faded)
    }

    // ── WIND full-screen sky takeover ─────────────────────────────────────

    private static var wSkyTop: Color { Color(hex: "#87CEEB") }
    private static var wSkyMid: Color { Color(hex: "#B8D4E8") }
    private static var wSkyLow: Color { Color(hex: "#E8F4F8") }

    /// The whole screen becomes sky during a wind send, then recedes —
    /// clouds drifting fast across the phone.
    private var windSkyLayer: some View {
        LinearGradient(colors: [Self.wSkyTop, Self.wSkyMid, Self.wSkyLow],
                       startPoint: .top, endPoint: .bottom)
            .overlay(fastClouds)
            .opacity(windSky ? 1 : 0)
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.7), value: windSky)
            .allowsHitTesting(false)
    }

    private var fastClouds: some View {
        GeometryReader { geo in
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                let ys: [CGFloat] = [0.16, 0.4, 0.64, 0.84]
                let periods: [Double] = [6, 9, 7, 5]   // fast drift
                ZStack {
                    ForEach(0..<4, id: \.self) { i in
                        windCloud
                            .scaleEffect(0.7 + CGFloat(i) * 0.22)
                            .position(
                                x: CGFloat(((t / periods[i]).truncatingRemainder(dividingBy: 1)))
                                   * (geo.size.width + 200) - 100,
                                y: geo.size.height * ys[i])
                    }
                }
            }
        }
    }

    private var windCloud: some View {
        ZStack {
            Circle().frame(width: 50, height: 50).offset(x: -32, y: 6)
            Circle().frame(width: 70, height: 70)
            Circle().frame(width: 54, height: 54).offset(x: 32, y: 4)
            Capsule().frame(width: 104, height: 32).offset(y: 16)
        }
        .foregroundColor(Color(hex: "#FFFAF0").opacity(0.8))
        .blur(radius: 4)
    }

    // ════ LEGACY small-overlay versions — superseded by the full
    // compass-face transformations below. Kept, not deleted. ════
    /*
    // ── FINGER FLICK SEND (pro) — 400 ms ─────────────────────────────────
    // Compress 80 ms → flick release 50 ms with fingertip sparks →
    // 270 ms curved flight. Quick and playful.

    private static var flickGold: Color { Color(hex: "#FFD700") }

    private let flickFlight = 0.45

    @ViewBuilder
    private func fingerFlickSend(end: CGSize) -> some View {
        let start   = ringStart
        let control = controlOffset(from: start, to: end, drama: 55)

        // The finger silhouette — 22×60, tip r11 top, base r8 bottom,
        // white 70 %, 8 px soft shadow. Sits just below the emoji,
        // at the ring edge where the launch happens.
        ZStack {
            Capsule()
                .fill(.white.opacity(0.7))
                .frame(width: 16, height: 60)
            Circle()
                .fill(.white.opacity(0.7))
                .frame(width: 22, height: 22)
                .offset(y: -19)
            Circle()
                .fill(.white.opacity(0.7))
                .frame(width: 16, height: 16)
                .offset(y: 22)
        }
        .shadow(color: .black.opacity(0.35), radius: 8)
        .scaleEffect(y: ffFlick ? 1.1 : (ffCompress ? 0.9 : 1.0), anchor: .bottom)
        .animation(AnimationSystem.easeInOutSine(0.08), value: ffCompress)
        .animation(.spring(response: 0.12, dampingFraction: 0.5), value: ffFlick)
        .opacity(ffFingerGone ? 0 : 1)
        .animation(.easeOut(duration: 0.15), value: ffFingerGone)
        .offset(y: 46)
        .offset(start)

        // Fingertip sparks — 5 particles, 2–3 px, white/gold, scatter
        // in the send direction, 80 ms lifetime
        if ffSparks {
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .fill(i % 2 == 0 ? .white : Self.flickGold)
                    .frame(width: i % 2 == 0 ? 2.5 : 3, height: i % 2 == 0 ? 2.5 : 3)
                    .offset(x: CGFloat(sin(rad)) * 18 + CGFloat(i - 2) * 5,
                            y: -CGFloat(cos(rad)) * 18 + CGFloat((i * 7) % 9) - 4)
                    .opacity(ffFlick ? 0 : 0.9)
                    .animation(.easeOut(duration: 0.08).delay(0.02), value: ffFlick)
                    .offset(y: 16)
                    .offset(start)
            }
        }

        // Trail: 8 soft circles in the emoji's hue, lingering 1 s
        ForEach(0..<8, id: \.self) { i in
            Circle()
                .fill(hue.opacity(AnimationSystem.Trail.opacityBold))
                .frame(width: 10 + CGFloat(i % 3) * 2,
                       height: 10 + CGFloat(i % 3) * 2)
                .blur(radius: 2)
                .opacity(trailFaded ? 0 : 1)
                .modifier(CurvedFlightEffect(progress: progress, start: start,
                                             control: control, end: end))
                .animation(AnimationSystem.easeOutCubic(flickFlight)
                            .delay(0.025 * Double(i + 1)), value: progress)
                .animation(.easeOut(duration: AnimationSystem.Trail.linger)
                            .delay(0.04 * Double(i)), value: trailFaded)
        }

        // The emoji — pressed down with the finger, launched off the tip
        symbol
            .scaleEffect(x: squashed ? 0.93 : 1.0, y: 1.0)   // 7 % squash, 100 ms return
            .scaleEffect(flightScale)                        // grows 1.0 → 1.5
            .rotationEffect(.degrees(progress > 0 ? 6 * (sin(rad) >= 0 ? 1 : -1) : 0))
            .shadow(color: hue.opacity(AnimationSystem.Glow.opacityMax),
                    radius: AnimationSystem.Glow.radiusMax)
            .opacity(faded ? 0 : 1)
            .offset(y: ffCompress && !ffFlick ? 5 : 0)        // rides the press
            .animation(AnimationSystem.easeInOutSine(0.08), value: ffCompress)
            .modifier(CurvedFlightEffect(progress: progress, start: start,
                                         control: control, end: end))
            .animation(AnimationSystem.easeOutCubic(flickFlight), value: progress)
            .animation(.easeOut(duration: 0.15), value: faded)
    }

    // ── BOW & ARROW SEND (pro) — 600 ms ──────────────────────────────────
    // Draw 200 ms → trembling hold 100 ms → release: string snaps 50 ms,
    // bow vibrates, the emoji-arrow flies a fast decisive arc.

    private static var amber: Color { Color(hex: "#E8B64C") }

    private let bowFlight = 0.45

    @ViewBuilder
    private func bowArrowSend(end: CGSize) -> some View {
        let start   = ringStart
        let control = controlOffset(from: start, to: end, drama: 70)
        let pull: CGFloat = baReleased ? 0 : (baDraw ? 9 : 0)   // ~15 % of 60

        // The bow rig — 60×80 silhouette, aimed along the bearing,
        // standing at the ring edge where the arrow nocks.
        ZStack {
            BowArchShape()
                .stroke(.white.opacity(0.7), lineWidth: 4)
            BowStringShape(pull: pull)
                .stroke(.white.opacity(0.7), lineWidth: 2)
        }
        .frame(width: 60, height: 80)
        .shadow(color: .black.opacity(0.35), radius: 8)
        .rotationEffect(.radians(rad))
        .offset(x: baVibrate ? 3 : 0)
        .animation(.spring(response: 0.15, dampingFraction: 0.28), value: baVibrate)
        .animation(.easeOut(duration: 0.05), value: baReleased)   // string snap
        .animation(AnimationSystem.easeInOutSine(0.2), value: baDraw)
        .opacity(baBowGone ? 0 : 1)
        .animation(.easeOut(duration: 0.2), value: baBowGone)
        .offset(start)

        // Trail: 10 elongated amber particles — the arrow's path, lingering 1 s
        ForEach(0..<10, id: \.self) { i in
            Capsule()
                .fill(LinearGradient(colors: [Self.amber.opacity(0.85), .clear],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 18, height: 4)
                .blur(radius: 1)
                .rotationEffect(.radians(rad - .pi / 2))
                .opacity(trailFaded ? 0 : 0.85 - Double(i) * 0.06)
                .modifier(CurvedFlightEffect(progress: progress, start: start,
                                             control: control, end: end))
                .animation(AnimationSystem.easeOutCubic(bowFlight)
                            .delay(0.015 * Double(i + 1)), value: progress)
                .animation(.easeOut(duration: AnimationSystem.Trail.linger)
                            .delay(0.03 * Double(i)), value: trailFaded)
        }

        // The emoji as arrowhead — elongated toward travel, amber-lit,
        // nocked against the string during the draw
        symbol
            .scaleEffect(x: squashed ? 0.85 : (baDraw && !baReleased ? 0.78 : 1.0),
                         y: baDraw && !baReleased ? 1.22 : 1.0)
            .scaleEffect(flightScale)                             // grows 1.0 → 1.5
            .rotationEffect(.degrees(progress > 0 ? 8 * (sin(rad) >= 0 ? 1 : -1) : 0))
            .shadow(color: Self.amber.opacity(0.75), radius: 9)   // the gold overlay glow
            .opacity(faded ? 0 : 1)
            .offset(x: CGFloat(sin(rad)) * -pull * 1.4,
                    y: CGFloat(cos(rad)) * pull * 1.4)            // drawn back with the string
            .offset(x: baJitter ? 1 : 0, y: baJitter ? -1 : 0)    // ±1 px hold tremble
            .animation(AnimationSystem.easeInOutSine(0.025), value: baJitter)
            .animation(AnimationSystem.easeInOutSine(0.2), value: baDraw)
            .modifier(CurvedFlightEffect(progress: progress, start: start,
                                         control: control, end: end))
            .animation(AnimationSystem.easeOutCubic(bowFlight), value: progress)
            .animation(.easeOut(duration: 0.15), value: faded)
    }

    */

    // ── FINGER FLICK — FULL COMPASS TRANSFORMATION ───────────────────────
    // The compass circle becomes a large hand. Transform 300 ms · compress
    // 200 ms · snap 80 ms with sparks · 800 ms full-screen flight · return.

    private static var flickGold: Color { Color(hex: "#FFD700") }
    private static var amber: Color { Color(hex: "#E8B64C") }
    private static var flickGold2: Color { Color(hex: "#FFD700") }
    private static var instrumentTint: Color { Color(hex: "#ece4f5") }   // white/lavender

    /// The fingertip sits at the bearing edge of the compass circle.
    private var fingerTipOffset: CGSize {
        CGSize(width: CGFloat(sin(rad)) * 150, height: -CGFloat(cos(rad)) * 150)
    }

    @ViewBuilder
    private func fingerFlickSend(end: CGSize) -> some View {
        let control = controlOffset(from: fingerTipOffset, to: end, drama: 70)

        // ── The launch pad — a clean recessed pocket, no finger anywhere.
        // Soft lavender border glow; it compresses with the press and
        // springs on the flick. ──
        // (previous hand silhouette retired:)
        // FingerShape()
        //     .fill(Self.instrumentTint.opacity(0.85))
        //     .frame(width: 120, height: 310)
        //     .shadow(color: .black.opacity(0.15), radius: 12)
        //     .rotationEffect(.radians(rad))
        ZStack {
            // Recessed bowl
            Circle()
                .fill(Color.black.opacity(0.30))
                .frame(width: 58, height: 58)
            Circle()
                .fill(
                    RadialGradient(colors: [.clear, Color.black.opacity(0.25)],
                                   center: .center, startRadius: 10, endRadius: 29)
                )
                .frame(width: 58, height: 58)
            // Soft lavender rim glow
            Circle()
                .stroke(Color(hex: "#c4a8d4").opacity(0.6), lineWidth: 1.5)
                .frame(width: 58, height: 58)
                .shadow(color: Color(hex: "#c4a8d4").opacity(0.5), radius: 8)
        }
        .scaleEffect(ffFlick ? 1.06 : (ffCompress ? 0.92 : 1.0))
        .animation(AnimationSystem.easeInOutSine(0.2), value: ffCompress)
        .animation(.spring(response: 0.16, dampingFraction: 0.45), value: ffFlick)
        .offset(fingerTipOffset)
        .opacity(instrumentGone ? 0 : (instrumentShown ? 1 : 0))
        .animation(.easeIn(duration: 0.3), value: instrumentShown)
        .animation(.easeOut(duration: 0.3), value: instrumentGone)

        // ── Spark explosion at the fingertip — 7 particles, white/gold ──
        if ffSparks {
            ForEach(0..<7, id: \.self) { i in
                Circle()
                    .fill(i % 2 == 0 ? .white : Self.flickGold2)
                    .frame(width: i % 2 == 0 ? 3 : 4, height: i % 2 == 0 ? 3 : 4)
                    .offset(x: fingerTipOffset.width + CGFloat(sin(rad)) * 26 + CGFloat(i - 3) * 7,
                            y: fingerTipOffset.height - CGFloat(cos(rad)) * 26 + CGFloat((i * 11) % 13) - 6)
                    .opacity(ffFlick ? 0 : 0.95)
                    .animation(.easeOut(duration: 0.25).delay(0.03), value: ffFlick)
            }
        }

        // ── Trail: 10 soft circles, emoji hue at 40 %, 1 s lingering fade ──
        ForEach(0..<10, id: \.self) { i in
            Circle()
                .fill(hue.opacity(0.4))
                .frame(width: 9, height: 9)
                .blur(radius: 2.5)
                .opacity(faded ? 0 : 1)
                .modifier(CurvedFlightEffect(progress: progress, start: fingerTipOffset,
                                             control: control, end: end))
                .animation(AnimationSystem.easeOutCubic(0.8)
                            .delay(0.03 * Double(i + 1)), value: progress)
                .animation(.easeOut(duration: 1.0).delay(0.06 * Double(i)), value: faded)
        }

        // ── A bright LIGHT STREAK trailing the launch ──
        if emojiAtTip {
            Capsule()
                .fill(LinearGradient(colors: [.white, Self.flickGold2.opacity(0.7), .clear],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 60, height: 8)
                .blur(radius: 2)
                .rotationEffect(.radians(rad - .pi / 2))
                .opacity(faded ? 0 : (progress > 0 ? 0.9 : 0))
                .modifier(CurvedFlightEffect(progress: progress, start: fingerTipOffset,
                                             control: control, end: end))
                .animation(AnimationSystem.easeOutCubic(0.5), value: progress)
                .animation(.easeOut(duration: 0.2), value: faded)
        }

        // ── The emoji — explodes from the pocket and streaks away ──
        if emojiAtTip {
            symbol
                .scaleEffect(flightScale)   // 1.0 → 1.8 mid-flight
                .rotationEffect(.degrees(progress > 0 ? 8 * (sin(rad) >= 0 ? 1 : -1) : 0))
                .shadow(color: hue.opacity(0.7), radius: 14)
                .opacity(faded ? 0 : 1)
                .modifier(CurvedFlightEffect(progress: progress, start: fingerTipOffset,
                                             control: control, end: end))
                .animation(AnimationSystem.easeOutCubic(0.5), value: progress)   // blazing
                .animation(.easeOut(duration: 0.3), value: flightScale)
                .animation(.easeOut(duration: 0.15), value: faded)
        }

        // ── Full-screen white flash as it explodes free ──
        if streakIn {
            Rectangle()
                .fill(Color.white)
                .opacity(0.22)
                .ignoresSafeArea()
                .transition(.opacity)
        }
    }

    // ── BOW & ARROW — FULL COMPASS TRANSFORMATION ────────────────────────
    // The compass circle becomes a full bow. Transform 300 ms · draw 400 ms
    // · trembling hold 150 ms · release · 700 ms streaking flight · return.

    private static var amber2: Color { Color(hex: "#D4A017") }

    @ViewBuilder
    private func bowArrowSend(end: CGSize) -> some View {
        let control = controlOffset(from: .zero, to: end, drama: 80)
        let pull: CGFloat = baReleased ? 0 : (baDraw ? 82 : 0)   // 25 % of 330

        // Tension dims the world 5 % during the draw
        Color.black.opacity(baDimmed ? 0.05 : 0)
            .ignoresSafeArea()
            .animation(AnimationSystem.easeInOutSine(0.4), value: baDimmed)

        // ── The bow — fills 90 % of the compass circle ──
        ZStack {
            BowArchShape(tension: baDraw && !baReleased ? 10 : 0)
                .stroke(Self.instrumentTint.opacity(0.85),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round))
            BowStringShape(pull: pull)
                .stroke(Self.instrumentTint.opacity(0.85), lineWidth: 2)
        }
        .frame(width: 330, height: 330)
        .shadow(color: .black.opacity(0.15), radius: 12)
        .rotationEffect(.radians(rad))
        .offset(x: baVibrate ? 4 : 0)
        .animation(.spring(response: 0.2, dampingFraction: 0.25), value: baVibrate)
        .animation(.easeOut(duration: 0.05), value: baReleased)        // string snap
        .animation(AnimationSystem.easeInOutSine(0.4), value: baDraw)  // real-physics draw
        .opacity(instrumentGone ? 0 : (instrumentShown ? 1 : 0))
        .animation(.easeIn(duration: 0.3), value: instrumentShown)
        .animation(.easeOut(duration: 0.3), value: instrumentGone)

        // ── Trail: 12 elongated amber particles, 1.2 s fade ──
        ForEach(0..<12, id: \.self) { i in
            Capsule()
                .fill(LinearGradient(colors: [Self.amber2.opacity(0.85), .clear],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 20, height: 3.5)
                .blur(radius: 1)
                .rotationEffect(.radians(rad - .pi / 2))
                .opacity(faded ? 0 : 0.9 - Double(i) * 0.06)
                .modifier(CurvedFlightEffect(progress: progress, start: .zero,
                                             control: control, end: end))
                .animation(AnimationSystem.easeOutCubic(0.7)
                            .delay(0.014 * Double(i + 1)), value: progress)
                .animation(.easeOut(duration: 1.2).delay(0.03 * Double(i)), value: faded)
        }

        // ── The arrow — emoji elongated 140 %, amber-lit, nocked on the
        // string, drawn back with it, then streaking to the edge ──
        if emojiAtTip {
            ZStack {
                ArrowShape()
                    .fill(Self.amber2.opacity(0.55))
                    .frame(width: 14, height: 64)
                    .offset(y: 14)
                symbol
                    .scaleEffect(x: 1.0, y: baReleased ? 1.4 : (baDraw ? 1.4 : 1.0))
                    .shadow(color: Self.amber2.opacity(0.8), radius: 10)
            }
            .scaleEffect(flightScale)   // 1.0 → 1.7 mid-flight
            .rotationEffect(progress > 0 ? .radians(rad) : .radians(rad))
            .opacity(faded ? 0 : 1)
            .offset(x: CGFloat(sin(rad)) * -pull, y: CGFloat(cos(rad)) * pull)
            .offset(x: baJitter ? 2 : 0, y: baJitter ? -2 : 0)   // ±2 px hold tremble
            .animation(AnimationSystem.easeInOutSine(0.03), value: baJitter)
            .animation(AnimationSystem.easeInOutSine(0.4), value: baDraw)
            .modifier(CurvedFlightEffect(progress: progress, start: .zero,
                                         control: control, end: end))
            .animation(AnimationSystem.easeOutCubic(0.7), value: progress)
            .animation(.easeOut(duration: 0.35), value: flightScale)
            .animation(.easeOut(duration: 0.25), value: faded)
        }

        // ── Arrival: bright flash, the arrow blooms back into the emoji ──
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [.white.opacity(0.9), .clear],
                                     center: .center, startRadius: 2, endRadius: 40))
                .frame(width: 80, height: 80)
            symbol
                .scaleEffect(1.2)
        }
        .offset(end)
        .opacity(baEdgeFlash ? 0 : (progress >= 1 && baReleased ? 0.95 : 0))
        .animation(.easeOut(duration: 0.35), value: baEdgeFlash)
    }

    // ── WAND SEND (pro) — 🪄 charge built on the instrument, released here ──
    // BURST 200 ms   crystal flash + 24 sparkles scatter from the launch point
    // FLIGHT 1000 ms curved arc, grows 1.0 → 1.6, gold/purple sparkle trail
    // IMPACT         purple/gold screen wash, medium haptic

    private static var wandGold: Color { Color(hex: "#D4AF37") }
    private static var wandPurple: Color { Color(hex: "#9b7fc0") }
    private let wandFlight = 1.00

    @ViewBuilder
    private func wandSend(end: CGSize) -> some View {
        // [6/6] THE MOST MAGICAL SEND: the crystal imploded on the wand; here
        // the magic EXPLODES from screen-center — a white flash fills the
        // screen, particles scatter in every direction, and the thought
        // launches from the explosion on a trail of stars.
        let control = controlOffset(for: end, drama: 60)
        return ZStack {
            wandWhiteFlashLayer
            wandExplosionCore
            wandScatter
            wandStarTrail(control: control, end: end)
            wandThought(control: control, end: end)
        }
    }

    /// Full-screen white flash, 0 → 0.6 → 0.
    private var wandWhiteFlashLayer: some View {
        Color.white.opacity(wandWhiteFlash ? 0.6 : 0)
            .ignoresSafeArea()
            .animation(.easeOut(duration: 0.15), value: wandWhiteFlash)
    }

    /// The core — implodes to a point, then explodes 0.3 → 2.0 and fades.
    private var wandExplosionCore: some View {
        Circle()
            .fill(RadialGradient(colors: [.white, Self.wandGold.opacity(0.6), .clear],
                                 center: .center, startRadius: 2, endRadius: 84))
            .frame(width: 168, height: 168)
            .scaleEffect(wandExplode ? 2.0 : 0.3)
            .opacity(wandExplode ? 0 : (chargeGlow ? 1 : 0))
            .animation(.easeOut(duration: 0.45), value: wandExplode)
    }

    /// 30 sparks flying outward in every direction from the explosion.
    private var wandScatter: some View {
        ForEach(0..<30, id: \.self) { i in
            let a: Double = Double(i) / 30 * 2 * .pi
            let dist: CGFloat = wandExplode ? 220 + CGFloat(i % 6) * 22 : 0
            let dot: CGFloat = i % 3 == 0 ? 5 : 3
            Circle()
                .fill(i % 2 == 0 ? Self.wandGold : Self.wandPurple)
                .frame(width: dot, height: dot)
                .blur(radius: 0.6)
                .offset(x: CGFloat(cos(a)) * dist, y: CGFloat(sin(a)) * dist)
                .opacity(wandExplode ? 0 : (chargeGlow ? 0.95 : 0))
                .animation(.easeOut(duration: 0.85), value: wandExplode)
        }
    }

    /// A trail of stars following the thought as it launches from center.
    private func wandStarTrail(control: CGSize, end: CGSize) -> some View {
        ForEach(0..<14, id: \.self) { i in
            let c: Color = (i % 2 == 0 ? Self.wandGold : Self.wandPurple).opacity(0.7)
            Image(systemName: "sparkle")
                .font(.system(size: i % 3 == 0 ? 9 : 6))
                .foregroundColor(c)
                .opacity(trailFaded ? 0 : 1)
                .modifier(CurvedFlightEffect(progress: progress, start: .zero,
                                             control: control, end: end))
                .animation(AnimationSystem.easeOutCubic(wandFlight)
                            .delay(0.02 * Double(i + 1)), value: progress)
                .animation(.easeOut(duration: 1.5).delay(0.05 * Double(i)),
                           value: trailFaded)
        }
    }

    /// The thought — launches from the explosion center, grows mid-flight.
    private func wandThought(control: CGSize, end: CGSize) -> some View {
        symbol
            .scaleEffect(flightScale)
            .shadow(color: Self.wandPurple.opacity(chargeGlow ? 0.7 : 0.2),
                    radius: chargeGlow ? 18 : 8)
            .opacity(faded ? 0 : 1)
            .modifier(CurvedFlightEffect(progress: progress, start: .zero,
                                         control: control, end: end))
            .animation(AnimationSystem.easeOutCubic(wandFlight), value: progress)
            .animation(.easeOut(duration: 0.35), value: flightScale)
            .animation(.easeOut(duration: 0.25), value: faded)
    }

    // ── Launch sequencing ─────────────────────────────────────────────────

    /// IMPACT — shared by every style except the firefly's soft landing:
    /// flash at the screen edge, lavender screen pulse, medium haptic,
    /// and the trail begins its long lingering fade.
    private func impact(flash: Bool = true) {
        if flash { flashVisible = true }   // on instantly…
        HapticEngine.sendImpact()          // …medium tap as it reaches the edge
        withAnimation(AnimationSystem.easeInOutSine(0.3)) { bgPulse = true }
        trailFaded = true                  // lingering fade via per-particle modifiers
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.18)) { flashVisible = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(AnimationSystem.easeInOutSine(0.3)) { bgPulse = false }
        }
    }

    /// The view stays alive until the last trail particle has faded.
    private func finish(after seconds: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { onComplete() }
    }

    private func launch() {
        switch style {

        case .rocket:
            launchRocket()

        case .wand:
            // [6/6] RELEASE — implosion → explosion → scatter → emoji launch.
            // The white flash fills the screen; the magic finds them.
            chargeGlow = true
            HapticEngine.lockOn()
            SoundEngine.shared.play(for: "style.shimmer")
            // FLASH 150 ms — the screen goes white as the crystal implodes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeOut(duration: 0.12)) { wandWhiteFlash = true }
                HapticEngine.send()
                SoundEngine.shared.play(for: "rocket.blast")   // a magical boom
            }
            // EXPLODE 200 ms — core blooms 0.3 → 2.0, sparks scatter, launch
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                wandExplode = true
                withAnimation(.easeOut(duration: 0.18)) { wandWhiteFlash = false }
                progress = 1
                withAnimation(AnimationSystem.easeOutCubic(wandFlight)) {
                    flightScale = 1.7
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
                faded = true
            }
            // IMPACT — flash, purple/gold screen wash, medium haptic
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.20) { impact() }
            finish(after: 1.2 + AnimationSystem.Trail.linger + 0.4)

        case .glow, .plane:   // ✈️ plane rides the glow launch as a placeholder [3/5]
            // [6/6] CHARGE 200 ms — the whole compass face expands and glows,
            // the needle locks, the golden ring blooms from center.
            chargeScale = 1.2
            chargeGlow  = true
            HapticEngine.lockOn()                     // the satisfying needle snap
            goldRing = true                           // expands 0.4 s, fades out
            withAnimation(.easeOut(duration: 0.25)) { compassExpand = true }  // face swells
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                chargeScale = 1.0
            }
            // LAUNCH 100 ms — 110 % squash, strong light haptic
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                withAnimation(.easeOut(duration: 0.08)) { squashed = true }
                HapticEngine.send()
            }
            // FLIGHT 900 ms — grows to 1.4 from the needle tip, fades last 200 ms.
            // The face contracts back as the thought launches away.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                progress = 1
                withAnimation(AnimationSystem.easeOutCubic(glowFlight)) {
                    flightScale = 1.4
                }
                withAnimation(.easeOut(duration: 0.15)) { squashed = false }
                withAnimation(.easeInOut(duration: 0.5)) { compassExpand = false }  // contract
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.80) {
                faded = true
            }
            // IMPACT 200 ms — flash, screen pulse, medium haptic
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.00) { impact() }
            finish(after: 1.0 + AnimationSystem.Trail.linger + 0.55)

        case .shootingStar:
            // CHARGE 150 ms — elongates 120 %, gold glow builds
            squashed   = true
            chargeGlow = true
            // STREAK 500 ms — blazing fast start
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                HapticEngine.send()
                SoundEngine.shared.play(for: "style.whoosh")
                squashed = false
                progress = 1
                withAnimation(AnimationSystem.easeOutCubic(starFlight)) {
                    flightScale = 1.5
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                faded = true
            }
            // IMPACT — bright flash, screen pulse, medium haptic
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.70) { impact() }
            finish(after: 0.7 + 0.9 + 0.55)

        case .firefly:
            // [4/5] FIX C — the leaf lifts from the bottom and SWIRLS lazily
            // around the sky for ~8 s (the most beautiful send, worth waiting
            // for), gathers for 1 s, then catches the wind and departs toward
            // the person.
            // PHASE 1 · SWIRL (8 s)   the leaf drifts the interior, in no hurry.
            // PHASE 2 · GATHER (1 s)  the wander settles, the wind picks a way.
            // PHASE 3 · SEND (2.5 s)  the leaf accelerates toward them and fades.
            HapticEngine.sendSoft()
            SoundEngine.shared.play(for: "style.chime")
            chargeGlow = true
            windSky = true                                   // full-screen sky in
            windFloating = true                              // big, lazy swirl
            withAnimation(AnimationSystem.easeInOutSine(2.4)
                            .repeatForever(autoreverses: true)) {
                orbPulse = true
            }
            // PHASE 2 — GATHER at 8.0 s: the wander shrinks, the leaf orients.
            DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
                withAnimation(.easeInOut(duration: 1.0)) { windFloating = false }
            }
            // PHASE 3 — DEPART at 9.0 s: accelerate to the screen edge.
            DispatchQueue.main.asyncAfter(deadline: .now() + 9.0) {
                progress = 1
                withAnimation(AnimationSystem.easeInOutSine(fireflyFlight)) {
                    flightScale = 1.3
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 11.2) {
                faded = true
            }
            // The sky recedes as the leaf leaves; gentle landing tap.
            DispatchQueue.main.asyncAfter(deadline: .now() + 11.4) {
                windSky = false
                impact(flash: false)
            }
            finish(after: 11.4 + AnimationSystem.Trail.lingerMax + 0.45)

        case .fingerFlick:
            // SLINGSHOT LAUNCH — blazing 600 ms. The thought explodes from the
            // pocket on a light streak, grows to 1.8, the band shudders behind.
            instrumentShown = true
            emojiAtTip = true
            ffSparks   = true
            ffFlick    = true                           // SNAP immediately
            streakIn   = true                           // bright flash
            HapticEngine.send()                         // satisfying snap
            SoundEngine.shared.play(for: "style.shimmer")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                progress = 1                            // streak away fast
                withAnimation(AnimationSystem.easeOutCubic(0.5)) {
                    flightScale = 1.8                   // grows big mid-flight
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { streakIn = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                faded = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.60) {
                impact()                                // flash · screen pulse · medium tap
                instrumentGone = true
            }
            finish(after: 0.6 + AnimationSystem.Trail.linger + 0.3)

        case .bowArrow:
            // FULL COMPASS: transform 300 → draw 400 (tension) → trembling
            // hold 150 → release → 700 ms streaking flight → flash bloom →
            // 400 ms return exhale
            instrumentShown = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                baDraw     = true                       // 25 % string pull
                emojiAtTip = true                       // nocked, becoming arrow
                baDimmed   = true                       // 5 % tension dim
                HapticEngine.sendSoft()                 // pulses build…
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                HapticEngine.send()                     // …soft → medium
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.70) {
                HapticEngine.lockOn()                   // full draw — strong
                withAnimation(AnimationSystem.easeInOutSine(0.03)
                                .repeatCount(5, autoreverses: true)) {
                    baJitter = true                     // ±2 px tremble
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
                baJitter   = false
                baReleased = true                       // string SNAPS — 50 ms
                baVibrate  = true                       // ±4 px ring, dampening
                baDimmed   = false
                HapticEngine.send()                     // the most satisfying
                SoundEngine.shared.play(for: "style.whoosh")
                progress = 1                            // 700 ms easeOutCubic
                withAnimation(AnimationSystem.easeOutCubic(0.35)) {
                    flightScale = 1.7                   // grows mid-flight
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) {
                baVibrate = false                       // rung out
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.50) {
                faded = true                            // trail lingers 1.2 s
                impact(flash: false)                    // screen pulse + medium tap
            }                                           // (the bow has its own bloom)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.60) {
                instrumentGone = true                   // string relaxed, exhale
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.90) {
                baEdgeFlash = true                      // bloom fades at the edge
            }
            finish(after: 1.9 + 1.2 + 0.3)
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // MARK: - ROCKET 🚀 — blast off (full-screen takeover)
    // ════════════════════════════════════════════════════════════════════

    private static var rocketOrange: Color { Color(hex: "#e0622c") }
    private static var rocketRed:    Color { Color(hex: "#e03c1c") }
    private static var rocketGold:   Color { Color(hex: "#FFD27a") }

    /// The flying rocket — body + nose + fins + porthole emoji + a flame
    /// streaming from the engine (behind the nose, before rotation).
    private var rocketGlyph: some View {
        ZStack {
            // Engine flame, streaming opposite the nose
            FlameShape()
                .fill(LinearGradient(colors: [.white, Self.rocketOrange, .clear],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 26, height: 62)
                .blur(radius: 2)
                .offset(y: 60)
            // Body
            RocketBodyShape()
                .fill(LinearGradient(colors: [.white, Color(hex: "#c8c8d2")],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 40, height: 96)
                .overlay(RocketNoseShape().fill(Color(hex: "#9a9aa6"))
                    .frame(width: 40, height: 96))
                .overlay(
                    ZStack {
                        ForEach([-1.0, 1.0], id: \.self) { side in
                            RocketFinShape(mirrored: side > 0)
                                .fill(Self.rocketOrange)
                                .frame(width: 16, height: 24)
                                .offset(x: CGFloat(side) * 19, y: 36)
                        }
                    }
                )
                .overlay(
                    Circle().fill(Color(hex: "#3a3550"))
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color(hex: "#6a6a76"), lineWidth: 1.5))
                        .offset(y: -6)
                )
            // The thought rides in the porthole
            symbol
                .scaleEffect(0.5)
                .offset(y: -6)
        }
        .frame(width: 60, height: 130)
    }

    private func rocketSend(end: CGSize) -> some View {
        let control = controlOffset(for: end, drama: 30)
        return ZStack {
            rocketWashes
            rocketCountdownView
            rocketSmokeView
            rocketTrailView(control: control, end: end)
            rocketFlightView(control: control, end: end)
            rocketExitView(end: end)
        }
    }

    /// Dark takeover + the orange ignition wash.
    @ViewBuilder
    private var rocketWashes: some View {
        Color.black.opacity(rkDarken ? 0.9 : 0)
            .ignoresSafeArea()
            .animation(.easeIn(duration: 0.4), value: rkDarken)
        Self.rocketOrange.opacity(rkIgnFlash ? 0.22 : 0)
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.1), value: rkIgnFlash)
    }

    /// The 3 · 2 · 1 number, large then fading.
    @ViewBuilder
    private var rocketCountdownView: some View {
        if let n = rkCount {
            Text("\(n)")
                .font(.system(size: 130, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: Self.rocketOrange.opacity(0.85), radius: 20)
                .scaleEffect(rkCountShown ? 1.0 : 1.45)
                .opacity(rkCountShown ? 1 : 0)
                .id(n)
                .animation(.easeOut(duration: 0.3), value: rkCountShown)
        }
    }

    /// Ignition smoke billowing from the base.
    @ViewBuilder
    private var rocketSmokeView: some View {
        if rkSmoke {
            ForEach(0..<12, id: \.self) { i in
                let dx = CGFloat((i * 53) % 80 - 40)
                let dy = 56 + CGFloat((i * 31) % 44)
                Circle()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 30, height: 30)
                    .blur(radius: 6)
                    .scaleEffect(rkSmoke ? 3.4 : 0.4)
                    .offset(x: dx, y: dy)
                    .opacity(rkSmoke ? 0 : 0.85)
                    .animation(.easeOut(duration: 1.1).delay(Double(i) * 0.02), value: rkSmoke)
            }
        }
    }

    /// The most dramatic trail in the app — 34 orange/red/white particles.
    private func rocketTrailView(control: CGSize, end: CGSize) -> some View {
        let palette: [Color] = [Self.rocketOrange, Self.rocketRed, .white, Self.rocketGold]
        return ForEach(0..<34, id: \.self) { i in
            let size: CGFloat = 6 + CGFloat(i % 5) * 2
            let color: Color = palette[i % palette.count]
            Circle()
                .fill(color.opacity(0.7))
                .frame(width: size, height: size)
                .blur(radius: 2)
                .opacity(rkTrailFaded ? 0 : 1)
                .modifier(CurvedFlightEffect(progress: rkProgress, start: .zero,
                                             control: control, end: end))
                .animation(.easeIn(duration: 1.5).delay(0.012 * Double(i)), value: rkProgress)
                .animation(.easeOut(duration: 2.0).delay(0.03 * Double(i % 12)), value: rkTrailFaded)
        }
    }

    /// The rocket itself — climbs toward the bearing, rotating to face it,
    /// growing dramatically then receding (perspective).
    private func rocketFlightView(control: CGSize, end: CGSize) -> some View {
        rocketGlyph
            .scaleEffect(rkScale)
            .rotationEffect(.radians(rad))
            .opacity(rkFaded ? 0 : 1)
            .shadow(color: Self.rocketOrange.opacity(0.7), radius: 16)
            .modifier(CurvedFlightEffect(progress: rkProgress, start: .zero,
                                         control: control, end: end))
            .animation(.easeIn(duration: 1.5), value: rkProgress)
            .animation(.easeOut(duration: 0.3), value: rkFaded)
    }

    /// Bright exit flash + a small lingering ember at the exit point.
    @ViewBuilder
    private func rocketExitView(end: CGSize) -> some View {
        Circle()
            .fill(RadialGradient(colors: [.white, Self.rocketOrange.opacity(0.5), .clear],
                                 center: .center, startRadius: 2, endRadius: 72))
            .frame(width: 144, height: 144)
            .offset(end)
            .opacity(rkExitFlash ? 1 : 0)
            .animation(.easeOut(duration: 0.25), value: rkExitFlash)
        Circle()
            .fill(Self.rocketOrange.opacity(rkEmber ? 0.0 : 0.5))
            .frame(width: 16, height: 16)
            .blur(radius: 4)
            .offset(end)
            .animation(.easeOut(duration: 1.4), value: rkEmber)
    }

    /// 3 · 2 · 1 → ignition → climb → exit. ~4 s total.
    private func launchRocket() {
        rkDarken = true

        // COUNTDOWN — 3 · 2 · 1, each with a beep + medium haptic
        for (idx, n) in [3, 2, 1].enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(idx) * 0.5) {
                rkCount = n
                rkCountShown = false
                withAnimation(.easeOut(duration: 0.2)) { rkCountShown = true }
                HapticEngine.rocketCountdown()
                SoundEngine.shared.play(for: "rocket.countdown")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
                    withAnimation(.easeIn(duration: 0.08)) { rkCountShown = false }
                }
            }
        }

        // IGNITION at 1.5 s — flame burst, smoke, orange flash, roar
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            rkCount = nil
            rkSmoke = true
            SoundEngine.shared.play(for: "rocket.blast")
            HapticEngine.rocketLaunch()                      // sustained .heavy ×3
            withAnimation(.easeIn(duration: 0.1)) { rkIgnFlash = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.1)) { rkIgnFlash = false }
            }
            withAnimation(.easeOut(duration: 0.3)) { rkScale = 2.5 }   // grows close
        }

        // LAUNCH at 1.8 s — climbs away toward the person, receding
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            rkProgress = 1
            withAnimation(.easeIn(duration: 1.5)) { rkScale = 0.3 }    // perspective
        }

        // Fade the rocket + trail near the edge
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.1) {
            rkFaded = true
            rkTrailFaded = true
        }

        // EXIT at 3.3 s — final bright flash, ember glow lingers
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.3) {
            rkExitFlash = true
            rkEmber = true
            HapticEngine.sendImpact()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.easeOut(duration: 0.2)) { rkExitFlash = false }
            }
        }

        finish(after: 4.0)
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
    /// [2/5] The sender — shown at the top of the replay, always visible.
    var fromName: String = ""
    let onDone: () -> Void

    @State private var dimmed   = false
    @State private var progress: CGFloat = 0   // edge → center
    @State private var bloomed  = false
    @State private var fadingOut = false
    @State private var wandBurst = false       // 🪄 crystal burst at the start
    @State private var tipping = true          // the 800 ms bucket-tip preamble
    @State private var landingDone = false     // the full landing finished

    private var hue: Color { EmojiHue.color(for: emoji) }
    private var rad: Double { bearingDegrees * .pi / 180 }

    private static let wandGold = Color(hex: "#D4AF37")
    private static let wandPurple = Color(hex: "#9b7fc0")
    private var isWand: Bool { style == .wand }

    /// 70–80 % of the original send duration (wand: a tight 70 %).
    private var travelDuration: Double {
        style.sendDuration * (isWand ? 0.70 : 0.75)
    }

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

                // [2/5] Sender name — always visible at the top of the replay
                if !fromName.isEmpty {
                    VStack {
                        Text("from \(fromName) ✦")
                            .font(.system(size: 22, design: .serif).italic())
                            .foregroundColor(Color(hex: "#c4a8d4"))
                            .shadow(color: .black.opacity(0.5), radius: 6)
                            .opacity(dimmed ? 1 : 0)
                            .animation(.easeIn(duration: 0.4), value: dimmed)
                            .padding(.top, 70)
                        Spacer()
                    }
                    .allowsHitTesting(false)
                }

                // 🪄 WAND — a memory of the cast: the crystal is already
                // glowing (no shake), it bursts at the start, and a sparkle
                // trail follows the thought home at 70 % duration.
                if isWand {
                    // BURST — sparkles scattering from the crystal at the edge
                    ForEach(0..<18, id: \.self) { i in
                        let a = Double(i) / 18 * 2 * .pi
                        let dist: CGFloat = wandBurst ? 55 + CGFloat(i % 5) * 7 : 0
                        Circle()
                            .fill(i % 2 == 0 ? Self.wandGold : Self.wandPurple)
                            .frame(width: i % 3 == 0 ? 4 : 3, height: i % 3 == 0 ? 4 : 3)
                            .blur(radius: 0.5)
                            .offset(x: edge.width + CGFloat(cos(a)) * dist,
                                    y: edge.height + CGFloat(sin(a)) * dist)
                            .opacity(wandBurst ? 0 : (dimmed ? 0.95 : 0))
                            .animation(.easeOut(duration: 0.55), value: wandBurst)
                            .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    }
                    // TRAIL — gold/purple sparkles following the thought home
                    ForEach(0..<10, id: \.self) { i in
                        Circle()
                            .fill((i % 2 == 0 ? Self.wandGold : Self.wandPurple).opacity(0.7))
                            .frame(width: 5, height: 5)
                            .blur(radius: 1.5)
                            .opacity(fadingOut ? 0 : (dimmed ? 1 : 0))
                            .modifier(CurvedFlightEffect(progress: progress,
                                                         start: edge, control: control,
                                                         end: .zero))
                            .animation(AnimationSystem.easeInOutQuad(travelDuration)
                                        .delay(0.02 * Double(i + 1)), value: progress)
                            .animation(.easeOut(duration: 0.3), value: fadingOut)
                            .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    }
                }

                // 2–4 · Edge → center in the original direction, then bloom
                Text(emoji)
                    .font(.system(size: 54))
                    .scaleEffect(bloomed ? 1.0 : 0.55)
                    .shadow(color: (isWand ? Self.wandPurple : hue).opacity(AnimationSystem.Glow.opacity),
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

                // ── THE REPLAY IS THE LANDING — the full per-instrument
                // landing drama plays over the themed world, then lingers on
                // the reveal. (Reliving the original moment completely.) ──
                CatchWorldBackground(style: style)
                    .ignoresSafeArea()
                    .opacity(dimmed ? 1 : 0)
                    .animation(.easeIn(duration: 0.3), value: dimmed)
                // The bucket TIPS and SPILLS empty first (800 ms), then the
                // instrument landing arrives into the emptied bucket.
                if dimmed && tipping {
                    BucketTipView(hue: hue, bubbleEmoji: emoji,
                                  onComplete: { withAnimation(.easeOut(duration: 0.2)) { tipping = false } })
                }
                if dimmed && !tipping && !landingDone {
                    InstrumentLandingView(style: style, emoji: emoji,
                                          onComplete: { landingComplete() })
                }
                if landingDone {
                    Text(emoji).font(.system(size: 72))
                        .shadow(color: hue.opacity(0.6), radius: 24)
                        .opacity(fadingOut ? 0 : 1)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
                // Sender name — always visible at the top, 28pt serif lavender
                if !fromName.isEmpty {
                    VStack {
                        Text("from \(fromName) ✦")
                            .font(.system(size: 28, design: .serif))
                            .foregroundColor(Color(hex: "#c4a8d4"))
                            .shadow(color: .black.opacity(0.6), radius: 8)
                            .opacity(dimmed ? 1 : 0)
                            .padding(.top, 70)
                        Spacer()
                    }
                    .allowsHitTesting(false)
                }
            }
        }
        .onAppear { play() }
        .onTapGesture { finish() }   // a memory shouldn't trap anyone
    }

    private func play() {
        withAnimation(.easeIn(duration: 0.3)) { dimmed = true }
        // The themed world appears, then the full landing plays (driven by
        // InstrumentLandingView). The old abbreviated flight is hidden behind
        // the opaque world.
    }

    /// The landing finished — linger on the reveal, then dismiss.
    private func landingComplete() {
        landingDone = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { finish() }
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


// ════════════════════════════════════════════════════════════════════════
// MARK: - Bow silhouette shapes
// ════════════════════════════════════════════════════════════════════════

/// The bow's limbs — an upward arch across the frame (aimed pre-rotation).
/// `tension` bends the arc slightly more while the string is drawn.
struct BowArchShape: Shape {
    var tension: CGFloat = 0

    var animatableData: CGFloat {
        get { tension }
        set { tension = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let y = rect.height * 0.55
        p.move(to: CGPoint(x: 0, y: y))
        // Control point extends ~40 % beyond the chord line
        p.addQuadCurve(to: CGPoint(x: rect.width, y: y),
                       control: CGPoint(x: rect.width / 2,
                                        y: y - rect.height * 0.40 - tension))
        return p
    }
}

/// A stylized minimal finger — tip circle, tapering shaft, wider base —
/// one smooth shape, warm and human, never photorealistic.
struct FingerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        // Fingertip — circle, ~22 pt radius at the top
        let tipR = w * 0.32
        p.addEllipse(in: CGRect(x: w / 2 - tipR, y: 0, width: tipR * 2, height: tipR * 2))
        // Shaft — tapers slightly toward the base
        p.move(to: CGPoint(x: w / 2 - tipR * 0.9, y: tipR))
        p.addLine(to: CGPoint(x: w / 2 + tipR * 0.9, y: tipR))
        p.addLine(to: CGPoint(x: w / 2 + tipR * 1.15, y: h * 0.62))
        p.addLine(to: CGPoint(x: w / 2 - tipR * 1.15, y: h * 0.62))
        p.closeSubpath()
        // Base — the rest of the hand, wider rounded form
        p.addRoundedRect(in: CGRect(x: w * 0.06, y: h * 0.58,
                                    width: w * 0.88, height: h * 0.40),
                         cornerSize: CGSize(width: w * 0.22, height: w * 0.22))
        return p
    }
}

/// Arrowhead + shaft, aimed up (pre-rotation) — rides behind the emoji.
struct ArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        // Head — two triangles meeting at the tip
        p.move(to: CGPoint(x: w / 2, y: 0))
        p.addLine(to: CGPoint(x: w, y: h * 0.28))
        p.addLine(to: CGPoint(x: w / 2, y: h * 0.20))
        p.addLine(to: CGPoint(x: 0, y: h * 0.28))
        p.closeSubpath()
        // Shaft
        p.addRect(CGRect(x: w / 2 - w * 0.10, y: h * 0.22,
                         width: w * 0.20, height: h * 0.78))
        return p
    }
}

/// The string — straight limb-to-limb, bending back to the nock as drawn.
struct BowStringShape: Shape {
    var pull: CGFloat   // 0 = straight, ~9 = full draw

    var animatableData: CGFloat {
        get { pull }
        set { pull = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let y = rect.height * 0.55
        p.move(to: CGPoint(x: 0, y: y))
        p.addLine(to: CGPoint(x: rect.width / 2, y: y + pull * 2.2))
        p.addLine(to: CGPoint(x: rect.width, y: y))
        return p
    }
}
