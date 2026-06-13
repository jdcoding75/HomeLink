// FlickDeskCompassFace.swift
// Pointward › Instruments › Flick
//
// ACT 1 of 3 — the FLICK V2 (DESK) compass face. A single watchable beat
// (rest → action), NOT an interactive drag:
//
//   the desk shows ONLY inside the compass ring (radial oak), the deep-purple
//   app background stays outside; a CRUMPLED PAPER BALL rests at centre with a
//   👆 pointing-finger below. The finger slides up to the ball, winds back (the
//   ball tilts ~3°), then SNAPS forward — the ball launches up-right spinning,
//   paper-dust bursts, a soft (filtered-noise) flick sound plays — and the
//   finger retracts. Then it hands off (onSend).
//
// Shared components (one source of truth): FlickDeskFaceFill + CrumpledPaperBall
// (FlickDeskWorld.swift) and DirectionIndicator (the person marker). The ring is
// the standard instrument look: lavender, ticks every 30°, dashed inner ring.

import SwiftUI

struct FlickDeskCompassFace: View {

    var personName: String = "them"
    var emoji: String = "💜"
    var bearingDegrees: Double = 45      // person marker sits here (spec: "S" at 45°)
    var onSend: () -> Void = {}
    /// [live 2026-06-13] true (default) = the test-lab beat that auto-plays once
    /// on appear. false = the LIVE compass face: it rests until TAPPED, plays the
    /// flick → onSend, then re-arms for the next send (so it is reusable).
    var autoPlay: Bool = true

    @State private var fingerLift: CGFloat = 0   // 0 rest → 1 up at the ball
    @State private var windBack: CGFloat = 0     // 0 → 1 wound back (ball tilt ~3°)
    @State private var snap: CGFloat = 0         // 0 → 1 snap forward
    @State private var ballFlight: CGFloat = 0   // 0 centre → 1 launched up-right
    @State private var dustBurst = false
    @State private var fingerGone = false
    @State private var didRun = false

    private static let lavender = Color(hex: "#c4a8d4")
    private static let faceD: CGFloat = 330       // desk circle diameter
    private static let ringRadius: CGFloat = 165
    private static let topCrop: CGFloat = 0.25    // [tweak] crop the top 25% of the desk

    var body: some View {
        ZStack {
            Color(hex: "#0d0d14").ignoresSafeArea()   // deep purple OUTSIDE the ring
            cluster
            labels
        }
        .contentShape(Rectangle())                       // whole face is tappable
        .onTapGesture { if !autoPlay { runOnce() } }     // LIVE: tap to flick-send
        .onAppear { if autoPlay { runOnce() } }          // TEST LAB: auto-play once
    }

    // ── The compass cluster (desk circle + ring + marker + ball/finger) ──────

    private var cluster: some View {
        ZStack {
            // [tweak] The warm-oak desk fills only the LOWER ~75% of the circle:
            // its top 25% is cut by a clean horizontal line, so it reads as a desk
            // surface with a flat horizon near the top and deep-purple space above
            // it — rather than oak filling the whole circle.
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
            DirectionIndicator(bearingDegrees: bearingDegrees, personName: personName,
                               personEmoji: emoji, ringRadius: Self.ringRadius,
                               showHint: false)
            dust
            ballAndFinger
        }
        .frame(width: 370, height: 370)
    }

    /// [tweak] The bright desk back-edge line along the horizontal crop — the
    /// "horizon" where the oak surface meets the space above it.
    private var horizonLine: some View {
        let r = Self.faceD / 2
        let off = r - Self.faceD * Self.topCrop          // distance of the cut above centre
        let half = (r * r - off * off).squareRoot()      // half-chord at the cut
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

    // ── The ball + finger ────────────────────────────────────────────────────

    private var ballAndFinger: some View {
        let flightX: CGFloat = ballFlight * 150
        let flightY: CGFloat = -ballFlight * 130
        let ballTilt: Double = Double(windBack) * -3 + Double(ballFlight) * 240
        let ballFade: Double = 1 - Double(max(0, ballFlight - 0.6) / 0.4)

        // Finger path: rest below → lifts to the ball → winds back a touch →
        // snaps forward/up → retracts.
        let baseY: CGFloat = 60
        let fingerY: CGFloat = baseY - fingerLift * 42 + windBack * 12 - snap * 24
        let fingerX: CGFloat = snap * 18
        let fingerRot: Double = -10 + Double(windBack) * 9 - Double(snap) * 18

        return ZStack {
            CrumpledPaperBall(size: 52, emoji: emoji, emojiOpacity: 0.28,
                              showShadow: ballFlight < 0.05)
                .rotationEffect(.degrees(ballTilt))
                .scaleEffect(1 - ballFlight * 0.5)
                .opacity(ballFade)
                .offset(x: flightX, y: flightY)

            Text("👆")
                .font(.system(size: 38))
                .rotationEffect(.degrees(fingerRot))
                .offset(x: fingerX, y: fingerY)
                .opacity(fingerGone ? 0 : 1)
                .shadow(color: .black.opacity(0.4), radius: 4)
        }
    }

    // ── Paper-dust burst at the snap ─────────────────────────────────────────

    @ViewBuilder
    private var dust: some View {
        if dustBurst {
            ForEach(0..<10, id: \.self) { i in
                let a = Double(i) / 10 * .pi                  // upper half
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

    // ── Labels — "pointing toward [name]" above, "flick ✦" below ─────────────

    private var labels: some View {
        VStack {
            Text("pointing toward \(personName)")
                .font(.system(size: 16, design: .serif).italic())
                .foregroundColor(Self.lavender.opacity(0.9))
                .shadow(color: .black.opacity(0.5), radius: 5)
                .padding(.top, 70)
            Spacer()
            Text("flick ✦")
                .font(.system(size: 18, design: .serif).italic())
                .foregroundColor(Self.lavender)
                .shadow(color: .black.opacity(0.5), radius: 5)
                .padding(.bottom, 80)
        }
        .allowsHitTesting(false)
    }

    // ── The single watchable beat ────────────────────────────────────────────

    private func runOnce() {
        guard !didRun else { return }
        didRun = true

        // Finger slides up to the ball.
        withAnimation(.easeOut(duration: 0.5)) { fingerLift = 1 }

        // Wind back — the ball tilts ~3°, the finger loads.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeInOut(duration: 0.4)) { windBack = 1 }
            HapticPattern.singleSoft.fire()
        }

        // SNAP — ball launches up-right spinning; dust bursts; soft flick sound.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.easeIn(duration: 0.12)) { snap = 1 }
            InstrumentSoundPlayer.shared.playSend(.flick, proIntensity: 1.25)   // sharp paper snap. proIntensity 1.25 already clamps the player to full (1.0); the snap was made one notch LOUDER by boosting flick_send.wav itself (~+2 dB RMS) — see FlickSounds.swift.
            HapticPattern.singleSoft.fire()                 // soft — NOT sharp
            dustBurst = true
            withAnimation(.easeOut(duration: 0.7)) { ballFlight = 1 }
        }

        // Finger retracts.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.55) {
            withAnimation(.easeOut(duration: 0.3)) { snap = 0; windBack = 0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.85) {
            withAnimation(.easeOut(duration: 0.3)) { fingerGone = true }
        }

        // Hand off — the beat is done.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            onSend()
            // LIVE: re-arm so the next tap can flick the next thought. (The test
            // lab leaves didRun latched — it plays exactly once.)
            if !autoPlay { rearm() }
        }
    }

    /// Snap every beat-state back to rest (no animation) so a live face can flick
    /// again. Called after the live hand-off.
    private func rearm() {
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
