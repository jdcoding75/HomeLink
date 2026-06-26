// SkinFaceView.swift
// Pointward › Views
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

// Clean modern precision instrument — minimalist, but unmistakably a compass:
// fine degree ticks, elegant light-weight cardinals, thin double ring border.
struct MinimalFaceView: View {
    let locked: Bool
    let quietMode: Bool
    let pingRingActive: Bool

    // Cool greys with a lavender whisper
    private static let inkBright = Color(hex: "#d8d4e4")
    private static let ink       = Color(hex: "#8a84a0")
    private static let inkDim    = Color(hex: "#4a4560")

    private let cardinals = ["N", "E", "S", "W"]

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

            // Thin double ring border
            Circle()
                .stroke(locked ? DesignTokens.Color.accentSoft : Self.ink.opacity(0.7),
                        lineWidth: locked ? 1.1 : 0.8)
                .frame(width: 200, height: 200)
                .animation(.easeInOut(duration: 0.4), value: locked)
            Circle()
                .stroke(Self.inkDim.opacity(0.8), lineWidth: 0.5)
                .frame(width: 194, height: 194)

            // Fine degree tick marks
            Canvas { ctx, size in
                let cx = size.width / 2, cy = size.height / 2
                let tickOuter: CGFloat = 95
                for deg in stride(from: 0, to: 360, by: 2) {
                    let rad  = Double(deg) * .pi / 180
                    let is90 = deg % 90 == 0
                    let is10 = deg % 10 == 0
                    let len: CGFloat = is90 ? 9 : is10 ? 6 : 3
                    let sw:  CGFloat = is90 ? 1.0 : is10 ? 0.6 : 0.3
                    let col = is90 ? Self.inkBright
                                   : is10 ? Self.ink.opacity(0.8)
                                          : Self.inkDim.opacity(0.7)
                    var path = Path()
                    path.move(to: CGPoint(x: cx + CGFloat(sin(rad)) * tickOuter,
                                          y: cy - CGFloat(cos(rad)) * tickOuter))
                    path.addLine(to: CGPoint(x: cx + CGFloat(sin(rad)) * (tickOuter - len),
                                             y: cy - CGFloat(cos(rad)) * (tickOuter - len)))
                    ctx.stroke(path, with: .color(col), lineWidth: sw)
                }
            }
            .frame(width: 200, height: 200)

            // Cardinals — elegant, light, letter-spaced
            ForEach(0..<4, id: \.self) { i in
                let rad = Double(i) * 90 * .pi / 180
                Text(cardinals[i])
                    .font(.system(size: 13, weight: i == 0 ? .medium : .light))
                    .kerning(1)
                    .foregroundColor(i == 0 ? DesignTokens.Color.accentSoft : Self.ink)
                    .offset(x: CGFloat(sin(rad)) * 70, y: -CGFloat(cos(rad)) * 70)
            }

            // Inner hairline ring
            Circle()
                .stroke(Self.inkDim.opacity(0.5), lineWidth: 0.4)
                .frame(width: 120, height: 120)
        }
    }
}

// MARK: - Classic face
//
// Genuine antique explorer/ship compass:
//   • full 32-point rose (cardinals → quarter-winds) as a layered, two-tone
//     pointed star — each point split light/dark for the classic chiaroscuro look
//   • fine tick marks at every single degree on the outer band
//   • N picked out in deep red; serif lettering; rich inks on a dark ground

struct ClassicFaceView: View {
    let locked: Bool
    let quietMode: Bool
    let pingRingActive: Bool

    // Antique palette
    private static let ivory       = Color(hex: "#e6d9b8")
    private static let parchment   = Color(hex: "#9a8d6e")
    private static let crimson     = Color(hex: "#9e2b25")
    private static let crimsonDeep = Color(hex: "#5e1a16")
    private static let gold        = Color(hex: "#c9a227")
    private static let goldDim     = Color(hex: "#7a6420")
    private static let midnight    = Color(hex: "#2a2138")

    private let cardinals      = ["N", "E", "S", "W"]
    private let intercardinals = ["NE", "SE", "SW", "NW"]

    var body: some View {
        ZStack {
            // Aged dark face
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#1d1626"), Color(hex: "#100c16")],
                        center: .center, startRadius: 10, endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)

            // Outer bezel ring (lock-aware)
            Circle()
                .stroke(locked ? DesignTokens.Color.accentSoft : Self.gold.opacity(0.85),
                        lineWidth: locked ? 1.5 : 1.2)
                .frame(width: 200, height: 200)
                .animation(.easeInOut(duration: 0.4), value: locked)

            // Fine companion ring
            Circle()
                .stroke(Self.goldDim.opacity(0.6), lineWidth: 0.5)
                .frame(width: 192, height: 192)

            // Degree ticks + 32-point rose
            Canvas { ctx, size in
                let cx = size.width / 2
                let cy = size.height / 2
                let r  = min(cx, cy)

                // Fine tick marks at every degree
                let tickOuter = r - 5
                for deg in 0..<360 {
                    let rad  = Double(deg) * .pi / 180
                    let is10 = deg % 10 == 0
                    let is5  = deg % 5 == 0
                    let len: CGFloat = is10 ? 7 : is5 ? 5 : 3
                    let sw:  CGFloat = is10 ? 0.8 : 0.4
                    let col = is10 ? Self.ivory.opacity(0.8)
                                   : is5 ? Self.parchment.opacity(0.7)
                                         : Self.parchment.opacity(0.4)
                    var path = Path()
                    path.move(to: CGPoint(x: cx + CGFloat(sin(rad)) * tickOuter,
                                          y: cy - CGFloat(cos(rad)) * tickOuter))
                    path.addLine(to: CGPoint(x: cx + CGFloat(sin(rad)) * (tickOuter - len),
                                             y: cy - CGFloat(cos(rad)) * (tickOuter - len)))
                    ctx.stroke(path, with: .color(col), lineWidth: sw)
                }

                // Two-tone star point: split down its spine, light/dark halves
                func drawPoint(_ angleDeg: Double, length: CGFloat, halfWidth: CGFloat,
                               light: Color, dark: Color, outline: Color? = nil) {
                    let rad  = angleDeg * .pi / 180
                    let dirX = CGFloat(sin(rad)),  dirY = -CGFloat(cos(rad))
                    let prpX = CGFloat(cos(rad)),  prpY =  CGFloat(sin(rad))
                    let tip      = CGPoint(x: cx + dirX * length, y: cy + dirY * length)
                    let shoulder = length * 0.3
                    let baseL    = CGPoint(x: cx + dirX * shoulder - prpX * halfWidth,
                                           y: cy + dirY * shoulder - prpY * halfWidth)
                    let baseR    = CGPoint(x: cx + dirX * shoulder + prpX * halfWidth,
                                           y: cy + dirY * shoulder + prpY * halfWidth)
                    let center   = CGPoint(x: cx, y: cy)

                    var left = Path()
                    left.move(to: center); left.addLine(to: baseL); left.addLine(to: tip)
                    left.closeSubpath()
                    ctx.fill(left, with: .color(light))

                    var right = Path()
                    right.move(to: center); right.addLine(to: baseR); right.addLine(to: tip)
                    right.closeSubpath()
                    ctx.fill(right, with: .color(dark))

                    if let outline {
                        var edge = Path()
                        edge.move(to: baseL); edge.addLine(to: tip); edge.addLine(to: baseR)
                        ctx.stroke(edge, with: .color(outline), lineWidth: 0.4)
                    }
                }

                // Classic 8-pointed nautical rose: 4 major (cardinal) points and
                // 4 minor (intercardinal) points, with small decorative points
                // tucked between every pair.
                for i in 0..<16 where i % 2 == 1 {       // decorative points between
                    drawPoint(Double(i) * 22.5, length: 32, halfWidth: 3.5,
                              light: Self.parchment.opacity(0.75), dark: Self.midnight)
                }
                for i in 0..<8 where i % 2 == 1 {        // minor points (NE SE SW NW)
                    drawPoint(Double(i) * 45, length: 56, halfWidth: 6.5,
                              light: Self.gold, dark: Self.crimsonDeep,
                              outline: Self.goldDim)
                }
                for i in 0..<4 {                          // major points (N E S W)
                    drawPoint(Double(i) * 90, length: 72, halfWidth: 8.5,
                              light: Self.ivory,
                              dark: i == 0 ? Self.crimson : Self.crimsonDeep,
                              outline: Self.gold.opacity(0.8))
                }

                // Center boss
                let boss = Path(ellipseIn: CGRect(x: cx - 5, y: cy - 5, width: 10, height: 10))
                ctx.fill(boss, with: .color(Self.midnight))
                ctx.stroke(boss, with: .color(Self.gold), lineWidth: 0.8)
                let pin = Path(ellipseIn: CGRect(x: cx - 1.5, y: cy - 1.5, width: 3, height: 3))
                ctx.fill(pin, with: .color(Self.ivory))
            }
            .frame(width: 200, height: 200)

            // Cardinal letters — N in red, serif for the antique look
            ForEach(0..<4, id: \.self) { i in
                let rad = Double(i) * 90 * .pi / 180
                Text(cardinals[i])
                    .font(.system(size: 12, weight: i == 0 ? .bold : .semibold, design: .serif))
                    .foregroundColor(i == 0 ? Color(hex: "#d4453c") : Self.ivory)
                    .offset(x: CGFloat(sin(rad)) * 82, y: -CGFloat(cos(rad)) * 82)
            }

            // Intercardinal letters — all 8 directions clearly labeled
            ForEach(0..<4, id: \.self) { i in
                let rad = (45.0 + Double(i) * 90) * .pi / 180
                Text(intercardinals[i])
                    .font(.system(size: 9, weight: .semibold, design: .serif))
                    .foregroundColor(Self.gold)
                    .offset(x: CGFloat(sin(rad)) * 82, y: -CGFloat(cos(rad)) * 82)
            }
        }
    }
}

// MARK: - Heart face

// Heart compass — one large, solid, beautifully curved heart: deep rose fill,
// clean lavender outline, fine concentric inner hearts, and a soft glow that
// breathes gently and burns brighter on lock. Jewelry, not cartoon.
struct HeartFaceView: View {
    let locked: Bool
    let quietMode: Bool
    let pingRingActive: Bool

    private static let rose     = Color(hex: "#c4a8d4")
    private static let roseHi   = Color(hex: "#e8c8e0")
    private static let roseDeep = Color(hex: "#3a1828")
    private static let roseDim  = Color(hex: "#5a4870")

    @State private var breathe = false

    var body: some View {
        ZStack {
            // Faint circular reference ring so the needle still reads as a compass
            Circle()
                .stroke(Self.roseDim.opacity(0.3), lineWidth: 0.5)
                .frame(width: 200, height: 200)

            // Soft glow behind the heart — gentle pulse, brighter when locked
            HeartShape()
                .fill(Self.rose)
                .frame(width: 162, height: 146)
                .blur(radius: 24)
                .opacity(
                    locked ? (quietMode ? 0.35 : 0.50)
                           : (breathe ? 0.22 : 0.10)
                )
                .offset(y: 4)
                .animation(.easeInOut(duration: 0.8), value: locked)

            // The heart — large, solid, deep purple-rose
            HeartShape()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#4a2034"), Self.roseDeep],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: 152, height: 137)
                .offset(y: 4)

            // Fine concentric inner hearts — crafted, not empty
            ForEach(1..<4, id: \.self) { i in
                HeartShape()
                    .stroke(Self.rose.opacity(0.30 - Double(i) * 0.07), lineWidth: 0.5)
                    .frame(width: 152 - CGFloat(i) * 28,
                           height: 137 - CGFloat(i) * 25)
                    .offset(y: 4)
            }

            // Clean smooth outline — lifts to bright when locked
            HeartShape()
                .stroke(locked ? Self.roseHi : Self.rose, lineWidth: 1.6)
                .frame(width: 152, height: 137)
                .offset(y: 4)
                .shadow(color: Self.rose.opacity(locked ? 0.7 : 0.25), radius: 6)
                .animation(.easeInOut(duration: 0.6), value: locked)
        }
        .onAppear {
            guard !quietMode else { return }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
    }
}

// MARK: - Heart shape

/// A mathematically clean heart built from four symmetric cubic bézier curves —
/// smooth lobes, gentle waist, sharp-but-graceful tip. No arc seams.
struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let x = rect.minX,  y = rect.minY
        var p = Path()

        // Bottom tip
        p.move(to: CGPoint(x: x + w * 0.5, y: y + h * 0.98))
        // Left side rising into the left lobe
        p.addCurve(
            to:       CGPoint(x: x + w * 0.04, y: y + h * 0.30),
            control1: CGPoint(x: x + w * 0.22, y: y + h * 0.74),
            control2: CGPoint(x: x + w * 0.04, y: y + h * 0.54)
        )
        // Left lobe over the top, down into the center dip
        p.addCurve(
            to:       CGPoint(x: x + w * 0.50, y: y + h * 0.24),
            control1: CGPoint(x: x + w * 0.04, y: y + h * 0.02),
            control2: CGPoint(x: x + w * 0.34, y: y)
        )
        // Mirror: center dip up over the right lobe
        p.addCurve(
            to:       CGPoint(x: x + w * 0.96, y: y + h * 0.30),
            control1: CGPoint(x: x + w * 0.66, y: y),
            control2: CGPoint(x: x + w * 0.96, y: y + h * 0.02)
        )
        // Right side falling back to the tip
        p.addCurve(
            to:       CGPoint(x: x + w * 0.5, y: y + h * 0.98),
            control1: CGPoint(x: x + w * 0.96, y: y + h * 0.54),
            control2: CGPoint(x: x + w * 0.78, y: y + h * 0.74)
        )
        p.closeSubpath()
        return p
    }
}

// MARK: - Celestial face

// Star map — navigate by the night sky: constellation patterns joined by
// hairline arcs, scattered stars, and subtle degree marks around the rim.
struct CelestialFaceView: View {
    let locked: Bool
    let quietMode: Bool
    let pingRingActive: Bool

    private static let starlight = Color(hex: "#c4a8d4")
    private static let nebula    = Color(hex: "#7c6b8e")

    var body: some View {
        ZStack {
            // Nebula ground — deep purple breathing into midnight blue
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#2a1845"), Color(hex: "#141b38"),
                                 Color(hex: "#0a1228")],
                        center: .center, startRadius: 8, endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)
            // Off-center nebula bloom for depth
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#6b4a9e").opacity(0.25), .clear],
                        center: UnitPoint(x: 0.32, y: 0.30),
                        startRadius: 4, endRadius: 80
                    )
                )
                .frame(width: 200, height: 200)

            // Thin double border
            Circle()
                .stroke(locked ? DesignTokens.Color.accentSoft.opacity(0.8)
                               : Self.nebula.opacity(0.5), lineWidth: 0.8)
                .frame(width: 200, height: 200)
                .animation(.easeInOut(duration: 0.4), value: locked)
            Circle()
                .stroke(Self.nebula.opacity(0.2), lineWidth: 0.4)
                .frame(width: 194, height: 194)

            Canvas { ctx, size in
                let cx = size.width / 2, cy = size.height / 2
                let r  = min(cx, cy)

                // Subtle degree marks around the rim
                let tickOuter = r - 4
                for deg in stride(from: 0, to: 360, by: 5) {
                    let rad  = Double(deg) * .pi / 180
                    let is90 = deg % 90 == 0
                    let is15 = deg % 15 == 0
                    let len: CGFloat = is90 ? 7 : is15 ? 5 : 2.5
                    let sw:  CGFloat = is90 ? 0.8 : 0.4
                    let col = is90 ? Self.starlight.opacity(0.7)
                                   : Self.nebula.opacity(is15 ? 0.5 : 0.3)
                    var path = Path()
                    path.move(to: CGPoint(x: cx + CGFloat(sin(rad)) * tickOuter,
                                          y: cy - CGFloat(cos(rad)) * tickOuter))
                    path.addLine(to: CGPoint(x: cx + CGFloat(sin(rad)) * (tickOuter - len),
                                             y: cy - CGFloat(cos(rad)) * (tickOuter - len)))
                    ctx.stroke(path, with: .color(col), lineWidth: sw)
                }

                // Many scattered stars — varied sizes and brightness, the
                // larger ones with a soft halo (deterministic, no flicker)
                var seed: UInt32 = 42
                for _ in 0..<70 {
                    seed = seed &* 1103515245 &+ 12345
                    let a  = Double(seed & 0x7fff) / Double(0x7fff) * .pi * 2
                    seed = seed &* 1103515245 &+ 12345
                    let ri = (r - 14) * (0.18 + Double(seed & 0x3fff) / Double(0x3fff) * 0.78)
                    let sx = cx + CGFloat(cos(a)) * ri
                    let sy = cy + CGFloat(sin(a)) * ri
                    let sr: CGFloat = 0.3 + CGFloat((seed >> 16) & 7) * 0.18
                    let op = 0.25 + Double((seed >> 20) & 7) * 0.1
                    if sr > 1.0 {  // bright star — soft halo
                        let halo = Path(ellipseIn: CGRect(x: sx - sr * 3, y: sy - sr * 3,
                                                          width: sr * 6, height: sr * 6))
                        ctx.fill(halo, with: .color(Self.starlight.opacity(0.10)))
                    }
                    let star = Path(ellipseIn: CGRect(x: sx - sr, y: sy - sr,
                                                      width: sr * 2, height: sr * 2))
                    ctx.fill(star, with: .color(Self.starlight.opacity(op)))
                }

                // Real constellation patterns — points + explicit edges
                // (offsets in face points from an anchor; recognisable shapes)
                struct Pattern {
                    let anchor: CGPoint        // offset from center
                    let pts: [CGPoint]         // star offsets from anchor
                    let edges: [(Int, Int)]
                }
                let patterns: [Pattern] = [
                    // Big Dipper — handle of three, bowl of four
                    Pattern(anchor: CGPoint(x: -52, y: -40),
                            pts: [CGPoint(x: 0, y: 0),  CGPoint(x: 12, y: 5),
                                  CGPoint(x: 24, y: 8), CGPoint(x: 36, y: 14),
                                  CGPoint(x: 50, y: 12), CGPoint(x: 48, y: 26),
                                  CGPoint(x: 34, y: 27)],
                            edges: [(0,1),(1,2),(2,3),(3,4),(4,5),(5,6),(6,3)]),
                    // Orion — shoulders, three-star belt, feet
                    Pattern(anchor: CGPoint(x: 28, y: 8),
                            pts: [CGPoint(x: 0, y: 0),   CGPoint(x: 24, y: 3),
                                  CGPoint(x: 8, y: 17),  CGPoint(x: 13, y: 20),
                                  CGPoint(x: 18, y: 23), CGPoint(x: 3, y: 40),
                                  CGPoint(x: 27, y: 38)],
                            edges: [(0,2),(1,4),(2,3),(3,4),(2,5),(4,6)]),
                    // Cassiopeia — the W
                    Pattern(anchor: CGPoint(x: -62, y: 30),
                            pts: [CGPoint(x: 0, y: 0),   CGPoint(x: 10, y: -9),
                                  CGPoint(x: 20, y: -1), CGPoint(x: 30, y: -11),
                                  CGPoint(x: 40, y: -4)],
                            edges: [(0,1),(1,2),(2,3),(3,4)]),
                    // Cygnus — the northern cross
                    Pattern(anchor: CGPoint(x: 30, y: -58),
                            pts: [CGPoint(x: 0, y: 0),    CGPoint(x: 0, y: -13),
                                  CGPoint(x: 1, y: 15),   CGPoint(x: -14, y: 6),
                                  CGPoint(x: 13, y: 5)],
                            edges: [(0,1),(0,2),(0,3),(0,4)]),
                ]
                for pattern in patterns {
                    let pts = pattern.pts.map {
                        CGPoint(x: cx + pattern.anchor.x + $0.x,
                                y: cy + pattern.anchor.y + $0.y)
                    }
                    // Hairline connectors
                    var lines = Path()
                    for (a, b) in pattern.edges {
                        lines.move(to: pts[a])
                        lines.addLine(to: pts[b])
                    }
                    ctx.stroke(lines, with: .color(Self.starlight.opacity(0.35)), lineWidth: 0.5)
                    // Constellation stars — bright with a soft halo
                    for p in pts {
                        let halo = Path(ellipseIn: CGRect(x: p.x - 3.4, y: p.y - 3.4,
                                                          width: 6.8, height: 6.8))
                        ctx.fill(halo, with: .color(Self.starlight.opacity(0.15)))
                        let dot = Path(ellipseIn: CGRect(x: p.x - 1.5, y: p.y - 1.5,
                                                         width: 3, height: 3))
                        ctx.fill(dot, with: .color(Color(hex: "#ece4f6")))
                    }
                }

                // A faint ecliptic arc for depth
                var arc = Path()
                arc.addArc(center: CGPoint(x: cx, y: cy), radius: r * 0.80,
                           startAngle: .radians(.pi * 0.62), endAngle: .radians(.pi * 1.18),
                           clockwise: false)
                ctx.stroke(arc, with: .color(Self.nebula.opacity(0.4)),
                           style: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
            }
            .frame(width: 200, height: 200)
        }
    }
}

// MARK: - Vintage face
//
// Military/surveyor brass compass:
//   • double ring border with a fine detail ring between
//   • degree bezel 0–360, ticks every 2°, numbered every 10° (radially set)
//   • N/S/E/W and NE/NW/SE/SW all labeled; surveyor crosshair through center
//   • warm gold/brass tones on a dark ground

struct VintageFaceView: View {
    let locked: Bool
    let quietMode: Bool
    let pingRingActive: Bool

    // Brass palette
    private static let brassBright = Color(hex: "#e3c887")
    private static let brass       = Color(hex: "#c9a86a")
    private static let brassDim    = Color(hex: "#8a703f")
    private static let brassDark   = Color(hex: "#56441f")

    private let cardinals      = ["N", "E", "S", "W"]
    private let intercardinals = ["NE", "SE", "SW", "NW"]

    var body: some View {
        ZStack {
            // Dark burnished face
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#221a0e"), Color(hex: "#120d06")],
                        center: .center, startRadius: 10, endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)

            // Double ring border with fine detail ring between
            Circle()
                .stroke(locked ? DesignTokens.Color.accentSoft : Self.brassBright.opacity(0.9),
                        lineWidth: locked ? 1.6 : 1.4)
                .frame(width: 200, height: 200)
                .animation(.easeInOut(duration: 0.4), value: locked)
            Circle()
                .stroke(Self.brassDim.opacity(0.7), lineWidth: 0.5)
                .frame(width: 194, height: 194)
            Circle()
                .stroke(Self.brass.opacity(0.8), lineWidth: 1.0)
                .frame(width: 186, height: 186)

            // Degree ticks + surveyor crosshair
            Canvas { ctx, size in
                let cx = size.width / 2, cy = size.height / 2

                // [§B5] Bezel NOTCHES every 15° (was every 2° + 10°/cardinal weights — the fine grid
                // was too dense to read). Cardinals (every 90°) heaviest; NO minor ticks.
                let tickOuter: CGFloat = 92
                for deg in stride(from: 0, to: 360, by: 15) {
                    let rad  = Double(deg) * .pi / 180
                    let is90 = deg % 90 == 0
                    let len: CGFloat = is90 ? 10 : 7
                    let sw:  CGFloat = is90 ? 1.2 : 0.8
                    let col = is90 ? Self.brassBright : Self.brass.opacity(0.9)
                    var path = Path()
                    path.move(to: CGPoint(x: cx + CGFloat(sin(rad)) * tickOuter,
                                          y: cy - CGFloat(cos(rad)) * tickOuter))
                    path.addLine(to: CGPoint(x: cx + CGFloat(sin(rad)) * (tickOuter - len),
                                             y: cy - CGFloat(cos(rad)) * (tickOuter - len)))
                    ctx.stroke(path, with: .color(col), lineWidth: sw)
                }

                // Surveyor crosshair: thin N–S / E–W lines through the pivot
                for axis in 0..<2 {
                    let rad = Double(axis) * 90 * .pi / 180
                    var line = Path()
                    line.move(to: CGPoint(x: cx + CGFloat(sin(rad)) * 44,
                                          y: cy - CGFloat(cos(rad)) * 44))
                    line.addLine(to: CGPoint(x: cx - CGFloat(sin(rad)) * 44,
                                             y: cy + CGFloat(cos(rad)) * 44))
                    ctx.stroke(line, with: .color(Self.brassDark.opacity(0.8)), lineWidth: 0.5)
                }

                // Pivot boss
                let boss = Path(ellipseIn: CGRect(x: cx - 4, y: cy - 4, width: 8, height: 8))
                ctx.stroke(boss, with: .color(Self.brass), lineWidth: 0.8)
                let pin = Path(ellipseIn: CGRect(x: cx - 1.2, y: cy - 1.2, width: 2.4, height: 2.4))
                ctx.fill(pin, with: .color(Self.brassBright))
            }
            .frame(width: 200, height: 200)

            // [§B5] Degree numbers every 30° (was every 10° — aligned to the new 15° notches + far more
            // readable), set radially like a real bezel.
            ForEach(0..<12, id: \.self) { i in
                let deg = i * 30
                let rad = Double(deg) * .pi / 180
                Text("\(deg)")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(deg % 90 == 0 ? Self.brassBright : Self.brass.opacity(0.85))
                    .rotationEffect(.degrees(Double(deg)))
                    .offset(x: CGFloat(sin(rad)) * 73, y: -CGFloat(cos(rad)) * 73)
            }

            // Cardinal letters — large and clear
            ForEach(0..<4, id: \.self) { i in
                let rad = Double(i) * 90 * .pi / 180
                Text(cardinals[i])
                    .font(.system(size: 14, weight: .bold, design: .serif))
                    .foregroundColor(i == 0 ? Self.brassBright : Self.brass)
                    .offset(x: CGFloat(sin(rad)) * 54, y: -CGFloat(cos(rad)) * 54)
            }

            // Intercardinal letters
            ForEach(0..<4, id: \.self) { i in
                let rad = (45.0 + Double(i) * 90) * .pi / 180
                Text(intercardinals[i])
                    .font(.system(size: 9, weight: .semibold, design: .serif))
                    .foregroundColor(Self.brass.opacity(0.9))
                    .offset(x: CGFloat(sin(rad)) * 54, y: -CGFloat(cos(rad)) * 54)
            }

            // Fine inner detail ring
            Circle()
                .stroke(style: StrokeStyle(lineWidth: 0.5, dash: [1.5, 2]))
                .foregroundColor(Self.brassDim.opacity(0.8))
                .frame(width: 128, height: 128)
        }
    }
}

// MARK: - Aurora face

// Polar expedition compass — the aurora bands stay, now set into a real
// instrument: fine ticks, teal cardinals, and layered ring depth.
struct AuroraFaceView: View {
    let locked: Bool
    let quietMode: Bool
    let pingRingActive: Bool

    private static let teal     = Color(hex: "#5dcaa5")
    private static let tealDeep = Color(hex: "#2f8e6f")
    private static let tealDim  = Color(hex: "#1d5c47")

    private let cardinals = ["N", "E", "S", "W"]

    private let bandColors: [Color] = [
        Color(hex: "#5dcaa5").opacity(0.12),
        Color(hex: "#7c6b8e").opacity(0.18),
        Color(hex: "#c4a8d4").opacity(0.10),
        Color(hex: "#5dcaa5").opacity(0.08),
    ]

    var body: some View {
        ZStack {
            // Layered double border for depth
            Circle()
                .stroke(locked ? Self.teal.opacity(0.7) : Self.teal.opacity(0.35),
                        lineWidth: locked ? 1.2 : 0.9)
                .frame(width: 200, height: 200)
                .animation(.easeInOut(duration: 0.4), value: locked)
            Circle()
                .stroke(Self.tealDeep.opacity(0.35), lineWidth: 0.5)
                .frame(width: 193, height: 193)
            Circle()
                .stroke(Self.tealDim.opacity(0.5), lineWidth: 0.4)
                .frame(width: 186, height: 186)

            // Fine tick marks between the border and the aurora bands
            Canvas { ctx, size in
                let cx = size.width / 2, cy = size.height / 2
                let tickOuter: CGFloat = 96
                for deg in stride(from: 0, to: 360, by: 5) {
                    let rad  = Double(deg) * .pi / 180
                    let is90 = deg % 90 == 0
                    let is15 = deg % 15 == 0
                    let len: CGFloat = is90 ? 8 : is15 ? 5.5 : 3
                    let sw:  CGFloat = is90 ? 1.0 : is15 ? 0.6 : 0.35
                    let col = is90 ? Self.teal
                                   : is15 ? Self.tealDeep.opacity(0.8)
                                          : Self.tealDim.opacity(0.8)
                    var path = Path()
                    path.move(to: CGPoint(x: cx + CGFloat(sin(rad)) * tickOuter,
                                          y: cy - CGFloat(cos(rad)) * tickOuter))
                    path.addLine(to: CGPoint(x: cx + CGFloat(sin(rad)) * (tickOuter - len),
                                             y: cy - CGFloat(cos(rad)) * (tickOuter - len)))
                    ctx.stroke(path, with: .color(col), lineWidth: sw)
                }
            }
            .frame(width: 200, height: 200)

            // The aurora bands — kept, now framed by the instrument
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

            // Cardinals in teal/green tones
            ForEach(0..<4, id: \.self) { i in
                let rad = Double(i) * 90 * .pi / 180
                Text(cardinals[i])
                    .font(.system(size: 12, weight: i == 0 ? .semibold : .regular, design: .rounded))
                    .foregroundColor(i == 0 ? Self.teal : Self.tealDeep)
                    .offset(x: CGFloat(sin(rad)) * 74, y: -CGFloat(cos(rad)) * 74)
            }

            // Inner hairline ring for layered depth
            Circle()
                .stroke(Self.tealDim.opacity(0.45), lineWidth: 0.4)
                .frame(width: 64, height: 64)
        }
    }
}

