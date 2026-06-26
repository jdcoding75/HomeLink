// PlaneReceiptAnimationV2.swift
// Pointward › Instruments › Plane
//
// ACT 3 of 3 — the V2 PLANE receipt (visual bible: Screen 4, parachute descent).
//
// A white parachute canopy drifts down out of the dark night sky, the emoji
// slung below it on suspension lines, swaying gently like a pendulum as it
// settles. It drifts toward the wooden bucket lower-right, the canopy collapses
// at touchdown, and the emoji catches in the bucket — then blooms into the
// shared EmojiRevealView.
//
//   FLY-OVER (0.0–0.9s) the paper plane from the send streaks ACROSS THE TOP,
//                       already in motion — the send→receipt hand-off as one
//                       continuous flight; it drops its payload and exits right
//   RELEASE (0.0–0.45s) OVERLAPPING the fly-over, the parachute pops open from
//                       the TOP-LEFT and begins its drop (visible overlap, not a
//                       second separate beat)
//   DESCEND (…–4.4s)    slow drift down toward the bucket, ±4° pendulum sway,
//                       plane_flight ambient
//   LAND   (4.4–5.0s)   canopy collapses, emoji settles into the bucket,
//                       cyan catch glow, plane_catch.wav
//   → EmojiRevealView (.received, .plane)                                = 5.0s
//
// Screen-coordinate rules (all 6): GeometryReader root, dark sky
// .ignoresSafeArea(), positions from geo.size, bucket bx=width-80·by=height-95.

import SwiftUI

struct PlaneReceiptAnimationV2: View {

    let senderBearing: Double            // unused — the chute drifts straight down
    let emoji: String
    var message: String? = nil
    var tagline: String? = nil
    let fromName: String
    var onRevealed: () -> Void = {}
    var onFinished: () -> Void = {}
    /// [catch-bucket-removed-2026-06] DEFAULT false = live (no bucket, re-center to reveal). Lab passes true.
    var showBucket: Bool = false

    static let duration: Double = InstrumentBoundaries.Receipt.plane   // 5.0

    // [continuity] The send's plane streaks across the top during this window,
    // overlapping the parachute's quick top-left release.
    private static let planeFlyEnd: Double = 0.9
    private static let deployEnd:  Double = 0.45   // quicker pop — releases overlapping the fly-over
    private static let descendEnd: Double = 4.4
    private static let total:      Double = InstrumentBoundaries.Receipt.plane   // 5.0

    private static let skyTop    = Color(hex: "#1a2d4a")
    private static let skyBottom = Color(hex: "#080e1e")
    private static let gold      = Color(hex: "#d4a030")
    private static let canopy    = Color(hex: "#e8e0f0")
    private static let canopyHi  = Color(hex: "#ffffff")
    private static let canopyLo  = Color(hex: "#b6aecb")
    private static let line      = Color(hex: "#cfc6e0")
    private static let bucketW: CGFloat = 150
    private static let bucketH: CGFloat = 128

    @State private var start: Date? = nil
    @State private var skyIn = false
    @State private var revealing = false
    @State private var bucketGlow = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if revealing {
                    EmojiRevealView(emoji: emoji, message: message, tagline: tagline,
                                    context: .received(fromName: fromName),
                                    ambient: .plane,
                                    onDismiss: onFinished)
                        .transition(.opacity)
                } else {
                    TimelineView(.animation) { timeline in
                        let e = clampedElapsed(now: timeline.date)
                        ZStack {
                            LinearGradient(colors: [Self.skyTop, Self.skyBottom],
                                           startPoint: .top, endPoint: .bottom)
                                .ignoresSafeArea()
                                .opacity(skyIn ? 1 : 0)

                            if showBucket { bucket(geo: geo) }   // [catch-bucket-removed-2026-06]
                            flyoverPlane(geo: geo, elapsed: e)
                            parachute(geo: geo, elapsed: e)

                            VStack {
                                Spacer()
                                Text(message(e))
                                    .font(.system(size: 20, design: .serif).italic())
                                    .foregroundColor(Color(hex: "#c4a8d4"))
                                    .shadow(color: .black.opacity(0.5), radius: 6)
                                    .padding(.bottom, geo.size.height * 0.06)
                                    .contentTransition(.opacity)
                                    .animation(.easeInOut(duration: 0.5), value: message(e))
                            }
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
        .onAppear { begin() }
    }

    // ── Sequencing ──────────────────────────────────────────────────────────

    private func begin() {
        start = Date()
        InstrumentSoundPlayer.shared.playReceipt(.plane)               // gentle flight ambient
        InstrumentSoundPlayer.shared.playCue(file: PlaneSounds.dropFile, duration: 0.35)
        withAnimation(.easeInOut(duration: 0.3)) { skyIn = true }
        HapticPattern.singleSoft.fire()

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.descendEnd) {
            InstrumentSoundPlayer.shared.playCue(file: PlaneSounds.catchFile, duration: 0.45)
            HapticPattern.doubleSoft.fire()
            withAnimation(.easeOut(duration: 0.5)) { bucketGlow = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.total) {
            onRevealed()
            withAnimation(.easeInOut(duration: 0.3)) { revealing = true }
        }
    }

    private func clampedElapsed(now: Date) -> Double {
        guard let start else { return 0 }
        return min(max(0, now.timeIntervalSince(start)), Self.total)
    }

    private func bucketPoint(_ size: CGSize) -> CGPoint {
        // [catch-bucket-removed-2026-06] bucketless (live) → re-center to the reveal focal point.
        showBucket ? CGPoint(x: size.width - 80, y: size.height - 95)
                   : CGPoint(x: size.width / 2, y: size.height * 0.46)
    }

    // ── The fly-over plane — continues the send's flight across the TOP ──────
    //
    // The same PlaneGlyph that exited the send re-enters here already in motion,
    // crossing the top of the sky left→right and exiting the right edge. It
    // carries no emoji — the payload is now under the parachute it just dropped.

    @ViewBuilder
    private func flyoverPlane(geo: GeometryProxy, elapsed e: Double) -> some View {
        if e <= Self.planeFlyEnd {
            let pos: CGPoint = planePos(geo.size, e)
            let bank: Double = sin(e * 2.2) * 3                 // gentle banking, like the send
            let fade: Double = e > Self.planeFlyEnd - 0.25
                ? max(0, (Self.planeFlyEnd - e) / 0.25) : 1     // fade out as it leaves
            PlaneGlyph(emoji: nil)                              // payload already released
                .frame(width: 120, height: 64)
                .rotationEffect(.degrees(bank))
                .position(pos)
                .opacity(fade)
                .allowsHitTesting(false)
        }
    }

    /// Steady left → right pass across the TOP band (already in motion — no slow
    /// accel), exiting off the right edge by planeFlyEnd.
    private func planePos(_ size: CGSize, _ e: Double) -> CGPoint {
        let p: Double = min(e / Self.planeFlyEnd, 1)            // linear → constant speed
        let entryX: CGFloat = -size.width * 0.15
        let exitX:  CGFloat =  size.width * 1.15
        let x = entryX + (exitX - entryX) * CGFloat(p)
        let arc = -sin(p * .pi) * size.height * 0.015          // a whisper of lift
        return CGPoint(x: x, y: size.height * 0.12 + arc)
    }

    // ── The parachute rig (canopy + lines + emoji), swaying as it descends ────

    @ViewBuilder
    private func parachute(geo: GeometryProxy, elapsed e: Double) -> some View {
        let pos = rigPos(geo.size, e)
        let sway = sin(e * 1.6) * 4 * (e < Self.descendEnd ? 1 : 0)      // ±4° pendulum
        let collapse = e > Self.descendEnd
            ? CGFloat(min((e - Self.descendEnd) / (Self.total - Self.descendEnd), 1)) : 0
        let deploy = min(e / Self.deployEnd, 1)

        ZStack {
            // Canopy — white dome, collapses at landing
            CanopyDome()
                .fill(LinearGradient(colors: [Self.canopyHi, Self.canopy, Self.canopyLo],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(CanopyDome().stroke(Self.canopyLo.opacity(0.6), lineWidth: 1))
                .frame(width: 132 * (1 - collapse * 0.7), height: 66 * (1 - collapse * 0.5))
                .scaleEffect(CGFloat(deploy), anchor: .bottom)
                .offset(y: -64)

            // Suspension lines converging from the canopy edge to the emoji
            CanopyLines()
                .stroke(Self.line.opacity(0.8), lineWidth: 1)
                .frame(width: 132 * (1 - collapse * 0.7), height: 64)
                .offset(y: -30)
                .opacity(deploy)

            // The emoji slung below
            Text(emoji).font(.system(size: 52)).offset(y: 18)
        }
        .rotationEffect(.degrees(sway), anchor: .center)
        .position(pos)
        .allowsHitTesting(false)
    }

    /// Top of the sky → just above the bucket mouth; slow steady drift, easing
    /// horizontally toward the bucket as it descends.
    private func rigPos(_ size: CGSize, _ e: Double) -> CGPoint {
        let bucket = bucketPoint(size)
        let topY = size.height * 0.12
        let landY = bucket.y - 54
        let p = min(e / Self.descendEnd, 1)
        // [continuity] Release from the TOP-LEFT (under the plane's pass), then
        // drift across to the bucket as before.
        let xFrom = size.width * 0.18
        let x = xFrom + (bucket.x - xFrom) * CGFloat(easeInOut(p))
        let y = topY + (landY - topY) * CGFloat(p)
        return CGPoint(x: x, y: y)
    }

    // ── The bucket (shared wooden skin) + cyan catch glow ────────────────────

    private func bucket(geo: GeometryProxy) -> some View {
        let p = bucketPoint(geo.size)
        let wood = Color(hex: "#8B4513"); let woodDark = Color(hex: "#6E3A1E")
        let brass = Color(hex: "#C9A86A")
        return ZStack {
            Circle().fill(Color(hex: "#50B4F0").opacity(bucketGlow ? 0.2 : 0))
                .frame(width: 130, height: 130).blur(radius: 30)
                .offset(y: -10)
            BucketHandleShape()
                .stroke(brass, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: Self.bucketW * 0.9, height: 52)
                .offset(y: -Self.bucketH / 2 - 16)
            BucketShape()
                .fill(LinearGradient(colors: [wood, woodDark], startPoint: .top, endPoint: .bottom))
                .frame(width: Self.bucketW, height: Self.bucketH)
                .overlay(
                    VStack {
                        Capsule().fill(brass).frame(height: 6).padding(.horizontal, -2).padding(.top, 12)
                        Spacer()
                        Capsule().fill(brass).frame(height: 6).padding(.horizontal, 6).padding(.bottom, 14)
                    }
                    .frame(width: Self.bucketW, height: Self.bucketH).opacity(0.85)
                )
                .shadow(color: .black.opacity(0.4), radius: 10, y: 6)
        }
        .position(p)
    }

    // ── Messages ───────────────────────────────────────────────────────────

    private func message(_ e: Double) -> String {
        let name = fromName.isEmpty ? "someone" : fromName
        // [copy 2026-06-25] unified sender sentence. was: "\(name) sent something ✦"
        if e < Self.deployEnd  { return "\(name) sent you something ✦" }
        if e < Self.descendEnd { return "drifting down ✦" }
        return "caught it ✦"
    }

    private func easeInOut(_ t: Double) -> Double {
        let x = min(max(t, 0), 1)
        return x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2
    }
}

// MARK: - Parachute shapes

/// A canopy dome — a half-ellipse top with a softly scalloped lower edge.
struct CanopyDome: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: 0, y: h))
        p.addQuadCurve(to: CGPoint(x: w, y: h),
                       control: CGPoint(x: w / 2, y: -h * 0.6))
        // gentle scallops along the bottom edge
        let scallops = 4
        for i in stride(from: scallops, through: 1, by: -1) {
            let x0 = w * CGFloat(i) / CGFloat(scallops)
            let x1 = w * CGFloat(i - 1) / CGFloat(scallops)
            p.addQuadCurve(to: CGPoint(x: x1, y: h),
                           control: CGPoint(x: (x0 + x1) / 2, y: h + h * 0.14))
        }
        p.closeSubpath()
        return p
    }
}

/// Suspension lines fanning from the canopy edge down to a convergence point.
struct CanopyLines: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let apex = CGPoint(x: w / 2, y: h)
        let count = 5
        for i in 0..<count {
            let x = w * CGFloat(i) / CGFloat(count - 1)
            p.move(to: CGPoint(x: x, y: 0))
            p.addLine(to: apex)
        }
        return p
    }
}
