// PlaneReceiptAnimation.swift
// Pointward › Instruments › Plane
//
// ACT 3 of 3 — the full-screen PLANE receipt + emoji reveal.
//
// A paper plane flies in from the left across the sky, banks nose-up, the
// cockpit opens and the emoji DROPS — falling gently into the wooden bucket
// waiting lower-right — then blooms into the shared EmojiRevealView.
//
//   FLIGHT (0.0–3.0s)  enters left, crosses at y≈0.28h, sparkle trail
//   DROP   (3.0–3.5s)  banks up, cockpit opens, emoji separates
//   FALL   (3.5–4.5s)  emoji falls toward the bucket, gold glow trail
//   CATCH  (4.5–5.0s)  bounces into the bucket, bucket glows cyan
//   → EmojiRevealView (.received, .plane)                                = 5.0s
//
// Screen-coordinate rules: GeometryReader root, daySky.ignoresSafeArea(), every
// position from geo.size.

import SwiftUI

struct PlaneReceiptAnimation: View {

    let senderBearing: Double            // unused — the plane flies in from the left
    let emoji: String
    var message: String? = nil
    var tagline: String? = nil
    let fromName: String
    var onRevealed: () -> Void = {}
    var onFinished: () -> Void = {}

    static let duration: Double = InstrumentBoundaries.Receipt.plane   // 5.0

    private static let flightEnd: Double = 3.0
    private static let dropEnd:   Double = 3.5
    private static let fallEnd:   Double = 4.5
    private static let total:     Double = InstrumentBoundaries.Receipt.plane   // 5.0

    private static let planeW: CGFloat = 132
    private static let planeH: CGFloat = 70
    private static let bucketW: CGFloat = 150
    private static let bucketH: CGFloat = 128
    private static let gold = Color(hex: "#f0d060")

    @State private var start: Date? = nil
    @State private var skyIn = false
    @State private var revealing = false
    @State private var bucketGlow = false
    @State private var droppedSound = false
    @State private var caughtSound = false

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
                            Color(hex: "#0d0d14").ignoresSafeArea()
                            InstrumentBackground.daySky.ignoresSafeArea().opacity(skyIn ? 1 : 0)

                            bucket(geo: geo)
                            sparkleTrail(geo: geo, elapsed: e)
                            emojiFallGlow(geo: geo, elapsed: e)
                            plane(geo: geo, elapsed: e)
                            fallingEmoji(geo: geo, elapsed: e)

                            VStack {
                                Spacer()
                                Text(message(e))
                                    .font(.system(size: 20, design: .serif).italic())
                                    .foregroundColor(InstrumentBackground.accentText)
                                    .shadow(color: .black.opacity(0.4), radius: 6)
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
        withAnimation(.easeInOut(duration: 0.3)) { skyIn = true }
        HapticPattern.singleSoft.fire()

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.dropEnd) {
            InstrumentSoundPlayer.shared.playCue(file: PlaneSounds.dropFile, duration: 0.35)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.fallEnd) {
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
        CGPoint(x: size.width * 0.68, y: size.height - 105)
    }

    // ── The plane (flight + bank) ────────────────────────────────────────────

    @ViewBuilder
    private func plane(geo: GeometryProxy, elapsed e: Double) -> some View {
        if e <= Self.dropEnd {
            let pos = planePos(geo.size, e)
            let banking = e > Self.flightEnd
            PlaneGlyph(emoji: planeCarriesEmoji(e) ? emoji : nil)
                .frame(width: Self.planeW, height: Self.planeH)
                .rotationEffect(.degrees(banking ? -14 : sin(e * 2.2) * 2))
                .position(pos)
                .opacity(e > Self.dropEnd - 0.1 ? 0.7 : 1)
        }
    }

    /// Plane carries the emoji until it separates at the drop.
    private func planeCarriesEmoji(_ e: Double) -> Bool { e < Self.flightEnd + 0.15 }

    private func planePos(_ size: CGSize, _ e: Double) -> CGPoint {
        let y = size.height * 0.28
        if e <= Self.flightEnd {
            let p = e / Self.flightEnd
            let x = -size.width * 0.1 + (size.width * 0.78) * CGFloat(p)
            return CGPoint(x: x, y: y)
        } else {
            // BANK — eases to a stop, nose up, near the drop point.
            let p = easeOut((e - Self.flightEnd) / (Self.dropEnd - Self.flightEnd))
            let x = size.width * 0.68
            return CGPoint(x: (size.width * 0.68) + (x - size.width * 0.68) * 0, y: y - CGFloat(p) * 8)
        }
    }

    // ── Falling emoji ─────────────────────────────────────────────────────────

    @ViewBuilder
    private func fallingEmoji(geo: GeometryProxy, elapsed e: Double) -> some View {
        if e > Self.flightEnd {
            let pos = fallPos(geo.size, e)
            Text(emoji).font(.system(size: 56)).position(pos)
        }
    }

    private func fallPos(_ size: CGSize, _ e: Double) -> CGPoint {
        let from = CGPoint(x: size.width * 0.68, y: size.height * 0.28)
        let bucket = bucketPoint(size)
        let landY = bucket.y - 28
        if e <= Self.fallEnd {
            let p = easeIn((e - Self.flightEnd) / (Self.fallEnd - Self.flightEnd))
            return CGPoint(x: from.x, y: from.y + (landY - from.y) * CGFloat(p))
        } else {
            // CATCH — a small bounce settling into the bucket mouth.
            let p = (e - Self.fallEnd) / (Self.total - Self.fallEnd)
            let bounce = sin(p * .pi) * 14
            return CGPoint(x: from.x, y: landY - CGFloat(bounce))
        }
    }

    @ViewBuilder
    private func emojiFallGlow(geo: GeometryProxy, elapsed e: Double) -> some View {
        if e > Self.flightEnd && e <= Self.fallEnd {
            let pos = fallPos(geo.size, e)
            Capsule()
                .fill(LinearGradient(colors: [Self.gold.opacity(0.5), .clear],
                                     startPoint: .bottom, endPoint: .top))
                .frame(width: 18, height: 70)
                .position(x: pos.x, y: pos.y - 40)
                .blur(radius: 3)
                .allowsHitTesting(false)
        }
    }

    // ── Sparkle trail behind the plane ───────────────────────────────────────

    @ViewBuilder
    private func sparkleTrail(geo: GeometryProxy, elapsed e: Double) -> some View {
        let count = 24
        ForEach(0..<count, id: \.self) { k in
            let tb = e - Double(k) * 0.05
            if tb > 0 && tb <= Self.flightEnd {
                let frac = Double(k) / Double(count)
                let p = planePos(geo.size, tb)
                let jy = CGFloat(sin(tb * 11 + Double(k))) * 10
                let isGold = k % 2 == 0
                Circle()
                    .fill(isGold ? Self.gold : Color.white)
                    .frame(width: 2.5 - CGFloat(frac) * 1.0, height: 2.5 - CGFloat(frac) * 1.0)
                    .opacity((1 - frac) * 0.8)
                    .position(x: p.x - Self.planeW * 0.4, y: p.y + jy)
                    .allowsHitTesting(false)
            }
        }
    }

    // ── The bucket (shared wooden skin) + catch glow ─────────────────────────

    private func bucket(geo: GeometryProxy) -> some View {
        let p = bucketPoint(geo.size)
        let wood = Color(hex: "#8B4513"); let woodDark = Color(hex: "#6E3A1E")
        let brass = Color(hex: "#C9A86A")
        return ZStack {
            // cyan catch radiance inside
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
        if e < Self.flightEnd { return "\(name) sent something ✦" }
        if e < Self.fallEnd   { return "here it comes ✦" }
        return "caught it ✦"
    }

    private func easeIn(_ t: Double) -> Double  { let x = min(max(t, 0), 1); return x * x }
    private func easeOut(_ t: Double) -> Double { let x = min(max(t, 0), 1); return 1 - pow(1 - x, 3) }
}
