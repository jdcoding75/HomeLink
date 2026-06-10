// FlickSendAnimationV2.swift
// Pointward › Instruments › Flick
//
// ACT 2 of 3 — the full-screen FLICK send journey.
//
// A crumpled paper ball, flicked into the dusk, spins through a twilight sky
// of sparse dim stars. It enters from the screen edge (the bearing it left the
// compass circle), arcs across ~58% height peaking above the midline, then
// drifts off toward that same bearing — cream paper flecks in its wake, not
// gold; this is paper, not magic.
//
//   Enter from transition.sendEntryPoint → arc across → exit toward exitBearing
//   Total: InstrumentBoundaries.Send.flick (0.7s).
//
// HANDOFF: receives InstrumentTransition from the compass face (ACT 1).
// On completion it calls onComplete; the shared send pipeline (CompassView)
// then shows the sent confirmation, exactly as every other instrument does.

import SwiftUI

struct FlickSendAnimationV2: View {

  let transition: InstrumentTransition
  var personName: String = ""
  var onComplete: () -> Void = {}

  static let duration: Double = InstrumentBoundaries.Send.flick   // 0.7
  private static let total: Double = 0.7

  private static let paper     = Color(hex: "#F8F8F0")
  private static let paperEdge = Color(hex: "#D9D4C2")
  private static let crease    = Color(hex: "#C9C2AC")
  private static let skyTop     = Color(hex: "#1a2d4a")
  private static let skyMid     = Color(hex: "#243d5c")
  private static let skyLow     = Color(hex: "#1e3550")

  // Sparse dim stars — index-derived positions (no render-time random).
  private static let starCount = 60
  private static let starSeeds: [(x: CGFloat, y: CGFloat, sz: CGFloat, o: Double)] = {
    (0..<starCount).map { i in
      let x = CGFloat((i * 97) % 100) / 100
      let y = CGFloat((i * 53) % 100) / 100
      let sz = CGFloat(1 + (i * 7) % 3)
      let o = 0.15 + Double((i * 13) % 10) / 40.0
      return (x, y, sz, o)
    }
  }()

  @State private var start: Date? = nil
  @State private var skyIn = false

  var body: some View {
    GeometryReader { geo in
      ZStack {
        Color(hex: "#0d0d14").ignoresSafeArea()
        LinearGradient(colors: [Self.skyTop, Self.skyMid, Self.skyLow],
                       startPoint: .top, endPoint: .bottom)
          .ignoresSafeArea()
          .opacity(skyIn ? 1 : 0)
        stars(geo: geo)

        TimelineView(.animation) { timeline in
          let elapsed = clampedElapsed(now: timeline.date)
          ZStack {
            trail(geo: geo, elapsed: elapsed)
            ball(geo: geo, elapsed: elapsed)
          }
        }
      }
    }
    .ignoresSafeArea()
    .onAppear {
      start = Date()
      withAnimation(.easeInOut(duration: 0.3)) { skyIn = true }
      InstrumentSoundPlayer.shared.playSend(.flick)
      HapticPattern.sharpSnap.fire()
      DispatchQueue.main.asyncAfter(deadline: .now() + Self.total) { onComplete() }
    }
  }

  private func clampedElapsed(now: Date) -> Double {
    guard let start else { return 0 }
    return min(max(0, now.timeIntervalSince(start)), Self.total)
  }

  // ── Path — edge → arc across ~58% height (peak above midline) → off-screen ─

  private func ballPos(geo: GeometryProxy, elapsed: Double) -> CGPoint {
    let size = geo.size
    let entry = transition.sendEntryPoint(screenSize: size)
    let exit  = departPoint(size)
    let mid = CGPoint(x: size.width / 2,
                      y: size.height * 0.58 - size.height * 0.18)   // arc peak above midline
    let p = CGFloat(min(1, elapsed / Self.total))
    return CGPoint(
      x: (1 - p) * (1 - p) * entry.x + 2 * (1 - p) * p * mid.x + p * p * exit.x,
      y: (1 - p) * (1 - p) * entry.y + 2 * (1 - p) * p * mid.y + p * p * exit.y
    )
  }

  private func departPoint(_ size: CGSize) -> CGPoint {
    let rad = transition.exitBearing * .pi / 180
    return CGPoint(x: size.width / 2 + CGFloat(sin(rad)) * size.width * 1.15,
                   y: size.height / 2 - CGFloat(cos(rad)) * size.height * 1.15)
  }

  // ── The crumpled paper ball — spins 300°/s, grows 0.85→1.0→0.85 ──────────

  @ViewBuilder
  private func ball(geo: GeometryProxy, elapsed: Double) -> some View {
    let pos = ballPos(geo: geo, elapsed: elapsed)
    let spin = elapsed * 300
    let p = min(1, elapsed / Self.total)
    let grow = 0.85 + 0.15 * CGFloat(sin(p * .pi))
    ZStack {
      Circle()
        .fill(RadialGradient(colors: [Self.paper, Self.paperEdge],
                             center: UnitPoint(x: 0.4, y: 0.35),
                             startRadius: 2, endRadius: 22))
        .frame(width: 40, height: 40)
        .shadow(color: .black.opacity(0.3), radius: 5, y: 3)
      ForEach(0..<3, id: \.self) { i in
        Capsule()
          .stroke(Self.crease.opacity(0.7), lineWidth: 1)
          .frame(width: 26 - CGFloat(i) * 5, height: 1)
          .rotationEffect(.degrees(Double(i) * 57))
      }
      Text(transition.emoji).font(.system(size: 18)).opacity(0.3)
    }
    .rotationEffect(.degrees(spin))
    .scaleEffect(grow)
    .position(pos)
  }

  // ── Cream trail flecks (NOT gold — paper, not magic) ─────────────────────

  @ViewBuilder
  private func trail(geo: GeometryProxy, elapsed: Double) -> some View {
    ForEach(0..<8, id: \.self) { k in
      let tb = elapsed - Double(k) * 0.03
      if tb > 0 {
        let frac = Double(k) / 8
        let p = ballPos(geo: geo, elapsed: tb)
        Circle()
          .fill(Self.paper.opacity((1 - frac) * 0.5))
          .frame(width: 6 - CGFloat(frac) * 3, height: 6 - CGFloat(frac) * 3)
          .position(p)
          .allowsHitTesting(false)
      }
    }
  }

  // ── Sparse dim stars ──────────────────────────────────────────────────────

  @ViewBuilder
  private func stars(geo: GeometryProxy) -> some View {
    ForEach(0..<Self.starCount, id: \.self) { i in
      let s = Self.starSeeds[i]
      Circle()
        .fill(Color.white.opacity(s.o * (skyIn ? 1 : 0)))
        .frame(width: s.sz, height: s.sz)
        .position(x: s.x * geo.size.width, y: s.y * geo.size.height)
        .allowsHitTesting(false)
    }
  }
}
