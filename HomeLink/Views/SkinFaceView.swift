// SkinFaceView.swift
// HomeLink › Views
//
// Dispatches to the correct skin face renderer.
// CompassView never knows which skin is active — it just passes state here.
// Adding a new skin = add a case here + a new *FaceView file. Nothing else changes.

import SwiftUI

struct SkinFaceView: View {
    let skin: CompassSkin
    let bearing: Double
    let locked: Bool
    let quietMode: Bool
    let pingRingActive: Bool

    var body: some View {
        Group {
            switch skin {
            case .minimal:    MinimalFaceView(locked: locked, quietMode: quietMode, pingRingActive: pingRingActive)
            case .classic:    ClassicFaceView(locked: locked, quietMode: quietMode, pingRingActive: pingRingActive)
            case .heart:      HeartFaceView(locked: locked, quietMode: quietMode, pingRingActive: pingRingActive)
            case .celestial:  CelestialFaceView(locked: locked, quietMode: quietMode, pingRingActive: pingRingActive)
            case .vintage:    VintageFaceView(locked: locked, quietMode: quietMode, pingRingActive: pingRingActive)
            case .aurora:     AuroraFaceView(locked: locked, quietMode: quietMode, pingRingActive: pingRingActive)
            }
        }
    }
}

// MARK: - Minimal face

struct MinimalFaceView: View {
    let locked: Bool
    let quietMode: Bool
    let pingRingActive: Bool

    var body: some View {
        ZStack {
            // Breathing ring — outermost, always present
            Circle()
                .stroke(
                    DesignTokens.Color.accentMid.opacity(pingRingActive ? 0.55 : 0.22),
                    lineWidth: 1
                )
                .scaleEffect(pingRingActive ? 1.07 : 1.0)
                .animation(
                    quietMode
                        ? Animation.easeInOut(duration: 8).repeatForever(autoreverses: true)
                        : AnimationSystem.ringBreath,
                    value: pingRingActive
                )
                .frame(width: 240, height: 240)

            // Lock glow ring
            if locked {
                Circle()
                    .stroke(DesignTokens.Color.accentSoft.opacity(quietMode ? 0.4 : 0.7), lineWidth: 1.5)
                    .frame(width: 248, height: 248)
                    .animation(AnimationSystem.pingGlow, value: locked)
            }

            // Outer structural ring
            Circle()
                .stroke(DesignTokens.Color.border, lineWidth: 1)
                .frame(width: 200, height: 200)

            // Inner structural ring
            Circle()
                .stroke(DesignTokens.Color.borderMid, lineWidth: 0.5)
                .frame(width: 130, height: 130)
        }
    }
}

// MARK: - Classic face

struct ClassicFaceView: View {
    let locked: Bool
    let quietMode: Bool
    let pingRingActive: Bool

    private let cardinals = ["N", "E", "S", "W"]

    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(locked ? DesignTokens.Color.accentSoft : DesignTokens.Color.border, lineWidth: locked ? 1.5 : 1)
                .frame(width: 200, height: 200)
                .animation(.easeInOut(duration: 0.4), value: locked)

            // Tick marks via Canvas
            Canvas { ctx, size in
                let cx = size.width / 2
                let cy = size.height / 2
                let r  = min(cx, cy) - 2

                for i in stride(from: 0, to: 360, by: 6) {
                    let rad    = Double(i) * .pi / 180
                    let major  = i % 90 == 0
                    let minor  = i % 30 == 0
                    let len    = major ? r * 0.15 : minor ? r * 0.1 : r * 0.06
                    let sw: CGFloat = major ? 0.9 : minor ? 0.6 : 0.35
                    let col = major
                        ? Color(hex: "#c4a8d4")
                        : minor ? Color(hex: "#5a4870") : Color(hex: "#3a3050")
                    let x1 = cx + CGFloat(sin(rad)) * (r - 1)
                    let y1 = cy - CGFloat(cos(rad)) * (r - 1)
                    let x2 = cx + CGFloat(sin(rad)) * CGFloat(r - len)
                    let y2 = cy - CGFloat(cos(rad)) * CGFloat(r - len)
                    var path = Path()
                    path.move(to: CGPoint(x: x1, y: y1))
                    path.addLine(to: CGPoint(x: x2, y: y2))
                    ctx.stroke(path, with: .color(col), lineWidth: sw)
                }
            }
            .frame(width: 200, height: 200)

            // Cardinal labels
            ForEach(0..<4, id: \.self) { i in
                let angle  = Double(i) * 90
                let rad    = angle * .pi / 180
                let radius = 200.0 * 0.76 / 2
                Text(cardinals[i])
                    .font(.system(size: 12, weight: i == 0 ? .semibold : .regular, design: .rounded))
                    .foregroundColor(i == 0 ? DesignTokens.Color.accentSoft : DesignTokens.Color.textMuted)
                    .offset(
                        x: CGFloat(sin(rad)) * radius,
                        y: -CGFloat(cos(rad)) * radius
                    )
            }
        }
    }
}

// MARK: - Heart face

struct HeartFaceView: View {
    let locked: Bool
    let quietMode: Bool
    let pingRingActive: Bool

    var body: some View {
        ZStack {
            // Dot ring
            Canvas { ctx, size in
                let cx = size.width / 2
                let cy = size.height / 2
                let r  = min(cx, cy) - 8
                for i in 0..<12 {
                    let rad = Double(i) * 30 * .pi / 180
                    let x = cx + CGFloat(sin(rad)) * r
                    let y = cy - CGFloat(cos(rad)) * r
                    let dot = Path(ellipseIn: CGRect(x: x-1, y: y-1, width: 2, height: 2))
                    ctx.fill(dot, with: .color(Color(hex: "#5a4870")))
                }
            }
            .frame(width: 200, height: 200)

            // Heart shape
            HeartShape()
                .stroke(locked ? DesignTokens.Color.accentSoft : DesignTokens.Color.accentMid,
                        lineWidth: 1.2)
                .fill(DesignTokens.Color.accentMid.opacity(locked ? (quietMode ? 0.12 : 0.2) : 0))
                .frame(width: 110, height: 100)
                .offset(y: 6)
                .scaleEffect(locked && !quietMode ? 1.04 : 1.0)
                .animation(
                    locked && !quietMode
                        ? Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                        : .easeInOut(duration: 0.4),
                    value: locked
                )
        }
    }
}

// MARK: - Heart shape

struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let cx = rect.midX
        return Path { p in
            p.move(to: CGPoint(x: cx, y: h * 0.9))
            p.addCurve(
                to: CGPoint(x: rect.minX, y: h * 0.3),
                control1: CGPoint(x: cx - w * 0.5, y: h * 0.75),
                control2: CGPoint(x: rect.minX,     y: h * 0.55)
            )
            p.addArc(
                center: CGPoint(x: rect.minX + w * 0.25, y: h * 0.25),
                radius: w * 0.25,
                startAngle: .degrees(180),
                endAngle: .degrees(0),
                clockwise: false
            )
            p.addArc(
                center: CGPoint(x: rect.maxX - w * 0.25, y: h * 0.25),
                radius: w * 0.25,
                startAngle: .degrees(180),
                endAngle: .degrees(0),
                clockwise: true
            )
            p.addCurve(
                to: CGPoint(x: cx, y: h * 0.9),
                control1: CGPoint(x: rect.maxX,     y: h * 0.55),
                control2: CGPoint(x: cx + w * 0.5, y: h * 0.75)
            )
            p.closeSubpath()
        }
    }
}

// MARK: - Celestial face

struct CelestialFaceView: View {
    let locked: Bool
    let quietMode: Bool
    let pingRingActive: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(DesignTokens.Color.border, lineWidth: 0.8)
                .frame(width: 200, height: 200)

            Canvas { ctx, size in
                let cx = size.width / 2, cy = size.height / 2
                let r  = min(cx, cy) - 8
                // Deterministic "stars"
                var seed: UInt32 = 42
                for _ in 0..<18 {
                    seed = seed &* 1103515245 &+ 12345
                    let a  = Double(seed & 0x7fff) / Double(0x7fff) * .pi * 2
                    seed = seed &* 1103515245 &+ 12345
                    let ri = r * (0.55 + Double(seed & 0x3fff) / Double(0x3fff) * 0.38)
                    let sx = cx + CGFloat(cos(a)) * ri
                    let sy = cy + CGFloat(sin(a)) * ri
                    let sr: CGFloat = 0.5 + CGFloat((seed >> 16) & 3) * 0.3
                    let op = 0.35 + Double((seed >> 20) & 3) * 0.15
                    let star = Path(ellipseIn: CGRect(x: sx - sr, y: sy - sr, width: sr*2, height: sr*2))
                    ctx.fill(star, with: .color(Color(hex: "#c4a8d4").opacity(op)))
                }
                // Dashed arc connectors
                for j in 0..<3 {
                    let startA = Double(j) * 120 * .pi / 180
                    let endA   = startA + 60 * .pi / 180
                    let arcR   = r * (0.62 + Double(j) * 0.12)
                    var arc = Path()
                    arc.addArc(
                        center: CGPoint(x: cx, y: cy),
                        radius: arcR,
                        startAngle: .radians(startA),
                        endAngle: .radians(endA),
                        clockwise: false
                    )
                    ctx.stroke(
                        arc,
                        with: .color(Color(hex: "#7c6b8e").opacity(0.4)),
                        style: StrokeStyle(lineWidth: 0.5, dash: [2, 3])
                    )
                }
            }
            .frame(width: 200, height: 200)
        }
    }
}

// MARK: - Vintage face

struct VintageFaceView: View {
    let locked: Bool
    let quietMode: Bool
    let pingRingActive: Bool

    private let allCardinals = ["N","NE","E","SE","S","SW","W","NW"]

    var body: some View {
        ZStack {
            Circle()
                .stroke(locked ? DesignTokens.Color.accentSoft : Color(hex: "#5a4870"), lineWidth: 1.2)
                .frame(width: 200, height: 200)

            Circle()
                .stroke(DesignTokens.Color.border, lineWidth: 0.4)
                .frame(width: 198, height: 198)

            // 72 tick marks via Canvas
            Canvas { ctx, size in
                let cx = size.width / 2, cy = size.height / 2
                let r  = min(cx, cy) - 2
                for i in stride(from: 0, to: 360, by: 5) {
                    let rad   = Double(i) * .pi / 180
                    let major = i % 90 == 0
                    let minor = i % 30 == 0
                    let len   = major ? r * 0.18 : minor ? r * 0.1 : r * 0.05
                    let sw: CGFloat = major ? 1.2 : minor ? 0.7 : 0.35
                    let col = major
                        ? Color(hex: "#c4a8d4")
                        : minor ? Color(hex: "#6b5f7a") : Color(hex: "#4a3860")
                    let x1 = cx + CGFloat(sin(rad)) * (r - 1)
                    let y1 = cy - CGFloat(cos(rad)) * (r - 1)
                    let x2 = cx + CGFloat(sin(rad)) * CGFloat(r - len)
                    let y2 = cy - CGFloat(cos(rad)) * CGFloat(r - len)
                    var path = Path()
                    path.move(to: CGPoint(x: x1, y: y1))
                    path.addLine(to: CGPoint(x: x2, y: y2))
                    ctx.stroke(path, with: .color(col), lineWidth: sw)
                }
            }
            .frame(width: 200, height: 200)

            // 8-point cardinal labels
            ForEach(0..<8, id: \.self) { i in
                let angle  = Double(i) * 45
                let rad    = angle * .pi / 180
                let radius = 200.0 * 0.82 / 2
                let major  = i % 2 == 0
                Text(allCardinals[i])
                    .font(.system(size: major ? 11 : 8, weight: major ? .medium : .regular, design: .rounded))
                    .foregroundColor(
                        i == 0 ? DesignTokens.Color.accentSoft
                               : major ? DesignTokens.Color.textSecondary
                                       : DesignTokens.Color.textDim
                    )
                    .offset(
                        x: CGFloat(sin(rad)) * radius,
                        y: -CGFloat(cos(rad)) * radius
                    )
            }

            // Dashed inner ring
            Circle()
                .stroke(
                    style: StrokeStyle(lineWidth: 0.5, dash: [1.5, 2])
                )
                .foregroundColor(Color(hex: "#5a4870"))
                .frame(width: 144, height: 144)
        }
    }
}

// MARK: - Aurora face

struct AuroraFaceView: View {
    let locked: Bool
    let quietMode: Bool
    let pingRingActive: Bool

    private let bandColors: [Color] = [
        Color(hex: "#5dcaa5").opacity(0.12),
        Color(hex: "#7c6b8e").opacity(0.18),
        Color(hex: "#c4a8d4").opacity(0.10),
        Color(hex: "#5dcaa5").opacity(0.08),
    ]

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(hex: "#5dcaa5").opacity(0.25), lineWidth: 0.8)
                .frame(width: 200, height: 200)

            ForEach(0..<bandColors.count, id: \.self) { i in
                Circle()
                    .stroke(bandColors[i], lineWidth: 2.0 + CGFloat(i) * 0.5)
                    .frame(
                        width: 200 * (0.42 + Double(i) * 0.15),
                        height: 200 * (0.42 + Double(i) * 0.15)
                    )
                    .animation(
                        Animation.easeInOut(duration: 4.0 + Double(i))
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.5),
                        value: locked
                    )
            }
        }
    }
}
