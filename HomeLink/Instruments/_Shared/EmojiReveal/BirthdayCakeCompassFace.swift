// BirthdayCakeCompassFace.swift
// Pointward › Instruments › _Shared › EmojiReveal
//
// A SPECIAL compass-face interaction that activates only when the selected
// emoji is 🎂. A birthday cake sits inside the compass ring with 5 lit candles;
// the user taps each flame out (in any order), and when all 5 are out the cake
// glows and the standard send pipeline fires via onSend().
//
// Screen-coordinate rules: GeometryReader root, positions from geo.size, compass
// centred at (w/2, h·0.46), radius min(w·0.38, 148). Works embedded in the 240pt
// compass face AND full-screen in the Animation Test Lab.

import SwiftUI

struct BirthdayCakeCompassFace: View {
    var bearingDegrees: Double = 0
    var personName: String = ""
    var onSend: () -> Void = {}

    private static let candles = 5
    private static let bottomTier = Color(hex: "#c4507a")
    private static let topTier    = Color(hex: "#e87aa0")
    private static let frosting   = Color.white.opacity(0.9)
    private static let base       = Color(hex: "#a03060")
    private static let candleY     = Color(hex: "#f0d080")
    private static let lavender   = Color(hex: "#c4a8d4")

    @State private var lit: [Bool] = Array(repeating: true, count: 5)
    @State private var puff: [Bool] = Array(repeating: false, count: 5)
    @State private var pulse = false
    @State private var glow = false
    @State private var sent = false

    private var outCount: Int { lit.filter { !$0 }.count }
    private var allOut: Bool { outCount >= Self.candles }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let cx = w / 2, cy = h * 0.46
            let R = min(w * 0.38, 148)

            // Cake geometry (relative to the ring radius)
            let topW = R * 0.86, topH = R * 0.30
            let botW = R * 1.12, botH = R * 0.34
            let topCY = cy + R * 0.06
            let botCY = topCY + topH / 2 + botH / 2 - R * 0.04
            let topTop = topCY - topH / 2

            ZStack {
                // Soft compass ring + glow when all candles are out
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: "#fbeef4"), Color(hex: "#f6dce8")],
                                         center: .center, startRadius: 4, endRadius: R))
                    .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 1.5))
                    .overlay(Circle().stroke(Self.lavender.opacity(glow ? 0.7 : 0), lineWidth: 4).blur(radius: 6))
                    .frame(width: R * 2, height: R * 2)
                    .position(x: cx, y: cy)

                // ── The cake ──
                // base
                Ellipse().fill(Self.base)
                    .frame(width: botW * 1.02, height: botH * 0.4)
                    .position(x: cx, y: botCY + botH / 2 - botH * 0.1)
                // bottom tier
                RoundedRectangle(cornerRadius: 6).fill(Self.bottomTier)
                    .frame(width: botW, height: botH)
                    .overlay(RoundedRectangle(cornerRadius: 6).fill(Self.frosting)
                        .frame(width: botW, height: botH * 0.22).offset(y: -botH * 0.39))
                    .position(x: cx, y: botCY)
                // top tier
                RoundedRectangle(cornerRadius: 5).fill(Self.topTier)
                    .frame(width: topW, height: topH)
                    .overlay(RoundedRectangle(cornerRadius: 5).fill(Self.frosting)
                        .frame(width: topW, height: topH * 0.22).offset(y: -topH * 0.39))
                    .position(x: cx, y: topCY)

                // ── Candles + flames ──
                ForEach(0..<Self.candles, id: \.self) { i in
                    let x = candleX(i, cx: cx, topW: topW)
                    // candle
                    RoundedRectangle(cornerRadius: 3).fill(Self.candleY)
                        .frame(width: 6, height: 18)
                        .opacity(lit[i] ? 1 : 0.7)
                        .position(x: x, y: topTop - 9)
                    // flame
                    Text("🔥")
                        .font(.system(size: 14))
                        .scaleEffect(lit[i] ? (pulse ? 1.08 : 0.92) : 0)
                        .animation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true), value: pulse)
                        .animation(.easeOut(duration: 0.18), value: lit[i])
                        .position(x: x, y: topTop - 24)
                    // puff burst on tap-out
                    if puff[i] {
                        CandlePuff(origin: CGPoint(x: x, y: topTop - 24))
                    }
                    // tap column (whole vertical strip above the candle)
                    Color.clear
                        .frame(width: max(34, topW / CGFloat(Self.candles)), height: R * 0.9)
                        .contentShape(Rectangle())
                        .position(x: x, y: topTop - R * 0.2)
                        .onTapGesture { tapCandle(i) }
                }

                // ── Progress label ──
                Text(allOut ? "ready ✦" : "tap each flame to send")
                    .font(.system(size: 12, design: .serif).italic())
                    .foregroundColor(Color(hex: "#9b8fa8"))
                    .position(x: cx, y: botCY + botH / 2 + R * 0.18)

                if !allOut {
                    Text("\(outCount) of \(Self.candles)")
                        .font(.system(size: 11, design: .serif))
                        .foregroundColor(Color(hex: "#9b8fa8").opacity(0.8))
                        .position(x: cx, y: botCY + botH / 2 + R * 0.30)
                }
            }
            .frame(width: w, height: h)
        }
        .onAppear { pulse = true }
    }

    private func candleX(_ i: Int, cx: CGFloat, topW: CGFloat) -> CGFloat {
        let usable = topW * 0.82
        let step = usable / CGFloat(Self.candles - 1)
        return cx - usable / 2 + step * CGFloat(i)
    }

    private func tapCandle(_ i: Int) {
        guard lit[i], !sent else { return }
        lit[i] = false
        puff[i] = true
        InstrumentSoundPlayer.shared.playCue(file: "birthday_candle_puff", duration: 0.2)
        HapticEngine.personSelected()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { puff[i] = false }

        if allOut { allCandlesOut() }
    }

    private func allCandlesOut() {
        guard !sent else { return }
        sent = true
        withAnimation(.easeOut(duration: 0.4)) { glow = true }
        InstrumentSoundPlayer.shared.playCue(file: "birthday_all_out", duration: 0.8)
        HapticEngine.connectionFelt()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { onSend() }
    }
}

/// 3–4 tiny cream/gold particles bursting upward from a blown-out flame.
private struct CandlePuff: View {
    let origin: CGPoint
    @State private var go = false
    private static let cream = Color(hex: "#fff3d8")
    private static let gold  = Color(hex: "#f0d080")

    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                let angle = -.pi / 2 + (Double(i) - 1.5) * 0.5
                Circle()
                    .fill(i % 2 == 0 ? Self.cream : Self.gold)
                    .frame(width: 3, height: 3)
                    .position(origin)
                    .offset(x: go ? CGFloat(cos(angle)) * 16 : 0,
                            y: go ? CGFloat(sin(angle)) * 22 : 0)
                    .opacity(go ? 0 : 0.9)
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 0.3)) { go = true } }
        .allowsHitTesting(false)
    }
}
