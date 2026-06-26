// BowReceiptAnimationV2.swift
// Pointward › Instruments › Bow
//
// ACT 3 of 3 — the full-screen BOW receipt + emoji reveal (visual bible Screen 4).
//
// A luminous gold arrow arcs in from the upper-left across a dark navy NIGHT sky
// and STICKS into the wooden bucket at impact — it does NOT dissolve and does
// NOT reposition. The emoji then DROPS off the stuck shaft down into the bucket
// mouth; the bucket glows LAVENDER (the bow world's colour, not cyan); the emoji
// settles visible inside, then blooms into the shared EmojiRevealView.
//
//   FLIGHT (0.0–2.4s)  arrow arcs in (single bezier), emoji on the shaft
//   STICK  (2.4s)      arrow embeds in the bucket and FREEZES (thunk)
//   DROP   (2.4–3.0s)  the emoji falls off the shaft into the bucket mouth
//   LAND   (3.0–3.5s)  lavender glow; emoji visible in the bucket
//   BLOOM  (3.5s+)     → EmojiRevealView (.received, .bow)             = 3.5s

import SwiftUI

struct BowReceiptAnimationV2: View {

    let senderBearing: Double
    let emoji: String
    var message: String? = nil
    var tagline: String? = nil
    let fromName: String
    var onRevealed: () -> Void = {}
    var onFinished: () -> Void = {}
    /// [catch-bucket-removed-2026-06] DEFAULT false = live (no bucket; landing re-centers to the
    /// reveal focal point — Decision X). Only the Animation Lab passes `true` to render the
    /// preserved bucket animation. Never accidentally re-enabled without an explicit Lab call.
    var showBucket: Bool = false

    static let duration: Double = InstrumentBoundaries.Receipt.bow   // 3.5

    private static let arriveT: Double = 2.4     // arrow sticks
    private static let dropEnd: Double = 3.0     // emoji finishes dropping in
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
    @State private var stuck = false             // arrow embedded + frozen
    @State private var emojiDrop: CGFloat = 0    // 0 on shaft → 1 in bucket
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
                            if showBucket { bucket(geo: geo) }   // [catch-bucket-removed-2026-06] was: bucket(geo: geo)
                            sparkleBurst(geo: geo)
                            arrow(geo: geo, elapsed: e)        // sticks + freezes
                            fallingEmoji(geo: geo)
                            if emojiInBucket {
                                Text(emoji).font(.system(size: 40)).position(bucketMouth(geo.size))
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
        // STICK — the arrow embeds (thunk) and freezes; the emoji starts dropping.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.arriveT) {
            stuck = true
            InstrumentSoundPlayer.shared.playCue(file: BowSounds.receiptFile,
                                                 duration: BowSounds.receiptDuration)
            HapticPattern.singleSoft.fire()
            withAnimation(.easeOut(duration: 0.4)) { burst = true }      // small gold spark
            withAnimation(.easeIn(duration: Self.dropEnd - Self.arriveT)) { emojiDrop = 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.dropEnd) {
            HapticPattern.doubleSoft.fire()
            withAnimation(.easeOut(duration: 0.4)) { glow = true }       // lavender glow
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
        // [catch-bucket-removed-2026-06] bucketless (live) → re-center: the arrow stick + emoji
        // drop both derive from this point, so the whole landing retargets to the reveal focal
        // point. Bucket position kept for the Lab (showBucket).
        showBucket ? CGPoint(x: size.width * 0.73, y: size.height - 145)
                   : CGPoint(x: size.width / 2,  y: size.height * 0.46)
    }
    private func bucketMouth(_ size: CGSize) -> CGPoint {
        let p = bucketPoint(size); return CGPoint(x: p.x, y: p.y - Self.bucketH * 0.30)
    }
    /// Where the arrow's centre comes to rest (up-left of the bucket so the tip
    /// embeds in the rim and the shaft sticks out — the emoji rides this point).
    private func stickPoint(_ size: CGSize) -> CGPoint {
        let p = bucketPoint(size); return CGPoint(x: p.x - 24, y: p.y - Self.bucketH * 0.66)
    }

    // ── The arrow (arcs in, then STICKS frozen) ──────────────────────────────

    @ViewBuilder
    private func arrow(geo: GeometryProxy, elapsed e: Double) -> some View {
        let p = stuck ? 1 : min(1, e / Self.arriveT)
        let pos = bezier(geo.size, p)
        let ahead = bezier(geo.size, min(1, p + 0.02))
        let behind = bezier(geo.size, max(0, p - 0.02))
        let angle = atan2(ahead.y - behind.y, ahead.x - behind.x) * 180 / .pi
        ZStack {
            if !stuck {
                // short gold trail (4 dots increasing opacity) — flight only
                ForEach(0..<4, id: \.self) { i in
                    let f = Double(i) / 3
                    let bp = bezier(geo.size, max(0, p - CGFloat(1 - f) * 0.06))
                    Circle().fill(Self.gold).frame(width: 2 + CGFloat(f) * 2, height: 2 + CGFloat(f) * 2)
                        .opacity(0.15 + f * 0.5).position(bp)
                }
            }
            // The arrow itself: carries the emoji in flight; once stuck it stays
            // solid (NO dissolve) and drops the emoji separately.
            BowArrowGlyph(emoji: stuck ? nil : emoji)
                .frame(width: Self.arrowW, height: Self.arrowH)
                .rotationEffect(.degrees(angle))
                .position(stuck ? stickPoint(geo.size) : pos)
        }
        .allowsHitTesting(false)
    }

    /// start: left edge 35% height · control: centre 20% height · end: stickPoint.
    private func bezier(_ size: CGSize, _ p: CGFloat) -> CGPoint {
        let s = CGPoint(x: -size.width * 0.05, y: size.height * 0.35)
        let c = CGPoint(x: size.width * 0.5, y: size.height * 0.20)
        let end = stickPoint(size)
        let mp = 1 - p
        return CGPoint(x: mp * mp * s.x + 2 * mp * p * c.x + p * p * end.x,
                       y: mp * mp * s.y + 2 * mp * p * c.y + p * p * end.y)
    }

    // ── The emoji dropping off the stuck shaft into the bucket ───────────────

    @ViewBuilder
    private func fallingEmoji(geo: GeometryProxy) -> some View {
        if stuck && !emojiInBucket {
            let from = stickPoint(geo.size)
            let to = bucketMouth(geo.size)
            let p = easeIn(Double(emojiDrop))
            let pos = CGPoint(x: from.x + (to.x - from.x) * CGFloat(p),
                              y: from.y + (to.y - from.y) * CGFloat(p))
            Text(emoji).font(.system(size: 40)).position(pos)
        }
    }

    @ViewBuilder
    private func sparkleBurst(geo: GeometryProxy) -> some View {
        if burst {
            let m = stickPoint(geo.size)
            ForEach(0..<7, id: \.self) { i in
                let a = (Double(i) / 7) * 2 * .pi - .pi / 2
                Circle().fill(i % 2 == 0 ? Self.gold : Self.goldHi)
                    .frame(width: 3.5, height: 3.5)
                    .position(m)
                    .offset(x: burst ? CGFloat(cos(a)) * 44 : 0,
                            y: burst ? CGFloat(sin(a)) * 44 : 0)
                    .opacity(burst ? 0 : 0.9)
                    .animation(.easeOut(duration: 0.7), value: burst)
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

    private func easeIn(_ t: Double) -> Double { let x = min(max(t, 0), 1); return x * x }
}
