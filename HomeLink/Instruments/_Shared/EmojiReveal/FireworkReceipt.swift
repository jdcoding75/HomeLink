// FireworkReceipt.swift
// Pointward › Instruments › _Shared › EmojiReveal
//
// The SPECIAL receipt for 🎆 — the screen opens on the fading afterglow of a
// firework, the 🎆 blooms from the warm centre, then drifts down into the
// shared wooden bucket on a gold sparkle trail before handing off to the shared
// EmojiRevealView.
//
//   BURST  (0.0–0.9s)  full-screen explosion — plays firework_big_burst, the
//                      IDENTICAL sound to the send screen's big burst
//   GLOW   (0.6s+)     held red/gold afterglow settles as the backdrop
//   BLOOM  (1.1s+)     🎆 blooms BIG over the glow + "from … ✦"; a soft,
//                      magical sparkle (firework_reveal_sparkle) plays UNDER
//                      the reveal only, resolving before the handoff
//   → EmojiRevealView (.received)                                      ≈ 2.6s
//
// Screen-coordinate rules: GeometryReader root, .ignoresSafeArea() background,
// positions from geo.size.

import SwiftUI

struct FireworkReceipt: View {
    var emoji: String = "🎆"
    var message: String? = nil
    var tagline: String? = nil
    let fromName: String
    var onRevealed: () -> Void = {}
    var onFinished: () -> Void = {}

    private static let gold     = Color(hex: "#ffeb3b")
    private static let amber    = Color(hex: "#fbc02d")
    private static let red       = Color(hex: "#f44336")
    private static let cyan      = Color(hex: "#50B4F0")
    private static let lavender = Color(hex: "#c4a8d4")
    private static let wood      = Color(hex: "#8B4513")
    private static let woodDark  = Color(hex: "#6E3A1E")
    private static let brass     = Color(hex: "#C9A86A")

    // [tweak] One continuous full-screen beat: BURST → held GLOW → big BLOOM.
    private static let burstEnd: Double = 0.9     // full-screen burst expands then fades
    private static let glowInAt: Double = 0.6     // the held glow fades in as the backdrop
    private static let bloomAt:  Double = 1.1     // the 🎆 blooms BIG over the glow
    private static let total:    Double = 2.6     // → EmojiRevealView (.compass)
    // (legacy bucket-beat stages — now-unreferenced helpers below)
    private static let driftAt:  Double = 2.0
    private static let landAt:   Double = 3.5

    private static let palette: [Color] = [gold, lavender, red, amber, Color.white]

    // Full-screen burst arms — angle · colour · length factor (index-derived).
    private static let armCount = 30
    private static let arms: [(angle: Double, color: Color, len: CGFloat)] = {
        var out: [(angle: Double, color: Color, len: CGFloat)] = []
        for i in 0..<armCount {
            out.append((angle: (Double(i) / Double(armCount)) * 2 * .pi,
                        color: palette[i % palette.count],
                        len: CGFloat(0.78 + Double((i * 31) % 22) / 100.0)))
        }
        return out
    }()

    private static let bucketW: CGFloat = 140
    private static let bucketH: CGFloat = 120

    // Residual sparkle dots (fractional positions, colour) — static.
    private static let sparkleDots: [(x: CGFloat, y: CGFloat, color: Color, ph: Double)] = {
        var out: [(x: CGFloat, y: CGFloat, color: Color, ph: Double)] = []
        let cols = [gold, red, amber]
        for i in 0..<22 {
            out.append((x: CGFloat((i * 89) % 100) / 100,
                        y: CGFloat((i * 37) % 70) / 100,
                        color: cols[i % 3],
                        ph: Double(i % 7) / 7.0))
        }
        return out
    }()

    @State private var start: Date? = nil
    @State private var landed = false
    @State private var revealing = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                if revealing {
                    // [tweak] the reveal renders over the CORRECT firework ambient
                    // (.compass = the brand deep-purple "user background"), not the
                    // forced rocket deep-space-with-star-drift.
                    EmojiRevealView(emoji: emoji, message: message, tagline: tagline,
                                    context: .received(fromName: fromName),
                                    ambient: .compass,
                                    onDismiss: onFinished)
                        .transition(.opacity)
                } else {
                    // ── Full-screen dark world (deep purple — continuous with the
                    //    .compass reveal it hands off to). ──
                    Color(hex: "#0d0d14").ignoresSafeArea()
                    LinearGradient(colors: [Color(hex: "#0d0d14"), Color(hex: "#12101c"), Color(hex: "#0d0d14")],
                                   startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()

                    TimelineView(.animation) { timeline in
                        let e = elapsed(now: timeline.date)
                        ZStack {
                            // ONE continuous full-screen beat: the held glow settles
                            // as the backdrop, a genuine edge-to-edge BURST opens, the
                            // 🎆 then blooms BIG and clear over the glow. No box.
                            heldGlow(w: w, h: h, e: e)
                            burst(w: w, h: h, e: e)
                            bigEmoji(w: w, h: h, e: e)

                            Text("from \(fromName.isEmpty ? "someone" : fromName) ✦")
                                .font(.system(size: 16, design: .serif).italic())
                                .foregroundColor(Self.lavender.opacity(0.85))
                                .position(x: w / 2, y: h * 0.86)
                                .opacity(e >= Self.bloomAt ? 1 : 0)
                                .animation(.easeIn(duration: 0.4), value: e >= Self.bloomAt)
                        }
                    }
                }
            }
            .frame(width: w, height: h)
        }
        .ignoresSafeArea()
        .onAppear { begin() }
    }

    private func elapsed(now: Date) -> Double {
        guard let start else { return 0 }
        return min(max(0, now.timeIntervalSince(start)), Self.total)
    }

    private func begin() {
        start = Date()
        // BURST SOUND — the opening explosion plays the IDENTICAL sound to the
        // send screen's big burst (firework_big_burst, 1.2s — see
        // FireworkSendAnimation.tick). The burst portion is unchanged.
        InstrumentSoundPlayer.shared.playCue(file: "firework_big_burst", duration: 1.2)
        HapticPattern.singleHeavy.fire()
        // MESSAGE-REVEAL SOUND — a soft, magical sparkle bed begins as the 🎆
        // blooms (AFTER the burst) and plays UNDER the reveal only, resolving
        // before the EmojiRevealView handoff. Gentle and quiet, never loud.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.bloomAt) {
            HapticPattern.heartbeat.fire()
            InstrumentSoundPlayer.shared.playCue(file: "firework_reveal_sparkle", duration: 1.5)
        }
        // burst → held glow → big BLOOM, as one continuous beat (no bucket).
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.total) {
            onRevealed()
            withAnimation(.easeInOut(duration: 0.4)) { revealing = true }
        }
    }

    // ── Full-screen opening burst (radial arms · shockwave rings · white core) ─

    @ViewBuilder
    private func burst(w: CGFloat, h: CGFloat, e: Double) -> some View {
        if e < Self.burstEnd {
            let cx = w / 2, cy = h * 0.42
            let R = max(w, h)
            let grow = easeOut(min(1, e / 0.45))
            let fade = 1 - easeIn(min(1, max(0, (e - 0.3) / (Self.burstEnd - 0.3))))
            ZStack {
                // radial arms reaching toward the screen edges
                ForEach(0..<Self.arms.count, id: \.self) { i in
                    let arm = Self.arms[i]
                    let len = R * 0.6 * arm.len * CGFloat(grow)
                    let tip = CGPoint(x: cx + CGFloat(cos(arm.angle)) * len,
                                      y: cy + CGFloat(sin(arm.angle)) * len)
                    Path { p in p.move(to: CGPoint(x: cx, y: cy)); p.addLine(to: tip) }
                        .stroke(arm.color.opacity(fade * 0.85),
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    Circle().fill(arm.color.opacity(fade))
                        .frame(width: 6, height: 6).position(tip)
                        .shadow(color: arm.color.opacity(fade * 0.8), radius: 5)
                }
                // expanding shockwave rings
                ForEach(0..<4, id: \.self) { k in
                    let rl = e - Double(k) * 0.1
                    if rl > 0 && rl < 0.8 {
                        let p = rl / 0.8
                        let d = CGFloat(easeOut(p)) * R
                        Circle()
                            .stroke(Self.palette[k % Self.palette.count].opacity((1 - p) * 0.5),
                                    lineWidth: CGFloat(3 * (1 - p) + 0.5))
                            .frame(width: d, height: d)
                            .position(x: cx, y: cy)
                    }
                }
                // white-hot core
                Circle()
                    .fill(RadialGradient(colors: [Color.white.opacity(fade), Self.gold.opacity(fade * 0.5), .clear],
                                         center: .center, startRadius: 2, endRadius: 90))
                    .frame(width: 220, height: 220)
                    .position(x: cx, y: cy)
                    .blendMode(.screen)
            }
            .allowsHitTesting(false)
        }
    }

    // ── The held glow backdrop (full-screen, settles after the burst) ────────

    @ViewBuilder
    private func heldGlow(w: CGFloat, h: CGFloat, e: Double) -> some View {
        let inP = easeOut(min(1, max(0, (e - Self.glowInAt) / 0.4)))
        let op = 0.34 * inP
        Circle()
            .fill(RadialGradient(colors: [Self.gold.opacity(op), Self.red.opacity(op * 0.6), .clear],
                                 center: .center, startRadius: 8, endRadius: max(w, h) * 0.7))
            .frame(width: max(w, h) * 1.5, height: max(w, h) * 1.5)
            .position(x: w / 2, y: h * 0.42)
            .blendMode(.screen)
            .allowsHitTesting(false)
    }

    // ── The 🎆 blooms BIG and clear over the glow ────────────────────────────

    @ViewBuilder
    private func bigEmoji(w: CGFloat, h: CGFloat, e: Double) -> some View {
        if e >= Self.bloomAt {
            let lp = (e - Self.bloomAt) / 0.6
            let bloom: CGFloat = lp < 0.7 ? CGFloat(easeOut(max(0, lp) / 0.7)) * 1.18
                               : (lp < 1.0 ? 1.18 - 0.18 * CGFloat((lp - 0.7) / 0.3) : 1.0)
            // Custom firework ART instead of the 🎆 system glyph (which renders
            // as an empty box in this context). Same vector burst the reveal hero
            // uses — see FireworkGlyph. Data stays 🎆.
            Group {
                if emoji == "🎆" {
                    FireworkGlyph(height: 150)
                } else {
                    Text(emoji).font(.system(size: 150))
                }
            }
                .scaleEffect(bloom)
                .shadow(color: Self.gold.opacity(0.6), radius: 22)
                .position(x: w / 2, y: h * 0.42)
                .allowsHitTesting(false)
        }
    }

    // ── Geometry ──────────────────────────────────────────────────────────

    private func bucketPoint(_ w: CGFloat, _ h: CGFloat) -> CGPoint {
        CGPoint(x: w - 80, y: h - 95)
    }
    private func centerPoint(_ w: CGFloat, _ h: CGFloat) -> CGPoint {
        CGPoint(x: w / 2, y: h * 0.4)
    }

    /// The emoji's position — held at centre through the bloom, then drifts to
    /// the bucket along a gentle downward arc.
    private func emojiPos(w: CGFloat, h: CGFloat, e: Double) -> CGPoint {
        let c = centerPoint(w, h)
        guard e >= Self.driftAt else { return c }
        let b = bucketPoint(w, h)
        let p = easeInOut(min(1, (e - Self.driftAt) / (Self.landAt - Self.driftAt)))
        let mid = CGPoint(x: (c.x + b.x) / 2, y: c.y + (b.y - c.y) * 0.35)   // slight arc
        let q = CGFloat(p)
        return CGPoint(
            x: (1 - q) * (1 - q) * c.x + 2 * (1 - q) * q * mid.x + q * q * b.x,
            y: (1 - q) * (1 - q) * c.y + 2 * (1 - q) * q * mid.y + q * q * b.y)
    }

    // ── Afterglow centre ──────────────────────────────────────────────────

    @ViewBuilder
    private func afterglow(w: CGFloat, h: CGFloat, e: Double) -> some View {
        // Hold a soft glow floor — this is the backdrop the message reveals over.
        let op = max(0.16, 0.30 - e * 0.07)
        Circle()
            .fill(RadialGradient(colors: [Self.gold.opacity(op), Self.red.opacity(op * 0.7), .clear],
                                 center: .center, startRadius: 6, endRadius: 200))
            .frame(width: 420, height: 420)
            .position(centerPoint(w, h))
            .blendMode(.screen)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private func sparkles(w: CGFloat, h: CGFloat, e: Double) -> some View {
        ForEach(0..<Self.sparkleDots.count, id: \.self) { i in
            let d = Self.sparkleDots[i]
            // residual dots drift gently upward and fade over the first ~1.6s
            let life = max(0, 1 - (e * 0.6 + d.ph))
            Circle().fill(d.color.opacity(life * 0.7))
                .frame(width: 3, height: 3)
                .position(x: d.x * w, y: d.y * h - CGFloat(e) * 14)
                .allowsHitTesting(false)
        }
    }

    // ── The emoji (bloom + drift) ───────────────────────────────────────────

    @ViewBuilder
    private func emojiView(w: CGFloat, h: CGFloat, e: Double) -> some View {
        if e >= Self.bloomAt {
            // Bloom big at the centre over the held glow and HOLD there — no drift,
            // no bucket. The focal point that the shared reveal then grows into.
            let lp = (e - Self.bloomAt) / 0.6
            let bloom: CGFloat = lp < 0.7 ? CGFloat(easeOut(max(0, lp) / 0.7)) * 1.15
                               : (lp < 1.0 ? 1.15 - 0.15 * CGFloat((lp - 0.7) / 0.3) : 1.0)
            Text(emoji)
                .font(.system(size: 104))
                .scaleEffect(bloom)
                .shadow(color: Self.gold.opacity(0.55), radius: 18)
                .position(centerPoint(w, h))
                .allowsHitTesting(false)
        }
    }

    /// Gold sparkle trail behind the drifting emoji (dots fading upward).
    @ViewBuilder
    private func sparkleTrail(w: CGFloat, h: CGFloat, e: Double) -> some View {
        if e >= Self.driftAt && e < Self.landAt {
            ForEach(0..<8, id: \.self) { k in
                let tb = e - Double(k) * 0.05
                if tb >= Self.driftAt {
                    let frac = Double(k) / 8
                    let p = emojiPos(w: w, h: h, e: tb)
                    Circle().fill(Self.gold.opacity((1 - frac) * 0.6))
                        .frame(width: 6 - CGFloat(frac) * 3, height: 6 - CGFloat(frac) * 3)
                        .position(x: p.x, y: p.y - CGFloat(k) * 2)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    // ── The wooden bucket ─────────────────────────────────────────────────

    private func bucket(w: CGFloat, h: CGFloat) -> some View {
        let p = bucketPoint(w, h)
        return ZStack {
            Ellipse()
                .fill(RadialGradient(colors: [Self.cyan.opacity(landed ? 0.2 : 0), .clear],
                                     center: .center, startRadius: 2, endRadius: 80))
                .frame(width: Self.bucketW * 1.2, height: 110)
                .offset(y: -Self.bucketH / 2).blur(radius: 6)
            BucketHandleShape()
                .stroke(Self.brass, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: Self.bucketW * 0.9, height: 48)
                .offset(y: -Self.bucketH / 2 - 14)
            BucketShape()
                .fill(LinearGradient(colors: [Self.wood, Self.woodDark], startPoint: .top, endPoint: .bottom))
                .frame(width: Self.bucketW, height: Self.bucketH)
                .overlay(
                    VStack {
                        Capsule().fill(Self.brass).frame(height: 6).padding(.horizontal, -2).padding(.top, 11)
                        Spacer()
                        Capsule().fill(Self.brass).frame(height: 6).padding(.horizontal, 6).padding(.bottom, 13)
                    }
                    .frame(width: Self.bucketW, height: Self.bucketH).opacity(0.85)
                )
                .shadow(color: .black.opacity(0.4), radius: 10, y: 6)
        }
        .position(p)
    }

    /// After landing: the emoji visible in the bucket + a few celebration sparkles.
    @ViewBuilder
    private func emojiInBucket(w: CGFloat, h: CGFloat, e: Double) -> some View {
        if e >= Self.landAt {
            let p = bucketPoint(w, h)
            let settle = easeOut(min(1, (e - Self.landAt) / (Self.total - Self.landAt)))
            ZStack {
                ForEach(0..<8, id: \.self) { k in
                    let a = (Double(k) / 8) * 2 * .pi
                    Circle().fill(Self.gold.opacity((1 - settle) * 0.8))
                        .frame(width: 4, height: 4)
                        .offset(x: CGFloat(cos(a)) * CGFloat(settle) * 50,
                                y: -Self.bucketH * 0.3 + CGFloat(sin(a)) * CGFloat(settle) * 30)
                }
                Text(emoji).font(.system(size: 44))
                    .scaleEffect(0.6 + 0.4 * CGFloat(settle))
                    .offset(y: -Self.bucketH * 0.16)
                    .opacity(settle)
            }
            .position(p)
            .allowsHitTesting(false)
        }
    }

    private func easeOut(_ t: Double) -> Double { let x = min(max(t,0),1); return 1 - pow(1 - x, 3) }
    private func easeIn(_ t: Double) -> Double { let x = min(max(t,0),1); return x * x }
    private func easeInOut(_ t: Double) -> Double {
        let x = min(max(t,0),1); return x < 0.5 ? 4*x*x*x : 1 - pow(-2*x + 2, 3) / 2
    }
}
