// BowReceiptAnimationV2.swift
// Pointward › Instruments › Bow
//
// ACT 3 of 3 — the full-screen BOW receipt + emoji reveal (visual bible Screen 4).
//
// A luminous gold arrow arcs in from the upper-left across a dark navy NIGHT sky
// and homes on a warm wooden bucket (brass band + rim + handle). On landing the
// shaft DISSOLVES into a burst of gold sparkles, the bucket glows LAVENDER (the
// bow world's colour — not cyan), the emoji settles visible inside the mouth,
// then it blooms into the shared EmojiRevealView.
//
//   FLIGHT   (0.0–2.6s)  arrow arcs in (single bezier), emoji on the shaft
//   DISSOLVE (2.6–3.0s)  shaft fades → gold sparkles burst; dissolve plays
//   LAND     (3.0–3.5s)  lavender glow; emoji visible in the bucket
//   BLOOM    (3.5s+)     → EmojiRevealView (.received, .bow)             = 3.5s

import SwiftUI

struct BowReceiptAnimationV2: View {

    let senderBearing: Double
    let emoji: String
    var message: String? = nil
    var tagline: String? = nil
    let fromName: String
    var onRevealed: () -> Void = {}
    var onFinished: () -> Void = {}

    static let duration: Double = InstrumentBoundaries.Receipt.bow   // 3.5

    private static let arriveT: Double = 2.6
    private static let dissolveEnd: Double = 3.0
    private static let total: Double = InstrumentBoundaries.Receipt.bow

    private static let skyTop = Color(hex: "#1a2d4a")
    private static let skyBot = Color(hex: "#0e1e38")
    private static let gold   = Color(hex: "#f0d060")
    private static let goldHi = Color(hex: "#ffe9a0")
    private static let lavender = Color(hex: "#c4a8d4")
    private static let bucketW: CGFloat = 130
    private static let bucketH: CGFloat = 120
    private static let arrowW: CGFloat = 150
    private static let arrowH: CGFloat = 34

    @State private var start: Date? = nil
    @State private var revealing = false
    @State private var solidity: Double = 1.0
    @State private var burst = false
    @State private var glow = false
    @State private var emojiInBucket = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if revealing {
                    EmojiRevealView(emoji: emoji, message: message, tagline: tagline,
                                    context: .received(fromName: fromName),
                                    ambient: .bow,
                                    onDismiss: onFinished)
                        .transition(.opacity)
                } else {
                    TimelineView(.animation) { timeline in
                        let e = clampedElapsed(now: timeline.date)
                        ZStack {
                            LinearGradient(colors: [Self.skyTop, Self.skyBot],
                                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                            stars(geo: geo)
                            bucket(geo: geo)
                            sparkleBurst(geo: geo)
                            if emojiInBucket {
                                Text(emoji).font(.system(size: 40)).position(bucketMouth(geo.size))
                            }
                            if e < Self.dissolveEnd {
                                arrow(geo: geo, elapsed: e)
                            }
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
        .onAppear { begin() }
    }

    private func begin() {
        start = Date()
        InstrumentSoundPlayer.shared.playCue(file: BowSounds.arrowWhistleFile,
                                             duration: BowSounds.arrowWhistleDuration)
        HapticPattern.singleSoft.fire()
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.arriveT) {
            InstrumentSoundPlayer.shared.playCue(file: BowSounds.sparkleDissolveFile,
                                                 duration: BowSounds.sparkleDissolveDuration)
            withAnimation(.easeOut(duration: 0.4)) { solidity = 0 }       // shaft dissolves
            withAnimation(.easeOut(duration: 0.8)) { burst = true }       // gold particles
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.dissolveEnd) {
            HapticPattern.doubleSoft.fire()
            withAnimation(.easeOut(duration: 0.4)) { glow = true }        // lavender bucket glow
            emojiInBucket = true
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
        CGPoint(x: size.width * 0.73, y: size.height - 145)
    }
    private func bucketMouth(_ size: CGSize) -> CGPoint {
        let p = bucketPoint(size); return CGPoint(x: p.x, y: p.y - Self.bucketH * 0.34)
    }

    // ── The arrow (arcs into the bucket via a single bezier) ─────────────────

    @ViewBuilder
    private func arrow(geo: GeometryProxy, elapsed e: Double) -> some View {
        let p = min(1, e / Self.arriveT)
        let pos = bezier(geo.size, p)
        let ahead = bezier(geo.size, min(1, p + 0.02))
        let angle = atan2(ahead.y - pos.y, ahead.x - pos.x) * 180 / .pi
        ZStack {
            // short gold trail (4 dots increasing opacity)
            ForEach(0..<4, id: \.self) { i in
                let f = Double(i) / 3
                let bp = bezier(geo.size, max(0, p - CGFloat(1 - f) * 0.06))
                Circle().fill(Self.gold).frame(width: 2 + CGFloat(f) * 2, height: 2 + CGFloat(f) * 2)
                    .opacity((0.15 + f * 0.5) * solidity).position(bp)
            }
            BowArrowGlyph(emoji: emoji, solidity: solidity)
                .frame(width: Self.arrowW, height: Self.arrowH)
                .rotationEffect(.degrees(angle))
                .position(pos)
        }
        .allowsHitTesting(false)
    }

    /// start: left edge 35% height · control: centre 20% height · end: bucket mouth.
    private func bezier(_ size: CGSize, _ p: CGFloat) -> CGPoint {
        let s = CGPoint(x: -size.width * 0.05, y: size.height * 0.35)
        let c = CGPoint(x: size.width * 0.5, y: size.height * 0.20)
        let mouth = bucketMouth(size)
        let mp = 1 - p
        let x = mp * mp * s.x + 2 * mp * p * c.x + p * p * mouth.x
        let y = mp * mp * s.y + 2 * mp * p * c.y + p * p * mouth.y
        return CGPoint(x: x, y: y)
    }

    // ── Gold sparkle burst from the bucket on dissolve ───────────────────────

    @ViewBuilder
    private func sparkleBurst(geo: GeometryProxy) -> some View {
        if burst {
            let m = bucketMouth(geo.size)
            ForEach(0..<9, id: \.self) { i in
                let a = (Double(i) / 9) * 2 * .pi - .pi / 2
                Circle().fill(i % 2 == 0 ? Self.gold : Self.goldHi)
                    .frame(width: 4, height: 4)
                    .position(m)
                    .offset(x: burst ? CGFloat(cos(a)) * 70 : 0,
                            y: burst ? CGFloat(sin(a)) * 80 - 20 : 0)
                    .opacity(burst ? 0 : 0.9)
                    .animation(.easeOut(duration: 0.9), value: burst)
            }
            .allowsHitTesting(false)
        }
    }

    // ── The wooden bucket (brown body · 3 staves · brass band/rim/handle) ────

    private func bucket(geo: GeometryProxy) -> some View {
        let p = bucketPoint(geo.size)
        let brown = LinearGradient(colors: [Color(hex: "#5a3a1f"), Color(hex: "#8a5a30"),
                                            Color(hex: "#7a4e2a"), Color(hex: "#4f3219")],
                                   startPoint: .top, endPoint: .bottom)
        let brass = LinearGradient(colors: [Color(hex: "#9a7320"), Color(hex: "#e8c060"),
                                            Color(hex: "#f5da80"), Color(hex: "#8a6418")],
                                   startPoint: .leading, endPoint: .trailing)
        let stave = Color(hex: "#28190c").opacity(0.55)
        return ZStack {
            Circle().fill(Self.lavender.opacity(glow ? 0.2 : 0))
                .frame(width: 150, height: 150).blur(radius: 34).offset(y: -10)
            BucketHandleShape().stroke(brass, style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
                .frame(width: Self.bucketW * 0.9, height: 46).offset(y: -Self.bucketH / 2 - 14)
            BucketShape().fill(brown)
                .frame(width: Self.bucketW, height: Self.bucketH)
                .overlay(
                    ZStack {
                        Rectangle().fill(stave).frame(width: 1.3).offset(x: -Self.bucketW * 0.22)
                        Rectangle().fill(stave).frame(width: 1.3)
                        Rectangle().fill(stave).frame(width: 1.3).offset(x: Self.bucketW * 0.22)
                    }
                )
                .overlay(Capsule().fill(brass).frame(height: 9).offset(y: -Self.bucketH * 0.06))
                .shadow(color: .black.opacity(0.45), radius: 10, y: 6)
            Ellipse().fill(Color(hex: "#0c0916").opacity(0.9))
                .overlay(Ellipse().stroke(brass, lineWidth: 3))
                .frame(width: Self.bucketW, height: 18)
                .offset(y: -Self.bucketH / 2)
        }
        .position(p)
    }

    private func stars(geo: GeometryProxy) -> some View {
        let specs: [(CGFloat, CGFloat, CGFloat, Bool)] = [
            (0.18, 0.14, 1.6, false), (0.36, 0.26, 1.2, true), (0.58, 0.12, 1.4, false),
            (0.78, 0.22, 1.3, true), (0.46, 0.40, 1.4, false), (0.20, 0.52, 1.2, true)
        ]
        return ForEach(0..<specs.count, id: \.self) { i in
            let s = specs[i]
            Circle().fill(s.3 ? Self.lavender.opacity(0.3) : Color.white.opacity(0.30))
                .frame(width: s.2 * 2, height: s.2 * 2)
                .position(x: geo.size.width * s.0, y: geo.size.height * s.1)
        }
        .allowsHitTesting(false)
    }
}
