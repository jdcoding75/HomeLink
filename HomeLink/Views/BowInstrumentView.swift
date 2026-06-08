// BowInstrumentView.swift
// Pointward › Views
//
// INSTRUMENT 2 — BOW & ARROW (Pro). The middle zone becomes a living bow:
// the arrow tracks the person's bearing, the user loads an emoji, draws
// the string back with a real drag, and releases. Aimed within 15° the
// arrow flies; off-target it bounces home.

import SwiftUI
import Combine

struct BowInstrumentView: View {

    /// The loaded thought (nil = nothing nocked yet).
    let loadedToken: String?
    let loadedSymbol: AnyView?
    let bearingDegrees: Double
    let personName: String
    var personEmoji: String = "💜"
    /// Fires when a valid aligned release happens.
    let onSend: () -> Void

    @State private var breathe = false
    @State private var drawAmount: CGFloat = 0      // 0…1
    @State private var dragging = false
    @State private var bounceBack = false
    @State private var showMissHint = false
    @State private var showAimFirstHint = false     // tried to draw off-target
    @State private var showPerfectAim = false       // "perfect aim ✦", brief
    @State private var perfectConfirmed = false     // strong haptic, once per entry
    @State private var aimPulse = false             // within-5° bright pulsing
    @State private var halfDrawHapticFired = false
    @State private var fullDrawHapticFired = false

    /// Aim haptics ride the shared alignment bands (2 s / 1 s / 0.5 s).
    private let aimTick = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    private static let tint   = Color(hex: "#ece4f5")
    private static let gold   = Color(hex: "#D4A017")
    private static let orange = Color(hex: "#e08a3c")
    private static let lavender = Color(hex: "#c4a8d4")
    private static let slackGrey = Color(hex: "#8a8694")

    private var rad: Double { bearingDegrees * .pi / 180 }
    private var alignDiff: Double { BearingCalculator.alignmentError(relativeBearing: bearingDegrees) }
    private var aligned: Bool { BearingCalculator.isSendAligned(bearingDegrees) }

    /// Progressive aim bands: 0 outside 30° · 1 within 30° · 2 within 15° ·
    /// 3 within 5°. Everything — string, arrow, haptics — keys off this.
    private var aimBand: Int {
        switch alignDiff {
        case ..<5:   return 3
        case ..<15:  return 2
        case ..<30:  return 1
        default:     return 0
        }
    }

    /// String: dim and slack → slightly brighter → bright and taut.
    private var stringBrightness: Double {
        switch aimBand {
        case 3:  return aimPulse ? 1.0 : 0.9
        case 2:  return 0.95
        case 1:  return 0.6
        default: return 0.35
        }
    }

    /// Arrow glow strength rides the aim bands (the wood/steel colors stay).
    private var arrowGlow: Double {
        switch aimBand {
        case 3:  return aimPulse ? 0.9 : 0.7
        case 2:  return 0.6
        case 1:  return 0.3
        default: return 0.0
        }
    }

    // (previous band-tinted string/arrow colors superseded by the
    //  handcrafted wood + steel palette; see stringBrightness/arrowGlow)

    var body: some View {
        ZStack {
            // Tension dims the world as the string comes back
            Color.black.opacity(Double(drawAmount) * 0.05)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // ── Where they are — marker + alignment arc (hints are ours) ──
            DirectionIndicator(bearingDegrees: bearingDegrees,
                               personName: personName,
                               personEmoji: personEmoji,
                               ringRadius: 172,
                               showHint: false)

            // ── The bow — a real handcrafted traditional bow: warm wood
            // grain limbs (dark at the tips, chestnut at the grip), a taut
            // off-white string. Aim feedback rides on top: dim and slack
            // off-target, glowing at the edges within 15°. ──
            ZStack {
                // Wood limbs — gradient tips → center → tips
                BowArchShape(tension: drawAmount * 14)
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: Color(hex: "#4A2208"), location: 0.0),
                                .init(color: Color(hex: "#D2691E"), location: 0.5),
                                .init(color: Color(hex: "#4A2208"), location: 1.0),
                            ],
                            startPoint: .leading, endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .opacity(aimBand >= 2 ? 1.0 : 0.8)
                // Wood grain — overlapping slimmer passes, slightly offset,
                // darker and lighter threads running along the limb
                BowArchShape(tension: drawAmount * 14)
                    .stroke(Color(hex: "#8B4513").opacity(0.45),
                            style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    .offset(y: -1)
                BowArchShape(tension: drawAmount * 14)
                    .stroke(Color(hex: "#4A2208").opacity(0.30),
                            style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
                    .offset(y: 1.2)
                BowArchShape(tension: drawAmount * 14)
                    .stroke(Color(hex: "#E8A664").opacity(0.18),
                            style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
                    .offset(y: -0.4)

                // The string — off-white, taut, softly luminous
                BowStringShape(pull: drawAmount * 84)   // 25 % of the bow width
                    .stroke(Color(hex: "#F5F0E8").opacity(stringBrightness),
                            lineWidth: 1.5)
                    .shadow(color: .white.opacity(0.10), radius: 8)
                    .shadow(color: Self.lavender.opacity(aimBand >= 2 ? 0.6 : 0),
                            radius: 6)   // ready-glow within 15°
            }
            .frame(width: 333, height: 333)
            .shadow(color: .black.opacity(0.20), radius: 8)   // soft, grounded
            .rotationEffect(.radians(rad))
            .scaleEffect(breathe ? 1.02 : 0.98)
            .animation(AnimationSystem.easeInOutSine(0.3), value: aimBand)

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

            // ── The arrow — a real one: wood shaft darkening toward the
            // nock, steel head, three feather fletches, silver nock.
            // Glow strength rides the aim bands; sparkles inside 5°. ──
            ZStack {
                TraditionalArrowView()
                    .opacity(loadedToken == nil ? 1.0 : 0.7)
                    .offset(y: 8)
                    .shadow(color: Self.gold.opacity(arrowGlow * 0.6), radius: 8)
                if let loadedSymbol {
                    loadedSymbol
                        .scaleEffect(x: 1.0, y: 1.0 + drawAmount * 0.4)   // elongates
                        .shadow(color: Self.gold.opacity(0.5 + Double(drawAmount) * 0.4),
                                radius: 8 + drawAmount * 8)
                }

                // Tip sparkles — within 5° only
                if aimBand == 3 {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(i == 1 ? Color(hex: "#FFD700") : .white)
                            .frame(width: i == 1 ? 3 : 2.5, height: i == 1 ? 3 : 2.5)
                            .offset(x: CGFloat(i - 1) * 7,
                                    y: -26 - CGFloat((i * 5) % 7))
                            .opacity(aimPulse ? 0.95 : 0.35)
                            .transition(.opacity)
                    }
                }
            }
            .rotationEffect(.radians(rad))
            .offset(x: CGFloat(sin(rad)) * -drawAmount * 84,
                    y: CGFloat(cos(rad)) * drawAmount * 84)
            .modifier(BounceBackEffect(active: bounceBack))
            .animation(AnimationSystem.easeInOutSine(0.3), value: aimBand)

            // ── "perfect aim ✦" — brief, inside 5° ──
            if showPerfectAim {
                Text("perfect aim ✦")
                    .font(.system(size: 14, design: .serif).italic())
                    .foregroundColor(Color(hex: "#FFD700"))
                    .shadow(color: Color(hex: "#FFD700").opacity(0.7), radius: 8)
                    .offset(y: -120)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }

            // ── Instructions — progressive with aim ──
            VStack {
                Spacer()
                if showAimFirstHint {
                    Text("aim toward \(personName) first")
                        .font(.system(size: 12, design: .serif).italic())
                        .foregroundColor(Self.orange)
                        .transition(.opacity)
                } else if showMissHint {
                    Text("aim toward \(personName)")
                        .font(.system(size: 12, design: .serif).italic())
                        .foregroundColor(Self.orange)
                        .transition(.opacity)
                } else if loadedToken != nil {
                    Text(drawAmount >= 0.97 ? "release to send"
                         : dragging ? ""
                         : aimBand >= 2 ? "ready · draw to send"
                         : "aim toward \(personName)")
                        .font(.system(size: 12, design: .serif).italic())
                        .foregroundColor(aimBand >= 2 ? Self.lavender.opacity(0.95)
                                                      : Self.lavender.opacity(0.65))
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
            withAnimation(AnimationSystem.easeInOutSine(0.6)
                            .repeatForever(autoreverses: true)) {
                aimPulse = true
            }
        }
        // Aim haptics — pulses quicken as the aim tightens (shared bands:
        // 2 s very subtle within 30°, 1 s soft within 15°), plus a strong
        // confirmation + brief "perfect aim ✦" entering 5°.
        .onReceive(aimTick) { _ in
            guard loadedToken != nil else { return }
            HapticEngine.catchAlignment(angleError: alignDiff)
            if aimBand == 3 && !perfectConfirmed {
                perfectConfirmed = true
                HapticEngine.lockOn()
                withAnimation { showPerfectAim = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation { showPerfectAim = false }
                }
            } else if aimBand < 3 && perfectConfirmed {
                perfectConfirmed = false
            }
        }
        .animation(.easeOut(duration: 0.25), value: showMissHint)
        .animation(.easeOut(duration: 0.25), value: showAimFirstHint)
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

                // DRAW RESTRICTION — off-target the string is resistant:
                // it barely budges, and pulling shows the aim-first hint.
                guard aimBand >= 2 else {
                    withAnimation(.interactiveSpring()) {
                        drawAmount = max(0, min(0.04, along / 700))
                    }
                    if along > 30 && !showAimFirstHint {
                        showAimFirstHint = true
                        HapticEngine.sendSoft()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation { showAimFirstHint = false }
                        }
                    }
                    return
                }

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

// MARK: - TraditionalArrowView

/// A real arrow, drawn small: wood shaft (darker toward the nock), a steel
/// triangular head, three feather marks near the tail, a silver nock.
/// Elegant and handcrafted — never cartoon.
struct TraditionalArrowView: View {

    var body: some View {
        ZStack {
            // Shaft — warm wood, sliding darker toward the nock end
            Capsule()
                .fill(
                    LinearGradient(colors: [Color(hex: "#A0522D"),
                                            Color(hex: "#6E3A1E")],
                                   startPoint: .top, endPoint: .bottom)
                )
                .frame(width: 3.5, height: 50)

            // Steel head — a small clean triangle at the tip
            Triangle()
                .fill(
                    LinearGradient(colors: [Color(hex: "#E8E8E8"),
                                            Color(hex: "#C0C0C0")],
                                   startPoint: .top, endPoint: .bottom)
                )
                .frame(width: 10, height: 13)
                .offset(y: -29)

            // Fletching — three feather marks near the nock
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(Color(hex: "#2a2a2a").opacity(0.6))
                    .frame(width: 6.5, height: 1.8)
                    .rotationEffect(.degrees(-32))
                    .offset(x: 3.5, y: 13 + CGFloat(i) * 4.5)
            }

            // Nock — a tiny silver ring at the tail
            Circle()
                .stroke(Color(hex: "#C0C0C0"), lineWidth: 1)
                .frame(width: 3.5, height: 3.5)
                .offset(y: 26.5)
        }
        .frame(width: 13, height: 58)
    }
}
