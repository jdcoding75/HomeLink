// BowInstrumentView.swift
// Pointward › Views
//
// INSTRUMENT 2 — BOW & ARROW (Pro). The middle zone becomes a living bow.
// [1/7] AIMING IS BY FINGER-SPIN — no phone movement, ever. The fix that
// finally works: ONE DragGesture, classified by where the finger lands. Drag
// on the outer RING (a visible track with a handle) to spin the bow toward
// the person; drag from the CENTER to pull the string. The old two-finger
// RotationGesture was unreliable and fought the draw gesture — gone.
// Spin the bow toward the person (their initial marker rides the ring):
// within 30° the arrow warms amber, within 15° it's bright gold and "draw to
// send" appears, within 5° it locks with a strong haptic and tip sparkles.

import SwiftUI
import Combine

struct BowInstrumentView: View {

    /// The loaded thought (nil = nothing nocked yet).
    let loadedToken: String?
    let loadedSymbol: AnyView?
    /// The person's real-world bearing — only used to place their marker and
    /// to know which way to spin the bow. The aim itself is the finger-spin.
    let bearingDegrees: Double
    let personName: String
    var personEmoji: String = "💜"
    /// Fires when a valid aligned release happens.
    let onSend: () -> Void

    // [1/7] FINGER-SPIN aim — the bow's facing direction in degrees (0 = up).
    // One DragGesture drives BOTH actions, classified by where the finger
    // lands: out on the rim → SPIN (rotate the bow by the finger's angle),
    // near the center → DRAW (pull the string). This replaced the unreliable
    // two-finger RotationGesture, which fought the draw gesture and rarely
    // fired. See `bowGesture`.
    @State private var spinAngle: Double = 0
    @State private var lockHapticFired = false      // strong tap once at 5°
    private enum BowGestureMode { case spin, draw }
    @State private var gestureMode: BowGestureMode? = nil
    @State private var lastFingerAngle: Double = 0  // for incremental spin
    /// Spin happens when the touch starts beyond this radius from center.
    private let spinRingInner: CGFloat = 118

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

    /// The bow faces the FINGER-SPUN angle ONLY — never the phone heading.
    private var rad: Double { spinAngle * .pi / 180 }
    /// [1/5] The aim target is FROZEN the moment a thought is nocked, so
    /// turning the phone afterwards never moves it — the bow is aimed purely
    /// by finger-spin. While nothing is loaded it tracks the live bearing so
    /// the marker shows where the person currently is.
    @State private var aimTarget: Double = 0
    /// How far the bow's facing is from the (frozen) aim target — wrap-safe.
    private var alignDiff: Double {
        BearingCalculator.alignmentError(relativeBearing: spinAngle - aimTarget)
    }
    private var aligned: Bool {
        BearingCalculator.isSendAligned(spinAngle - aimTarget)
    }

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

            // ── Where they are — the person-initial marker rides the ring at
            // their bearing; it brightens as the FINGER-SPIN aim closes in
            // (approachError = the bow-vs-person angle, not the phone). ──
            DirectionIndicator(bearingDegrees: aimTarget,
                               personName: personName,
                               personEmoji: personEmoji,
                               ringRadius: 172,
                               showHint: false,
                               approachError: alignDiff)

            // ── [1/7] SPIN RING — the affordance for aiming. A faint dashed
            // track with a grab handle at the bow's current facing; drag the
            // handle (or anywhere on the rim) around to spin the bow. ──
            if loadedToken != nil {
                ZStack {
                    Circle()
                        .stroke(Self.lavender.opacity(0.18),
                                style: StrokeStyle(lineWidth: 1.5, dash: [3, 6]))
                        .frame(width: 316, height: 316)
                    // The grab handle, riding the rim at the bow's facing angle
                    ZStack {
                        Circle()
                            .fill(Self.lavender.opacity(aimBand >= 2 ? 0.95 : 0.7))
                            .frame(width: 16, height: 16)
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(DesignTokens.Color.background)
                    }
                    .scaleEffect(aimPulse ? 1.12 : 1.0)
                    .shadow(color: Self.lavender.opacity(0.6), radius: 5)
                    .offset(x: CGFloat(sin(rad)) * 158, y: -CGFloat(cos(rad)) * 158)
                }
                .allowsHitTesting(false)   // the gesture lives on the whole frame
                .transition(.opacity)
            }

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

            // [4/7] In-instrument progressive instruction REMOVED — the single
            // instruction lives only at the bottom of the compass screen
            // (sendControl). "perfect aim ✦" above is a transient cue, kept.
        }
        .frame(width: 370, height: 370)
        .contentShape(Circle())
        // [1/7] ONE reliable gesture: drag on the rim to spin/aim, drag from
        // the center to draw the string. No phone movement, no two-finger
        // twist — a single finger does everything.
        .gesture(bowGesture)
        // [1/5] Keep the aim target tracking the live bearing UNTIL a thought
        // is nocked; once armed it freezes, so the phone heading can't move it.
        .onChange(of: bearingDegrees) { _, newValue in
            if loadedToken == nil { aimTarget = newValue }
        }
        .onChange(of: loadedToken) { _, token in
            if token == nil { aimTarget = bearingDegrees }   // re-arm: re-sync
        }
        .onAppear {
            aimTarget = bearingDegrees
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

    // ── [1/7] ONE gesture, classified by where the finger lands ────────────
    // The instrument frame is 370×370 so its center is (185, 185).

    /// Finger angle around the center, in degrees, 0° = up, clockwise.
    private func angleFromCenter(_ p: CGPoint) -> Double {
        let dx = Double(p.x - 185), dy = Double(p.y - 185)
        return atan2(dx, -dy) * 180 / .pi
    }

    private var bowGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                guard loadedToken != nil else { return }

                // Classify on the first move: rim → spin, center → draw.
                if gestureMode == nil {
                    let r = hypot(value.startLocation.x - 185,
                                  value.startLocation.y - 185)
                    gestureMode = r > spinRingInner ? .spin : .draw
                    if gestureMode == .spin {
                        lastFingerAngle = angleFromCenter(value.startLocation)
                    } else {
                        dragging = true
                    }
                }

                if gestureMode == .spin {
                    handleSpin(to: value.location)
                } else {
                    handleDraw(translation: value.translation)
                }
            }
            .onEnded { value in
                if gestureMode == .draw { endDraw() }
                gestureMode = nil
            }
    }

    /// SPIN — rotate the bow by the incremental change in the finger's angle
    /// around the center. Incremental (not absolute) so it never jumps on wrap.
    private func handleSpin(to location: CGPoint) {
        let cur = angleFromCenter(location)
        var delta = cur - lastFingerAngle
        while delta >  180 { delta -= 360 }
        while delta < -180 { delta += 360 }
        lastFingerAngle = cur
        spinAngle += delta
        // Strong satisfying haptic the moment it locks at 5°
        if aimBand == 3, !lockHapticFired {
            lockHapticFired = true
            HapticEngine.lockOn()
        }
        if aimBand < 3 { lockHapticFired = false }
    }

    /// DRAW — pull the string back, opposite the bow's facing direction.
    private func handleDraw(translation: CGSize) {
        dragging = true
        let opposite = CGSize(width: -CGFloat(sin(rad)), height: CGFloat(cos(rad)))
        let along = translation.width * opposite.width
                  + translation.height * opposite.height

        // DRAW RESTRICTION — off-target the string is resistant.
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
        // [5/5] BOW — tension building: pulses strengthen and quicken as the
        // string draws back.
        HapticEngine.bowDraw(newAmount)
        if newAmount >= 0.6 && !halfDrawHapticFired {
            halfDrawHapticFired = true
        }
        if newAmount >= 0.97 && !fullDrawHapticFired {
            fullDrawHapticFired = true
        }
        if newAmount < 0.5 { halfDrawHapticFired = false }
        if newAmount < 0.9 { fullDrawHapticFired = false }
        withAnimation(.interactiveSpring()) { drawAmount = newAmount }
    }

    private func endDraw() {
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
            HapticEngine.bowRelease()       // [5/5] sharp snap as it fires
            withAnimation(.easeOut(duration: 0.05)) { drawAmount = 0 }
            onSend()
        } else {
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
