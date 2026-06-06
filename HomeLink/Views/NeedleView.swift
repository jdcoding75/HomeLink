// NeedleView.swift
// Pointward › Views
//
// The animated needle. Drawn with two Triangle shapes — north tip points
// toward the target, south tip points away. Skin tints the colours.
// Ambient sway is a tiny ±2° oscillation when stationary, giving the
// compass a living, breathing quality.

import SwiftUI

struct NeedleView: View {

    let bearing:   Double
    let skin:      CompassSkin
    var locked:    Bool    = false
    var quietMode: Bool    = false

    @State private var swayOffset: Double = 0
    @State private var swayAnimating = false

    var body: some View {
        ZStack {
            // North tip — points toward target
            Triangle()
                .fill(northColor)
                .frame(width: 14, height: 48)
                .offset(y: -26)            // place tip above centre

            // South tip — points away
            Triangle()
                .fill(southColor)
                .frame(width: 12, height: 30)
                .rotationEffect(.degrees(180))
                .offset(y: 17)
        }
        .rotationEffect(.degrees(bearing + swayOffset))
        .animation(
            quietMode
                ? .spring(response: 1.2, dampingFraction: 0.65)
                : AnimationSystem.needleSettle,
            value: bearing
        )
        .onAppear { startSway() }
        .onChange(of: quietMode) { _, q in
            stopSway()
            if !q { startSway() }
        }
    }

    // MARK: - Skin colours
    // Single source of truth: each skin's accent palette in CompassSkins.swift.

    private var northColor: Color { skin.northAccentColor }
    private var southColor: Color { skin.southAccentColor }

    // MARK: - Ambient sway

    private func startSway() {
        guard !swayAnimating else { return }
        swayAnimating = true
        animateSway()
    }

    private func stopSway() {
        swayAnimating = false
        withAnimation(.easeOut(duration: 0.4)) { swayOffset = 0 }
    }

    private func animateSway() {
        guard swayAnimating else { return }
        let target: Double = swayOffset >= 0 ? -2 : 2
        let duration: Double = quietMode ? 9 : 5
        withAnimation(.easeInOut(duration: duration)) {
            swayOffset = target
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            animateSway()
        }
    }
}

// MARK: - Triangle shape

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to:     CGPoint(x: rect.midX,  y: rect.minY))
            p.addLine(to:  CGPoint(x: rect.maxX,  y: rect.maxY))
            p.addLine(to:  CGPoint(x: rect.minX,  y: rect.maxY))
            p.closeSubpath()
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(hex: "#0d0d14").ignoresSafeArea()
        NeedleView(bearing: 340, skin: .minimal, locked: false)
            .frame(width: 200, height: 200)
    }
}
