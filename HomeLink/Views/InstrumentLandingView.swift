// InstrumentLandingView.swift
// Pointward › Views
//
// THE LANDING — dramatic per-instrument arrival animations for the receipt.
// The receive should feel as special as the send: full screen, dramatic,
// emotional. Each instrument arrives from the sender's direction, grows as it
// approaches, lands with the most satisfying haptic in the app, and the emoji
// emerges. `onComplete` fires once the emoji has fully emerged so the parent
// (ReceiptView / ReplayOverlayView) can show the reveal text.
//
// All programmatic SwiftUI — no assets. Reuses the instrument shapes.

import SwiftUI

struct InstrumentLandingView: View {
    let style: SenderStyle
    let emoji: String
    var onComplete: () -> Void = {}

    var body: some View {
        GeometryReader { geo in
            ZStack {
                switch style {
                case .rocket:       RocketLanding(emoji: emoji, size: geo.size, onComplete: onComplete)
                case .firefly:      LeafLanding(emoji: emoji, size: geo.size, onComplete: onComplete)
                case .fingerFlick:  PostItLanding(emoji: emoji, size: geo.size, onComplete: onComplete)
                case .bowArrow:     ArrowLanding(emoji: emoji, size: geo.size, onComplete: onComplete)
                case .wand:         WandLanding(emoji: emoji, size: geo.size, onComplete: onComplete)
                case .plane:        PlaneLanding(emoji: emoji, size: geo.size, onComplete: onComplete)
                default:            OrbLanding(emoji: emoji, size: geo.size, onComplete: onComplete)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

// ════════════════════════════════════════════════════════════════════════
// MARK: - Shared helpers
// ════════════════════════════════════════════════════════════════════════

/// The emoji rising out of the instrument — tiny → large with a warm glow.
private struct EmergingEmoji: View {
    let emoji: String
    let hue: Color
    let scale: CGFloat
    var body: some View {
        ZStack {
            Circle().fill(hue.opacity(0.35 * Double(min(1, scale))))
                .frame(width: 225, height: 225).blur(radius: 44)   // [5/5] 50% bigger
            Text(emoji).font(.system(size: 108))                    // [5/5] 50% bigger
                .scaleEffect(scale)
                .shadow(color: hue.opacity(0.7), radius: 28)
        }
    }
}

private func hueFor(_ emoji: String) -> Color { EmojiHue.color(for: emoji) }

// ════════════════════════════════════════════════════════════════════════
// MARK: - [1/7] ROCKET LANDING 🚀
// ════════════════════════════════════════════════════════════════════════

private struct RocketLanding: View {
    let emoji: String; let size: CGSize; var onComplete: () -> Void

    @State private var descend: CGFloat = 0      // 0 top → 1 landed
    @State private var grow: CGFloat = 0.3
    @State private var legs: CGFloat = 0         // landing legs out
    @State private var hover = false             // hover flames
    @State private var shake: CGFloat = 0
    @State private var flash = false
    @State private var dust = false
    @State private var noseOpen: CGFloat = 0     // nose cone split
    @State private var bounce: CGFloat = 1
    @State private var emojiScale: CGFloat = 0
    @State private var emojiUp: CGFloat = 0

    private static let orange = Color(hex: "#e0622c")
    private static let amber  = Color(hex: "#e08a3c")

    var body: some View {
        let cx = size.width / 2
        let topY = size.height * 0.12
        let padY = size.height * 0.74
        let y = topY + (padY - topY) * descend
        ZStack {
            Color.white.opacity(flash ? 0.3 : 0).ignoresSafeArea().allowsHitTesting(false)

            // dust burst at the pad
            if dust {
                ForEach(0..<20, id: \.self) { i in
                    let a = Double(i) / 20 * 2 * .pi
                    Circle().fill(Color(hex: "#9a8f80").opacity(0.6))
                        .frame(width: 8, height: 8)
                        .offset(x: CGFloat(cos(a)) * 120, y: CGFloat(sin(a)) * 50)
                        .opacity(0)
                        .animation(.easeOut(duration: 1.0), value: dust)
                        .position(x: cx, y: padY + 60)
                }
            }
            // landing pad
            RoundedRectangle(cornerRadius: 4).fill(Color(hex: "#5e5e5e"))
                .frame(width: 120, height: 12).position(x: cx, y: padY + 64)

            rocket
                .scaleEffect(grow * bounce)
                .offset(x: shake)
                .position(x: cx, y: y)

            EmergingEmoji(emoji: emoji, hue: hueFor(emoji), scale: emojiScale)
                .offset(y: -emojiUp)
                .position(x: cx, y: y - 70)
        }
        .onAppear { run(padY: padY) }
    }

    private var rocket: some View {
        ZStack {
            // hover/landing flames at the base
            FlameShape().fill(LinearGradient(colors: [Self.amber, Self.orange, .clear],
                                             startPoint: .top, endPoint: .bottom))
                .frame(width: 22, height: hover ? 26 : 56)
                .offset(y: 86)
                .opacity(noseOpen > 0 ? 0 : 1)
            // landing legs
            ForEach([-1.0, 1.0], id: \.self) { side in
                Rectangle().fill(Color(hex: "#8a8a8a"))
                    .frame(width: 3, height: 24 * legs)
                    .rotationEffect(.degrees(side > 0 ? 28 : -28))
                    .offset(x: CGFloat(side) * 22, y: 78)
            }
            // body (split into two halves at the nose when delivering)
            RocketBodyShape().fill(LinearGradient(colors: [.white, Color(hex: "#b8b8c2")],
                                                  startPoint: .leading, endPoint: .trailing))
                .frame(width: 56, height: 150)
                .overlay(RocketNoseShape().fill(Color(hex: "#9a9aa6"))
                    .frame(width: 56, height: 150)
                    .scaleEffect(x: 1 - noseOpen, anchor: .center)
                    .offset(x: -noseOpen * 26))
                .overlay(RocketNoseShape().fill(Color(hex: "#9a9aa6"))
                    .frame(width: 56, height: 150)
                    .scaleEffect(x: noseOpen, anchor: .center)
                    .offset(x: noseOpen * 26).opacity(noseOpen))
                .overlay(ZStack {
                    ForEach([-1.0, 1.0], id: \.self) { side in
                        RocketFinShape(mirrored: side > 0).fill(Self.orange)
                            .frame(width: 22, height: 34).offset(x: CGFloat(side) * 27, y: 56)
                    }
                })
        }
        .frame(width: 110, height: 200)
    }

    private func run(padY: CGFloat) {
        // ARRIVAL — descends and grows
        withAnimation(.easeIn(duration: 2.0)) { descend = 0.8; grow = 1.0 }
        for k in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6 + Double(k) * 0.4) {
                HapticEngine.rocketCountdown(); jitter()
            }
        }
        // DESCENT — legs deploy, switch to hover
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(AnimationSystem.easeOutBack(0.4)) { legs = 1 }
            hover = true
            SoundEngine.shared.play(for: "rocket.landing")
        }
        // TOUCHDOWN
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            withAnimation(.easeIn(duration: 0.3)) { descend = 1 }
            HapticEngine.rocketLaunch()              // BOOM
            SoundEngine.shared.play(for: "rocket.blast")
            dust = true
            withAnimation(.easeOut(duration: 0.08)) { flash = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.2)) { flash = false }
            }
            withAnimation(AnimationSystem.easeOutBack(0.4)) { bounce = 1.05 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(AnimationSystem.easeOutBack(0.3)) { bounce = 1.0 }
            }
        }
        // DELIVERY — nose opens, emoji rises
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.9) {
            withAnimation(AnimationSystem.easeOutBack(0.5)) { noseOpen = 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.3) {
            HapticEngine.catchReveal()
            withAnimation(AnimationSystem.easeOutBack(0.5)) { emojiScale = 1; emojiUp = 40 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { onComplete() }
    }

    private func jitter() {
        withAnimation(.spring(response: 0.1, dampingFraction: 0.3)) { shake = CGFloat.random(in: -3...3) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { shake = 0 }
        }
    }
}

// ════════════════════════════════════════════════════════════════════════
// MARK: - [2/7] WIND / LEAF LANDING 🌬️
// ════════════════════════════════════════════════════════════════════════

private struct LeafLanding: View {
    let emoji: String; let size: CGSize; var onComplete: () -> Void

    @State private var drift: CGFloat = 0        // 0 edge → 1 center
    @State private var grow: CGFloat = 0.3
    @State private var sway = false
    @State private var tip = false
    @State private var emojiScale: CGFloat = 0
    @State private var emojiUp: CGFloat = 0
    @State private var leafGone = false
    @State private var seedSwirl = false

    var body: some View {
        let cx = size.width / 2
        let startX = size.width * 0.18, startY = size.height * 0.18
        let endX = cx, endY = size.height * 0.55
        let x = startX + (endX - startX) * drift
        let y = startY + (endY - startY) * drift
        ZStack {
            // seed trail
            ForEach(0..<22, id: \.self) { i in
                let t = max(0, drift - CGFloat(i) * 0.03)
                let sx = startX + (endX - startX) * t
                let sy = startY + (endY - startY) * t
                let orbit = seedSwirl ? CGFloat(sin(Double(i) + drift * 6)) * 16 : 0
                DandelionSeed(size: 8, opacity: 0.7)
                    .position(x: sx + orbit, y: sy + CGFloat(cos(Double(i))) * 8)
            }
            // the leaf carrying the emoji
            ZStack {
                LeafShape().fill(Color(hex: "#5a8a3a")).frame(width: 72, height: 50)
                Text(emoji).font(.system(size: 30)).offset(y: -6)
            }
            .rotationEffect(.degrees(tip ? 24 : (sway ? 8 : -8)))
            .scaleEffect(grow)
            .opacity(leafGone ? 0 : 1)
            .position(x: x + (sway ? 8 : -8), y: y)

            EmergingEmoji(emoji: emoji, hue: hueFor(emoji), scale: emojiScale)
                .offset(y: -emojiUp)
                .position(x: endX, y: endY - 30)
        }
        .onAppear { run(endX: endX, endY: endY) }
    }

    private func run(endX: CGFloat, endY: CGFloat) {
        withAnimation(AnimationSystem.easeInOutSine(0.8).repeatForever(autoreverses: true)) { sway = true }
        withAnimation(.easeInOut(duration: 3.0)) { drift = 0.85; grow = 1.0 }
        // APPROACH — seeds swirl, soft pulse
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            seedSwirl = true
            HapticEngine.windBreath()
        }
        // LANDING — leaf tips, emoji lifts off
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.2) {
            withAnimation(.easeInOut(duration: 0.6)) { drift = 1; tip = true }
            HapticEngine.windSend()
            SoundEngine.shared.play(for: "style.chime")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.8) {
            withAnimation(AnimationSystem.easeOutBack(0.6)) { emojiScale = 1; emojiUp = 36 }
            withAnimation(.easeOut(duration: 1.4)) { leafGone = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.6) { onComplete() }
    }
}

// ════════════════════════════════════════════════════════════════════════
// MARK: - [3/7] FLICK / POST-IT LANDING 👆
// ════════════════════════════════════════════════════════════════════════

private struct PostItLanding: View {
    let emoji: String; let size: CGSize; var onComplete: () -> Void

    @State private var fly: CGFloat = 0
    @State private var spin: Double = 0
    @State private var grow: CGFloat = 0.3
    @State private var pinned = false
    @State private var pin: CGFloat = 0
    @State private var shake: CGFloat = 0
    @State private var vibrate: CGFloat = 0
    @State private var dust = false
    @State private var emojiScale: CGFloat = 0
    @State private var emojiUp: CGFloat = 0
    @State private var cornerLift = false

    var body: some View {
        let cx = size.width / 2
        let startX = size.width * 0.2, startY = size.height * 0.2
        let endX = cx, endY = size.height * 0.5
        let x = startX + (endX - startX) * fly
        let y = startY + (endY - startY) * fly
        ZStack {
            if dust {
                // Cork dust bursts outward from the pin strike.
                ForEach(0..<18, id: \.self) { i in
                    let a = Double(i) / 18 * 2 * .pi
                    Circle().fill(Color(hex: "#B8835A").opacity(0.75))
                        .frame(width: CGFloat(3 + i % 3), height: CGFloat(3 + i % 3))
                        .offset(x: CGFloat(cos(a)) * CGFloat(18 + i % 5 * 6),
                                y: CGFloat(sin(a)) * CGFloat(14 + i % 4 * 5))
                        .opacity(0).animation(.easeOut(duration: 0.7), value: dust)
                        .position(x: endX, y: endY - 22)
                }
            }
            // the post-it note
            ZStack {
                PaperNoteShape().fill(LinearGradient(colors: [Color(hex: "#FFEB3B"), Color(hex: "#FFD600")],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 90, height: 98)
                    .overlay(PaperFoldShape().fill(Color(hex: "#F0C800")).frame(width: 90, height: 98))
                    .overlay(Text(emoji).font(.system(size: 46)))
                    .shadow(color: .black.opacity(0.3), radius: pinned ? 3 : 6, y: 3)
                // the pin — shoots through with a 1.3 overshoot
                ZStack {
                    Circle().fill(Color.black.opacity(0.25)).frame(width: 15, height: 15).offset(y: 1)
                    Circle().fill(RadialGradient(colors: [Color(hex: "#FF5533"), Color(hex: "#CC2200")],
                                                 center: UnitPoint(x: 0.35, y: 0.3), startRadius: 1, endRadius: 7))
                        .frame(width: 14, height: 14)
                }
                .scaleEffect(pin).offset(y: -44)
            }
            .rotationEffect(.degrees(pinned ? 0 : spin))
            .scaleEffect(grow)
            .offset(x: shake + (vibrate != 0 ? vibrate : 0), y: cornerLift ? -2 : 0)
            .position(x: pinned ? endX : x, y: pinned ? endY : y)

            EmergingEmoji(emoji: emoji, hue: hueFor(emoji), scale: emojiScale)
                .offset(y: -emojiUp)
                .position(x: endX, y: endY - 30)
        }
        .onAppear { run(endX: endX, endY: endY) }
    }

    private func run(endX: CGFloat, endY: CGFloat) {
        withAnimation(.easeIn(duration: 2.0)) { fly = 0.9; grow = 1.0; spin = 720 }
        // APPROACH — orient flat
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.4)) { fly = 0.95 }
        }
        // LANDING — SLAP
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            pinned = true
            HapticEngine.thoughtFired()    // sharp THWACK — rigid, satisfying
            HapticEngine.flickRelease()
            SoundEngine.shared.play(for: "style.whoosh")
            dust = true
            shakeScreen()
            // Pin SHOOTS through: 0 → 1.3 (fast) → 1.0 (settle).
            withAnimation(.easeOut(duration: 0.1)) { pin = 1.3 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(AnimationSystem.easeOutBack(0.35)) { pin = 1.0 }
            }
            // vibration dampening
            for k in 0..<4 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(k) * 0.08) {
                    withAnimation(.easeOut(duration: 0.08)) { vibrate = CGFloat(2 - k % 2 * 4) }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { vibrate = 0 }
        }
        // DELIVERY — corner lifts, emoji rises
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            withAnimation(.easeOut(duration: 0.3)) { cornerLift = true }
            HapticEngine.catchReveal()
            withAnimation(AnimationSystem.easeOutBack(0.5)) { emojiScale = 1; emojiUp = 36 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { onComplete() }
    }

    private func shakeScreen() {
        withAnimation(.spring(response: 0.08, dampingFraction: 0.3)) { shake = 4 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) { shake = 0 }
        }
    }
}

// ════════════════════════════════════════════════════════════════════════
// MARK: - [4/7] BOW & ARROW LANDING 🏹
// ════════════════════════════════════════════════════════════════════════

private struct ArrowLanding: View {
    let emoji: String; let size: CGSize; var onComplete: () -> Void

    @State private var fly: CGFloat = 0
    @State private var grow: CGFloat = 0.3
    @State private var vibrate: CGFloat = 0
    @State private var shake: CGFloat = 0
    @State private var chips = false
    @State private var emojiScale: CGFloat = 0
    @State private var emojiFwd: CGFloat = 0
    @State private var arrowGone = false

    private static let amber = Color(hex: "#D4A017")

    var body: some View {
        let cx = size.width / 2
        let startX = size.width * 0.78, startY = size.height * 0.2
        let endX = cx, endY = size.height * 0.55
        let x = startX + (endX - startX) * fly
        let y = startY + (endY - startY) * fly
        ZStack {
            if chips {
                ForEach(0..<8, id: \.self) { i in
                    let a = Double(i) / 8 * 2 * .pi
                    Capsule().fill(Color(hex: "#6E3A1E"))
                        .frame(width: 5, height: 2)
                        .offset(x: CGFloat(cos(a)) * 36, y: CGFloat(sin(a)) * 24)
                        .opacity(0).animation(.easeOut(duration: 0.7), value: chips)
                        .position(x: endX, y: endY)
                }
            }
            // the arrow, emoji as arrowhead
            ZStack {
                TraditionalArrowView().scaleEffect(1.6)
                Text(emoji).font(.system(size: 26)).offset(y: -28)
            }
            .rotationEffect(.radians(.pi * 0.85))   // pointing inward/down
            .scaleEffect(grow)
            .offset(x: vibrate)
            .opacity(arrowGone ? 0 : 1)
            .position(x: x, y: y)

            EmergingEmoji(emoji: emoji, hue: hueFor(emoji), scale: emojiScale)
                .position(x: endX, y: endY - 10 - emojiFwd)
        }
        .offset(x: shake)
        .onAppear { run(endX: endX, endY: endY) }
    }

    private func run(endX: CGFloat, endY: CGFloat) {
        SoundEngine.shared.play(for: "style.whoosh")
        withAnimation(.easeIn(duration: 1.4)) { fly = 1; grow = 1.0 }
        // IMPACT — THUNK
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            HapticEngine.bowRelease()
            SoundEngine.shared.play(for: "rocket.landing")
            chips = true
            withAnimation(.spring(response: 0.08, dampingFraction: 0.3)) { shake = 6 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { shake = 0 }
            }
            // shaft vibrates dampening
            for k in 0..<6 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(k) * 0.08) {
                    withAnimation(.easeOut(duration: 0.08)) { vibrate = CGFloat(3 - (k % 2) * 6) * CGFloat(6 - k) / 6 }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { vibrate = 0 }
        }
        // DELIVERY — emoji separates forward, grows
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            HapticEngine.catchReveal()
            withAnimation(AnimationSystem.easeOutBack(0.6)) { emojiScale = 1; emojiFwd = 30 }
            withAnimation(.easeOut(duration: 0.8)) { arrowGone = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.3) { onComplete() }
    }
}

// ════════════════════════════════════════════════════════════════════════
// MARK: - [5/7] WAND LANDING 🪄
// ════════════════════════════════════════════════════════════════════════

private struct WandLanding: View {
    let emoji: String; let size: CGSize; var onComplete: () -> Void

    @State private var converge: CGFloat = 0     // 0 spread → 1 center
    @State private var explode = false
    @State private var flash = false
    @State private var reform: CGFloat = 0       // 0 scattered → 1 emoji
    @State private var emojiScale: CGFloat = 0
    @State private var orbit = false

    private static let gold = Color(hex: "#D4AF37")
    private static let purple = Color(hex: "#9b7fc0")

    private struct Spark: Identifiable {
        let id = UUID(); let base: Double; let radius: CGFloat; let gold: Bool
    }
    private let sparks: [Spark] = {
        var out: [Spark] = []
        for i in 0..<54 {
            let base = Double(i) / 54 * 2 * .pi
            let radius = CGFloat(60 + (i * 37) % 180)
            out.append(Spark(base: base, radius: radius, gold: i % 2 == 0))
        }
        return out
    }()

    var body: some View {
        let cx = size.width / 2, cy = size.height * 0.5
        ZStack {
            Color.white.opacity(flash ? 0.7 : 0).ignoresSafeArea().allowsHitTesting(false)
            Self.purple.opacity(0.12 * Double(converge)).ignoresSafeArea().allowsHitTesting(false)

            ForEach(sparks) { s in
                let r: CGFloat = sparkRadius(s)
                let a: Double = s.base + (orbit ? Double(converge) * 3 : 0)
                let dot: CGFloat = explode ? 8 : 5 + converge * 4
                Image(systemName: "sparkle")
                    .font(.system(size: dot))
                    .foregroundColor(s.gold ? Self.gold : Self.purple)
                    .offset(x: CGFloat(cos(a)) * r, y: CGFloat(sin(a)) * r)
                    .position(x: cx, y: cy)
            }

            EmergingEmoji(emoji: emoji, hue: hueFor(emoji), scale: emojiScale)
                .position(x: cx, y: cy)
        }
        .onAppear { run() }
    }

    /// converge in → explode out → reform inward.
    private func sparkRadius(_ s: Spark) -> CGFloat {
        if explode {
            return reform > 0 ? (1 - reform) * 220 + 20 : 240
        }
        return (1 - converge) * s.radius + 6
    }

    private func run() {
        SoundEngine.shared.play(for: "style.shimmer")
        // CONVERGENCE — spiral in, building
        withAnimation(.easeIn(duration: 1.6).speed(0.8)) { converge = 1 }
        orbit = true
        for k in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(k) * 0.4) { HapticEngine.wandShake() }
        }
        // EXPLOSION
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            explode = true
            HapticEngine.wandFull()
            SoundEngine.shared.play(for: "rocket.blast")
            withAnimation(.easeOut(duration: 0.1)) { flash = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.2)) { flash = false }
            }
        }
        // FORMATION — sparks stream back, emoji forms
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
            withAnimation(.easeInOut(duration: 1.0)) { reform = 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            HapticEngine.catchReveal()
            withAnimation(AnimationSystem.easeOutBack(0.6)) { emojiScale = 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) { onComplete() }
    }
}

// ════════════════════════════════════════════════════════════════════════
// MARK: - [6/7] PLANE LANDING ✈️
// ════════════════════════════════════════════════════════════════════════

// Full cinematic arrival:
//   APPROACH  a speck on the horizon grows over 3 s, its shadow sweeping in
//   FLYOVER   it buzzes the bucket low, shadow racing across it
//   LOOP      a full victory loop around the screen, banking hard
//   FINAL     gear drops, flaps extend, it lines up and descends
//   TOUCHDOWN gentle thud, roll-out, prop winds down
//   DELIVERY  the door swings open and the thought hops out into the bucket
private struct PlaneLanding: View {
    let emoji: String; let size: CGSize; var onComplete: () -> Void

    // Phase: 0 approach · 1 flyover · 2 loop · 3 final descent · 4 landed · 5 deliver
    @State private var phase = 0
    @State private var segT: CGFloat = 0          // 0…1 within the current segment
    @State private var loopT: CGFloat = 0         // 0…1 = 0…360° of the loop
    @State private var scale: CGFloat = 0.05      // speck → full size
    @State private var prop: Double = 0
    @State private var bank: Double = 0           // wing-bank tilt (3D y-axis)
    @State private var gear: CGFloat = 0
    @State private var flaps: CGFloat = 0
    @State private var doorOpen: CGFloat = 0
    @State private var shake: CGFloat = 0
    @State private var shadow: CGFloat = 0        // 0…1 ground-shadow strength
    @State private var bucketTilt: Double = 0
    @State private var propRun = true
    @State private var emojiScale: CGFloat = 0
    @State private var emojiUp: CGFloat = 0

    private static let red = Color(hex: "#CC2200")
    private static let yellow = Color(hex: "#FFD700")

    // ── Geometry ──
    private var cx: CGFloat { size.width / 2 }
    private var bucketPos: CGPoint { CGPoint(x: cx, y: size.height * 0.72) }
    private var speckStart: CGPoint { CGPoint(x: size.width * 0.98, y: size.height * 0.05) }
    private var loopCenter: CGPoint { CGPoint(x: cx, y: size.height * 0.40) }
    private var loopRadius: CGFloat { min(size.width, size.height) * 0.34 }
    /// Top of the loop circle — the approach ends here and the descent begins.
    private var loopTop: CGPoint { CGPoint(x: loopCenter.x, y: loopCenter.y - loopRadius) }
    /// A low flyover point just above the bucket.
    private var flyoverPoint: CGPoint { CGPoint(x: cx, y: bucketPos.y - 70) }

    private func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    /// The plane's position + heading for the current phase.
    private var planePlacement: (pos: CGPoint, rot: Double) {
        switch phase {
        case 0:  return (lerp(speckStart, flyoverPoint, segT), 150)            // approach
        case 1:  return (lerp(flyoverPoint, loopTop, segT), 200 - Double(segT) * 110) // flyover→climb
        case 2:                                                                 // loop
            let a = Double(loopT) * 2 * .pi
            return (CGPoint(x: loopCenter.x + CGFloat(sin(a)) * loopRadius,
                            y: loopCenter.y - CGFloat(cos(a)) * loopRadius),
                    Double(loopT) * 360 + 90)
        default: return (lerp(loopTop, bucketPos, segT), 180)                  // descend, nose down
        }
    }

    var body: some View {
        let place = planePlacement
        ZStack {
            bucket.position(bucketPos)

            // Travelling ground shadow — sweeps under the plane.
            Ellipse()
                .fill(Color.black.opacity(0.22 * Double(shadow)))
                .frame(width: 70 * scale + 30, height: 18 * scale + 8)
                .blur(radius: 4)
                .position(x: place.pos.x, y: bucketPos.y + 30)
                .opacity(phase >= 4 ? 0 : 1)

            plane
                .scaleEffect(scale)
                .rotationEffect(.degrees(place.rot))
                .rotation3DEffect(.degrees(bank), axis: (x: 0, y: 1, z: 0))
                .offset(y: shake)
                .position(place.pos)
                .opacity(phase >= 5 ? 0 : 1)

            // The delivered thought — hops up out of the bucket.
            EmergingEmoji(emoji: emoji, hue: hueFor(emoji), scale: emojiScale)
                .offset(y: -emojiUp)
                .position(x: bucketPos.x, y: bucketPos.y - 6)
        }
        .onAppear { run() }
    }

    private var bucket: some View {
        BucketShape()
            .fill(LinearGradient(colors: [Color(hex: "#3a3550"), Color(hex: "#1e1828")],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: 96, height: 84)
            .overlay(BucketShape().stroke(Color(hex: "#c4a8d4").opacity(0.5), lineWidth: 1.5))
            .rotationEffect(.degrees(bucketTilt), anchor: .bottom)
            .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
    }

    private var plane: some View {
        ZStack {
            // Wings
            Capsule().fill(LinearGradient(colors: [Color(hex: "#FFE869"), Self.yellow],
                                          startPoint: .leading, endPoint: .trailing))
                .frame(width: 104, height: 18)
            // Flaps — extend down off the wing trailing edge on final approach
            ForEach([-1.0, 1.0], id: \.self) { side in
                Capsule().fill(Color(hex: "#E0B000"))
                    .frame(width: 30, height: 7)
                    .rotationEffect(.degrees(Double(side) * Double(flaps) * 35), anchor: .top)
                    .offset(x: CGFloat(side) * 34, y: 9)
                    .opacity(Double(flaps))
            }
            // Fuselage + side door
            Capsule().fill(LinearGradient(colors: [Color(hex: "#FF5533"), Self.red],
                                          startPoint: .leading, endPoint: .trailing))
                .frame(width: 40, height: 110)
                .overlay(
                    RoundedRectangle(cornerRadius: 3).fill(Color(hex: "#FF8866"))
                        .frame(width: 18, height: 22)
                        .rotationEffect(.degrees(doorOpen * 75), anchor: .leading)
                        .offset(x: 14, y: 6)
                )
            // Tail
            Capsule().fill(Self.yellow).frame(width: 44, height: 14).offset(y: 56)
            // Nose + propeller
            Circle().fill(Self.red).frame(width: 30, height: 30).offset(y: -54)
            ForEach(0..<2, id: \.self) { i in
                Capsule().fill(Color(hex: "#4a4a4a")).frame(width: 5, height: 44)
                    .rotationEffect(.degrees(Double(i) * 90 + prop))
            }
            .offset(y: -58).blur(radius: propRun ? 1.5 : 0)
            // Landing gear — drops on final approach
            ForEach([-1.0, 1.0], id: \.self) { side in
                VStack(spacing: 0) {
                    Rectangle().fill(Color(hex: "#333")).frame(width: 2, height: 12 * gear)
                    Circle().fill(Color(hex: "#222")).frame(width: 8 * gear, height: 8 * gear)
                }
                .offset(x: CGFloat(side) * 16, y: 56)
            }
        }
        .frame(width: 120, height: 150)
    }

    private func run() {
        withAnimation(.linear(duration: 9.0)) { prop = 360 * 22 }   // prop blurs the whole flight
        SoundEngine.shared.play(for: "plane.wind")

        // PHASE 0 — APPROACH (3 s): a speck grows in, shadow sweeping under it.
        withAnimation(.easeIn(duration: 3.0)) { segT = 1; scale = 0.85; shadow = 1 }
        withAnimation(.easeInOut(duration: 1.0)) { bank = -18 }

        // PHASE 1 — FLYOVER (1.2 s): buzz the bucket, shadow races across.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            phase = 1; segT = 0; bank = 0
            HapticEngine.planeWind()
            withAnimation(.easeInOut(duration: 1.2)) { segT = 1; scale = 1.0 }
        }
        // PHASE 2 — LOOP (2.6 s): a full victory loop, banking hard.
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.2) {
            phase = 2; loopT = 0
            HapticEngine.send()
            withAnimation(.easeInOut(duration: 2.6)) { loopT = 1 }
            withAnimation(.easeInOut(duration: 0.6)) { bank = 30 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.6)) { bank = 0 }
            }
        }
        // PHASE 3 — FINAL: gear drops + flaps extend, then descend to the bucket.
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.8) {
            phase = 3; segT = 0
            HapticEngine.planeWind()
            withAnimation(AnimationSystem.easeOutBack(0.5)) { gear = 1 }
            withAnimation(.easeOut(duration: 0.5)) { flaps = 1 }
            withAnimation(.easeInOut(duration: 1.4)) { segT = 1 }
        }
        // PHASE 4 — TOUCHDOWN: gentle thud, roll-out, prop winds down.
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.2) {
            phase = 4
            HapticEngine.rocketLanding()
            SoundEngine.shared.play(for: "style.bell")
            withAnimation(.spring(response: 0.12, dampingFraction: 0.4)) { shake = 4 }
            withAnimation(.easeOut(duration: 0.3)) { bucketTilt = -5 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                    shake = 0; bucketTilt = 0
                }
            }
            propRun = false
            withAnimation(.linear(duration: 0.6)) { prop += 90 }   // wind down
        }
        // PHASE 5 — DELIVERY: door swings open, the thought hops out.
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.9) {
            withAnimation(AnimationSystem.easeOutBack(0.5)) { doorOpen = 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 9.3) {
            phase = 5
            HapticEngine.catchReveal()
            SoundEngine.shared.play(for: emoji)
            withAnimation(AnimationSystem.easeOutBack(0.55)) { emojiScale = 1; emojiUp = 46 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.2) { onComplete() }
    }
}

// ════════════════════════════════════════════════════════════════════════
// MARK: - [7/7] COMPASS / ORB LANDING 🧭
// ════════════════════════════════════════════════════════════════════════

private struct OrbLanding: View {
    let emoji: String; let size: CGSize; var onComplete: () -> Void

    @State private var travel: CGFloat = 0
    @State private var grow: CGFloat = 0.6
    @State private var pulse = false
    @State private var flash = false
    @State private var dissolve: CGFloat = 0     // 0 orb → 1 dissolved
    @State private var emojiScale: CGFloat = 0

    private static let lavender = Color(hex: "#c4a8d4")

    var body: some View {
        let startX = size.width * 0.8, startY = size.height * 0.2
        let endX = size.width / 2, endY = size.height * 0.5
        let x = startX + (endX - startX) * travel
        let y = startY + (endY - startY) * travel
        ZStack {
            Self.lavender.opacity(flash ? 0.15 : 0).ignoresSafeArea().allowsHitTesting(false)
            // soft light trail
            ForEach(0..<6, id: \.self) { i in
                let t = max(0, travel - CGFloat(i) * 0.05)
                Circle().fill(hueFor(emoji).opacity(0.25 - Double(i) * 0.03))
                    .frame(width: 30, height: 30).blur(radius: 4)
                    .position(x: startX + (endX - startX) * t, y: startY + (endY - startY) * t)
            }
            // the orb
            Circle()
                .fill(RadialGradient(colors: [hueFor(emoji).opacity(0.95), hueFor(emoji).opacity(0.3), .clear],
                                     center: .center, startRadius: 4, endRadius: 30))
                .frame(width: 60, height: 60)
                .scaleEffect((grow * (pulse ? 1.06 : 0.94)) + dissolve * 1.4)
                .opacity(1 - Double(dissolve))
                .position(x: x, y: y)

            EmergingEmoji(emoji: emoji, hue: hueFor(emoji), scale: emojiScale)
                .position(x: endX, y: endY)
        }
        .onAppear { run() }
    }

    private func run() {
        withAnimation(AnimationSystem.easeInOutSine(0.7).repeatForever(autoreverses: true)) { pulse = true }
        withAnimation(.easeInOut(duration: 2.0)) { travel = 1; grow = 1.2 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { HapticEngine.windBreath() }
        // ARRIVAL AT CENTER — warm flash, bell
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            HapticEngine.lockOn()
            SoundEngine.shared.play(for: "style.bell")
            withAnimation(.easeOut(duration: 0.2)) { flash = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeIn(duration: 0.2)) { flash = false }
            }
        }
        // DELIVERY — orb dissolves, emoji revealed
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation(.easeOut(duration: 0.6)) { dissolve = 1 }
            HapticEngine.catchReveal()
            withAnimation(AnimationSystem.easeOutBack(0.6)) { emojiScale = 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) { onComplete() }
    }
}
