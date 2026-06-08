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
    /// [3/5] Optional distance shown beneath the marker ("88 mi").
    var distanceText: String? = nil
    /// Instruments that aim by something other than the phone bearing (the
    /// bow's finger-spin) pass their own approach error so the marker and arc
    /// brighten as *that* aim closes in, while the marker stays at the
    /// person's real-world bearing. nil → use the phone-bearing error.
    var approachError: Double? = nil

    @State private var pulse = false

    private static let lavender = Color(hex: "#c4a8d4")

    private var rad: Double { bearingDegrees * .pi / 180 }
    private var angleError: Double {
        approachError ?? BearingCalculator.alignmentError(relativeBearing: bearingDegrees)
    }

    /// The person's first initial, shown inside the marker (• when unknown).
    private var initial: String {
        let trimmed = personName.trimmingCharacters(in: .whitespaces)
        return trimmed.first.map { String($0).uppercased() } ?? "•"
    }

    /// Outside 15°: 0.2 · within 15°: 0.6 · within 5°: pulsing to 1.0
    private var arcOpacity: Double {
        switch angleError {
        case ..<5:   return pulse ? 1.0 : 0.75
        case ..<15:  return 0.6
        default:     return 0.2
        }
    }

    /// Marker brightness — brightens steadily as the aim approaches.
    private var markerOpacity: Double {
        switch angleError {
        case ..<5:   return pulse ? 1.0 : 0.9
        case ..<15:  return 0.9
        case ..<30:  return 0.65
        default:     return 0.45
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

            // ── [3/5] Direction hint — a small chevron near the center
            // pointing toward the marker, so the way is obvious at a glance.
            Image(systemName: "chevron.up")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Self.lavender.opacity(angleError < 30 ? 0.7 : 0.4))
                .offset(y: -ringRadius * 0.42)
                .rotationEffect(.radians(rad))
                .animation(.easeOut(duration: 0.25), value: bearingDegrees)

            // ── [3/5] Person initial marker — bigger (36 pt), bolder, slowly
            // pulsing, with the distance beneath. Glows on approach: soft
            // within 30°, bright pulse within 15°, a confirming flash at 5°.
            PersonInitialMarker(initial: initial, opacity: markerOpacity,
                                near: angleError < 30,
                                close: angleError < 15, perfect: angleError < 5,
                                pulse: pulse, distanceText: distanceText)
                .offset(x: CGFloat(sin(rad)) * (ringRadius + 26),
                        y: -CGFloat(cos(rad)) * (ringRadius + 26))
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

/// [3/5] A 36 pt soft-lavender disc holding the person's BOLD initial, with
/// four crosshair ticks and the distance beneath. It pulses gently to draw
/// the eye, and its glow escalates as the aim closes: soft within 30°, a
/// bright pulse within 15°, a confirming flash ring at 5°.
struct PersonInitialMarker: View {

    let initial: String
    var opacity: Double = 0.7
    var near: Bool = false       // within 30°
    var close: Bool = false      // within 15°
    var perfect: Bool = false    // within 5°
    var pulse: Bool = false      // the slow 2 s attention pulse
    var distanceText: String? = nil

    private static let lavender = Color(hex: "#c4a8d4")

    var body: some View {
        ZStack {
            // Confirmation flash ring — appears at 5° as a strong lock cue
            if perfect {
                Circle()
                    .stroke(Self.lavender.opacity(pulse ? 0.0 : 0.8), lineWidth: 2)
                    .frame(width: pulse ? 58 : 40, height: pulse ? 58 : 40)
            }

            // Four crosshair ticks extending beyond the rim
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(Self.lavender.opacity(opacity))
                    .frame(width: 1.6, height: 9)
                    .offset(y: -28)
                    .rotationEffect(.degrees(Double(i) * 90))
            }

            // The disc — 36 pt
            Circle()
                .fill(DesignTokens.Color.background.opacity(0.85))
                .frame(width: 36, height: 36)
                .overlay(
                    Circle().stroke(Self.lavender.opacity(opacity),
                                    lineWidth: perfect ? 2.4 : 1.6)
                )

            // The initial — bold
            Text(initial)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(Self.lavender.opacity(min(1, opacity + 0.1)))

            // Distance beneath the marker
            if let distanceText {
                Text(distanceText)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(Self.lavender.opacity(min(1, opacity)))
                    .monospacedDigit()
                    .fixedSize()
                    .offset(y: 30)
            }
        }
        // Slow attention pulse (0.95–1.05) plus an approach boost.
        .scaleEffect((pulse ? 1.05 : 0.95) * (perfect ? 1.14 : (close ? 1.06 : 1.0)))
        .shadow(color: Self.lavender.opacity(perfect ? 0.9 : (close ? 0.7 : (near ? 0.4 : 0.2))),
                radius: perfect ? 12 : (close ? 9 : (near ? 6 : 3)))
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
