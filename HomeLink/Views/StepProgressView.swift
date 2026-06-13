// StepProgressView.swift
// Pointward › Views
//
// [2/5] A universal step tracker — a row of dots beneath the instrument that
// shows where you are in the send. Inactive steps are dim, the active step
// pulses bright, completed steps fill with a check. Labels and the current
// step come from the host (CompassView), which knows what's loaded and
// whether the aim has landed.

import SwiftUI

struct StepProgressView: View {

    let instrument: Instrument
    /// 0-based index of the step currently in progress. Anything below it is
    /// completed; anything above is upcoming.
    let currentStep: Int

    @State private var pulse = false

    private static let lavender = Color(hex: "#c4a8d4")

    /// The named steps for each instrument (mirrors the spec).
    static func stepNames(for instrument: Instrument) -> [String] {
        switch instrument {
        case .compass: return ["emoji", "message", "point", "hold"]
        case .bow:     return ["emoji", "message", "aim", "draw", "release"]
        case .flick:   return ["emoji", "message", "flick"]
        case .wand:    return ["emoji", "message", "shake", "release"]
        case .firefly: return ["emoji", "message", "breathe"]        // wind
        case .rocket:  return ["emoji", "message", "aim", "fuel", "blast"]
        case .plane:   return ["emoji", "message", "wind", "fly"]
        }
    }

    /// [4/6] The optional step (the message) wears a small "?".
    static let optionalStep = "message"

    private var steps: [String] { Self.stepNames(for: instrument) }

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, label in
                stepDot(index: index, label: label)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    @ViewBuilder
    private func stepDot(index: Int, label: String) -> some View {
        let completed = index < currentStep
        let active = index == currentStep
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(completed ? Self.lavender
                          : (active ? Self.lavender.opacity(pulse ? 1.0 : 0.6)
                                    : Self.lavender.opacity(0.3)))
                    .frame(width: 8, height: 8)
                    .scaleEffect(active ? (pulse ? 1.25 : 0.9) : 1.0)
                if completed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 5, weight: .bold))
                        .foregroundColor(DesignTokens.Color.background)
                }
            }
            .shadow(color: Self.lavender.opacity(active ? 0.7 : 0), radius: 4)

            // [4/6] The optional message step shows a trailing "?".
            // (Text "+" concatenation is deprecated in iOS 26 → separate Text
            //  views in an HStack, so the "?" keeps its own lavender tint.)
            HStack(spacing: 0) {
                Text(label)
                if label == Self.optionalStep {
                    Text(" ?").foregroundColor(Self.lavender.opacity(0.7))
                }
            }
            .font(.system(size: 8, weight: active ? .semibold : .regular))
            .foregroundColor(active ? Self.lavender
                             : (completed ? Self.lavender.opacity(0.7)
                                          : DesignTokens.Color.textDim))
        }
        .frame(width: 46)
        .animation(.easeOut(duration: 0.25), value: currentStep)
    }
}
