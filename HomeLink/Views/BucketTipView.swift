// BucketTipView.swift
// Pointward › Views
//
// THE BUCKET TIP — an 800 ms preamble before a replay. The bucket tilts,
// spills its thought-bubbles out into the air, and rights itself empty and
// ready, so the replay's instrument landing has somewhere to arrive. A small
// flourish that makes a replay feel like reliving the moment fresh.
//
//   PHASE 1 · TILT   (300 ms)  rotation 0° → -35° easeInOutSine · medium tap
//   PHASE 2 · SPILL  (300 ms)  bubbles fly out (staggered) · bucket → -45°
//   PHASE 3 · RETURN (200 ms)  rotation -45° → 0° easeOutBack (overshoots)
//
// Reuses BucketShape / BucketHandleShape from BucketCatchView.

import SwiftUI

struct BucketTipView: View {
    /// The hue of the thought being replayed — tints the spilling bubbles.
    var hue: Color = Color(hex: "#c4a8d4")
    /// One bubble carries the replayed emoji; the rest are faded memories.
    var bubbleEmoji: String = ""
    var onComplete: () -> Void = {}

    @State private var rotation: Double = 0
    @State private var spilled = false

    private static let wood     = Color(hex: "#8B4513")
    private static let woodDark = Color(hex: "#6E3A1E")
    private static let band     = Color(hex: "#888888")

    private struct Bubble: Identifiable {
        let id = UUID()
        let rest: CGSize
        let fly: CGSize
        let delay: Double
        let carriesEmoji: Bool
    }
    // Four bubbles nestled in the bucket, each spilling up-and-out.
    private let bubbles: [Bubble] = [
        Bubble(rest: CGSize(width: -20, height: 26),  fly: CGSize(width: -95, height: -185), delay: 0.00, carriesEmoji: true),
        Bubble(rest: CGSize(width:  12, height: 34),  fly: CGSize(width:  72, height: -205), delay: 0.03, carriesEmoji: false),
        Bubble(rest: CGSize(width:  -6, height: 16),  fly: CGSize(width: -42, height: -160), delay: 0.06, carriesEmoji: false),
        Bubble(rest: CGSize(width:  24, height: 24),  fly: CGSize(width: 112, height: -150), delay: 0.09, carriesEmoji: false),
    ]

    var body: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let cy = geo.size.height * 0.55
            ZStack {
                // Spilling bubbles — fly out, shrink and fade
                ForEach(bubbles) { b in
                    Circle()
                        .fill(RadialGradient(colors: [hue.opacity(0.55), hue.opacity(0.18)],
                                             center: .center, startRadius: 2, endRadius: 24))
                        .frame(width: 46, height: 46)
                        .overlay(
                            Group {
                                if b.carriesEmoji && !bubbleEmoji.isEmpty {
                                    Text(bubbleEmoji).font(.system(size: 22))
                                }
                            }
                        )
                        .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
                        .scaleEffect(spilled ? 0.3 : 1.0)
                        .opacity(spilled ? 0 : 1)
                        .offset(x: spilled ? b.fly.width : b.rest.width,
                                y: spilled ? b.fly.height : b.rest.height)
                        .animation(.easeOut(duration: 0.3).delay(b.delay), value: spilled)
                        .position(x: cx, y: cy - 10)
                }

                // The bucket — tilts on its base
                bucket
                    .rotationEffect(.degrees(rotation), anchor: .bottom)
                    .position(x: cx, y: cy)
            }
            .onAppear { run() }
        }
    }

    private var bucket: some View {
        ZStack {
            BucketHandleShape()
                .stroke(Self.band, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 170, height: 60)
                .offset(y: -100)
            BucketShape()
                .fill(LinearGradient(colors: [Self.wood, Self.woodDark],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 180, height: 160)
                .overlay(
                    VStack {
                        Capsule().fill(Self.band).frame(height: 6).padding(.top, 12)
                        Spacer()
                        Capsule().fill(Self.band).frame(height: 6).padding(.bottom, 16)
                    }
                    .frame(width: 180, height: 160)
                    .opacity(0.85)
                )
                .shadow(color: .black.opacity(0.4), radius: 10, y: 6)
        }
    }

    private func run() {
        // PHASE 1 · TILT (300 ms)
        HapticEngine.lockOn()
        withAnimation(AnimationSystem.easeInOutSine(0.3)) { rotation = -35 }

        // PHASE 2 · SPILL (300 ms) — bubbles fly out, bucket tips further
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeIn(duration: 0.3)) { rotation = -45 }
            spilled = true
        }

        // PHASE 3 · RETURN (200 ms) — rights itself, easeOutBack overshoots
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            HapticEngine.sendSoft()
            withAnimation(AnimationSystem.easeOutBack(0.2)) { rotation = 0 }
        }

        // Done — hand off to the replay's instrument landing.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { onComplete() }
    }
}
