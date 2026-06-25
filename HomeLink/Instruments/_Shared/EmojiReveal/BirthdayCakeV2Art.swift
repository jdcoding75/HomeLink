// BirthdayCakeV2Art.swift
// Pointward › Instruments › _Shared › EmojiReveal
//
// Shared cake art for the Birthday Cake V2 hero mechanism — used by the V2
// compass face (tap-to-light), send (confetti burst), and receipt (mic
// blow-out). One cake definition so all three screens match exactly.
//
// The cake body (tiers · drips · brass platter) is a reusable View; the candle
// flames are drawn by each screen (they differ: unlit/lighting/lit/blown-out),
// using BirthdayCakeV2.candle(...) for shared geometry + colours.
//
// Geometry is expressed at scale = 1 (bottom tier ≈ 120pt wide) and scaled by
// the caller, so the same cake works in the 240pt compass ring and full screen.

import SwiftUI

// 5 candles. Locked.
enum BirthdayCakeV2 {

    static let candleCount = 3   // [mechanism-reset PART 5] was 5 — single source; allLit is count-agnostic

    // Palette (approved spec)
    static let bottomA = Color(hex: "#ca658b")
    static let bottomB = Color(hex: "#e87aa0")
    static let bottomC = Color(hex: "#b05273")
    static let creamA  = Color.white
    static let creamB  = Color(hex: "#ffe9a0")
    static let topA    = Color(hex: "#b295c2")
    static let topB    = Color(hex: "#c4a8d4")
    static let topC    = Color(hex: "#9a7eb0")
    static let platA   = Color(hex: "#5a4010")
    static let platB   = Color(hex: "#d4a030")
    static let platC   = Color(hex: "#ffe9a0")

    static let lavender = Color(hex: "#c4a8d4")
    static let gold     = Color(hex: "#f0d060")
    static let pink     = Color(hex: "#e87aa0")
    static let warmGold = Color(hex: "#d4a030")

    // Candle layout (relative to the cake centre, at scale 1)
    static let candleDX: [CGFloat]     = [-28, -14, 0, 14, 28]
    static let candleHeight: [CGFloat] = [22, 28, 34, 28, 22]   // staggered
    static let candleColors: [Color]   = [lavender, gold, pink, gold, lavender]

    // Tier sizing at scale 1
    static let bottomW: CGFloat = 120, bottomH: CGFloat = 44
    static let topW: CGFloat = 88,     topH: CGFloat = 36

    /// One candle's geometry on screen.
    struct CandleSpec {
        let x: CGFloat        // screen x of the candle centre
        let bottomY: CGFloat  // where the candle meets the top tier
        let wickY: CGFloat    // top of the candle (flame sits here)
        let color: Color
        let width: CGFloat
    }

    /// The y of the top tier's top surface (candles stand here).
    static func topTierTopY(center: CGPoint, scale: CGFloat) -> CGFloat {
        let topCY = center.y - bottomH / 2 * scale - topH / 2 * scale + 4 * scale
        return topCY - topH / 2 * scale
    }

    /// Geometry for candle i, scaled and positioned around `center`.
    static func candle(_ i: Int, center: CGPoint, scale: CGFloat) -> CandleSpec {
        let topTopY = topTierTopY(center: center, scale: scale)
        let h = candleHeight[i] * scale
        return CandleSpec(
            x: center.x + candleDX[i] * scale,
            bottomY: topTopY,
            wickY: topTopY - h,
            color: candleColors[i],
            width: 5 * scale
        )
    }
}

/// The cake body — two frosted tiers, a cream drip seam, a white drip on top,
/// on a brass platter. Centred on `center`, sized by `scale`. No candles.
struct BirthdayCakeBody: View {
    let center: CGPoint
    var scale: CGFloat = 1

    var body: some View {
        let s = scale
        let cx = center.x, cy = center.y
        let botW = BirthdayCakeV2.bottomW * s, botH = BirthdayCakeV2.bottomH * s
        let topW = BirthdayCakeV2.topW * s,    topH = BirthdayCakeV2.topH * s
        let topCY = cy - botH / 2 - topH / 2 + 4 * s
        let seamY = cy - botH / 2

        ZStack {
            // Brass platter beneath the cake
            Ellipse()
                .fill(LinearGradient(colors: [BirthdayCakeV2.platA, BirthdayCakeV2.platB, BirthdayCakeV2.platC],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: botW * 1.28, height: 16 * s)
                .position(x: cx, y: cy + botH / 2 + 7 * s)

            // Bottom tier — pink frosting
            RoundedRectangle(cornerRadius: 7 * s)
                .fill(LinearGradient(colors: [BirthdayCakeV2.bottomB, BirthdayCakeV2.bottomA, BirthdayCakeV2.bottomC],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: botW, height: botH)
                .position(x: cx, y: cy)

            // Cream drip seam between the tiers
            BirthdayDrip(bumps: 5)
                .fill(LinearGradient(colors: [BirthdayCakeV2.creamA, BirthdayCakeV2.creamB],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: botW * 0.96, height: 12 * s)
                .position(x: cx, y: seamY + 2 * s)

            // Top tier — lavender frosting
            RoundedRectangle(cornerRadius: 6 * s)
                .fill(LinearGradient(colors: [BirthdayCakeV2.topB, BirthdayCakeV2.topA, BirthdayCakeV2.topC],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: topW, height: topH)
                .position(x: cx, y: topCY)

            // White drip on the top tier
            BirthdayDrip(bumps: 4)
                .fill(BirthdayCakeV2.creamA)
                .frame(width: topW * 0.94, height: 10 * s)
                .position(x: cx, y: topCY - topH / 2 + 5 * s)
        }
    }
}

/// A simple scalloped drip edge (rounded bumps along the bottom).
struct BirthdayDrip: Shape {
    let bumps: Int
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let bw = w / CGFloat(max(1, bumps))
        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: w, y: 0))
        p.addLine(to: CGPoint(x: w, y: h * 0.4))
        var x = w
        var i = 0
        while i < bumps {
            x -= bw
            p.addQuadCurve(to: CGPoint(x: x, y: h * 0.4),
                           control: CGPoint(x: x + bw / 2, y: h))
            i += 1
        }
        p.closeSubpath()
        return p
    }
}

/// A warm candle flame — outer glow, inner core, white-hot dot. `lit` 0…1
/// drives bloom; `lean` (−1…1) bends it sideways for the first blow; `sway`
/// adds a gentle idle wobble.
struct BirthdayFlame: View {
    var lit: CGFloat = 1        // 0 = out, 1 = full
    var lean: CGFloat = 0       // −1 left … 1 right
    var sway: Double = 0        // degrees
    var scale: CGFloat = 1

    var body: some View {
        let s = scale
        ZStack {
            Ellipse().fill(BirthdayCakeV2.creamB.opacity(0.5 * Double(lit)))
                .frame(width: 16 * s, height: 26 * s).blur(radius: 4 * s)
            Ellipse().fill(BirthdayCakeV2.creamB)
                .frame(width: 11 * s, height: 18 * s)
            Ellipse().fill(BirthdayCakeV2.gold)
                .frame(width: 7 * s, height: 12 * s).offset(y: 1 * s)
            Circle().fill(.white)
                .frame(width: 3.2 * s, height: 3.2 * s).offset(y: 3 * s)
                .shadow(color: BirthdayCakeV2.creamB, radius: 4 * s)
        }
        .scaleEffect(x: lit, y: lit, anchor: .bottom)
        .rotationEffect(.degrees(sway + Double(lean) * 32), anchor: .bottom)
        .offset(x: lean * 6 * s)
    }
}

/// A self-contained lit birthday cake — the cake body + 5 lit candles — drawn to
/// fit a box of the given `height`. Used anywhere a 🎂 glyph would otherwise
/// render (the reveal hero + the bucket drift) so the cake art matches the
/// compass/send/receipt screens. The underlying thought data stays 🎂.
struct BirthdayCakeGlyph: View {
    /// Approximate visual height in points (≈ the emoji font size it replaces).
    var height: CGFloat = 120

    var body: some View {
        let scale = height / 150
        let box = CGSize(width: height * 1.18, height: height)
        let center = CGPoint(x: box.width / 2, y: box.height * 0.64)
        return ZStack {
            BirthdayCakeBody(center: center, scale: scale)
            ForEach(0..<BirthdayCakeV2.candleCount, id: \.self) { i in
                let c = BirthdayCakeV2.candle(i, center: center, scale: scale)
                // candle stick
                Capsule().fill(c.color)
                    .frame(width: c.width, height: max(2, c.bottomY - c.wickY))
                    .position(x: c.x, y: (c.bottomY + c.wickY) / 2)
                // lit flame on the wick
                BirthdayFlame(lit: 1, scale: scale * 0.7)
                    .position(x: c.x, y: c.wickY - 3 * scale)
            }
        }
        .frame(width: box.width, height: box.height)
    }
}
