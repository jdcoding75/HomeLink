// PlaneReceiptAnimation.swift
// Pointward › Instruments › Plane
//
// ACT 3 of 3 — the V1 PLANE receipt (visual bible: the "coming-at-you" flight).
//
// THE UNIQUE MECHANIC: the plane flies TOWARD the viewer, not across the screen.
// It starts small high on the dark night sky, grows as it accelerates toward
// the camera, overflies (exiting the bottom of the screen), and RELEASES the
// emoji — which then falls into the wooden bucket waiting lower-right, swaying
// gently, before blooming into the shared EmojiRevealView.
//
//   APPROACH (0.0–3.5s)  plane scale 0.4→1.6, drifts toward lower-centre,
//                        plane_approach.wav, emoji in cockpit
//   OVERFLIGHT (3.5–4.2s) scale 1.6→2.2, exits the bottom, plane_drop.wav,
//                        emoji separates and keeps falling
//   FALL (4.2–5.5s)      emoji falls to the bucket, gold sparkle trail, ±8pt
//                        sway; CATCH → cyan bucket glow, plane_catch.wav
//   → EmojiRevealView (.received, .plane)                                = 5.5s
//
// Screen-coordinate rules (all 6): GeometryReader root, dark sky
// .ignoresSafeArea(), positions from geo.size, bucket bx=width-80·by=height-95.

import SwiftUI

struct PlaneReceiptAnimation: View {

    let senderBearing: Double            // unused — the plane flies toward the viewer
    let emoji: String
    var message: String? = nil
    var tagline: String? = nil
    let fromName: String
    var onRevealed: () -> Void = {}
    var onFinished: () -> Void = {}

    static let duration: Double = 5.5

    private static let approachEnd: Double = 3.5
    private static let overEnd:     Double = 4.2
    private static let total:       Double = 5.5

    private static let skyTop    = Color(hex: "#1a2d4a")
    private static let skyBottom = Color(hex: "#080e1e")
    private static let gold      = Color(hex: "#d4a030")
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

                            bucket(geo: geo)
                            emojiFallGlow(geo: geo, elapsed: e)
                            plane(geo: geo, elapsed: e)
                            fallingEmoji(geo: geo, elapsed: e)

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
        InstrumentSoundPlayer.shared.playCue(file: PlaneSounds.approachFile, duration: 3.0)
        withAnimation(.easeInOut(duration: 0.3)) { skyIn = true }
        HapticPattern.singleSoft.fire()

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.approachEnd) {
            InstrumentSoundPlayer.shared.playCue(file: PlaneSounds.dropFile, duration: 0.35)
            HapticEngine.send()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (Self.total - 0.7)) {
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
        CGPoint(x: size.width - 80, y: size.height - 95)
    }

    // ── The plane growing toward the viewer ──────────────────────────────────

    @ViewBuilder
    private func plane(geo: GeometryProxy, elapsed e: Double) -> some View {
        if e <= Self.overEnd {
            let pos = planePos(geo.size, e)
            let scale = planeScale(e)
            let carries = e < Self.approachEnd + 0.05
            PlaneTopDownGlyph(emoji: carries ? emoji : nil)
                .frame(width: 96, height: 116)
                .rotationEffect(.degrees(180))         // nose-down: flying toward us
                .scaleEffect(scale)
                .position(pos)
                .opacity(e > Self.overEnd - 0.15 ? 0.55 : 1)
                .allowsHitTesting(false)
        }
    }

    /// Small high → large low; accelerates toward the camera (easeIn), then
    /// blows past full size as it overflies.
    private func planeScale(_ e: Double) -> CGFloat {
        if e <= Self.approachEnd {
            let p = easeIn(e / Self.approachEnd)
            return 0.4 + CGFloat(p) * 1.2                       // 0.4 → 1.6
        } else {
            let p = (e - Self.approachEnd) / (Self.overEnd - Self.approachEnd)
            return 1.6 + CGFloat(min(p, 1)) * 0.6               // 1.6 → 2.2
        }
    }

    private func planePos(_ size: CGSize, _ e: Double) -> CGPoint {
        let startP = CGPoint(x: size.width * 0.5, y: size.height * 0.26)
        if e <= Self.approachEnd {
            let p = easeIn(e / Self.approachEnd)
            // drifts slightly toward lower-centre as it grows
            return CGPoint(x: size.width * 0.5,
                           y: startP.y + (size.height * 0.50 - startP.y) * CGFloat(p))
        } else {
            // OVERFLIGHT — accelerates off the bottom of the screen
            let p = (e - Self.approachEnd) / (Self.overEnd - Self.approachEnd)
            return CGPoint(x: size.width * 0.5,
                           y: size.height * 0.50 + CGFloat(p) * size.height * 0.75)
        }
    }

    // ── The released emoji falling to the bucket ──────────────────────────────

    @ViewBuilder
    private func fallingEmoji(geo: GeometryProxy, elapsed e: Double) -> some View {
        if e > Self.approachEnd {
            let pos = fallPos(geo.size, e)
            Text(emoji).font(.system(size: 56)).position(pos)
                .allowsHitTesting(false)
        }
    }

    private func fallPos(_ size: CGSize, _ e: Double) -> CGPoint {
        let from = CGPoint(x: size.width * 0.5, y: size.height * 0.50)
        let bucket = bucketPoint(size)
        let landY = bucket.y - 28
        let fallStart = Self.approachEnd
        let fallSpan  = Self.total - fallStart
        let raw = (e - fallStart) / fallSpan
        let p = easeIn(min(raw, 1))
        let x = from.x + (bucket.x - from.x) * CGFloat(p)
        let sway = CGFloat(sin((e - fallStart) * 6)) * 8 * CGFloat(1 - p)   // ±8pt, settling
        let y = from.y + (landY - from.y) * CGFloat(p)
        return CGPoint(x: x + sway, y: min(y, landY))
    }

    @ViewBuilder
    private func emojiFallGlow(geo: GeometryProxy, elapsed e: Double) -> some View {
        if e > Self.approachEnd && e < Self.total - 0.4 {
            let pos = fallPos(geo.size, e)
            Capsule()
                .fill(LinearGradient(colors: [Self.gold.opacity(0.5), .clear],
                                     startPoint: .bottom, endPoint: .top))
                .frame(width: 18, height: 70)
                .position(x: pos.x, y: pos.y - 42)
                .blur(radius: 3)
                .allowsHitTesting(false)
        }
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
        if e < Self.approachEnd { return "\(name) is flying in ✦" }
        if e < Self.total - 0.7 { return "here it comes ✦" }
        return "caught it ✦"
    }

    private func easeIn(_ t: Double) -> Double { let x = min(max(t, 0), 1); return x * x }
}
