// BowInstrumentView.swift
// Pointward › Views
//
// INSTRUMENT 2 — BOW & ARROW (Pro). The middle zone becomes a living bow:
// the arrow tracks the person's bearing, the user loads an emoji, draws
// the string back with a real drag, and releases. Aimed within 15° the
// arrow flies; off-target it bounces home.

import SwiftUI

struct BowInstrumentView: View {

    /// The loaded thought (nil = nothing nocked yet).
    let loadedToken: String?
    let loadedSymbol: AnyView?
    let bearingDegrees: Double
    let personName: String
    /// Fires when a valid aligned release happens.
    let onSend: () -> Void

    @State private var breathe = false
    @State private var drawAmount: CGFloat = 0      // 0…1
    @State private var dragging = false
    @State private var bounceBack = false
    @State private var showMissHint = false
    @State private var halfDrawHapticFired = false
    @State private var fullDrawHapticFired = false

    private static let tint   = Color(hex: "#ece4f5")
    private static let gold   = Color(hex: "#D4A017")
    private static let orange = Color(hex: "#e08a3c")
    private static let lavender = Color(hex: "#c4a8d4")

    private var rad: Double { bearingDegrees * .pi / 180 }
    private var alignDiff: Double { min(bearingDegrees, 360 - bearingDegrees) }
    private var aligned: Bool { alignDiff <= 15 }

    var body: some View {
        ZStack {
            // Tension dims the world as the string comes back
            Color.black.opacity(Double(drawAmount) * 0.05)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // ── The bow — fills the circle, aimed at them, breathing ──
            ZStack {
                BowArchShape(tension: drawAmount * 14)
                    .stroke(Self.tint.opacity(0.85),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round))
                BowStringShape(pull: drawAmount * 84)   // 25 % of the bow width
                    .stroke(Self.tint.opacity(0.85), lineWidth: 2)
            }
            .frame(width: 333, height: 333)
            .shadow(color: .black.opacity(0.15), radius: 12)
            .rotationEffect(.radians(rad))
            .scaleEffect(breathe ? 1.02 : 0.98)

            // ── Trajectory — dotted arc showing where the arrow goes ──
            if dragging && drawAmount > 0.08 {
                TrajectoryArcShape(rad: rad)
                    .stroke(aligned ? Self.lavender.opacity(0.7)
                                    : Self.orange.opacity(0.7),
                            style: StrokeStyle(lineWidth: 2, dash: [4, 7]))
                    .frame(width: 333, height: 333)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            // ── The arrow — nocked at center, drawn back with the string ──
            ZStack {
                ArrowShape()
                    .fill(Self.gold.opacity(loadedToken == nil ? 0.85 : 0.55))
                    .frame(width: 13, height: 58)
                    .offset(y: 8)
                if let loadedSymbol {
                    loadedSymbol
                        .scaleEffect(x: 1.0, y: 1.0 + drawAmount * 0.4)   // elongates
                        .shadow(color: Self.gold.opacity(0.5 + Double(drawAmount) * 0.4),
                                radius: 8 + drawAmount * 8)
                }
            }
            .rotationEffect(.radians(rad))
            .offset(x: CGFloat(sin(rad)) * -drawAmount * 84,
                    y: CGFloat(cos(rad)) * drawAmount * 84)
            .modifier(BounceBackEffect(active: bounceBack))

            // ── Instructions ──
            VStack {
                Spacer()
                if showMissHint {
                    Text("aim toward \(personName)")
                        .font(.system(size: 12, design: .serif).italic())
                        .foregroundColor(Self.orange)
                        .transition(.opacity)
                } else if loadedToken != nil {
                    Text(drawAmount >= 0.97 ? "release to send"
                         : dragging ? "" : "draw the string back")
                        .font(.system(size: 12, design: .serif).italic())
                        .foregroundColor(Self.lavender.opacity(0.85))
                        .transition(.opacity)
                }
            }
            .padding(.bottom, 2)
            .allowsHitTesting(false)
        }
        .frame(width: 370, height: 370)
        .contentShape(Circle())
        .gesture(drawGesture)
        .onAppear {
            withAnimation(AnimationSystem.easeInOutSine(3.0)
                            .repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
        .animation(.easeOut(duration: 0.25), value: showMissHint)
    }

    // ── The draw: drag away from the person to pull the string ──

    private var drawGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard loadedToken != nil else { return }
                dragging = true
                // Component of the drag opposite the bearing direction
                let opposite = CGSize(width: -CGFloat(sin(rad)), height: CGFloat(cos(rad)))
                let along = value.translation.width * opposite.width
                          + value.translation.height * opposite.height
                let newAmount = max(0, min(1, along / 120))
                // Haptic milestones
                if newAmount >= 0.6 && !halfDrawHapticFired {
                    halfDrawHapticFired = true
                    HapticEngine.sendSoft()
                }
                if newAmount >= 0.97 && !fullDrawHapticFired {
                    fullDrawHapticFired = true
                    HapticEngine.send()
                }
                if newAmount < 0.5 { halfDrawHapticFired = false }
                if newAmount < 0.9 { fullDrawHapticFired = false }
                withAnimation(.interactiveSpring()) { drawAmount = newAmount }
            }
            .onEnded { _ in
                dragging = false
                defer {
                    halfDrawHapticFired = false
                    fullDrawHapticFired = false
                }
                guard loadedToken != nil, drawAmount > 0.35 else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                        drawAmount = 0
                    }
                    return
                }
                if aligned {
                    // String snaps — the instrument's own quick feedback;
                    // the full flight is the bowArrow sender animation.
                    withAnimation(.easeOut(duration: 0.05)) { drawAmount = 0 }
                    onSend()
                } else {
                    // MISS: the arrow thuds home, hint appears
                    HapticEngine.sendSoft()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.45)) {
                        drawAmount = 0
                        bounceBack = true
                    }
                    showMissHint = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        bounceBack = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                        withAnimation { showMissHint = false }
                    }
                }
            }
    }
}

/// A short dotted arc ahead of the arrow — where the shot will travel.
struct TrajectoryArcShape: Shape {
    let rad: Double

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let dir  = CGPoint(x: sin(rad), y: -cos(rad))
        let perp = CGPoint(x: cos(rad), y: sin(rad))
        p.move(to: c)
        p.addQuadCurve(
            to: CGPoint(x: c.x + dir.x * rect.width * 0.52,
                        y: c.y + dir.y * rect.height * 0.52),
            control: CGPoint(x: c.x + dir.x * rect.width * 0.26 + perp.x * 22,
                             y: c.y + dir.y * rect.height * 0.26 + perp.y * 22)
        )
        return p
    }
}

/// A comic little overshoot wobble for missed shots.
struct BounceBackEffect: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(active ? 4 : 0))
            .animation(active
                       ? .spring(response: 0.18, dampingFraction: 0.25)
                       : .easeOut(duration: 0.2),
                       value: active)
    }
}
