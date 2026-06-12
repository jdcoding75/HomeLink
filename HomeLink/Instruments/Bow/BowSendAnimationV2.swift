// BowSendAnimationV2.swift
// Pointward › Instruments › Bow
//
// ACT 2 of 3 — the full-screen BOW send journey (visual bible Screen 3).
//
// A luminous gold arrow — gold shaft, blazing white tip, lavender fletching, the
// emoji riding the shaft — streaks across a dark navy NIGHT sky on a gold
// particle trail and exits off the right edge. The shared send pipeline then
// shows the sent confirmation (this view never shows EmojiRevealView).
//
//   LAUNCH (0.0–0.30s)  arrow appears LOW-left, the release accel (easeIn)
//   FLIGHT (0.30–1.95s) a long, graceful rising ARC across the whole screen on a
//                       true bezier curve; whistle plays
//   EXIT   (1.95–2.30s) exits the right edge HIGH (≈0.30h) — continuing into
//                       BowReceiptAnimationV2's upper-left arrival, so the send's
//                       exit and the receipt's entry read as one continuous flight.
//
// Total: 2.30s — a noticeably more unhurried lob, lengthened by PATH not just
// speed, sitting comfortably under the 3.5s receipt. Trajectory/timing only —
// the arrow art, draw/release, and sounds are unchanged. V2 only; the live bow
// timing constant InstrumentBoundaries.Send.bow is deliberately NOT touched.

import SwiftUI

struct BowSendAnimationV2: View {

    let transition: InstrumentTransition
    var personName: String = ""
    var onComplete: () -> Void = {}

    // The lengthened, graceful flight lives HERE (V2 only) — decoupled from the
    // live InstrumentBoundaries.Send.bow (0.8s) so V1 and the boundary are untouched.
    private static let total:     Double = 2.30
    private static let launchEnd: Double = 0.30
    private static let flightEnd: Double = 1.95
    static let duration: Double = total

    private static let skyTop = Color(hex: "#1a2d4a")
    private static let skyBot = Color(hex: "#0e1e38")
    private static let gold   = Color(hex: "#f0d060")
    private static let goldHi = Color(hex: "#ffe9a0")
    private static let lavender = Color(hex: "#c4a8d4")
    private static let arrowW: CGFloat = 150
    private static let arrowH: CGFloat = 34

    @State private var start: Date? = nil

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let e = clampedElapsed(now: timeline.date)
                ZStack {
                    LinearGradient(colors: [Self.skyTop, Self.skyBot],
                                   startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()
                    stars(geo: geo)
                    trail(geo: geo, elapsed: e)
                    arrow(geo: geo, elapsed: e)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            start = Date()
            InstrumentSoundPlayer.shared.playCue(file: BowSounds.sendFile, duration: BowSounds.sendDuration)
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.launchEnd) {
                InstrumentSoundPlayer.shared.playCue(file: BowSounds.arrowWhistleFile,
                                                     duration: BowSounds.arrowWhistleDuration)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.total) { onComplete() }
        }
    }

    private func clampedElapsed(now: Date) -> Double {
        guard let start else { return 0 }
        return min(max(0, now.timeIntervalSince(start)), Self.total)
    }

    @ViewBuilder
    private func arrow(geo: GeometryProxy, elapsed e: Double) -> some View {
        // Aim the arrow along its flight tangent so the long arc reads naturally
        // (the glyph art is unchanged — only its heading follows the path).
        let t0 = max(0, min(Self.total - 0.03, e))
        let a = arrowPos(geo.size, t0)
        let b = arrowPos(geo.size, t0 + 0.03)
        let angle = atan2(Double(b.y - a.y), Double(b.x - a.x)) * 180 / .pi
        BowArrowGlyph(emoji: transition.emoji)
            .frame(width: Self.arrowW, height: Self.arrowH)
            .rotationEffect(.degrees(angle))
            .position(arrowPos(geo.size, e))
    }

    /// A long, graceful LOB: from low-left, up over the whole screen on a true
    /// quadratic-bezier arc, exiting the right edge HIGH (≈0.30h) so the flight
    /// continues straight into BowReceiptAnimationV2's upper-left arrival.
    private func arrowPos(_ size: CGSize, _ e: Double) -> CGPoint {
        let s   = CGPoint(x: -size.width * 0.15, y: size.height * 0.82)   // low-left start
        let c   = CGPoint(x:  size.width * 0.52, y: size.height * 0.06)   // high control → real arc
        let end = CGPoint(x:  size.width * 1.15, y: size.height * 0.30)   // exit high-right (receipt entry band)
        return bezier(s, c, end, CGFloat(pathProgress(e)))
    }

    /// Maps elapsed time → 0…1 along the path: a snappy release, then a long
    /// unhurried glide, then a soft easing out through the exit.
    private func pathProgress(_ e: Double) -> Double {
        if e <= Self.launchEnd {
            return easeIn(e / Self.launchEnd) * 0.14
        } else if e <= Self.flightEnd {
            return 0.14 + ((e - Self.launchEnd) / (Self.flightEnd - Self.launchEnd)) * 0.78
        } else {
            return 0.92 + easeOut((e - Self.flightEnd) / (Self.total - Self.flightEnd)) * 0.08
        }
    }

    /// Quadratic bezier point at p (0…1).
    private func bezier(_ s: CGPoint, _ c: CGPoint, _ end: CGPoint, _ p: CGFloat) -> CGPoint {
        let mp = 1 - p
        return CGPoint(x: mp * mp * s.x + 2 * mp * p * c.x + p * p * end.x,
                       y: mp * mp * s.y + 2 * mp * p * c.y + p * p * end.y)
    }

    @ViewBuilder
    private func trail(geo: GeometryProxy, elapsed e: Double) -> some View {
        let head = arrowPos(geo.size, e)
        ZStack {
            Capsule()
                .fill(LinearGradient(colors: [Self.gold.opacity(0.0), Self.gold.opacity(0.5)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 150, height: 8)
                .blur(radius: 3)
                .position(x: head.x - Self.arrowW * 0.45 - 60, y: head.y)
            ForEach(0..<14, id: \.self) { i in
                let f = Double(i) / 13
                let dx = -CGFloat(1 - f) * 150 - Self.arrowW * 0.42
                let jy = CGFloat(sin(Double(i) * 1.7 + e * 30)) * 6
                Circle()
                    .fill(i % 2 == 0 ? Self.gold : Self.goldHi)
                    .frame(width: 1.2 + CGFloat(f) * 1.8, height: 1.2 + CGFloat(f) * 1.8)
                    .opacity(0.12 + f * 0.53)
                    .position(x: head.x + dx, y: head.y + jy)
            }
        }
        .opacity(e > 0.02 ? 1 : 0)
        .allowsHitTesting(false)
    }

    private func stars(geo: GeometryProxy) -> some View {
        let specs: [(CGFloat, CGFloat, CGFloat, Bool)] = [
            (0.16, 0.18, 1.6, false), (0.34, 0.30, 1.2, true), (0.52, 0.14, 1.4, false),
            (0.70, 0.26, 1.3, true), (0.84, 0.40, 1.6, false), (0.24, 0.66, 1.2, true)
        ]
        return ForEach(0..<specs.count, id: \.self) { i in
            let s = specs[i]
            Circle()
                .fill(s.3 ? Self.lavender.opacity(0.3) : Color.white.opacity(0.32))
                .frame(width: s.2 * 2, height: s.2 * 2)
                .position(x: geo.size.width * s.0, y: geo.size.height * s.1)
        }
        .allowsHitTesting(false)
    }

    private func easeIn(_ t: Double) -> Double  { let x = min(max(t, 0), 1); return x * x }
    private func easeOut(_ t: Double) -> Double { let x = min(max(t, 0), 1); return 1 - pow(1 - x, 2) }
}
