// WandSendAnimation.swift
// Pointward › Instruments › Wand
//
// ACT 2 of 3 — the full-screen WAND send cut scene.
//
// The previously-missing dramatic beat: after the compass-face crystal charges
// and releases, the wand BLAZES across the full screen toward the person — a
// continuation of the compass-face magic, not a new visual world. A luminous
// gem-tipped wand (the emoji riding the gem) streaks from the screen edge along
// the send bearing — fast and purposeful, faster than the wind, trailing a
// purple glow and gold sparks — through the centre and out toward them, then
// hands off to the shared sent confirmation.
//
//   BLAZE (0.0–1.55s)  wand streaks entry-edge → centre → exit-edge along
//                      exitBearing; bright purple→white streak; white launch
//                      flash; purple/gold particle wake
//   FADE  (1.55–2.0s)  the trail thins, the magic recedes
//   → EmojiRevealView (.sent, .wand)                                      = 2.0s
//
// Screen-coordinate rules: GeometryReader root, magicalDark.ignoresSafeArea(),
// every position derived from geo.size — no hardcoded dimensions, no UIScreen.
//
// HANDOFF: receives InstrumentTransition from the compass face (ACT 1) and
// blazes along transition.exitBearing. On completion it calls onComplete; the
// shared send pipeline (CompassView) then shows the sent confirmation, exactly
// as every other instrument does.

import SwiftUI

struct WandSendAnimation: View {

    let transition: InstrumentTransition
    var personName: String = ""
    var onComplete: () -> Void = {}

    static let duration: Double = InstrumentBoundaries.Send.wand   // 2.0
    static let soundFile: String = WandSounds.sendFile

    private static let total:    Double = InstrumentBoundaries.Send.wand    // 2.0
    private static let blazeEnd: Double = 1.55                              // streak crosses by here
    private static let purple = Color(hex: "#b98cff")
    private static let gold   = Color(hex: "#f0d060")

    @State private var start: Date? = nil
    @State private var skyIn = false
    @State private var flash = false
    @State private var revealing = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if revealing {
                    EmojiRevealView(emoji: transition.emoji,
                                    message: transition.message,
                                    tagline: transition.tagline,
                                    context: .sent(recipientName: personName.isEmpty ? "them" : personName),
                                    ambient: .wand,
                                    onDismiss: onComplete)
                        .transition(.opacity)
                } else {
                    TimelineView(.animation) { timeline in
                        let e = clampedElapsed(now: timeline.date)
                        ZStack {
                            Color(hex: "#0d0d14").ignoresSafeArea()
                            InstrumentBackground.magicalDark.ignoresSafeArea().opacity(skyIn ? 1 : 0)

                            sparkTrail(geo: geo, elapsed: e)
                            wand(geo: geo, elapsed: e)

                            // launch flash — the crystal's energy releasing
                            Color.white.opacity(flash ? 0.45 : 0).ignoresSafeArea().allowsHitTesting(false)

                            VStack {
                                Spacer()
                                Text(message(e))
                                    .font(.system(size: 20, design: .serif).italic())
                                    .foregroundColor(InstrumentBackground.accentText)
                                    .shadow(color: .black.opacity(0.5), radius: 6)
                                    .padding(.bottom, geo.size.height * 0.06)
                                    .contentTransition(.opacity)
                                    .animation(.easeInOut(duration: 0.4), value: message(e))
                            }
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            start = Date()
            InstrumentSoundPlayer.shared.playSend(.wand)            // wand_send.wav (2.0s)
            SoundEngine.shared.play(for: "style.shimmer")           // a magical sparkle on release
            HapticEngine.send()
            withAnimation(.easeOut(duration: 0.25)) { skyIn = true }
            withAnimation(.easeOut(duration: 0.10)) { flash = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.easeIn(duration: 0.22)) { flash = false }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.total) {
                withAnimation(.easeInOut(duration: 0.3)) { revealing = true }
            }
        }
    }

    private func clampedElapsed(now: Date) -> Double {
        guard let start else { return 0 }
        return min(max(0, now.timeIntervalSince(start)), Self.total)
    }

    // ── Path: entry edge → centre → exit edge, along the send bearing ────────

    /// Unit vector pointing toward the person (the send bearing).
    private func bearingDir() -> CGPoint {
        let rad = transition.exitBearing * .pi / 180
        return CGPoint(x: CGFloat(sin(rad)), y: -CGFloat(cos(rad)))
    }

    /// Wand position at the given elapsed time: from the edge OPPOSITE the
    /// bearing, through the centre, out to the edge TOWARD the person.
    private func wandPos(_ size: CGSize, _ e: Double) -> CGPoint {
        let dir = bearingDir()
        let reach = max(size.width, size.height) * 1.15
        let cx = size.width / 2, cy = size.height / 2
        let entry = CGPoint(x: cx - dir.x * reach, y: cy - dir.y * reach)
        let exit  = CGPoint(x: cx + dir.x * reach, y: cy + dir.y * reach)
        let p = blazeProgress(e)
        return CGPoint(x: entry.x + (exit.x - entry.x) * CGFloat(p),
                       y: entry.y + (exit.y - entry.y) * CGFloat(p))
    }

    /// Fast and purposeful — easeInOutCubic across the blaze window.
    private func blazeProgress(_ e: Double) -> Double {
        let t = min(max(e / Self.blazeEnd, 0), 1)
        return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
    }

    // ── The wand glyph ───────────────────────────────────────────────────────

    @ViewBuilder
    private func wand(geo: GeometryProxy, elapsed e: Double) -> some View {
        let pos = wandPos(geo.size, e)
        let dir = bearingDir()
        let angle = atan2(dir.y, dir.x) * 180 / .pi
        let gone = e > Self.blazeEnd
        let fade = gone ? max(0, 1 - (e - Self.blazeEnd) / (Self.total - Self.blazeEnd)) : 1
        ZStack {
            // bright purple→white streak trailing the tip
            Capsule()
                .fill(LinearGradient(colors: [Self.purple.opacity(0), Self.purple.opacity(0.6), .white],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 150, height: 10)
                .offset(x: -95)
                .blur(radius: 3)
            // soft gem glow
            Circle().fill(Self.purple.opacity(0.5)).frame(width: 70, height: 70).blur(radius: 22)
            // the wand itself — slim gem-tipped staff, emoji riding the gem
            WandStaffGlyph(emoji: transition.emoji)
                .frame(width: 96, height: 36)
        }
        .rotationEffect(.degrees(angle))
        .position(pos)
        .opacity(fade)
        .allowsHitTesting(false)
    }

    // ── Purple + gold particle wake ──────────────────────────────────────────

    @ViewBuilder
    private func sparkTrail(geo: GeometryProxy, elapsed e: Double) -> some View {
        let count = 30
        let perp = CGPoint(x: -bearingDir().y, y: bearingDir().x)
        ForEach(0..<count, id: \.self) { k in
            let tb = e - Double(k) * 0.025
            if tb > 0 && tb <= Self.blazeEnd {
                let frac = Double(k) / Double(count)
                let p = wandPos(geo.size, tb)
                let jitter = CGFloat(sin(tb * 13 + Double(k) * 1.7)) * 16
                let isGold = k % 3 == 0
                Circle()
                    .fill(isGold ? Self.gold : Self.purple)
                    .frame(width: 4 - CGFloat(frac) * 2.4, height: 4 - CGFloat(frac) * 2.4)
                    .opacity((1 - frac) * 0.9)
                    .position(x: p.x + perp.x * jitter, y: p.y + perp.y * jitter)
                    .blur(radius: 0.4)
                    .allowsHitTesting(false)
            }
        }
    }

    // ── Messages ─────────────────────────────────────────────────────────────

    private func message(_ e: Double) -> String {
        let name = personName.isEmpty ? "them" : personName
        if e < Self.blazeEnd * 0.5 { return "the magic finds them ✦" }
        if e < Self.blazeEnd { return "to \(name) ✦" }
        return "on its way ✦"
    }
}

// MARK: - Wand glyph — a slim gem-tipped staff with the emoji riding the gem

private struct WandStaffGlyph: View {
    let emoji: String
    var body: some View {
        ZStack {
            // staff
            Capsule()
                .fill(LinearGradient(colors: [Color(hex: "#6b5f7a"), Color(hex: "#2a2335")],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 64, height: 6)
                .offset(x: -16)
            // gem
            Circle()
                .fill(RadialGradient(colors: [.white, Color(hex: "#c4a8d4"), Color(hex: "#7c6b8e")],
                                     center: .center, startRadius: 0, endRadius: 12))
                .frame(width: 20, height: 20)
                .offset(x: 18)
                .shadow(color: Color(hex: "#c4a8d4").opacity(0.9), radius: 8)
            // emoji riding the tip
            Text(emoji).font(.system(size: 26)).offset(x: 24, y: -18)
        }
    }
}
