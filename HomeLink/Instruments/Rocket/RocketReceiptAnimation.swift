// RocketReceiptAnimation.swift
// Pointward › Instruments › Rocket
//
// ACT 3 of 3 — the full-screen ROCKET receipt (v2 PARACHUTE) + emoji reveal.
//
// The approved v2 design: a capsule falls in from the top of a starfield over a
// curved Earth horizon, its parachute DEPLOYS with a whoosh, it FLOATS down on a
// lazy sway, then LANDS softly into the shared bucket — AUTO-CATCH (the rocket
// lands itself) — and hands off to the shared EmojiRevealView.
//
//   FALL    (1.50s)  capsule only, grows 0.4 → 1.0, slight wobble, exhaust
//   DEPLOY  (0.80s)  canopy inflates 0.15 → 1.0, whoosh (in rocket_receipt.wav)
//   FLOAT   (4.55s)  gentle sway + tilt, drifts down toward the bucket
//   LAND    (0.90s)  final drop, canopy collapses, capsule settles in the bucket
//   → EmojiRevealView (the reveal)                                      = 7.75s
//
// Screen-coordinate rules (InstrumentBoundaries): GeometryReader root, background
// .ignoresSafeArea(), every position from geo.size.

import SwiftUI

struct RocketReceiptAnimation: View {

    // ── Receives (parity with the other receipts) ───────────────────────────
    let senderBearing: Double       // unused — the capsule falls from the top
    let emoji: String
    var message: String? = nil
    var tagline: String? = nil
    let fromName: String
    var onRevealed: () -> Void = {}
    var onFinished: () -> Void = {}

    // ── Source-of-truth timing + sound ──────────────────────────────────────
    static let duration: Double = InstrumentBoundaries.Receipt.rocket   // 7.75
    static let soundFile: String = RocketSounds.receiptFile
    static let revealLinger: Double = InstrumentBoundaries.Reveal.linger

    // Phase boundaries (seconds). 1.5 + 0.8 + 4.55 + 0.9 = 7.75.
    private static let fallDur:   Double = 1.5
    private static let deployDur: Double = 0.8
    private static let floatDur:  Double = 4.55
    private static let landDur:   Double = 0.9
    private static let fallEnd:   Double = fallDur                                   // 1.50
    private static let deployEnd: Double = fallDur + deployDur                       // 2.30
    private static let floatEnd:  Double = fallDur + deployDur + floatDur            // 6.85
    private static let total:     Double = fallDur + deployDur + floatDur + landDur  // 7.75

    private static let bucketW: CGFloat = 150
    private static let bucketH: CGFloat = 128
    private static let canopyW: CGFloat = 160
    private static let capsuleW: CGFloat = 36
    private static let capsuleH: CGFloat = 56
    private static let linesLen: CGFloat = 64    // suspension line length

    // Palette
    private static let panelA  = Color(hex: "#c4a8d4")
    private static let panelB  = Color(hex: "#9b8fa8")
    private static let panelC  = Color(hex: "#e8d4f8")
    private static let capsule = Color(hex: "#e8e4f0")
    private static let capsuleShade = Color(hex: "#d0c8e0")
    private static let accentSoft = Color(hex: "#c4a8d4")
    private static let accentMid  = Color(hex: "#7c6b8e")

    @State private var start: Date? = nil
    @State private var revealing = false
    @State private var landedHaptic = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if revealing {
                    // THE PEAK — the ONE shared reveal screen, on deep space.
                    EmojiRevealView(emoji: emoji, message: message,
                                    tagline: tagline,
                                    context: .received(fromName: fromName),
                                    ambient: .rocket,
                                    onDismiss: onFinished)
                        .transition(.opacity)
                } else {
                    TimelineView(.animation) { timeline in
                        let elapsed = clampedElapsed(now: timeline.date)
                        ZStack {
                            // BACKGROUND — deep space, full screen (RULE 2).
                            InstrumentBackground.deepSpace.ignoresSafeArea()
                            stars(geo: geo)
                            earthHorizon(geo: geo)
                            bucket(geo: geo)
                            rocketUnit(geo: geo, elapsed: elapsed)
                            label(geo: geo, elapsed: elapsed)
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
        .onAppear { begin() }
    }

    // ── Sequencing ──────────────────────────────────────────────────────────

    private func begin() {
        start = Date()
        // The full rocket_receipt.wav (7.75s) carries the engine → whoosh →
        // wind → settle; if the file is missing the player no-ops (never crash).
        InstrumentSoundPlayer.shared.playReceipt(.rocket)
        HapticPattern.singleSoft.fire()   // the capsule enters

        // Touchdown — the soft settle into the bucket (no sound, haptic only).
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.floatEnd) {
            HapticPattern.doubleSoft.fire()
        }
        // After landing → the emoji reveal.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.total) {
            onRevealed()
            withAnimation(.easeInOut(duration: 0.3)) { revealing = true }
        }
    }

    private func clampedElapsed(now: Date) -> Double {
        guard let start else { return 0 }
        return min(max(0, now.timeIntervalSince(start)), Self.total)
    }

    // ── Geometry per phase ──────────────────────────────────────────────────

    private func bucketPoint(_ size: CGSize) -> CGPoint {
        CGPoint(x: size.width / 2, y: size.height - 110)
    }

    /// The capsule's centre Y over the whole journey.
    private func capsuleY(_ size: CGSize, _ e: Double) -> CGFloat {
        let h = size.height
        let bucketTop = bucketPoint(size).y - 24    // settle just inside the mouth
        if e <= Self.fallEnd {
            return lerp(-0.14 * h, 0.20 * h, easeOut(e / Self.fallDur))
        } else if e <= Self.deployEnd {
            return 0.20 * h
        } else if e <= Self.floatEnd {
            let p = (e - Self.deployEnd) / Self.floatDur               // linear drift
            return lerp(0.20 * h, bucketTop - 140, p)
        } else {
            let p = easeOut((e - Self.floatEnd) / Self.landDur)
            return lerp(bucketTop - 140, bucketTop, p)
        }
    }

    /// Horizontal sway — slight wobble on the fall, lazy sway on the float.
    private func swayX(_ e: Double) -> CGFloat {
        if e <= Self.fallEnd {
            return CGFloat(sin(e * 9)) * 5
        } else if e <= Self.floatEnd {
            let t = e - Self.deployEnd
            return CGFloat(sin(t * 0.55) * 12 + sin(t * 0.28) * 6)
        } else {
            // Damp toward 0 as it lands.
            let p = (e - Self.floatEnd) / Self.landDur
            let t = Self.floatDur
            return CGFloat(sin(t * 0.55) * 12 + sin(t * 0.28) * 6) * (1 - CGFloat(p))
        }
    }

    private func tilt(_ e: Double) -> Double {
        guard e > Self.deployEnd, e <= Self.floatEnd else { return 0 }
        let t = e - Self.deployEnd
        return sin(t * 0.55) * 4
    }

    private func capsuleScale(_ e: Double) -> CGFloat {
        e <= Self.fallEnd ? (0.4 + 0.6 * CGFloat(easeOut(e / Self.fallDur))) : 1.0
    }

    /// Canopy inflation + collapse. Returns (scaleX, scaleY) on the canopy.
    private func canopyScale(_ e: Double) -> (CGFloat, CGFloat) {
        if e <= Self.fallEnd {
            return (0, 0)                                    // not deployed yet
        } else if e <= Self.deployEnd {
            let s = 0.15 + 0.85 * CGFloat(easeOut((e - Self.fallEnd) / Self.deployDur))
            return (s, s)                                    // inflate 0.15 → 1.0
        } else if e <= Self.floatEnd {
            return (1, 1)
        } else {
            let p = CGFloat(easeOut((e - Self.floatEnd) / Self.landDur))
            return (1 - 0.85 * p, 1 - 0.95 * p)              // collapse on land
        }
    }

    // ── The parachute + capsule unit ────────────────────────────────────────

    @ViewBuilder
    private func rocketUnit(geo: GeometryProxy, elapsed e: Double) -> some View {
        let size = geo.size
        let cy = capsuleY(size, e)
        let cx = size.width / 2 + swayX(e)
        let cScale = capsuleScale(e)
        let (canX, canY) = canopyScale(e)
        let canopyDeployed = e > Self.fallEnd

        ZStack {
            // Faint exhaust trail above the capsule during the fall.
            if e <= Self.fallEnd {
                exhaustTrail()
                    .frame(width: 14, height: 70)
                    .position(x: cx, y: cy - Self.capsuleH * cScale * 0.5 - 38)
                    .opacity(0.5 * (1 - e / Self.fallDur))
            }

            // Canopy + suspension lines (once deploying).
            if canopyDeployed {
                let canopyCenterY = cy - Self.linesLen - Self.canopyW * 0.22
                suspensionLines(cx: cx, capsuleTopY: cy - Self.capsuleH / 2,
                                canopyY: canopyCenterY, scaleX: canX)
                    .opacity(Double(min(1, canX * 1.4)))
                ParachuteCanopy()
                    .frame(width: Self.canopyW, height: Self.canopyW * 0.55)
                    .scaleEffect(x: canX, y: canY, anchor: .bottom)
                    .position(x: cx, y: canopyCenterY)
            }

            // Capsule — the bullet body.
            CapsuleBody()
                .frame(width: Self.capsuleW, height: Self.capsuleH)
                .scaleEffect(cScale)
                .rotationEffect(.degrees(tilt(e)))
                .position(x: cx, y: cy)
        }
    }

    private func exhaustTrail() -> some View {
        LinearGradient(colors: [Color.orange.opacity(0.5), Color.yellow.opacity(0.2), .clear],
                       startPoint: .bottom, endPoint: .top)
            .clipShape(Capsule())
            .blur(radius: 3)
    }

    private func suspensionLines(cx: CGFloat, capsuleTopY: CGFloat,
                                 canopyY: CGFloat, scaleX: CGFloat) -> some View {
        Path { p in
            let rimY = canopyY + Self.canopyW * 0.22
            let half = (Self.canopyW * 0.5) * scaleX
            for i in 0..<6 {
                let f = CGFloat(i) / 5                     // 0…1 across the rim
                let rx = cx - half + half * 2 * f
                p.move(to: CGPoint(x: rx, y: rimY))
                p.addLine(to: CGPoint(x: cx + (f - 0.5) * Self.capsuleW,
                                      y: capsuleTopY))
            }
        }
        .stroke(Self.accentSoft.opacity(0.45), lineWidth: 0.7)
    }

    // ── Bucket — the shared wooden skin ─────────────────────────────────────

    private func bucket(geo: GeometryProxy) -> some View {
        let p = bucketPoint(geo.size)
        let wood = Color(hex: "#8B4513"); let woodDark = Color(hex: "#6E3A1E")
        let brass = Color(hex: "#C9A86A")
        return ZStack {
            BucketHandleShape()
                .stroke(brass, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: Self.bucketW * 0.9, height: 52)
                .offset(y: -Self.bucketH / 2 - 16)
            BucketShape()
                .fill(LinearGradient(colors: [wood, woodDark],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: Self.bucketW, height: Self.bucketH)
                .overlay(
                    VStack {
                        Capsule().fill(brass).frame(height: 6)
                            .padding(.horizontal, -2).padding(.top, 12)
                        Spacer()
                        Capsule().fill(brass).frame(height: 6)
                            .padding(.horizontal, 6).padding(.bottom, 14)
                    }
                    .frame(width: Self.bucketW, height: Self.bucketH).opacity(0.85)
                )
                .shadow(color: .black.opacity(0.4), radius: 10, y: 6)
        }
        .position(p)
    }

    // ── Starfield ───────────────────────────────────────────────────────────

    private struct Star { let x: CGFloat; let y: CGFloat; let r: CGFloat; let o: Double; let lav: Bool }
    private static let stars: [Star] = (0..<200).map { i in
        // Deterministic hash → stable positions (no Date/random in the body).
        let h1 = Double((i &* 2654435761) % 100000) / 100000
        let h2 = Double((i &* 40503 &+ 12345) % 100000) / 100000
        let h3 = Double((i &* 92821 &+ 7) % 1000) / 1000
        return Star(x: CGFloat(h1), y: CGFloat(h2),
                    r: CGFloat(0.2 + h3 * 1.2),
                    o: 0.25 + h3 * 0.65,
                    lav: i % 7 == 0)
    }

    private func stars(geo: GeometryProxy) -> some View {
        Canvas { ctx, size in
            for s in Self.stars {
                let rect = CGRect(x: s.x * size.width, y: s.y * size.height,
                                  width: s.r * 2, height: s.r * 2)
                let color: Color = s.lav ? Self.accentSoft : .white
                ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(s.o)))
            }
        }
        .allowsHitTesting(false)
    }

    // ── Earth horizon at the bottom ─────────────────────────────────────────

    private func earthHorizon(geo: GeometryProxy) -> some View {
        let w = geo.size.width
        let h = geo.size.height
        let earthH: CGFloat = 145
        return Canvas { ctx, size in
            // The Earth is a huge ellipse whose centre is far BELOW the screen —
            // only its curved top edge shows as the horizon.
            let earthR = w * 1.8
            let cx = w / 2
            let cyEarth = h + earthR - earthH       // centre below screen
            let earthRect = CGRect(x: cx - earthR, y: cyEarth - earthR,
                                   width: earthR * 2, height: earthR * 2)

            // Atmosphere glow above the horizon.
            ctx.fill(
                Path(ellipseIn: earthRect.insetBy(dx: -10, dy: -10)),
                with: .radialGradient(
                    Gradient(colors: [Color(hex: "#3a6ea5").opacity(0.0),
                                      Color(hex: "#4a9abb").opacity(0.35)]),
                    center: CGPoint(x: cx, y: cyEarth),
                    startRadius: earthR - 26, endRadius: earthR + 14))

            // The Earth body.
            let earth = Path(ellipseIn: earthRect)
            ctx.fill(earth, with: .linearGradient(
                Gradient(colors: [Color(hex: "#1f4e79"), Color(hex: "#13314f")]),
                startPoint: CGPoint(x: cx, y: cyEarth - earthR),
                endPoint: CGPoint(x: cx, y: h)))

            // Continents — soft blobs near the horizon.
            ctx.clip(to: earth)
            let blobs: [(CGFloat, CGFloat, CGFloat)] = [
                (0.20, 0.30, 46), (0.55, 0.18, 60), (0.78, 0.40, 40), (0.38, 0.55, 34)
            ]
            for b in blobs {
                let bx = b.0 * w, by = h - earthH * (1 - b.1) + 8
                ctx.fill(Path(ellipseIn: CGRect(x: bx - b.2, y: by, width: b.2 * 2, height: b.2)),
                         with: .color(Color(hex: "#2e6b3e").opacity(0.55)))
            }
            // City light dots.
            for i in 0..<26 {
                let lx = CGFloat(Double((i &* 73 &+ 11) % 100) / 100) * w
                let ly = h - earthH * 0.5 + CGFloat(Double((i &* 31) % 100) / 100) * (earthH * 0.45)
                ctx.fill(Path(ellipseIn: CGRect(x: lx, y: ly, width: 1.4, height: 1.4)),
                         with: .color(Color(hex: "#ffe9a8").opacity(0.8)))
            }
        }
        .overlay(
            // Bright horizon line glow.
            Ellipse()
                .stroke(Color(hex: "#7ec8e3").opacity(0.7), lineWidth: 2)
                .frame(width: w * 3.6, height: w * 3.6)
                .position(x: w / 2, y: h + w * 1.8 - earthH)
                .blur(radius: 3)
        )
        .frame(width: w, height: h)
        .allowsHitTesting(false)
    }

    // ── Label ───────────────────────────────────────────────────────────────

    @ViewBuilder
    private func label(geo: GeometryProxy, elapsed e: Double) -> some View {
        VStack {
            Spacer()
            Text(message(e))
                .font(.system(size: 20, design: .serif).italic())
                .foregroundColor(Self.accentSoft)
                .shadow(color: .black.opacity(0.5), radius: 6)
                .padding(.bottom, geo.size.height * 0.06)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.5), value: message(e))
        }
    }

    private func message(_ e: Double) -> String {
        let name = fromName.isEmpty ? "someone" : fromName
        if e < Self.fallEnd   { return "\(name) sent something ✦" }
        if e < Self.floatEnd  { return "drifting down to you ✦" }
        return "almost here ✦"
    }

    // ── Easing ──────────────────────────────────────────────────────────────

    private func easeOut(_ t: Double) -> Double { let x = min(max(t, 0), 1); return 1 - pow(1 - x, 3) }
    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: Double) -> CGFloat { a + (b - a) * CGFloat(t) }
}

// MARK: - Parachute canopy (multi-panel dome)

private struct ParachuteCanopy: View {
    private static let panelA = Color(hex: "#c4a8d4")
    private static let panelB = Color(hex: "#9b8fa8")
    private static let panelC = Color(hex: "#e8d4f8")
    private static let accentSoft = Color(hex: "#c4a8d4")

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // Alternating panels as vertical wedges of the dome.
                Canvas { ctx, size in
                    let panels = 6
                    let colors = [Self.panelB, Self.panelA, Self.panelC,
                                  Self.panelA, Self.panelB, Self.panelC]
                    for i in 0..<panels {
                        let x0 = size.width * CGFloat(i) / CGFloat(panels)
                        let x1 = size.width * CGFloat(i + 1) / CGFloat(panels)
                        let xm = (x0 + x1) / 2
                        var p = Path()
                        p.move(to: CGPoint(x: x0, y: size.height))
                        // Dome top — each panel arcs up toward the centre vent.
                        p.addQuadCurve(to: CGPoint(x: x1, y: size.height),
                                       control: CGPoint(x: xm, y: -size.height * 0.15))
                        p.closeSubpath()
                        ctx.fill(p, with: .color(colors[i]))
                    }
                    // Highlight on the upper panels.
                    let hi = Path(ellipseIn: CGRect(x: size.width * 0.18, y: -size.height * 0.1,
                                                    width: size.width * 0.5, height: size.height * 0.7))
                    ctx.fill(hi, with: .color(.white.opacity(0.18)))
                }
                .clipShape(DomeShape())

                // Canopy rim line.
                DomeShape().stroke(Self.accentSoft.opacity(0.6), lineWidth: 1.2)

                // Vent circle at the top — dark with a lavender ring.
                Circle()
                    .fill(Color(hex: "#2a2336"))
                    .frame(width: w * 0.10, height: w * 0.10)
                    .overlay(Circle().stroke(Self.accentSoft.opacity(0.7), lineWidth: 1))
                    .position(x: w / 2, y: h * 0.06)
            }
        }
    }
}

private struct DomeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY),
                       control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.15))
        p.closeSubpath()
        return p
    }
}

// MARK: - Capsule body (one-piece rounded bullet)

private struct CapsuleBody: View {
    private static let body  = Color(hex: "#e8e4f0")
    private static let shade = Color(hex: "#d0c8e0")
    private static let accentMid = Color(hex: "#7c6b8e")
    private static let accentSoft = Color(hex: "#c4a8d4")

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // One-piece bullet — rounded naturally at the top, the nose is
                // part of the body (same colour).
                BulletShape()
                    .fill(LinearGradient(colors: [Self.shade, Self.body, Self.body],
                                         startPoint: .leading, endPoint: .trailing))
                    .overlay(BulletShape().stroke(Self.accentMid.opacity(0.35), lineWidth: 0.8))

                // Colour band.
                Rectangle()
                    .fill(Self.accentMid.opacity(0.4))
                    .frame(width: w, height: h * 0.10)
                    .position(x: w / 2, y: h * 0.46)
                    .clipShape(BulletShape())

                // Window — dark circle, lavender ring, reflection dot.
                Circle()
                    .fill(Color(hex: "#1c1726"))
                    .frame(width: w * 0.42, height: w * 0.42)
                    .overlay(Circle().stroke(Self.accentSoft.opacity(0.8), lineWidth: 1))
                    .overlay(
                        Circle().fill(.white.opacity(0.6))
                            .frame(width: w * 0.10, height: w * 0.10)
                            .offset(x: -w * 0.07, y: -w * 0.07)
                    )
                    .position(x: w / 2, y: h * 0.34)

                // Retro base ring.
                Capsule()
                    .fill(Self.accentMid)
                    .frame(width: w * 0.96, height: h * 0.07)
                    .position(x: w / 2, y: h * 0.95)
            }
        }
    }
}

/// A one-piece bullet — a rectangle with a smoothly rounded top (the nose) and a
/// slightly rounded base.
private struct BulletShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let noseH = h * 0.42
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY - h * 0.05))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + noseH))
        // Rounded nose.
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY),
                       control: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + noseH),
                       control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - h * 0.05))
        // Rounded base.
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - h * 0.05),
                       control: CGPoint(x: rect.midX, y: rect.maxY + h * 0.06))
        p.closeSubpath()
        return p
    }
}
