// BowArrowGlyph.swift
// Pointward › Instruments › Bow
//
// The shared luminous gold arrow from the bow visual bible — a gold shaft
// fading to a blazing white tip, lavender fletching + nock at the rear, and the
// emoji riding the shaft midpoint. Points RIGHT (tip at the trailing edge), so a
// left→right flight reads naturally. Used by the send + receipt animations.

import SwiftUI

struct BowArrowGlyph: View {
    var emoji: String? = nil
    /// Shaft + tip opacity (dissolve drives this toward 0 in the receipt).
    var solidity: Double = 1.0

    private static let gold0    = Color(hex: "#2255a0")   // cool nock end
    private static let gold     = Color(hex: "#c4a030")
    private static let goldLite = Color(hex: "#f0d060")
    private static let glowGold = Color(hex: "#f0c83c")
    private static let lavender = Color(hex: "#c4a8d4")

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let midY = h / 2
            let tipX = w * 0.95
            ZStack {
                // Soft gold glow under the shaft
                Capsule()
                    .fill(Self.glowGold.opacity(0.15 * solidity))
                    .frame(width: w * 0.86, height: 10)
                    .position(x: w * 0.45, y: midY)
                    .blur(radius: 2)

                // The shaft — cool→gold gradient
                Capsule()
                    .fill(LinearGradient(colors: [Self.gold0.opacity(0.6), Self.gold, Self.goldLite],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: w * 0.80, height: 2.6)
                    .opacity(solidity)
                    .position(x: w * 0.46, y: midY)

                // Fletching (lavender vanes) + nock at the rear (left)
                ArrowFletch()
                    .fill(Self.lavender.opacity(0.78 * solidity))
                    .frame(width: 18, height: 16)
                    .position(x: w * 0.08, y: midY - 5)
                ArrowFletch()
                    .fill(Self.lavender.opacity(0.55 * solidity))
                    .frame(width: 18, height: 16)
                    .rotation3DEffect(.degrees(180), axis: (x: 1, y: 0, z: 0))
                    .position(x: w * 0.08, y: midY + 5)
                Circle().fill(Self.lavender.opacity(0.9 * solidity))
                    .frame(width: 5, height: 5)
                    .position(x: w * 0.05, y: midY)

                // Tip glow + arrowhead (right)
                Ellipse()
                    .fill(RadialGradient(colors: [.white, Self.goldLite.opacity(0.7), .clear],
                                         center: .center, startRadius: 1, endRadius: 12))
                    .frame(width: 22, height: 22)
                    .opacity(solidity)
                    .position(x: tipX - 4, y: midY)
                ArrowHead()
                    .fill(LinearGradient(colors: [Self.goldLite, Self.gold],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: 16, height: 13)
                    .opacity(solidity)
                    .position(x: tipX, y: midY)

                // The emoji riding the shaft midpoint
                if let emoji {
                    Text(emoji).font(.system(size: 15))
                        .position(x: w * 0.5, y: midY - 9)
                }
            }
        }
    }
}

/// A single fletching vane (a soft right-angled sliver at the nock end).
struct ArrowFletch: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY),
                       control: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.4, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// A right-pointing arrowhead triangle.
struct ArrowHead: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
