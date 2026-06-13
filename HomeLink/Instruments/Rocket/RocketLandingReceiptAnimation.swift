// RocketLandingReceiptAnimation.swift
// Pointward › Instruments › Rocket
//
// THE FINAL ROCKET RECEIPT — a MERGE of the two approved rocket arrivals:
//
//   • BASE (from RocketReceiptAnimation, the v2 PARACHUTE): the full-screen
//     environment — the deep-space starfield, the curved EARTH HORIZON, the
//     shared WOODEN BUCKET, the descent-toward-bucket framing, and the approved
//     rocket_receipt.wav sound + haptics.
//   • DESCENT (from RocketLanding, the LEGS-down lander): instead of a parachute,
//     the rocket DESCENDS UPRIGHT, its LANDING LEGS DEPLOY, and it TOUCHES DOWN
//     on the curved earth BESIDE the bucket — flash · dust · BOOM · settle.
//   • DELIVERY (new): on touchdown the NOSE CONE SPLITS and the EMOJI POPS OUT OF
//     THE CONE, arcs over, and DROPS into the bucket — then the shared reveal.
//
//   FALL    (2.00s)  rocket descends upright, grows 0.3 → 1.0, exhaust flames
//   LEGS    (1.20s)  landing legs swing out, switch to a hover flame
//   TOUCH   (0.80s)  final settle — flash · dust burst · BOOM haptic · bounce
//   EJECT   (1.60s)  nose cone splits, emoji pops from the cone, arcs to bucket
//   SETTLE  (0.40s)  emoji drops in, cyan/lavender catch glow
//   → EmojiRevealView (.rocket)                                          ≈ 6.0s
//
// Screen-coordinate rules (InstrumentBoundaries): GeometryReader root, background
// .ignoresSafeArea(), every position derived from geo.size. No hardcoded screen
// dimensions, no UIScreen.main.bounds.

import SwiftUI

struct RocketLandingReceiptAnimation: View {

    // ── Receives (parity with the other receipts) ───────────────────────────
    let senderBearing: Double       // unused — the rocket descends from the top
    let emoji: String
    var message: String? = nil
    var tagline: String? = nil
    let fromName: String
    var onRevealed: () -> Void = {}
    var onFinished: () -> Void = {}

    // ── Palette (shared with the parachute receipt) ─────────────────────────
    private static let accentSoft = Color(hex: "#c4a8d4")
    private static let accentMid  = Color(hex: "#7c6b8e")
    private static let orange = Color(hex: "#e0622c")
    private static let amber  = Color(hex: "#e08a3c")

    private static let bucketW: CGFloat = 150
    private static let bucketH: CGFloat = 128

    // ── Animation state (legs-down landing, from RocketLanding) ─────────────
    @State private var descend: CGFloat = 0      // 0 top → 1 landed
    @State private var grow: CGFloat = 0.3
    @State private var legs: CGFloat = 0         // landing legs out
    @State private var hover = false             // hover flames on final descent
    @State private var shake: CGFloat = 0
    @State private var flash = false
    @State private var dust = false
    @State private var noseOpen: CGFloat = 0     // nose cone split
    @State private var bounce: CGFloat = 1
    // ── Emoji ejection (new — pops from the cone into the bucket) ───────────
    @State private var emojiScale: CGFloat = 0
    @State private var emojiEject: CGFloat = 0   // 0 at cone → 1 in the bucket
    @State private var bucketGlow = false
    @State private var revealing = false

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
                    ZStack {
                        // BACKGROUND — deep space, full screen (RULE 2).
                        InstrumentBackground.deepSpace.ignoresSafeArea()
                        stars(geo: geo)
                        earthHorizon(geo: geo)
                        bucket(geo: geo)
                        rocketUnit(geo: geo)
                        ejectedEmoji(geo: geo)
                        label(geo: geo)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .onAppear { run() }
    }

    // ── Geometry ─────────────────────────────────────────────────────────────

    /// The rocket lands at the left; the bucket sits to its right. The emoji
    /// ejects from the cone and arcs across into the bucket.
    private func rocketX(_ size: CGSize) -> CGFloat { size.width * 0.34 }

    /// The curved earth's surface Y at a given x — the SAME ellipse drawn by
    /// earthHorizon, so the rocket + bucket seat exactly on the VISIBLE horizon
    /// (no floating gap).
    private func earthSurfaceY(_ size: CGSize, atX x: CGFloat) -> CGFloat {
        let earthH: CGFloat = 145
        let earthR = size.width * 1.8
        let cyEarth = size.height + earthR - earthH
        let dx = x - size.width / 2
        let inside = max(0, earthR * earthR - dx * dx)
        return cyEarth - inside.squareRoot()
    }

    /// Legs-bottom offset from the rocket's centre (frame 110×200, scale 1).
    private static let rocketFootOffset: CGFloat = 86

    /// The bucket sits SEATED on the earth, lightly planted (base ~34pt below the
    /// surface) at its x — so the rocket and bucket share one grounded horizon.
    private func bucketPoint(_ size: CGSize) -> CGPoint {
        let bx = size.width * 0.66
        return CGPoint(x: bx, y: earthSurfaceY(size, atX: bx) - 34)
    }

    /// The rocket centre Y over the descent: from the top of the screen down to a
    /// SEATED pad where its legs touch the curved earth surface (no floating gap).
    private func rocketY(_ size: CGSize) -> CGFloat {
        let topY = size.height * 0.10
        let padY = earthSurfaceY(size, atX: rocketX(size)) - Self.rocketFootOffset
        return topY + (padY - topY) * descend
    }

    /// Where the cone's mouth sits when the rocket has landed — the emoji's
    /// launch point.
    private func conePoint(_ size: CGSize) -> CGPoint {
        CGPoint(x: rocketX(size), y: rocketY(size) - 84 * grow)
    }

    // ── The legs-down rocket (from RocketLanding) ───────────────────────────

    @ViewBuilder
    private func rocketUnit(geo: GeometryProxy) -> some View {
        let size = geo.size
        rocket
            .scaleEffect(grow * bounce)
            .offset(x: shake)
            .position(x: rocketX(size), y: rocketY(size))

        // Flash + dust burst at the pad (touchdown).
        Color.white.opacity(flash ? 0.3 : 0).ignoresSafeArea().allowsHitTesting(false)
        if dust {
            ForEach(0..<20, id: \.self) { i in
                let a = Double(i) / 20 * 2 * .pi
                Circle().fill(Color(hex: "#9a8f80").opacity(0.6))
                    .frame(width: 8, height: 8)
                    .offset(x: CGFloat(cos(a)) * 120, y: CGFloat(sin(a)) * 40)
                    .opacity(0)
                    .animation(.easeOut(duration: 1.0), value: dust)
                    .position(x: rocketX(size), y: rocketY(size) + 70)
            }
        }
    }

    private var rocket: some View {
        ZStack {
            // hover/landing flames at the base
            FlameShape().fill(LinearGradient(colors: [Self.amber, Self.orange, .clear],
                                             startPoint: .top, endPoint: .bottom))
                .frame(width: 22, height: hover ? 26 : 56)
                .offset(y: 86)
                .opacity(noseOpen > 0 ? 0 : 1)
            // landing legs
            ForEach([-1.0, 1.0], id: \.self) { side in
                Rectangle().fill(Color(hex: "#8a8a8a"))
                    .frame(width: 3, height: 24 * legs)
                    .rotationEffect(.degrees(side > 0 ? 28 : -28))
                    .offset(x: CGFloat(side) * 22, y: 78)
            }
            // body (split into two halves at the nose when delivering)
            RocketBodyShape().fill(LinearGradient(colors: [.white, Color(hex: "#b8b8c2")],
                                                  startPoint: .leading, endPoint: .trailing))
                .frame(width: 56, height: 150)
                .overlay(RocketNoseShape().fill(Color(hex: "#9a9aa6"))
                    .frame(width: 56, height: 150)
                    .scaleEffect(x: 1 - noseOpen, anchor: .center)
                    .offset(x: -noseOpen * 26))
                .overlay(RocketNoseShape().fill(Color(hex: "#9a9aa6"))
                    .frame(width: 56, height: 150)
                    .scaleEffect(x: noseOpen, anchor: .center)
                    .offset(x: noseOpen * 26).opacity(noseOpen))
                .overlay(ZStack {
                    ForEach([-1.0, 1.0], id: \.self) { side in
                        RocketFinShape(mirrored: side > 0).fill(Self.orange)
                            .frame(width: 22, height: 34).offset(x: CGFloat(side) * 27, y: 56)
                    }
                })
        }
        .frame(width: 110, height: 200)
    }

    // ── The emoji ejected from the cone into the bucket ─────────────────────

    @ViewBuilder
    private func ejectedEmoji(geo: GeometryProxy) -> some View {
        if emojiScale > 0.001 {
            let size = geo.size
            let cone = conePoint(size)
            let mouth = CGPoint(x: bucketPoint(size).x, y: bucketPoint(size).y - 30)
            let p = emojiEject
            // Arc across: lerp cone → mouth, lifted by a parabola so it pops up
            // out of the cone before dropping into the bucket.
            let x = cone.x + (mouth.x - cone.x) * p
            let y = cone.y + (mouth.y - cone.y) * p - CGFloat(sin(Double(p) * .pi)) * 70
            let hue = EmojiHue.color(for: emoji)
            ZStack {
                if p > 0.01 && p < 0.99 {
                    Capsule()
                        .fill(LinearGradient(colors: [hue.opacity(0.4), .clear],
                                             startPoint: .bottom, endPoint: .top))
                        .frame(width: 18, height: 70)
                        .blur(radius: 3)
                        .position(x: x, y: y + 44)
                        .allowsHitTesting(false)
                }
                Circle().fill(hue.opacity(0.35 * Double(min(1, emojiScale))))
                    .frame(width: 150, height: 150).blur(radius: 32)
                    .position(x: x, y: y)
                Text(emoji).font(.system(size: 64))
                    .scaleEffect(emojiScale)
                    .shadow(color: hue.opacity(0.7), radius: 22)
                    .position(x: x, y: y)
            }
        }
    }

    // ── Bucket — the shared wooden skin (from the parachute receipt) ─────────

    private func bucket(geo: GeometryProxy) -> some View {
        let p = bucketPoint(geo.size)
        let wood = Color(hex: "#8B4513"); let woodDark = Color(hex: "#6E3A1E")
        let brass = Color(hex: "#C9A86A")
        return ZStack {
            // Cyan/lavender catch glow inside the bucket on landing.
            Circle().fill(Self.accentSoft.opacity(bucketGlow ? 0.22 : 0))
                .frame(width: 140, height: 140).blur(radius: 30).offset(y: -6)
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

    // ── Starfield (from the parachute receipt) ──────────────────────────────

    private struct Star { let x: CGFloat; let y: CGFloat; let r: CGFloat; let o: Double; let lav: Bool }
    private static let starField: [Star] = (0..<200).map { i in
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
            for s in Self.starField {
                let rect = CGRect(x: s.x * size.width, y: s.y * size.height,
                                  width: s.r * 2, height: s.r * 2)
                let color: Color = s.lav ? Self.accentSoft : .white
                ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(s.o)))
            }
        }
        .allowsHitTesting(false)
    }

    // ── Earth horizon at the bottom (from the parachute receipt) ────────────

    private func earthHorizon(geo: GeometryProxy) -> some View {
        let w = geo.size.width
        let h = geo.size.height
        let earthH: CGFloat = 145
        return Canvas { ctx, size in
            let earthR = w * 1.8
            let cx = w / 2
            let cyEarth = h + earthR - earthH
            let earthRect = CGRect(x: cx - earthR, y: cyEarth - earthR,
                                   width: earthR * 2, height: earthR * 2)
            ctx.fill(
                Path(ellipseIn: earthRect.insetBy(dx: -10, dy: -10)),
                with: .radialGradient(
                    Gradient(colors: [Color(hex: "#3a6ea5").opacity(0.0),
                                      Color(hex: "#4a9abb").opacity(0.35)]),
                    center: CGPoint(x: cx, y: cyEarth),
                    startRadius: earthR - 26, endRadius: earthR + 14))
            let earth = Path(ellipseIn: earthRect)
            ctx.fill(earth, with: .linearGradient(
                Gradient(colors: [Color(hex: "#1f4e79"), Color(hex: "#13314f")]),
                startPoint: CGPoint(x: cx, y: cyEarth - earthR),
                endPoint: CGPoint(x: cx, y: h)))
            ctx.clip(to: earth)
            let blobs: [(CGFloat, CGFloat, CGFloat)] = [
                (0.20, 0.30, 46), (0.55, 0.18, 60), (0.78, 0.40, 40), (0.38, 0.55, 34)
            ]
            for b in blobs {
                let bx = b.0 * w, by = h - earthH * (1 - b.1) + 8
                ctx.fill(Path(ellipseIn: CGRect(x: bx - b.2, y: by, width: b.2 * 2, height: b.2)),
                         with: .color(Color(hex: "#2e6b3e").opacity(0.55)))
            }
            for i in 0..<26 {
                let lx = CGFloat(Double((i &* 73 &+ 11) % 100) / 100) * w
                let ly = h - earthH * 0.5 + CGFloat(Double((i &* 31) % 100) / 100) * (earthH * 0.45)
                ctx.fill(Path(ellipseIn: CGRect(x: lx, y: ly, width: 1.4, height: 1.4)),
                         with: .color(Color(hex: "#ffe9a8").opacity(0.8)))
            }
        }
        .overlay(
            Ellipse()
                .stroke(Color(hex: "#7ec8e3").opacity(0.7), lineWidth: 2)
                .frame(width: w * 3.6, height: w * 3.6)
                .position(x: w / 2, y: h + w * 1.8 - earthH)
                .blur(radius: 3)
        )
        .frame(width: w, height: h)
        .allowsHitTesting(false)
    }

    // ── Label (from the parachute receipt) ──────────────────────────────────

    @ViewBuilder
    private func label(geo: GeometryProxy) -> some View {
        VStack {
            Spacer()
            Text(messageLine)
                .font(.system(size: 20, design: .serif).italic())
                .foregroundColor(Self.accentSoft)
                .shadow(color: .black.opacity(0.5), radius: 6)
                .padding(.bottom, geo.size.height * 0.06)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.5), value: messageLine)
        }
    }

    private var messageLine: String {
        let name = fromName.isEmpty ? "someone" : fromName
        if descend < 0.85 { return "\(name) is landing ✦" }
        if noseOpen < 1   { return "touchdown ✦" }
        return "almost here ✦"
    }

    // ── Sequencing ──────────────────────────────────────────────────────────

    private func run() {
        // Keep the approved rocket_receipt.wav (engine → settle); no-ops if
        // the file is missing (never crashes).
        InstrumentSoundPlayer.shared.playReceipt(.rocket)
        HapticPattern.singleSoft.fire()

        // FALL — descends upright and grows, gently.
        withAnimation(.easeIn(duration: 2.6)) { descend = 0.82; grow = 1.0 }
        for k in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7 + Double(k) * 0.45) {
                HapticEngine.rocketCountdown(); jitter()
            }
        }

        // LEGS — deploy + switch to a hover flame, just before the settle.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation(AnimationSystem.easeOutBack(0.4)) { legs = 1 }
            hover = true
        }

        // SETTLE — a SLOW, graceful final descent that DECELERATES onto the
        // surface (0.82 → 1.0 over 2.0s, easeOut) — no fast drop.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            withAnimation(.easeOut(duration: 2.0)) { descend = 1 }
        }

        // TOUCHDOWN — fires as the legs seat (tail of the slow settle):
        // soft dust · flash · gentle bounce.
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.4) {
            HapticPattern.doubleSoft.fire()
            dust = true
            withAnimation(.easeOut(duration: 0.08)) { flash = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.2)) { flash = false }
            }
            withAnimation(AnimationSystem.easeOutBack(0.4)) { bounce = 1.04 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(AnimationSystem.easeOutBack(0.3)) { bounce = 1.0 }
            }
        }

        // EJECT — nose cone splits, emoji pops out of the cone.
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.9) {
            withAnimation(AnimationSystem.easeOutBack(0.5)) { noseOpen = 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.3) {
            HapticEngine.catchReveal()
            withAnimation(AnimationSystem.easeOutBack(0.5)) { emojiScale = 1 }
            // Arc across and drop into the bucket.
            withAnimation(.easeInOut(duration: 1.1)) { emojiEject = 1 }
        }

        // SETTLE — the emoji drops in; catch glow + soft thud.
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.2) {
            withAnimation(.easeOut(duration: 0.4)) { emojiScale = 0.55; bucketGlow = true }
            InstrumentSoundPlayer.shared.playCue(file: PlaneSounds.catchFile, duration: 0.45)
            HapticPattern.singleSoft.fire()
        }

        // → the shared reveal.
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.8) {
            onRevealed()
            withAnimation(.easeInOut(duration: 0.3)) { revealing = true }
        }
    }

    private func jitter() {
        withAnimation(.spring(response: 0.1, dampingFraction: 0.3)) { shake = 3 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { shake = 0 }
        }
    }
}
