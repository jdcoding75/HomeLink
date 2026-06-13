// FireworkGlyph.swift
// Pointward › Instruments › _Shared › EmojiReveal
//
// Shared firework art for the 🎆 reveal hero. Mirrors BirthdayCakeGlyph /
// GiftBoxGlyph: a custom-drawn firework burst renders in place of the 🎆 glyph,
// because the system emoji glyph does not render reliably in this context (it
// shows as an empty box). The underlying thought data stays 🎆.
//
// A simple, recognizable burst: a white-hot core with radiating gold/amber/warm
// arms and a spark dot at each tip, over a soft gold glow. Drawn with the same
// Path-arm + Circle-tip idiom the live firework send/receipt bursts already use,
// so the hero matches the rest of the firework instrument.
//
// Geometry is expressed relative to `height` (the emoji font size it replaces),
// so the same burst works at any size the caller asks for.

import SwiftUI

struct FireworkGlyph: View {
    /// Approximate visual height in points (≈ the emoji font size it replaces).
    var height: CGFloat = 156

    // Palette — warm gold/amber burst (pairs with the reveal glow #FFD700 and
    // the firework send/receipt screens' gold · amber · warm · red).
    private static let core     = Color.white
    private static let gold     = Color(hex: "#ffeb3b")
    private static let amber    = Color(hex: "#fbc02d")
    private static let warm     = Color(hex: "#ff8c42")
    private static let red      = Color(hex: "#f44336")
    private static let lavender = Color(hex: "#c4a8d4")
    private static let palette: [Color] = [gold, amber, warm, lavender, red]

    // 16 radial arms, long/short alternating for a livelier burst (index-derived,
    // so the art is deterministic — no render-time randomness).
    private static let armCount = 16

    var body: some View {
        let box = CGSize(width: height, height: height)
        let cx = box.width / 2, cy = box.height / 2
        let R = height * 0.46                 // arm reach

        return ZStack {
            // Soft outer glow.
            Circle()
                .fill(RadialGradient(colors: [Self.gold.opacity(0.35), .clear],
                                     center: .center, startRadius: 2, endRadius: R))
                .frame(width: R * 2, height: R * 2)
                .position(x: cx, y: cy)
                .blur(radius: 6)

            // Radiating arms + a spark dot at each tip.
            ForEach(0..<Self.armCount, id: \.self) { i in
                let a = (Double(i) / Double(Self.armCount)) * 2 * .pi
                let len = R * (i % 2 == 0 ? 1.0 : 0.66)        // long/short alternate
                let color = Self.palette[i % Self.palette.count]
                let tip = CGPoint(x: cx + CGFloat(cos(a)) * len,
                                  y: cy + CGFloat(sin(a)) * len)
                // the arm line (centre → tip)
                Path { p in
                    p.move(to: CGPoint(x: cx, y: cy))
                    p.addLine(to: tip)
                }
                .stroke(color, style: StrokeStyle(lineWidth: height * 0.022, lineCap: .round))
                // spark dot at the tip
                Circle().fill(color)
                    .frame(width: height * 0.05, height: height * 0.05)
                    .position(tip)
                    .shadow(color: color.opacity(0.8), radius: height * 0.03)
            }

            // White-hot core.
            Circle()
                .fill(RadialGradient(colors: [Self.core, Self.gold.opacity(0.6), .clear],
                                     center: .center, startRadius: 1, endRadius: height * 0.13))
                .frame(width: height * 0.28, height: height * 0.28)
                .position(x: cx, y: cy)
        }
        .frame(width: box.width, height: box.height)
    }
}
