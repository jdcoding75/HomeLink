// FlickDeskWorld.swift
// Pointward › Instruments › Flick
//
// SHARED desk + crumpled-paper-ball components for the Flick V2 (DESK) design.
// ONE source of truth for the world + the ball, reused by the V2 compass face,
// the V2 send, and the V2 receipt. (The bucket reuses the shared BucketShape /
// BucketHandleShape; the person marker reuses the shared DirectionIndicator —
// nothing forked.)
//
//   • FlickDeskWorld     — full-screen school desk: deep-purple wall (top ~30%)
//                          over a warm-oak desk surface, a bright seam edge,
//                          subtle curved wood grain, and a soft wall→desk shadow.
//   • FlickDeskFaceFill  — the radial-oak fill clipped INTO the compass circle.
//   • CrumpledPaperBall  — the off-white crumpled ball (irregular bezel, creases,
//                          soft ground shadow). NOT a flat card.
//   • CrumpledBallShape  — the irregular closed-bezier outline.

import SwiftUI

// MARK: - Palette (the one place the desk colours live)

enum FlickDeskPalette {
    static let wallTop  = Color(hex: "#1a1428")
    static let wallBot  = Color(hex: "#2a2040")
    static let deskA    = Color(hex: "#d4982e")
    static let deskB    = Color(hex: "#b87820")
    static let deskC    = Color(hex: "#a06818")
    static let deskD    = Color(hex: "#8a5810")
    static let deskEdge = Color(hex: "#f0c878")
    static let grain    = Color(hex: "#7a4e18")

    static let paperA = Color(hex: "#f8f8f0")
    static let paperB = Color(hex: "#e4e4d4")
    static let paperC = Color(hex: "#d0d0bc")
    static let paperD = Color(hex: "#c0c0a8")
    static let crease = Color(hex: "#b8b3a0")
}

// MARK: - Full-screen desk world

/// The full school desk: wall behind (top `wallFraction`), oak desk surface
/// below, a bright seam edge, curved wood grain (0.09 alpha) and a soft shadow
/// where the wall meets the desk.
struct FlickDeskWorld: View {
    var wallFraction: CGFloat = 0.30

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let seamY = h * wallFraction
            ZStack(alignment: .topLeading) {
                // Wall — fills the whole screen; the desk paints over the lower part.
                LinearGradient(colors: [FlickDeskPalette.wallTop, FlickDeskPalette.wallBot],
                               startPoint: .top, endPoint: .bottom)
                    .frame(width: w, height: h)

                // Desk surface.
                LinearGradient(colors: [FlickDeskPalette.deskA, FlickDeskPalette.deskB,
                                        FlickDeskPalette.deskC, FlickDeskPalette.deskD],
                               startPoint: .top, endPoint: .bottom)
                    .frame(width: w, height: h - seamY)
                    .overlay(deskGrain(width: w, height: h - seamY))
                    .offset(y: seamY)

                // Soft shadow the wall casts onto the desk, just below the seam.
                LinearGradient(colors: [Color.black.opacity(0.35), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(width: w, height: 28)
                    .offset(y: seamY)

                // Bright edge line at the seam.
                Rectangle()
                    .fill(FlickDeskPalette.deskEdge.opacity(0.7))
                    .frame(width: w, height: 1.5)
                    .offset(y: seamY)
            }
        }
        .allowsHitTesting(false)
    }

    /// Subtle curved wood grain across the desk (0.09 alpha).
    private func deskGrain(width w: CGFloat, height h: CGFloat) -> some View {
        Canvas { ctx, size in
            let lines = 7
            for i in 0..<lines {
                let frac = CGFloat(i + 1) / CGFloat(lines + 1)
                let y = size.height * frac
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                // A gentle long curve — bows down a touch toward the middle.
                path.addQuadCurve(to: CGPoint(x: size.width, y: y),
                                  control: CGPoint(x: size.width / 2,
                                                   y: y + 12 + CGFloat(i % 3) * 4))
                ctx.stroke(path, with: .color(FlickDeskPalette.grain.opacity(0.09)),
                           lineWidth: 1.4)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Desk fill clipped into the compass circle

/// The desk seen ONLY inside the compass ring — a radial oak gradient (deep
/// purple stays outside, supplied by the host face).
struct FlickDeskFaceFill: View {
    var body: some View {
        ZStack {
            RadialGradient(colors: [FlickDeskPalette.deskA, FlickDeskPalette.deskB,
                                    FlickDeskPalette.deskC, FlickDeskPalette.deskD],
                           center: UnitPoint(x: 0.5, y: 0.42),
                           startRadius: 0, endRadius: 190)
            // A couple of faint curved grain arcs for tactility.
            Canvas { ctx, size in
                for i in 0..<3 {
                    let y = size.height * (0.40 + CGFloat(i) * 0.16)
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addQuadCurve(to: CGPoint(x: size.width, y: y),
                                      control: CGPoint(x: size.width / 2, y: y + 16))
                    ctx.stroke(path, with: .color(FlickDeskPalette.grain.opacity(0.09)),
                               lineWidth: 1.4)
                }
            }
        }
    }
}

// MARK: - Crumpled paper ball

/// A crumpled paper ball — off-white radial gradient, an irregular bezier
/// outline, a handful of crease lines and a soft ground shadow. NOT a flat card.
struct CrumpledPaperBall: View {
    var size: CGFloat = 46
    var emoji: String? = nil
    var emojiOpacity: Double = 0.0
    var showShadow: Bool = true

    var body: some View {
        ZStack {
            if showShadow {
                Ellipse()
                    .fill(Color.black.opacity(0.28))
                    .frame(width: size * 0.86, height: size * 0.22)
                    .blur(radius: 3)
                    .offset(y: size * 0.52)
            }
            CrumpledBallShape()
                .fill(RadialGradient(colors: [FlickDeskPalette.paperA, FlickDeskPalette.paperB,
                                              FlickDeskPalette.paperC, FlickDeskPalette.paperD],
                                     center: UnitPoint(x: 0.4, y: 0.34),
                                     startRadius: 1, endRadius: size * 0.6))
                .overlay(CrumpledBallShape().stroke(FlickDeskPalette.paperD.opacity(0.6),
                                                    lineWidth: 0.8))
            creases
            if let emoji {
                Text(emoji).font(.system(size: size * 0.40)).opacity(emojiOpacity)
            }
        }
        .frame(width: size, height: size)
    }

    /// 5 crease lines fanned across the ball.
    private var creases: some View {
        ForEach(0..<5, id: \.self) { i in
            let len = size * (0.62 - CGFloat(i % 3) * 0.10)
            Capsule()
                .stroke(FlickDeskPalette.crease.opacity(0.65), lineWidth: 0.9)
                .frame(width: len, height: 1)
                .rotationEffect(.degrees(Double(i) * 47 + 12))
                .offset(x: CGFloat((i % 2 == 0 ? -1 : 1)) * size * 0.06,
                        y: CGFloat(i - 2) * size * 0.07)
        }
    }
}

/// An irregular, closed-bezier blob — a crumpled-ball silhouette. Built from a
/// deterministic ring of slightly varied radii, smoothed with quad curves
/// through the midpoints (vertices act as controls) so the outline reads soft
/// and lumpy, never a clean circle.
struct CrumpledBallShape: Shape {
    private static let bumps: [CGFloat] = [1.0, 0.90, 1.05, 0.88, 1.0, 0.94, 1.06, 0.91]

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let n = Self.bumps.count
        var pts: [CGPoint] = []
        for i in 0..<n {
            let a = Double(i) / Double(n) * 2 * .pi
            pts.append(CGPoint(x: c.x + CGFloat(cos(a)) * r * Self.bumps[i],
                               y: c.y + CGFloat(sin(a)) * r * Self.bumps[i]))
        }
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        }
        var p = Path()
        p.move(to: mid(pts[n - 1], pts[0]))
        for i in 0..<n {
            let cur = pts[i]
            let next = pts[(i + 1) % n]
            p.addQuadCurve(to: mid(cur, next), control: cur)
        }
        p.closeSubpath()
        return p
    }
}
