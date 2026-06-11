// PlaneSendAnimation.swift
// Pointward › Instruments › Plane
//
// ACT 2 of 3 — the full-screen PLANE send journey (visual bible: Screen 3).
//
// The top-down white plane climbs across a dark night sky on a clean NE
// diagonal — entering low from the SOUTH-WEST (lower-left), leveling at mid
// screen, and exiting toward the NORTH-EAST (upper-right) — nose pointing the
// way it travels, the loaded emoji riding the cockpit, a gold→white particle
// wake trailing to the SW behind it.
//
//   LAUNCH (0.0–0.4s)  enters SW edge, hard accel, plane_launch cue
//   FLIGHT (0.4–2.6s)  NE diagonal through ~0.5h, gold/white wake
//   EXIT   (2.6–3.0s)  exits the NE corner; trail + ambient fade
//   → onComplete → finishSend pipeline (NOT EmojiRevealView)              = 3.0s
//
// Screen-coordinate rules (all 6): GeometryReader root, dark sky
// .ignoresSafeArea(), every position from geo.size, no UIScreen, no hardcodes.
//
// HANDOFF: receives InstrumentTransition from the compass face (ACT 1). On
// completion it calls onComplete; the shared CompassView send pipeline then
// shows the sent confirmation — this view never presents EmojiRevealView(.sent).

import SwiftUI

struct PlaneSendAnimation: View {

    let transition: InstrumentTransition
    var personName: String = ""
    var onComplete: () -> Void = {}

    static let soundFile: String = PlaneSounds.flightFile

    private static let total:    Double = 3.0
    private static let launchEnd: Double = 0.4
    private static let flightEnd: Double = 2.6

    private static let skyTop    = Color(hex: "#1a2d4a")
    private static let skyBottom = Color(hex: "#080e1e")
    private static let gold      = Color(hex: "#d4a030")    // framework gold trail

    @State private var start: Date? = nil
    @State private var skyIn = false

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let e = clampedElapsed(now: timeline.date)
                ZStack {
                    LinearGradient(colors: [Self.skyTop, Self.skyBottom],
                                   startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()
                        .opacity(skyIn ? 1 : 0)

                    wake(geo: geo, elapsed: e)
                    plane(geo: geo, elapsed: e)

                    VStack {
                        Spacer()
                        Text(message(e))
                            .font(.system(size: 20, design: .serif).italic())
                            .foregroundColor(Color(hex: "#c4a8d4"))
                            .shadow(color: .black.opacity(0.5), radius: 6)
                            .padding(.bottom, geo.size.height * 0.06)
                            .contentTransition(.opacity)
                            .animation(.easeInOut(duration: 0.4), value: message(e))
                    }
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            start = Date()
            InstrumentSoundPlayer.shared.playSend(.plane)                         // gentle 5s flight ambient
            InstrumentSoundPlayer.shared.playCue(file: PlaneSounds.launchFile, duration: 0.6)
            HapticEngine.send()
            withAnimation(.easeInOut(duration: 0.3)) { skyIn = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.total) {
                onComplete()                                                      // → finishSend, no reveal
            }
        }
    }

    private func clampedElapsed(now: Date) -> Double {
        guard let start else { return 0 }
        return min(max(0, now.timeIntervalSince(start)), Self.total)
    }

    // ── Flight path: SW (lower-left) → NE (upper-right), cruising mid-screen ──

    /// Progress 0→1 across the whole journey (hard accel, ease at the exit).
    private func progress(_ e: Double) -> Double {
        let t = min(max(e / Self.total, 0), 1)
        return t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2   // easeInOut quad
    }

    private func planePos(_ size: CGSize, _ e: Double) -> CGPoint {
        let entry = CGPoint(x: -size.width * 0.18, y: size.height * 0.78)   // SW, low
        let exit  = CGPoint(x:  size.width * 1.18, y: size.height * 0.22)   // NE, high
        let p = CGFloat(progress(e))
        // slight downward-bowed arc so it "levels" at mid screen (~0.5h)
        let arc = sin(Double(p) * .pi) * size.height * 0.06
        return CGPoint(x: entry.x + (exit.x - entry.x) * p,
                       y: entry.y + (exit.y - entry.y) * p + CGFloat(arc))
    }

    // ── The top-down plane (nose-up drawing rotated +45° to point NE) ─────────

    @ViewBuilder
    private func plane(geo: GeometryProxy, elapsed e: Double) -> some View {
        let pos = planePos(geo.size, e)
        PlaneTopDownGlyph(emoji: transition.emoji)
            .frame(width: 96, height: 116)
            .rotationEffect(.degrees(45))          // nose-up glyph → points NE
            .position(pos)
            .allowsHitTesting(false)
    }

    // ── Gold/white particle wake, trailing SW behind the plane ────────────────

    @ViewBuilder
    private func wake(geo: GeometryProxy, elapsed e: Double) -> some View {
        let count = 20                              // framework: 20 max
        ForEach(0..<count, id: \.self) { k in
            let tb = e - Double(k) * 0.045
            if tb > 0 && tb <= Self.flightEnd {
                let frac = Double(k) / Double(count)
                let p = planePos(geo.size, tb)
                let jitter = CGFloat(sin(tb * 12 + Double(k) * 1.6)) * 12   // ±12pt drift
                let isGold = k % 2 == 0
                Circle()
                    .fill(isGold ? Self.gold : Color.white)
                    .frame(width: 3 - CGFloat(frac) * 1.6, height: 3 - CGFloat(frac) * 1.6)
                    .opacity((1 - frac) * 0.85)
                    .position(x: p.x - 26, y: p.y + 26 + jitter)            // toward the SW tail
                    .allowsHitTesting(false)
            }
        }
    }

    // ── Caption ───────────────────────────────────────────────────────────────

    private func message(_ e: Double) -> String {
        let name = personName.isEmpty ? "them" : personName
        if e < Self.launchEnd { return "off it goes ✦" }
        if e < Self.flightEnd { return "flying to \(name) ✦" }
        return "on its way ✦"
    }
}

// MARK: - Top-down plane glyph (nose UP) — matches the compass-face plane

/// A compact top-down, front-facing plane drawn nose-UP: white fuselage, swept
/// wings, tail fin, brass-hub propeller, the emoji in the cockpit. Rotate to
/// point it along a flight path.
struct PlaneTopDownGlyph: View {
    var emoji: String? = nil

    private static let bodyLight = Color(hex: "#e8e0f0")
    private static let bodyShade = Color(hex: "#b6aecb")
    private static let bodyEdge  = Color(hex: "#cfc6e0")
    private static let brass     = Color(hex: "#e8c060")
    private static let brassDark = Color(hex: "#b9923a")
    private static let propBlade = Color(hex: "#d8d0e6")

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                // tail fin + horizontal stabilizer (rear / bottom)
                Capsule().fill(Self.bodyShade)
                    .frame(width: w * 0.06, height: h * 0.15)
                    .offset(y: h * 0.30)
                Capsule().fill(LinearGradient(colors: [Self.bodyLight, Self.bodyShade],
                                              startPoint: .top, endPoint: .bottom))
                    .frame(width: w * 0.32, height: h * 0.06)
                    .offset(y: h * 0.28)

                // wings
                Capsule().fill(LinearGradient(colors: [Self.bodyLight, Self.bodyShade],
                                              startPoint: .leading, endPoint: .trailing))
                    .overlay(Capsule().stroke(Self.bodyEdge.opacity(0.6), lineWidth: 0.8))
                    .frame(width: w * 0.96, height: h * 0.13)
                    .offset(y: h * 0.02)
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 2)

                // fuselage
                Capsule().fill(LinearGradient(colors: [Self.bodyLight, Self.bodyEdge, Self.bodyShade],
                                              startPoint: .leading, endPoint: .trailing))
                    .overlay(Capsule().stroke(Self.bodyEdge.opacity(0.7), lineWidth: 0.8))
                    .frame(width: w * 0.23, height: h * 0.62)

                // cockpit + emoji (toward the nose / top)
                Circle().fill(Color(hex: "#243a5c"))
                    .frame(width: w * 0.16, height: w * 0.16)
                    .overlay(Circle().stroke(Self.bodyEdge.opacity(0.8), lineWidth: 1))
                    .overlay { if let emoji { Text(emoji).font(.system(size: h * 0.16)) } }
                    .offset(y: -h * 0.10)

                // nose + brass propeller (front / top)
                Circle().fill(RadialGradient(colors: [Self.bodyLight, Self.bodyShade],
                                             center: UnitPoint(x: 0.4, y: 0.35),
                                             startRadius: 1, endRadius: w * 0.11))
                    .frame(width: w * 0.19, height: w * 0.19)
                    .offset(y: -h * 0.26)
                ZStack {
                    ForEach(0..<2, id: \.self) { i in
                        Capsule().fill(Self.propBlade)
                            .frame(width: w * 0.045, height: h * 0.28)
                            .rotationEffect(.degrees(Double(i) * 90 + 30))
                    }
                    Circle().fill(RadialGradient(colors: [Self.brass, Self.brassDark],
                                                 center: .center, startRadius: 0, endRadius: w * 0.05))
                        .frame(width: w * 0.09, height: w * 0.09)
                }
                .offset(y: -h * 0.30)
            }
            .frame(width: w, height: h)
        }
    }
}
