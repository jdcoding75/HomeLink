// PlaneGlyph.swift
// Pointward › Instruments › Plane
//
// The shared Apple-style minimal paper-plane glyph — clean white/blue body,
// cockpit window carrying the emoji, wing, tail fin, engine nacelle. Used by the
// send + receipt animations (and available to the compass face). Points RIGHT
// (nose at the trailing/right edge), so a left→right flight reads naturally.

import SwiftUI

struct PlaneGlyph: View {
    /// The emoji riding in the cockpit (nil shows a plain window shine).
    var emoji: String? = nil

    private static let bodyA = Color(hex: "#deeeff")
    private static let bodyB = Color(hex: "#f5faff")
    private static let bodyC = Color(hex: "#ffffff")
    private static let bodyD = Color(hex: "#d8ecff")
    private static let stroke = Color(hex: "#b8d4ee")
    private static let wingA = Color(hex: "#e8f4ff")
    private static let wingB = Color(hex: "#c0d8f0")
    private static let window = Color(hex: "#c8e4ff")
    private static let windowEdge = Color(hex: "#90c0e8")

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                // Main wing (behind the fuselage)
                Ellipse()
                    .fill(LinearGradient(colors: [Self.wingA, Self.wingB],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: w * 0.52, height: h * 0.9)
                    .rotationEffect(.degrees(-16))
                    .offset(x: -w * 0.04, y: h * 0.2)

                // Tail fin (rear / left)
                PlaneTriangle()
                    .fill(Self.bodyD)
                    .overlay(PlaneTriangle().stroke(Self.stroke, lineWidth: 0.8))
                    .frame(width: w * 0.18, height: h * 0.5)
                    .offset(x: -w * 0.4, y: -h * 0.2)

                // Fuselage
                Capsule()
                    .fill(LinearGradient(colors: [Self.bodyA, Self.bodyB, Self.bodyC, Self.bodyD],
                                         startPoint: .leading, endPoint: .trailing))
                    .overlay(Capsule().stroke(Self.stroke, lineWidth: 0.8))
                    .frame(width: w, height: h * 0.5)

                // Fuselage shading strip along the top
                Capsule().fill(.white.opacity(0.5))
                    .frame(width: w * 0.86, height: h * 0.07)
                    .offset(y: -h * 0.13)

                // Engine nacelle under the wing
                Ellipse().fill(Self.wingA)
                    .overlay(Ellipse().stroke(Self.stroke, lineWidth: 0.6))
                    .frame(width: w * 0.2, height: h * 0.22)
                    .offset(x: -w * 0.02, y: h * 0.17)

                // Cockpit window + emoji (toward the nose / right)
                ZStack {
                    Ellipse().fill(Self.window)
                        .overlay(Ellipse().stroke(Self.windowEdge, lineWidth: 1))
                    if let emoji {
                        Text(emoji).font(.system(size: h * 0.30))
                    }
                    // window shine
                    Ellipse().fill(.white.opacity(0.55))
                        .frame(width: w * 0.05, height: h * 0.06)
                        .offset(x: -w * 0.04, y: -h * 0.05)
                }
                .frame(width: w * 0.3, height: h * 0.36)
                .offset(x: w * 0.24, y: -h * 0.01)
            }
            .frame(width: w, height: h)
        }
    }
}

/// A right-pointing triangle for the tail fin.
struct PlaneTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
