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
//   LAUNCH (0.0–0.3s)  arrow appears at the edge, hard accel (easeIn)
//   FLIGHT (0.3–0.5s)  travels at y≈0.55h with a slight arc; whistle plays
//   EXIT   (0.5–0.8s)  exits right (geo.size.width × 1.15); trail fades
//
// Total: InstrumentBoundaries.Send.bow (0.8s).

import SwiftUI

struct BowSendAnimationV2: View {

    let transition: InstrumentTransition
    var personName: String = ""
    var onComplete: () -> Void = {}

    static let duration: Double = InstrumentBoundaries.Send.bow   // 0.8

    private static let launchEnd: Double = 0.3
    private static let flightEnd: Double = 0.5
    private static let total:     Double = 0.8

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
        BowArrowGlyph(emoji: transition.emoji)
            .frame(width: Self.arrowW, height: Self.arrowH)
            .position(arrowPos(geo.size, e))
    }

    /// Left → right at y ≈ 0.55h with a slight upward arc at centre.
    private func arrowPos(_ size: CGSize, _ e: Double) -> CGPoint {
        let entryX = -size.width * 0.15
        let exitX  =  size.width * 1.15
        let p: Double
        if e <= Self.launchEnd {
            p = easeIn(e / Self.launchEnd) * 0.18
        } else if e <= Self.flightEnd {
            p = 0.18 + ((e - Self.launchEnd) / (Self.flightEnd - Self.launchEnd)) * 0.62
        } else {
            p = 0.80 + easeOut((e - Self.flightEnd) / (Self.total - Self.flightEnd)) * 0.20
        }
        let x = entryX + (exitX - entryX) * CGFloat(p)
        let arc = -sin(p * .pi) * size.height * 0.08
        return CGPoint(x: x, y: size.height * 0.55 + arc)
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
