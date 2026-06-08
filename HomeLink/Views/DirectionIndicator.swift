// DirectionIndicator.swift
// Pointward › Views
//
// THE GUIDE — every instrument shows exactly where the person is:
//
//   PERSON MARKER   their emoji (20 pt) floating just outside the circle
//                   at the true real-world bearing, riding every heading
//                   change as the phone rotates
//   ALIGNMENT ARC   a soft 15° arc on the outer ring centered on them —
//                   dim lavender far away (0.2), glowing when close (0.6),
//                   pulsing at full strength inside 5°
//   HINT            "point toward [name]" → "ready ✦" → "perfect ✦"
//
// Overlay-only: hit-testing disabled, sized to the instrument's 370 pt frame.

import SwiftUI

struct DirectionIndicator: View {

    let bearingDegrees: Double
    let personName: String
    let personEmoji: String
    /// Ring radius of the host instrument (marker floats just outside it).
    var ringRadius: CGFloat = 180
    /// Bow & wind draw their own richer hints — they pass false.
    var showHint: Bool = true

    @State private var pulse = false

    private static let lavender = Color(hex: "#c4a8d4")

    private var rad: Double { bearingDegrees * .pi / 180 }
    private var angleError: Double {
        BearingCalculator.alignmentError(relativeBearing: bearingDegrees)
    }

    /// Outside 15°: 0.2 · within 15°: 0.6 · within 5°: pulsing to 1.0
    private var arcOpacity: Double {
        switch angleError {
        case ..<5:   return pulse ? 1.0 : 0.75
        case ..<15:  return 0.6
        default:     return 0.2
        }
    }

    private var hint: String {
        switch angleError {
        case ..<5:   return "perfect ✦"
        case ..<15:  return "ready ✦"
        default:     return "point toward \(personName)"
        }
    }

    var body: some View {
        ZStack {
            // ── Alignment arc — 15° span centered on their bearing ──
            AlignmentArcShape(rad: rad, spanDegrees: 15)
                .stroke(Self.lavender.opacity(arcOpacity),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: ringRadius * 2, height: ringRadius * 2)
                .shadow(color: Self.lavender.opacity(angleError < 15 ? 0.5 : 0),
                        radius: 8)
                .animation(AnimationSystem.easeInOutSine(0.3), value: arcOpacity)

            // ── Direction marker — a small needle, purely navigational.
            // (emoji marker retired: Text(personEmoji) — kept in the param)
            Triangle()
                .fill(Self.lavender)
                .frame(width: 8, height: 20)
                .scaleEffect(angleError < 5 ? 1.3 : (angleError < 15 ? 1.15 : 1.0))
                .shadow(color: Self.lavender.opacity(angleError < 15 ? 0.8 : 0.4),
                        radius: 6)
                .offset(x: CGFloat(sin(rad)) * (ringRadius + 16),
                        y: -CGFloat(cos(rad)) * (ringRadius + 16))
                .rotationEffect(.radians(rad), anchor: .center)
                .animation(.easeOut(duration: 0.2), value: bearingDegrees)
                .animation(.easeOut(duration: 0.25), value: angleError < 15)

            // ── Hint — small italic muted lavender, below the instrument ──
            if showHint {
                VStack {
                    Spacer()
                    Text(hint)
                        .font(.system(size: 11, design: .serif).italic())
                        .foregroundColor(Self.lavender.opacity(angleError < 15 ? 0.9 : 0.6))
                        .animation(.easeInOut(duration: 0.25), value: hint)
                }
                .padding(.bottom, -14)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(AnimationSystem.easeInOutSine(0.7)
                            .repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

/// An arc spanning `spanDegrees` centered on the bearing, on the outer ring.
struct AlignmentArcShape: Shape {
    let rad: Double
    var spanDegrees: Double = 15

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let bearingAngle = Angle(radians: rad - .pi / 2)   // shape space: 0 = +x
        p.addArc(center: CGPoint(x: rect.midX, y: rect.midY),
                 radius: rect.width / 2,
                 startAngle: bearingAngle - .degrees(spanDegrees / 2),
                 endAngle: bearingAngle + .degrees(spanDegrees / 2),
                 clockwise: false)
        return p
    }
}
