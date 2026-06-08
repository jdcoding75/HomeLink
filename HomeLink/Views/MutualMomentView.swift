// MutualMomentView.swift
// Pointward › Views
//
// THE MUTUAL MOMENT — both needles resting on each other at once, within
// 15°, detected through compass_bearings on both sides. The screen warms
// with a golden glow, a lavender wash pulses once, "[name] is pointing
// toward you too ✦" breathes in. Three seconds, then gone.
// Throttled upstream (PingManager) to once per five minutes per pair.

import SwiftUI

struct MutualMomentView: View {

    let partnerName: String

    @State private var glowIn    = false
    @State private var washPulse = false
    @State private var textIn    = false

    private static let gold     = Color(hex: "#E8B64C")
    private static let lavender = Color(hex: "#c4a8d4")

    var body: some View {
        ZStack {
            // Golden warmth blooming from the center
            RadialGradient(
                colors: [Self.gold.opacity(glowIn ? 0.26 : 0), .clear],
                center: .center, startRadius: 30, endRadius: 460
            )
            .ignoresSafeArea()
            .animation(.easeIn(duration: 0.9), value: glowIn)

            // One warm lavender wash — a single slow pulse across the screen
            Self.lavender.opacity(washPulse ? 0 : 0.14)
                .ignoresSafeArea()
                .animation(.easeOut(duration: 1.4), value: washPulse)

            VStack {
                Spacer()
                Text("\(partnerName) is pointing toward you too ✦")
                    .font(.system(size: 16, design: .serif).italic())
                    .foregroundColor(Color(hex: "#f0e2c0"))
                    .shadow(color: Self.gold.opacity(0.8), radius: 10)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                    .opacity(textIn ? 1 : 0)
                    .animation(.easeIn(duration: 0.8), value: textIn)
                    .padding(.bottom, 110)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            glowIn = true
            washPulse = true
            HapticEngine.connectionFelt()   // soft shared double pulse
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                textIn = true
            }
        }
    }
}

#Preview {
    ZStack {
        Color(hex: "#0d0d14").ignoresSafeArea()
        MutualMomentView(partnerName: "Mum")
    }
}
