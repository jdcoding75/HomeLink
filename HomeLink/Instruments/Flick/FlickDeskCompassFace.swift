// FlickDeskCompassFace.swift
// Pointward › Instruments › Flick
//
// ACT 1 of 3 — the FLICK V2 (DESK) compass face.
//
// THE LIVE MECHANIC (autoPlay == false) is the ORIGINAL, restored flick:
//   the desk shows ONLY inside the compass ring (radial oak), the deep-purple
//   app background stays outside; a CRUMPLED PAPER BALL rests at centre with a
//   👆 finger hint. A TARGET POINT sits on the compass ring edge (the
//   destination marker). The user simply FLICKS the paper ball toward that
//   point — a quick swipe toward the target launches it. Aim is FORGIVING: a
//   generous ±45° tolerance cone around the target means flicking in its general
//   direction counts (no compass-alignment / heading mechanic — just the flick
//   direction vs. the frozen target). A weak flick, or one aimed well away,
//   bounces home; a real flick toward the point sends.
//
//   The target point is FROZEN on appear (a fixed point on the ring), so it
//   never tracks the live compass heading — flicking, not aligning, is the act.
//
// THE TEST-LAB BEAT (autoPlay == true) is a single watchable rest→action beat:
//   the finger slides up, winds back, SNAPS the ball toward the target point,
//   paper-dust bursts, the flick sound plays, then it hands off (onSend).
//
// Shared components (one source of truth): FlickDeskFaceFill + CrumpledPaperBall
// (FlickDeskWorld.swift) and DirectionIndicator (the target point). The ring is
// the standard instrument look: lavender, ticks every 30°, dashed inner ring.

import SwiftUI

struct FlickDeskCompassFace: View {

    var personName: String = "them"
    var emoji: String = "💜"
    /// Used ONCE on appear to place the FROZEN target point on the ring. After
    /// that the live heading is ignored — the flick direction is checked against
    /// the FROZEN target (a generous ±45° cone), never the live compass heading.
    var bearingDegrees: Double = 45
    var onSend: () -> Void = {}
    /// true = the test-lab beat that auto-plays once on appear. false = the LIVE
    /// compass face: it rests until the paper ball is FLICKED, sends, then
    /// re-arms for the next flick (so it is reusable).
    var autoPlay: Bool = true

    // Test-lab beat state
    @State private var fingerLift: CGFloat = 0   // 0 rest → 1 up at the ball
    @State private var windBack: CGFloat = 0     // 0 → 1 wound back (ball tilt ~3°)
    @State private var snap: CGFloat = 0         // 0 → 1 snap forward
    @State private var fingerGone = false
    @State private var didRun = false

    // Shared flight + live-flick state
    @State private var ballFlight: CGFloat = 0   // 0 centre → 1 launched at target
    @State private var dustBurst = false
    /// The frozen destination on the ring (degrees, 0 = up, clockwise). Set once
    /// on appear; never updated from the live heading. The flick's ±45° tolerance
    /// cone is measured against THIS frozen target — not the live compass heading.
    @State private var targetAngle: Double = 45
    @State private var dragOffset: CGSize = .zero
    @State private var dragging = false
    @State private var interacted = false        // hides the finger hint
    @State private var hintPhase = false         // looping demo finger
    @State private var launching = false         // a live flick is in flight
    @State private var showWeakHint = false      // "flick a little harder"

    private static let lavender = Color(hex: "#c4a8d4")
    private static let faceD: CGFloat = 330       // desk circle diameter
    private static let ringRadius: CGFloat = 165
    private static let topCrop: CGFloat = 0.25    // [tweak] crop the top 25% of the desk

    /// A real flick must move at least this fast (points/sec) to count as a launch.
    private let minFlickSpeed: CGFloat = 280

    /// [tolerance cone 2026-06-13] A GENEROUS ±45° cone around the target point.
    /// The flick only has to head in the general direction of the target — it
    /// should feel forgiving and fun, never precise. (Restores the aim cone the
    /// original flick had, which had been lost when the gesture went speed-only.)
    private static let aimTolerance: Double = 45

    private var targetRad: Double { targetAngle * .pi / 180 }

    var body: some View {
        ZStack {
            Color(hex: "#0d0d14").ignoresSafeArea()   // deep purple OUTSIDE the ring
            cluster
            labels
        }
        .contentShape(Rectangle())
        // Test lab: tap replays the beat. Live: the ball's own flick gesture is
        // the mechanic, so a face tap does nothing.
        .onTapGesture { if autoPlay { didRun = false; runOnce() } }
        .onAppear {
            targetAngle = bearingDegrees           // freeze the destination point
            if autoPlay {
                runOnce()
            } else {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    hintPhase = true
                }
            }
        }
    }

    // ── The compass cluster (desk circle + ring + target point + ball/finger) ──

    private var cluster: some View {
        ZStack {
            // [tweak] The warm-oak desk fills only the LOWER ~75% of the circle.
            ZStack {
                FlickDeskFaceFill()
                    .frame(width: Self.faceD, height: Self.faceD)
                horizonLine
            }
            .frame(width: Self.faceD, height: Self.faceD)
            .clipShape(DeskCropShape(topCrop: Self.topCrop))
            .overlay(DeskCropShape(topCrop: Self.topCrop)
                .stroke(Color(hex: "#6a3e1e").opacity(0.6), lineWidth: 3))
            .shadow(color: .black.opacity(0.35), radius: 10)

            ringDecor
            // The TARGET POINT on the ring edge — the destination the ball is
            // flicked toward. Placed at the FROZEN targetAngle (not live heading).
            DirectionIndicator(bearingDegrees: targetAngle, personName: personName,
                               personEmoji: emoji, ringRadius: Self.ringRadius,
                               showHint: false)
            targetGlow
            dust
            ballAndFinger
        }
        .frame(width: 370, height: 370)
    }

    /// [tweak] The bright desk back-edge line along the horizontal crop.
    private var horizonLine: some View {
        let r = Self.faceD / 2
        let off = r - Self.faceD * Self.topCrop
        let half = (r * r - off * off).squareRoot()
        return Rectangle()
            .fill(FlickDeskPalette.deskEdge.opacity(0.85))
            .frame(width: half * 2, height: 2)
            .offset(y: -off)
    }

    /// Lavender ring · ticks every 30° · dashed inner ring.
    private var ringDecor: some View {
        ZStack {
            Circle()
                .stroke(Self.lavender.opacity(0.5), lineWidth: 1.5)
                .frame(width: Self.faceD, height: Self.faceD)
            ForEach(0..<12, id: \.self) { i in
                Capsule()
                    .fill(Self.lavender.opacity(0.55))
                    .frame(width: 2, height: 9)
                    .offset(y: -Self.ringRadius)
                    .rotationEffect(.degrees(Double(i) * 30))
            }
            Circle()
                .stroke(Self.lavender.opacity(0.3),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
                .frame(width: 250, height: 250)
        }
    }

    /// A soft pulsing halo on the ring at the target point — reads as "flick to
    /// here". Calm in the live face; absent during the launch/test beat.
    @ViewBuilder
    private var targetGlow: some View {
        if !autoPlay && !launching {
            Circle()
                .fill(Self.lavender.opacity(0.18))
                .frame(width: 30, height: 30)
                .scaleEffect(hintPhase ? 1.25 : 0.9)
                .offset(x: CGFloat(sin(targetRad)) * Self.ringRadius,
                        y: -CGFloat(cos(targetRad)) * Self.ringRadius)
                .allowsHitTesting(false)
        }
    }

    // ── The ball + finger ────────────────────────────────────────────────────

    private var ballAndFinger: some View {
        // Flight travels from centre out to the target point along targetAngle.
        let reach: CGFloat = ballFlight * 178
        let flightX: CGFloat = CGFloat(sin(targetRad)) * reach
        let flightY: CGFloat = -CGFloat(cos(targetRad)) * reach
        let ballTilt: Double = Double(windBack) * -3 + Double(ballFlight) * 240
        let ballFade: Double = 1 - Double(max(0, ballFlight - 0.6) / 0.4)

        // While the finger is dragging the ball back, the ball follows it; once
        // launched (or in the test beat) it rides the flight path.
        let useDrag = dragging || dragOffset != .zero
        let ballX = useDrag ? dragOffset.width : flightX
        let ballY = useDrag ? dragOffset.height : flightY

        // Test-lab finger path: rest below → lifts → winds back → snaps → retracts.
        let baseY: CGFloat = 60
        let beatFingerY: CGFloat = baseY - fingerLift * 42 + windBack * 12 - snap * 24
        let beatFingerX: CGFloat = snap * 18
        let beatFingerRot: Double = -10 + Double(windBack) * 9 - Double(snap) * 18

        return ZStack {
            CrumpledPaperBall(size: 52, emoji: emoji, emojiOpacity: 0.28,
                              showShadow: ballFlight < 0.05 && !dragging)
                .rotationEffect(.degrees(ballTilt))
                .scaleEffect(useDrag && dragging ? 1.05 : 1 - ballFlight * 0.5)
                .opacity(ballFade)
                .offset(x: ballX, y: ballY)
                // LIVE: the paper ball itself is flickable. This drag IS the
                // mechanic — flick it within a generous ±45° cone of the target.
                .gesture(autoPlay || launching ? nil : flickGesture)

            if autoPlay {
                // The test-lab demo finger that performs the beat.
                Text("👆")
                    .font(.system(size: 38))
                    .rotationEffect(.degrees(beatFingerRot))
                    .offset(x: beatFingerX, y: beatFingerY)
                    .opacity(fingerGone ? 0 : 1)
                    .shadow(color: .black.opacity(0.4), radius: 4)
            } else if !interacted && !launching {
                // LIVE: a gentle looping hint — pull back, flick — fades on touch.
                Text("👆")
                    .font(.system(size: 34))
                    .rotationEffect(.degrees(hintPhase ? -8 : 12))
                    .offset(x: 16, y: hintPhase ? 20 : -14)
                    .opacity(0.85)
                    .shadow(color: .black.opacity(0.4), radius: 4)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
    }

    // ── Paper-dust burst at the launch ───────────────────────────────────────

    @ViewBuilder
    private var dust: some View {
        if dustBurst {
            ForEach(0..<10, id: \.self) { i in
                let a = Double(i) / 10 * .pi
                let r: CGFloat = 30 + CGFloat(i % 4) * 8
                Circle()
                    .fill(FlickDeskPalette.paperA.opacity(0.7))
                    .frame(width: 5, height: 5)
                    .offset(x: CGFloat(cos(a)) * r * 0.7 + 10,
                            y: -CGFloat(sin(a)) * r - 6)
                    .opacity(0)
                    .animation(.easeOut(duration: 0.7), value: dustBurst)
                    .allowsHitTesting(false)
            }
        }
    }

    // ── Labels ───────────────────────────────────────────────────────────────

    private var labels: some View {
        VStack {
            Text("pointing toward \(personName)")
                .font(.system(size: 16, design: .serif).italic())
                .foregroundColor(Self.lavender.opacity(0.9))
                .shadow(color: .black.opacity(0.5), radius: 5)
                .padding(.top, 70)
            Spacer()
            Text(showWeakHint ? "flick a little harder ✦"
                 : autoPlay ? "flick ✦" : "flick toward the point ✦")
                .font(.system(size: 18, design: .serif).italic())
                .foregroundColor(Self.lavender)
                .shadow(color: .black.opacity(0.5), radius: 5)
                .padding(.bottom, 80)
        }
        .allowsHitTesting(false)
    }

    // ── LIVE flick gesture — the entire mechanic (aim-free) ──────────────────

    private var flickGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                guard !launching else { return }
                interacted = true
                dragging = true
                dragOffset = value.translation
            }
            .onEnded { value in
                dragging = false
                guard !launching else { return }
                let v = value.velocity
                let speed = hypot(v.width, v.height)
                // [tolerance cone 2026-06-13] Flick direction in the SAME convention
                // as targetAngle (0 = up, clockwise): atan2(dx, -dy). A generous ±45°
                // cone around the frozen target means flicking ANYWHERE in its general
                // direction counts as a hit — forgiving and fun, not precise.
                let flickAngle = atan2(Double(v.width), -Double(v.height)) * 180 / .pi
                let aimError = BearingCalculator.alignmentError(
                    relativeBearing: flickAngle - targetAngle)
                if speed >= minFlickSpeed && aimError <= Self.aimTolerance {
                    launchLive()
                } else if speed < minFlickSpeed {
                    weakBounce()        // too gentle → "flick a little harder ✦"
                } else {
                    missBounce()        // strong but aimed away → "flick toward the point ✦"
                }
            }
    }

    /// A real flick — the ball flies to the target point and hands off.
    private func launchLive() {
        launching = true
        withAnimation(.easeOut(duration: 0.15)) { dragOffset = .zero }
        InstrumentSoundPlayer.shared.playSend(.flick, proIntensity: 1.25)
        HapticEngine.flickRelease()
        dustBurst = true
        withAnimation(.easeOut(duration: 0.6)) { ballFlight = 1 }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { onSend() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8)  { rearmLive() }
    }

    /// A weak flick — the ball springs home, a gentle nudge to flick harder.
    private func weakBounce() {
        HapticEngine.sendSoft()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { dragOffset = .zero }
        showWeakHint = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation { showWeakHint = false }
        }
    }

    /// A flick that was strong enough but aimed well OUTSIDE the ±45° cone — the
    /// ball springs home. No "flick harder" hint (they flicked hard enough, just
    /// not toward the target); the standing "flick toward the point ✦" label guides.
    private func missBounce() {
        HapticEngine.sendSoft()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { dragOffset = .zero }
    }

    /// Reset the live face so the next thought can be flicked.
    private func rearmLive() {
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) {
            ballFlight = 0; dustBurst = false; launching = false
            interacted = false; dragOffset = .zero
        }
    }

    // ── The test-lab watchable beat (autoPlay only) ──────────────────────────

    private func runOnce() {
        guard !didRun else { return }
        didRun = true

        withAnimation(.easeOut(duration: 0.5)) { fingerLift = 1 }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeInOut(duration: 0.4)) { windBack = 1 }
            HapticPattern.singleSoft.fire()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.easeIn(duration: 0.12)) { snap = 1 }
            InstrumentSoundPlayer.shared.playSend(.flick, proIntensity: 1.25)
            HapticPattern.singleSoft.fire()
            dustBurst = true
            withAnimation(.easeOut(duration: 0.7)) { ballFlight = 1 }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.55) {
            withAnimation(.easeOut(duration: 0.3)) { snap = 0; windBack = 0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.85) {
            withAnimation(.easeOut(duration: 0.3)) { fingerGone = true }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            onSend()
            if !autoPlay { rearmBeat() }
        }
    }

    /// Reset the test-lab beat state (no animation).
    private func rearmBeat() {
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) {
            fingerLift = 0; windBack = 0; snap = 0
            ballFlight = 0; dustBurst = false; fingerGone = false
        }
        didRun = false
    }
}

/// The desk circle with its TOP `topCrop` fraction cut off by a clean horizontal
/// line — the circle intersected with its lower portion — so the warm oak reads
/// as a surface with a flat horizon near the top and space above it.
private struct DeskCropShape: Shape {
    var topCrop: CGFloat = 0.25
    func path(in rect: CGRect) -> Path {
        let circle = Path(ellipseIn: rect)
        let cutY = rect.minY + rect.height * topCrop
        let lower = Path(CGRect(x: rect.minX, y: cutY,
                                width: rect.width, height: rect.maxY - cutY))
        return circle.intersection(lower)
    }
}
