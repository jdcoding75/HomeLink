// PlaneSendAnimation.swift
// Pointward › Instruments › Plane
//
// ACT 2 of 3 — the full-screen PLANE send journey.
//
// A clean paper plane streaks in, climbs into a gentle arc across the daytime
// sky trailing gold/white sparkles with the emoji riding in the cockpit, then
// exits off the right edge and hands off to the shared sent confirmation.
//
//   LAUNCH (0.0–0.5s)  enters from the edge, hard accel, gold→white streak
//   FLIGHT (0.5–4.5s)  cruises at y≈0.52h on a slight arc, sparkle trail, banking
//   EXIT   (4.5–5.0s)  exits right (geo.size.width × 1.15), trail + sound fade
//   → EmojiRevealView (.sent, .plane)                                    = 5.0s
//
// Screen-coordinate rules: GeometryReader root, daySky.ignoresSafeArea(), every
// position from geo.size.

import SwiftUI

struct PlaneSendAnimation: View {

    let transition: InstrumentTransition
    var personName: String = ""
    var onComplete: () -> Void = {}

    static let duration: Double = InstrumentBoundaries.Send.plane   // 5.0
    static let soundFile: String = PlaneSounds.sendFile

    private static let launchDur: Double = 0.5
    private static let exitDur:   Double = 0.5
    private static let total:     Double = InstrumentBoundaries.Send.plane          // 5.0
    private static let flightEnd: Double = total - exitDur                          // 4.5

    private static let planeW: CGFloat = 132
    private static let planeH: CGFloat = 70
    private static let gold = Color(hex: "#f0d060")

    @State private var start: Date? = nil
    @State private var skyIn = false
    @State private var revealing = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if revealing {
                    EmojiRevealView(emoji: transition.emoji,
                                    message: transition.message,
                                    tagline: transition.tagline,
                                    context: .sent(recipientName: personName.isEmpty ? "them" : personName),
                                    ambient: .plane,
                                    onDismiss: onComplete)
                        .transition(.opacity)
                } else {
                    TimelineView(.animation) { timeline in
                        let e = clampedElapsed(now: timeline.date)
                        ZStack {
                            Color(hex: "#0d0d14").ignoresSafeArea()
                            InstrumentBackground.daySky.ignoresSafeArea().opacity(skyIn ? 1 : 0)

                            sparkleTrail(geo: geo, elapsed: e)
                            plane(geo: geo, elapsed: e)

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
        .onAppear {
            start = Date()
            InstrumentSoundPlayer.shared.playSend(.plane)               // gentle flight ambient (5s)
            InstrumentSoundPlayer.shared.playCue(file: PlaneSounds.launchFile, duration: 0.6)
            withAnimation(.easeInOut(duration: 0.3)) { skyIn = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.total) {
                withAnimation(.easeInOut(duration: 0.3)) { revealing = true }
            }
        }
    }

    private func clampedElapsed(now: Date) -> Double {
        guard let start else { return 0 }
        return min(max(0, now.timeIntervalSince(start)), Self.total)
    }

    // ── The plane ────────────────────────────────────────────────────────────

    @ViewBuilder
    private func plane(geo: GeometryProxy, elapsed e: Double) -> some View {
        let pos = planePos(geo.size, e)
        let bank = sin(e * 2.2) * 2                       // gentle ±2° banking
        let streak = e < Self.launchDur                  // launch streak only at the start
        ZStack {
            if streak {
                Capsule()
                    .fill(LinearGradient(colors: [Self.gold.opacity(0.0), Self.gold.opacity(0.5), .white],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: 120, height: 14 - CGFloat(e / Self.launchDur) * 11)
                    .offset(x: -90)
                    .blur(radius: 2)
            }
            PlaneGlyph(emoji: transition.emoji)
                .frame(width: Self.planeW, height: Self.planeH)
        }
        .rotationEffect(.degrees(bank))
        .position(pos)
    }

    /// Left → right flight at y ≈ 0.52h with a slight upward arc.
    private func planePos(_ size: CGSize, _ e: Double) -> CGPoint {
        let entry = CGPoint(x: -size.width * 0.15, y: size.height * 0.52)
        let exit  = CGPoint(x:  size.width * 1.15, y: size.height * 0.52)
        let p: Double
        if e <= Self.launchDur {
            p = easeIn(e / Self.launchDur) * 0.12                       // hard accel out of the gate
        } else if e <= Self.flightEnd {
            let f = (e - Self.launchDur) / (Self.flightEnd - Self.launchDur)
            p = 0.12 + f * 0.76
        } else {
            p = 0.88 + easeIn((e - Self.flightEnd) / Self.exitDur) * 0.12
        }
        let x = entry.x + (exit.x - entry.x) * CGFloat(p)
        let arc = -sin(p * .pi) * size.height * 0.12                    // lifts at mid-flight
        return CGPoint(x: x, y: entry.y + arc)
    }

    // ── Sparkle trail (gold + white) ───────────────────────────────────────

    @ViewBuilder
    private func sparkleTrail(geo: GeometryProxy, elapsed e: Double) -> some View {
        let count = 28
        ForEach(0..<count, id: \.self) { k in
            let tb = e - Double(k) * 0.05
            if tb > Self.launchDur * 0.5 && tb <= Self.flightEnd {
                let frac = Double(k) / Double(count)
                let p = planePos(geo.size, tb)
                let jy = CGFloat(sin(tb * 11 + Double(k))) * 12
                let isGold = k % 2 == 0
                Circle()
                    .fill(isGold ? Self.gold : Color.white)
                    .frame(width: 2.5 - CGFloat(frac) * 1.0, height: 2.5 - CGFloat(frac) * 1.0)
                    .opacity((1 - frac) * 0.85)
                    .position(x: p.x - Self.planeW * 0.4, y: p.y + jy)
                    .allowsHitTesting(false)
            }
        }
    }

    // ── Messages ───────────────────────────────────────────────────────────

    private func message(_ e: Double) -> String {
        let name = personName.isEmpty ? "them" : personName
        if e < Self.launchDur { return "off it goes ✦" }
        if e < Self.flightEnd { return "flying to \(name) ✦" }
        return "on its way ✦"
    }

    private func easeIn(_ t: Double) -> Double { let x = min(max(t, 0), 1); return x * x }
}
