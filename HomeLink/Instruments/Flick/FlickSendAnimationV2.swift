// FlickSendAnimationV2.swift
// Pointward › Instruments › Flick
//
// ACT 2 of 3 — the full-screen FLICK V2 (DESK) send journey.
//
// The crumpled paper ball, flicked off the desk, spins across a TWILIGHT SKY
// (#1a2d4a→#243d5c→#1e3550→#0e1e30) of faint stars in ONE smooth continuous arc
// — no hesitation: left edge → right edge, a gentle arc peaking ~18% up, a faint
// cream dust trail in its wake. ~3.5s.
//
// HANDOFF: receives InstrumentTransition from the compass face (ACT 1).
// On completion it calls onComplete; the shared send pipeline (CompassView)
// then shows the sent confirmation, exactly as every other instrument does.

import SwiftUI

struct FlickSendAnimationV2: View {

  let transition: InstrumentTransition
  var personName: String = ""
  var onComplete: () -> Void = {}

  static let duration: Double = 3.5
  private static let total: Double = 3.5

  private static let skyTop = Color(hex: "#1a2d4a")
  private static let skyMid = Color(hex: "#243d5c")
  private static let skyLow = Color(hex: "#1e3550")
  private static let skyBot = Color(hex: "#0e1e30")

  // Sparse faint stars — index-derived positions (no render-time random).
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
        LinearGradient(colors: [Self.skyTop, Self.skyMid, Self.skyLow, Self.skyBot],
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
      InstrumentSoundPlayer.shared.playSend(.flick)   // gentle paper snap+whoosh
      HapticPattern.singleSoft.fire()                 // soft — NOT sharp
      DispatchQueue.main.asyncAfter(deadline: .now() + Self.total) { onComplete() }
    }
  }

  private func clampedElapsed(now: Date) -> Double {
    guard let start else { return 0 }
    return min(max(0, now.timeIntervalSince(start)), Self.total)
  }

  // ── Path — left edge → right edge, ONE gentle arc peaking ~18% up ─────────

  private func ballPos(geo: GeometryProxy, elapsed: Double) -> CGPoint {
    let size = geo.size
    let startPt = CGPoint(x: -size.width * 0.05, y: size.height * 0.62)
    let endPt   = CGPoint(x: size.width * 1.05,  y: size.height * 0.62)
    // Control chosen so the quad's apex sits ~18% of the height above the
    // baseline (apex.y = 0.25·start + 0.5·control + 0.25·end).
    let ctrl    = CGPoint(x: size.width * 0.5, y: size.height * 0.26)
    let p = CGFloat(min(1, elapsed / Self.total))
    let mx = (1 - p) * (1 - p) * startPt.x + 2 * (1 - p) * p * ctrl.x + p * p * endPt.x
    let my = (1 - p) * (1 - p) * startPt.y + 2 * (1 - p) * p * ctrl.y + p * p * endPt.y
    return CGPoint(x: mx, y: my)
  }

  // ── The crumpled paper ball — spins steadily, gentle breathing scale ──────

  @ViewBuilder
  private func ball(geo: GeometryProxy, elapsed: Double) -> some View {
    let pos = ballPos(geo: geo, elapsed: elapsed)
    let spin = elapsed * 220                                  // 220°/sec, calm
    let p = min(1, elapsed / Self.total)
    let grow = 0.9 + 0.12 * CGFloat(sin(p * .pi))            // 0.9 → ~1.0 → 0.9
    CrumpledPaperBall(size: 46, emoji: transition.emoji, emojiOpacity: 0.3,
                      showShadow: false)
      .rotationEffect(.degrees(spin))
      .scaleEffect(grow)
      .position(pos)
  }

  // ── Cream trail flecks (NOT gold — paper, not magic) ─────────────────────

  @ViewBuilder
  private func trail(geo: GeometryProxy, elapsed: Double) -> some View {
    ForEach(0..<10, id: \.self) { k in
      let tb = elapsed - Double(k) * 0.07
      if tb > 0 {
        let frac = Double(k) / 10
        let p = ballPos(geo: geo, elapsed: tb)
        Circle()
          .fill(FlickDeskPalette.paperA.opacity((1 - frac) * 0.45))
          .frame(width: 6 - CGFloat(frac) * 3, height: 6 - CGFloat(frac) * 3)
          .position(p)
          .allowsHitTesting(false)
      }
    }
  }

  // ── Faint stars ───────────────────────────────────────────────────────────

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
