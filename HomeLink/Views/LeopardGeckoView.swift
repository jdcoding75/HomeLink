// LeopardGeckoView.swift
// Pointward › Views
//
// [pairing-retire extraction-prep] Moved VERBATIM out of PingView.swift (which is
// being retired with the pairing era). LeopardGeckoView is LIVE — used by CompassView,
// SettingsView, EmojiPickerView, ProSetupView — so it lives in its own file now,
// independent of the dead PingView. No logic change; type name + signature identical.

import SwiftUI

// MARK: - LeopardGeckoView

/// A hand-drawn leopard gecko "emoji" — golden #F5A623 base, dark leopard
/// spots, big glossy eyes, fat tapering tail. Cute, recognisable, and a
/// personal touch for the gecko lover in the family.
struct LeopardGeckoView: View {
    var size: CGFloat = 30

    private static let base   = Color(hex: "#F5A623")
    private static let belly  = Color(hex: "#FFC85C")
    private static let spot   = Color(hex: "#3d2410")
    private static let eyeInk = Color(hex: "#241509")

    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width, h = sz.height
            func pt(_ x: Double, _ y: Double) -> CGPoint {
                CGPoint(x: x * w, y: y * h)
            }
            func ellipse(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double) -> Path {
                Path(ellipseIn: CGRect(x: (cx - rx) * w, y: (cy - ry) * h,
                                       width: rx * 2 * w, height: ry * 2 * h))
            }

            // Tail — fat at the base, tapering with a gentle curl to the right
            var tail = Path()
            tail.move(to: pt(0.42, 0.60))
            tail.addCurve(to: pt(0.74, 0.90),
                          control1: pt(0.66, 0.64), control2: pt(0.84, 0.72))
            tail.addCurve(to: pt(0.46, 0.70),
                          control1: pt(0.62, 0.99), control2: pt(0.40, 0.86))
            tail.closeSubpath()
            ctx.fill(tail, with: .color(Self.base))

            // Stubby legs with round toes
            let legs: [(Double, Double, Double, Double)] = [
                (0.38, 0.36, 0.20, 0.28),   // front left
                (0.62, 0.36, 0.80, 0.28),   // front right
                (0.38, 0.56, 0.20, 0.64),   // back left
                (0.62, 0.56, 0.80, 0.64),   // back right
            ]
            for (x1, y1, x2, y2) in legs {
                var leg = Path()
                leg.move(to: pt(x1, y1))
                leg.addLine(to: pt(x2, y2))
                ctx.stroke(leg, with: .color(Self.base),
                           style: StrokeStyle(lineWidth: w * 0.075, lineCap: .round))
                ctx.fill(ellipse(x2, y2, 0.045, 0.04), with: .color(Self.base))
            }

            // Body
            ctx.fill(ellipse(0.50, 0.46, 0.150, 0.230), with: .color(Self.base))
            // Lighter belly stripe
            ctx.fill(ellipse(0.50, 0.50, 0.075, 0.150), with: .color(Self.belly.opacity(0.55)))

            // Head — broad and rounded, the leopard-gecko wedge
            ctx.fill(ellipse(0.50, 0.20, 0.180, 0.150), with: .color(Self.base))

            // Big glossy eyes
            ctx.fill(ellipse(0.405, 0.165, 0.052, 0.062), with: .color(Self.eyeInk))
            ctx.fill(ellipse(0.595, 0.165, 0.052, 0.062), with: .color(Self.eyeInk))
            ctx.fill(ellipse(0.422, 0.145, 0.016, 0.018), with: .color(.white.opacity(0.92)))
            ctx.fill(ellipse(0.612, 0.145, 0.016, 0.018), with: .color(.white.opacity(0.92)))

            // Little smile
            var smile = Path()
            smile.addArc(center: pt(0.50, 0.225), radius: w * 0.052,
                         startAngle: .degrees(25), endAngle: .degrees(155),
                         clockwise: false)
            ctx.stroke(smile, with: .color(Self.spot),
                       style: StrokeStyle(lineWidth: max(0.8, w * 0.022), lineCap: .round))
            // Nostrils
            ctx.fill(ellipse(0.46, 0.115, 0.008, 0.008), with: .color(Self.spot.opacity(0.7)))
            ctx.fill(ellipse(0.54, 0.115, 0.008, 0.008), with: .color(Self.spot.opacity(0.7)))

            // Leopard spots — scattered over head, body and tail
            let spots: [(Double, Double, Double)] = [
                (0.40, 0.27, 0.018), (0.59, 0.28, 0.020),
                (0.44, 0.36, 0.024), (0.57, 0.41, 0.028),
                (0.45, 0.50, 0.026), (0.58, 0.55, 0.020),
                (0.43, 0.62, 0.018), (0.52, 0.31, 0.016),
                (0.55, 0.66, 0.018), (0.62, 0.76, 0.018),
                (0.68, 0.84, 0.014), (0.51, 0.58, 0.014),
            ]
            for (sx, sy, sr) in spots {
                ctx.fill(ellipse(sx, sy, sr, sr * 0.88), with: .color(Self.spot.opacity(0.85)))
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview("Leopard gecko") {
    LeopardGeckoView(size: 120)
        .padding()
        .background(Color(hex: "#0d0d14"))
}
