// BirthdayCakeReceipt.swift
// Pointward › Instruments › _Shared › EmojiReveal
//
// The SPECIAL receipt for 🎂 — there is NO bucket; the cake itself is the
// vessel. An UNLIT cake appears (wicks, no flames) with smoke wisps drifting up
// from each wick, the cake glows, the 🎂 blooms from its centre, and it hands
// off to the shared EmojiRevealView.
//
//   APPEAR (0.0–0.5s)  cake scales 0.3 → 1.0 easeOut, smoke begins
//   GLOW   (1.5s)      cake glows softly
//   BLOOM  (1.8s)      🎂 blooms 0 → 1.2 → 1.0 from the cake centre
//   → EmojiRevealView (.received)                                      ≈ 2.6s
//
// Screen-coordinate rules: GeometryReader root, .ignoresSafeArea() background,
// positions from geo.size.

import SwiftUI

struct BirthdayCakeReceipt: View {
    var emoji: String = "🎂"
    var message: String? = nil
    var tagline: String? = nil
    let fromName: String
    var onRevealed: () -> Void = {}
    var onFinished: () -> Void = {}

    private static let bottomTier = Color(hex: "#c4507a")
    private static let topTier    = Color(hex: "#e87aa0")
    private static let frosting   = Color.white.opacity(0.9)
    private static let base       = Color(hex: "#a03060")
    private static let wick       = Color(hex: "#3a2a20")
    private static let lavender   = Color(hex: "#c4a8d4")
    private static let candles = 5

    @State private var start: Date? = nil
    @State private var cakeScale: CGFloat = 0.3
    @State private var glow = false
    @State private var emojiBloom: CGFloat = 0
    @State private var revealing = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let cx = w / 2, cy = h * 0.46
            let R: CGFloat = min(w * 0.42, 168)
            ZStack {
                if revealing {
                    EmojiRevealView(emoji: emoji, message: message, tagline: tagline,
                                    context: .received(fromName: fromName),
                                    ambient: .compass,
                                    onDismiss: onFinished)
                        .transition(.opacity)
                } else {
                    Color(hex: "#0d0d14").ignoresSafeArea()
                    RadialGradient(colors: [Color(hex: "#1a1228"), Color(hex: "#0d0d14")],
                                   center: .center, startRadius: 40, endRadius: 520)
                        .ignoresSafeArea()

                    cake(cx: cx, cy: cy, R: R)
                    smoke(cx: cx, cy: cy, R: R)

                    // The blooming 🎂 from the cake centre.
                    Text(emoji).font(.system(size: 96))
                        .scaleEffect(emojiBloom)
                        .position(x: cx, y: cy - R * 0.05)

                    Text("from \(fromName.isEmpty ? "someone" : fromName) ✦")
                        .font(.system(size: 16, design: .serif).italic())
                        .foregroundColor(Self.lavender.opacity(0.8))
                        .position(x: cx, y: h * 0.82)
                }
            }
            .frame(width: w, height: h)
        }
        .ignoresSafeArea()
        .onAppear { begin() }
    }

    // ── The unlit cake (wicks, no flames) ─────────────────────────────────

    @ViewBuilder
    private func cake(cx: CGFloat, cy: CGFloat, R: CGFloat) -> some View {
        let topW = R * 0.86, topH = R * 0.30
        let botW = R * 1.12, botH = R * 0.34
        let topCY = cy + R * 0.06
        let botCY = topCY + topH / 2 + botH / 2 - R * 0.04
        let topTop = topCY - topH / 2
        ZStack {
            Circle().fill(Self.lavender.opacity(glow ? 0.18 : 0))
                .frame(width: R * 1.9, height: R * 1.9).blur(radius: 40).position(x: cx, y: cy)

            Ellipse().fill(Self.base)
                .frame(width: botW * 1.02, height: botH * 0.4)
                .position(x: cx, y: botCY + botH / 2 - botH * 0.1)
            RoundedRectangle(cornerRadius: 6).fill(Self.bottomTier)
                .frame(width: botW, height: botH)
                .overlay(RoundedRectangle(cornerRadius: 6).fill(Self.frosting)
                    .frame(width: botW, height: botH * 0.22).offset(y: -botH * 0.39))
                .position(x: cx, y: botCY)
            RoundedRectangle(cornerRadius: 5).fill(Self.topTier)
                .frame(width: topW, height: topH)
                .overlay(RoundedRectangle(cornerRadius: 5).fill(Self.frosting)
                    .frame(width: topW, height: topH * 0.22).offset(y: -topH * 0.39))
                .position(x: cx, y: topCY)

            // wicks (no flames)
            ForEach(0..<Self.candles, id: \.self) { i in
                let x = candleX(i, cx: cx, topW: topW)
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "#f0d080"))
                    .frame(width: 6, height: 16).position(x: x, y: topTop - 8)
                Rectangle().fill(Self.wick)
                    .frame(width: 1.6, height: 6).position(x: x, y: topTop - 18)
            }
        }
        .scaleEffect(cakeScale, anchor: .center)
    }

    // ── Smoke wisps rising from each wick ──────────────────────────────────

    @ViewBuilder
    private func smoke(cx: CGFloat, cy: CGFloat, R: CGFloat) -> some View {
        let topH = R * 0.30
        let topCY = cy + R * 0.06
        let wickY = topCY - topH / 2 - 20
        let topW = R * 0.86
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, _ in
                for i in 0..<Self.candles {
                    let x = candleX(i, cx: cx, topW: topW)
                    for k in 0..<4 {
                        let phase = (t * 0.5 + Double(k) * 0.25 + Double(i) * 0.13)
                            .truncatingRemainder(dividingBy: 1.0)
                        let rise = CGFloat(phase) * 30
                        let wobble = CGFloat(sin(phase * .pi * 2 + Double(i))) * 6
                        let op = (1 - phase) * 0.35 * Double(cakeScale)
                        let r: CGFloat = 2 + CGFloat(phase) * 3
                        let rect = CGRect(x: x + wobble - r, y: wickY - rise - r, width: r * 2, height: r * 2)
                        ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(op)))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func candleX(_ i: Int, cx: CGFloat, topW: CGFloat) -> CGFloat {
        let usable = topW * 0.82
        let step = usable / CGFloat(Self.candles - 1)
        return cx - usable / 2 + step * CGFloat(i)
    }

    // ── Sequence ────────────────────────────────────────────────────────────

    private func begin() {
        start = Date()
        InstrumentSoundPlayer.shared.playCue(file: "birthday_smoke", duration: 1.0)
        withAnimation(.easeOut(duration: 0.5)) { cakeScale = 1.0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.5)) { glow = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            HapticPattern.heartbeat.fire()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) { emojiBloom = 1.2 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { emojiBloom = 1.0 }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            onRevealed()
            withAnimation(.easeInOut(duration: 0.3)) { revealing = true }
        }
    }
}
