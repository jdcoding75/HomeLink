// FireworkReceipt.swift
// Pointward › Instruments › _Shared › EmojiReveal
//
// The SPECIAL receipt for 🎆 — the screen opens on the fading afterglow of a
// firework, the 🎆 blooms from the warm centre, then drifts down into the
// shared wooden bucket on a gold sparkle trail before handing off to the shared
// EmojiRevealView.
//
//   AFTERGLOW (0.0–1.0s)  residual sparkle dots + soft red/gold centre glow
//   BLOOM     (1.0–2.0s)  🎆 blooms 0 → 1.2 → 1.0 (spring) from the centre
//   DRIFT     (2.0–3.5s)  emoji drifts to the lower-right bucket, sparkle trail
//   LAND      (3.5s)      cyan glow + celebration sparkles; firework_sparkle
//   → EmojiRevealView (.received)                                      ≈ 3.8s
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

    private static let bloomAt:  Double = 1.0
    private static let driftAt:  Double = 2.0
    private static let landAt:   Double = 3.5
    private static let total:    Double = 3.8

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
                    EmojiRevealView(emoji: emoji, message: message, tagline: tagline,
                                    context: .received(fromName: fromName),
                                    ambient: .rocket,
                                    onDismiss: onFinished)
                        .transition(.opacity)
                } else {
                    // ── DEEP SPACE gradient ──
                    Color(hex: "#080911").ignoresSafeArea()
                    LinearGradient(colors: [Color(hex: "#080911"), Color(hex: "#11162b"), Color(hex: "#1f1826")],
                                   startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()

                    TimelineView(.animation) { timeline in
                        let e = elapsed(now: timeline.date)
                        ZStack {
                            afterglow(w: w, h: h, e: e)
                            sparkles(w: w, h: h, e: e)
                            bucket(w: w, h: h)
                            sparkleTrail(w: w, h: h, e: e)
                            emojiView(w: w, h: h, e: e)
                            emojiInBucket(w: w, h: h, e: e)

                            Text("from \(fromName.isEmpty ? "someone" : fromName) ✦")
                                .font(.system(size: 16, design: .serif).italic())
                                .foregroundColor(Self.lavender.opacity(0.8))
                                .position(x: w / 2, y: h * 0.86)
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
        InstrumentSoundPlayer.shared.playCue(file: "firework_sparkle", duration: 1.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.bloomAt) {
            HapticPattern.heartbeat.fire()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.landAt) {
            InstrumentSoundPlayer.shared.playCue(file: "firework_sparkle", duration: 1.0)
            HapticPattern.singleSoft.fire()
            withAnimation(.easeOut(duration: 0.4)) { landed = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.total) {
            onRevealed()
            withAnimation(.easeInOut(duration: 0.3)) { revealing = true }
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
        let op = max(0, 0.28 - e * 0.12)
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
        if e >= Self.bloomAt && e < Self.landAt {
            let bloom: CGFloat = {
                let lp = (e - Self.bloomAt) / 0.6
                if lp < 0 { return 0 }
                if lp < 0.7 { return CGFloat(easeOut(lp / 0.7)) * 1.2 }      // 0 → 1.2
                if lp < 1.0 { return 1.2 - 0.2 * CGFloat((lp - 0.7) / 0.3) } // 1.2 → 1.0
                return 1.0
            }()
            let drifting = e >= Self.driftAt
            let scale = drifting ? max(0.6, 1.0 - CGFloat((e - Self.driftAt) / (Self.landAt - Self.driftAt)) * 0.4) : bloom
            Text(emoji)
                .font(.system(size: 96))
                .scaleEffect(scale)
                .shadow(color: Self.gold.opacity(0.5), radius: 16)
                .position(emojiPos(w: w, h: h, e: e))
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
    private func easeInOut(_ t: Double) -> Double {
        let x = min(max(t,0),1); return x < 0.5 ? 4*x*x*x : 1 - pow(-2*x + 2, 3) / 2
    }
}
