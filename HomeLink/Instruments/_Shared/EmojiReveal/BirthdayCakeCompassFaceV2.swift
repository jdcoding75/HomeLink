// BirthdayCakeCompassFaceV2.swift
// Pointward › Instruments › _Shared › EmojiReveal
//
// V2 — the HERO birthday compass face. Activates only when the selected emoji
// is 🎂 (same emoji-special pattern as FireworkCompassFace). Five UNLIT candles
// stand on a two-tier cake in a dark night sky inside the ring; the sender TAPS
// each candle to LIGHT it. When all five are lit the cake flares, confetti
// sounds, and the standard send pipeline fires via onSend().
//
// This is the sender's half of the wish ritual: LIGHT here → the receiver BLOWS
// them out (mic) on the other phone.
//
// V1 (BirthdayCakeCompassFace, tap-to-blow-out) is kept untouched as the
// fallback per the framework's versioning rule.
//
// Screen-coordinate rules: GeometryReader root, positions from geo.size.

import SwiftUI

struct BirthdayCakeCompassFaceV2: View {
    var bearingDegrees: Double = 0
    var personName: String = ""
    var onSend: () -> Void = {}

    @State private var lit: [Bool] = Array(repeating: false, count: BirthdayCakeV2.candleCount)
    @State private var flameScale: [CGFloat] = Array(repeating: 0, count: BirthdayCakeV2.candleCount)
    @State private var flare = false
    @State private var sent = false

    private var litCount: Int { lit.filter { $0 }.count }
    private var allLit: Bool { litCount >= BirthdayCakeV2.candleCount }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let cx = w / 2, cy = h * 0.46
            let R = min(w * 0.38, 148)
            let scale = R / 110
            let cakeCenter = CGPoint(x: cx, y: cy + R * 0.20)

            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    skyBackground(cx: cx, cy: cy, R: R)
                    cakeGlow(center: cakeCenter, R: R)
                    embers(center: cakeCenter, scale: scale, t: t)

                    BirthdayCakeBody(center: cakeCenter, scale: scale)

                    candlesAndFlames(center: cakeCenter, scale: scale, t: t)
                    tapTargets(center: cakeCenter, scale: scale, R: R)

                    instruction(cx: cx, cy: cy, R: R)
                }
                .frame(width: w, height: h)
            }
        }
    }

    // ── Background ───────────────────────────────────────────────────────────

    private func skyBackground(cx: CGFloat, cy: CGFloat, R: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(colors: [Color(hex: "#1a2d4a"), Color(hex: "#141d30"), Color(hex: "#050914")],
                                 center: .center, startRadius: 0, endRadius: R))
            .overlay(Circle().stroke(.white.opacity(0.10), lineWidth: 1.2))
            .frame(width: R * 2, height: R * 2)
            .clipShape(Circle())
            .position(x: cx, y: cy)
    }

    private func cakeGlow(center: CGPoint, R: CGFloat) -> some View {
        // Soft lavender glow at rest; warms to gold and grows as candles light.
        let frac = Double(litCount) / Double(BirthdayCakeV2.candleCount)
        let radius = 70 + CGFloat(frac) * 60 + (flare ? 26 : 0)
        let glowColor = litCount == 0 ? BirthdayCakeV2.lavender : BirthdayCakeV2.warmGold
        let op = 0.16 + frac * 0.30
        return Circle()
            .fill(RadialGradient(colors: [glowColor.opacity(op), .clear],
                                 center: .center, startRadius: 4, endRadius: radius))
            .frame(width: radius * 2, height: radius * 2)
            .position(center)
            .blendMode(.screen)
            .allowsHitTesting(false)
    }

    // ── Candles + flames ─────────────────────────────────────────────────────

    @ViewBuilder
    private func candlesAndFlames(center: CGPoint, scale: CGFloat, t: Double) -> some View {
        ForEach(0..<BirthdayCakeV2.candleCount, id: \.self) { i in
            let c = BirthdayCakeV2.candle(i, center: center, scale: scale)
            // candle stick
            RoundedRectangle(cornerRadius: 3 * scale)
                .fill(c.color)
                .frame(width: c.width, height: c.bottomY - c.wickY)
                .position(x: c.x, y: (c.bottomY + c.wickY) / 2)
            // wick nub
            Rectangle().fill(Color(hex: "#3a2a20"))
                .frame(width: 1.6 * scale, height: 5 * scale)
                .position(x: c.x, y: c.wickY - 2 * scale)
            // flame (only when lit)
            if lit[i] {
                let sway = sin(t * 2.2 + Double(i)) * 2.0   // gentle 1–2° sway
                BirthdayFlame(lit: flameScale[i], lean: 0, sway: sway, scale: scale)
                    .position(x: c.x, y: c.wickY - 9 * scale)
            }
        }
    }

    /// Tap columns above each candle (≥44pt) — tapping an unlit one lights it.
    @ViewBuilder
    private func tapTargets(center: CGPoint, scale: CGFloat, R: CGFloat) -> some View {
        ForEach(0..<BirthdayCakeV2.candleCount, id: \.self) { i in
            let c = BirthdayCakeV2.candle(i, center: center, scale: scale)
            Color.clear
                .frame(width: 44, height: R * 0.9)
                .contentShape(Rectangle())
                .position(x: c.x, y: c.wickY - R * 0.25)
                .onTapGesture { lightCandle(i) }
        }
    }

    private func embers(center: CGPoint, scale: CGFloat, t: Double) -> some View {
        ZStack {
            ForEach(0..<BirthdayCakeV2.candleCount, id: \.self) { i in
                if lit[i] {
                    let c = BirthdayCakeV2.candle(i, center: center, scale: scale)
                    ForEach(0..<3, id: \.self) { k in
                        let phase = (t * 0.4 + Double(k) * 0.33 + Double(i) * 0.17).truncatingRemainder(dividingBy: 1)
                        let rise = CGFloat(phase) * 26 * scale
                        let wob = CGFloat(sin(phase * .pi * 2 + Double(i))) * 4
                        Circle().fill(BirthdayCakeV2.warmGold.opacity((1 - phase) * 0.7))
                            .frame(width: 2.4 * scale, height: 2.4 * scale)
                            .position(x: c.x + wob, y: c.wickY - 14 * scale - rise)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    // ── Instruction ──────────────────────────────────────────────────────────

    @ViewBuilder
    private func instruction(cx: CGFloat, cy: CGFloat, R: CGFloat) -> some View {
        if allLit {
            Text("make a wish ✦")
                .font(.system(size: 13, design: .serif).italic())
                .foregroundColor(BirthdayCakeV2.warmGold)
                .shadow(color: BirthdayCakeV2.warmGold.opacity(0.6), radius: 6)
                .position(x: cx, y: cy + R * 1.06)
        } else {
            Text("tap each candle to light it ✦")
                .font(.system(size: 12, design: .serif).italic())
                .foregroundColor(BirthdayCakeV2.lavender.opacity(0.85))
                .shadow(color: .black.opacity(0.5), radius: 4)
                .position(x: cx, y: cy + R * 1.06)
        }
    }

    // ── Mechanic ─────────────────────────────────────────────────────────────

    private func lightCandle(_ i: Int) {
        guard !lit[i], !sent else { return }
        lit[i] = true
        HapticEngine.personSelected()
        InstrumentSoundPlayer.shared.playCue(file: "birthday_candle_light", duration: 0.2)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) { flameScale[i] = 1 }
        if allLit { allCandlesLit() }
    }

    private func allCandlesLit() {
        guard !sent else { return }
        sent = true
        // brief flare — flames brighten
        withAnimation(.easeOut(duration: 0.3)) { flare = true }
        HapticEngine.connectionFelt()
        InstrumentSoundPlayer.shared.playCue(file: "birthday_confetti", duration: 1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { onSend() }
    }
}
