// FireworkCompassFace.swift
// Pointward › Instruments › _Shared › EmojiReveal
//
// A SPECIAL compass-face interaction that activates only when the selected
// emoji is 🎆 (same pattern as BirthdayCakeCompassFace for 🎂). A firework
// rocket sits inside the compass ring with a curled fuse; a lit match rests at
// the bottom. The user DRAGS the match up to the fuse tip — the fuse catches,
// sparks crawl down toward the rocket, the rocket jitters harder and harder,
// and when the burn completes the standard send pipeline fires via onSend().
//
// Visual bible: firework_4screens.svg, Screens 1 (idle) & 2 (charging).
// Screen-coordinate rules: GeometryReader root, positions from geo.size, compass
// centred at (w/2, h·0.46), radius min(w·0.38, 148). Works embedded in the
// 240pt compass face AND full-screen in the Animation Test Lab.

import SwiftUI

struct FireworkCompassFace: View {
    var bearingDegrees: Double = 0
    var personName: String = ""
    var onSend: () -> Void = {}

    // Palette (visual bible)
    private static let bodyTop  = Color(hex: "#f44336")
    private static let bodyBot  = Color(hex: "#d32f2f")
    private static let coneTop  = Color(hex: "#ffeb3b")
    private static let coneBot  = Color(hex: "#fbc02d")
    private static let fuseGrey = Color(hex: "#9b8fa8")
    private static let brass    = Color(hex: "#c9a86a")
    private static let spark    = Color(hex: "#ffeb3b")
    private static let matchStk = Color(hex: "#e8c060")
    private static let lavender = Color(hex: "#c4a8d4")

    private static let burnDuration: Double = 2.0

    @State private var matchDrag: CGSize = .zero   // live drag of the match
    @State private var lit = false
    @State private var litAt: Date? = nil
    @State private var sent = false
    @State private var idlePulse = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let cx = w / 2, cy = h * 0.46
            let R = min(w * 0.38, 148)

            // Rocket geometry
            let bodyW = R * 0.34, bodyH = R * 0.72
            let bodyCY = cy - R * 0.04
            let bodyTopY = bodyCY - bodyH / 2
            // [phase3] SHORT fuse just above the rocket — the long non-functional
            // "top fuse string" that ran to the corner is gone. The match now
            // STARTS TOP-LEFT and the user drags it DOWN to the fuse.
            let fuseTip = CGPoint(x: cx + bodyW * 0.55, y: bodyTopY - R * 0.10)
            let matchRest = CGPoint(x: cx - R * 0.62, y: cy - R * 0.64)
            let matchPos = CGPoint(x: matchRest.x + matchDrag.width,
                                   y: matchRest.y + matchDrag.height)

            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let burn = burnProgress(now: timeline.date)        // 0…1
                // Rocket jitter grows with the burn (3–5° → more as it burns).
                let jitter = lit ? sin(t * 34) * (1.5 + burn * 4.5) : 0

                ZStack {
                    // ── DARK SKY inside the ring (Screen 1/2 background) ──
                    Circle()
                        .fill(RadialGradient(
                            colors: [Color(hex: "#1a2d4a"), Color(hex: "#101e38"), Color(hex: "#080e1e")],
                            center: .center, startRadius: 0, endRadius: R))
                        .overlay(stars(R: R))
                        .overlay(Circle().stroke(.white.opacity(0.10), lineWidth: 1.2))
                        .frame(width: R * 2, height: R * 2)
                        .clipShape(Circle())
                        .position(x: cx, y: cy)

                    // ── Glow that rises as the fuse burns (red → yellow) ──
                    Circle()
                        .fill(RadialGradient(
                            colors: [Self.bodyTop.opacity(lit ? 0.04 + burn * 0.12 : 0.0), .clear],
                            center: .center, startRadius: 4, endRadius: R * 0.8))
                        .frame(width: R * 2, height: R * 2)
                        .position(x: cx, y: cy)
                        .blendMode(.screen)
                    // Idle soft gold glow (Screen 1)
                    Circle()
                        .fill(RadialGradient(colors: [Self.spark.opacity(idlePulse ? 0.10 : 0.06), .clear],
                                             center: .center, startRadius: 2, endRadius: 50))
                        .frame(width: 120, height: 120)
                        .position(x: cx, y: bodyTopY)

                    // ── The rocket (jitters as it burns) ──
                    rocket(cx: cx, bodyCY: bodyCY, bodyW: bodyW, bodyH: bodyH, R: R)
                        .rotationEffect(.degrees(jitter), anchor: .bottom)

                    // ── The curled fuse + travelling spark ──
                    fuse(from: CGPoint(x: cx + bodyW * 0.35, y: bodyTopY + 2),
                         to: fuseTip, burn: burn, t: t)

                    // ── The match (draggable) ──
                    match(at: matchPos, t: t)
                        .gesture(matchGesture(fuseTip: fuseTip, matchRest: matchRest))

                    // ── Instruction ──
                    Text(lit ? "fuse burning... ✦" : "drag the match down to the fuse ✦")
                        .font(.system(size: 12, design: .serif).italic())
                        .foregroundColor(Self.lavender.opacity(0.85))
                        .shadow(color: .black.opacity(0.5), radius: 4)
                        .position(x: cx, y: cy + R * 1.04)
                }
                .frame(width: w, height: h)
                .onChange(of: burn) { _, newValue in
                    if newValue >= 1.0 { fire() }
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                idlePulse = true
            }
        }
    }

    // ── Burn clock ────────────────────────────────────────────────────────

    private func burnProgress(now: Date) -> Double {
        guard let litAt else { return 0 }
        return min(1, max(0, now.timeIntervalSince(litAt) / Self.burnDuration))
    }

    // ── The rocket ──────────────────────────────────────────────────────────

    @ViewBuilder
    private func rocket(cx: CGFloat, bodyCY: CGFloat, bodyW: CGFloat, bodyH: CGFloat, R: CGFloat) -> some View {
        let coneH = bodyW * 0.95
        let bodyTopY = bodyCY - bodyH / 2
        ZStack {
            // Stick below the body (brass line)
            Rectangle().fill(Self.brass)
                .frame(width: 2.5, height: R * 0.5)
                .position(x: cx, y: bodyCY + bodyH / 2 + R * 0.22)
            // Body
            RoundedRectangle(cornerRadius: bodyW * 0.18)
                .fill(LinearGradient(colors: [Self.bodyTop, Self.bodyBot],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: bodyW, height: bodyH)
                .overlay(RoundedRectangle(cornerRadius: bodyW * 0.18)
                            .stroke(.white.opacity(0.18), lineWidth: 1))
                .position(x: cx, y: bodyCY)
            // Yellow cone top
            Triangle()
                .fill(LinearGradient(colors: [Self.coneTop, Self.coneBot],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: bodyW * 1.02, height: coneH)
                .position(x: cx, y: bodyTopY - coneH / 2 + 1)
        }
    }

    // ── The curled fuse + travelling spark ───────────────────────────────────

    @ViewBuilder
    private func fuse(from start: CGPoint, to tip: CGPoint, burn: Double, t: Double) -> some View {
        // A curling bezier from the rocket top out to the fuse tip.
        let c1 = CGPoint(x: start.x + (tip.x - start.x) * 0.1, y: start.y - 34)
        let c2 = CGPoint(x: tip.x + 14, y: start.y - 6)
        ZStack {
            FuseCurl(start: start, c1: c1, c2: c2, end: tip)
                .stroke(Self.fuseGrey, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            // The burning spark crawls from the TIP down toward the rocket.
            if lit {
                let p = 1 - burn                    // 1 at tip → 0 at rocket
                let sparkPos = bezier(start: start, c1: c1, c2: c2, end: tip, t: p)
                ForEach(0..<5, id: \.self) { k in
                    let jit = CGFloat(sin(t * 40 + Double(k))) * 3
                    Circle()
                        .fill(k % 2 == 0 ? Self.spark : Color.white)
                        .frame(width: 5 - CGFloat(k) * 0.6, height: 5 - CGFloat(k) * 0.6)
                        .position(x: sparkPos.x + jit, y: sparkPos.y - CGFloat(k) * 2)
                        .shadow(color: Self.spark.opacity(0.8), radius: 4)
                        .opacity(1 - Double(k) * 0.15)
                }
            }
        }
    }

    // ── The match ─────────────────────────────────────────────────────────

    @ViewBuilder
    private func match(at pos: CGPoint, t: Double) -> some View {
        let flicker = 0.9 + sin(t * 18) * 0.12
        ZStack {
            // stick
            Capsule().fill(Self.matchStk)
                .frame(width: 5, height: 30)
                .offset(y: 9)
            // lit head — red base, yellow flame, red inner, white hot dot
            Ellipse().fill(Color(hex: "#c0392b")).frame(width: 9, height: 11).offset(y: -10)
            Ellipse().fill(Self.coneTop).frame(width: 12, height: 18)
                .scaleEffect(flicker).offset(y: -18)
            Ellipse().fill(Color(hex: "#e74c3c")).frame(width: 6, height: 11)
                .scaleEffect(flicker).offset(y: -19)
            Circle().fill(.white).frame(width: 3.5, height: 3.5).offset(y: -20)
                .shadow(color: Self.coneTop, radius: 5)
        }
        .position(pos)
    }

    private func matchGesture(fuseTip: CGPoint, matchRest: CGPoint) -> some Gesture {
        DragGesture()
            .onChanged { v in
                guard !lit, !sent else { return }
                matchDrag = v.translation
                let mp = CGPoint(x: matchRest.x + v.translation.width,
                                 y: matchRest.y + v.translation.height)
                if hypot(mp.x - fuseTip.x, mp.y - fuseTip.y) < 42 {
                    ignite()
                }
            }
            .onEnded { _ in
                // Snap the (now consumed) match back if it never lit the fuse.
                if !lit { withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { matchDrag = .zero } }
            }
    }

    // ── Mechanic ────────────────────────────────────────────────────────────

    private func ignite() {
        guard !lit else { return }
        lit = true
        litAt = Date()
        HapticEngine.personSelected()
        InstrumentSoundPlayer.shared.playCue(file: "firework_fuse_burn", duration: Self.burnDuration)
    }

    private func fire() {
        guard lit, !sent else { return }
        sent = true
        HapticEngine.rocketLaunch()
        InstrumentSoundPlayer.shared.playCue(file: "firework_launch", duration: 0.8)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { onSend() }
    }

    // ── Tiny stars scattered in the dark sky ─────────────────────────────────

    private func stars(R: CGFloat) -> some View {
        let specs: [(CGFloat, CGFloat, CGFloat)] = [
            (0.28, 0.24, 1.3), (0.70, 0.30, 1.1), (0.40, 0.64, 1.2),
            (0.66, 0.62, 1.0), (0.34, 0.44, 1.1), (0.58, 0.20, 1.2), (0.76, 0.50, 1.0)
        ]
        return ZStack {
            ForEach(0..<specs.count, id: \.self) { i in
                let s = specs[i]
                Circle().fill(.white.opacity(0.5))
                    .frame(width: s.2 * 2, height: s.2 * 2)
                    .position(x: R * 2 * s.0, y: R * 2 * s.1)
            }
        }
        .frame(width: R * 2, height: R * 2)
    }

    // ── Quadratic-ish cubic bezier point sampler ─────────────────────────────

    private func bezier(start: CGPoint, c1: CGPoint, c2: CGPoint, end: CGPoint, t: Double) -> CGPoint {
        let u = 1 - t
        let x = u*u*u*Double(start.x) + 3*u*u*t*Double(c1.x) + 3*u*t*t*Double(c2.x) + t*t*t*Double(end.x)
        let y = u*u*u*Double(start.y) + 3*u*u*t*Double(c1.y) + 3*u*t*t*Double(c2.y) + t*t*t*Double(end.y)
        return CGPoint(x: x, y: y)
    }
}

/// The curling fuse path (cubic bezier).
private struct FuseCurl: Shape {
    let start: CGPoint; let c1: CGPoint; let c2: CGPoint; let end: CGPoint
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: start)
        p.addCurve(to: end, control1: c1, control2: c2)
        return p
    }
}
