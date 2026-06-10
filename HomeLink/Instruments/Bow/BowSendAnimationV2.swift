// BowSendAnimationV2.swift
// Pointward › Instruments › Bow
//
// ACT 2 of 3 — the full-screen BOW send journey.
//
// THE GEMINI REDESIGN. A thin luminous gold arrow — gold shaft fading to a
// blazing white tip, a ✦ sparkle at the point, the emoji riding just above —
// launches from the screen edge (the same bearing it left the compass circle),
// streaks across the daytime sky on a soft glow-to-white trail, and exits.
//
//   LAUNCH (0.0–0.3s)  arrow appears at sendEntryPoint; string ghost-lines
//                      vibrate and fade; hard acceleration (easeIn)
//   FLIGHT (0.3–0.5s)  horizontal across ~55% height, slight upward arc at
//                      centre; whistle plays; gentle axial spin (scaleY)
//   EXIT   (0.5–0.8s)  exits off-screen along exitBearing; trail fades
//
// Total: InstrumentBoundaries.Send.bow (0.8s).
//
// HANDOFF: receives InstrumentTransition from the compass face (ACT 1) and
// begins the arrow at transition.sendEntryPoint(screenSize:) — never centre.
// On completion it calls onComplete; the shared send pipeline (CompassView)
// then shows the sent confirmation, exactly as every other instrument does.

import SwiftUI

struct BowSendAnimationV2: View {

  let transition: InstrumentTransition
  var personName: String = ""
  var onComplete: () -> Void = {}

  static let duration: Double = InstrumentBoundaries.Send.bow   // 0.8

  private static let launchEnd: Double = 0.3
  private static let flightEnd: Double = 0.5
  private static let total:     Double = 0.8

  private static let gold     = Color(hex: "#D4A017")
  private static let goldLite = Color(hex: "#F2D279")

  @State private var start: Date? = nil
  @State private var skyIn = false

  var body: some View {
    GeometryReader { geo in
      ZStack {
        Color(hex: "#0d0d14").ignoresSafeArea()
        InstrumentBackground.daySky
          .ignoresSafeArea()
          .opacity(skyIn ? 1 : 0)

        TimelineView(.animation) { timeline in
          let elapsed = clampedElapsed(now: timeline.date)
          ZStack {
            stringGhosts(geo: geo, elapsed: elapsed)
            streak(geo: geo, elapsed: elapsed)
            arrow(geo: geo, elapsed: elapsed)
          }
        }
      }
    }
    .ignoresSafeArea()
    .onAppear {
      start = Date()
      withAnimation(.easeInOut(duration: 0.3)) { skyIn = true }
      // The string release + airy whistle across the flight.
      InstrumentSoundPlayer.shared.playSend(.bow)
      InstrumentSoundPlayer.shared.playCue(file: BowSounds.arrowWhistleFile,
                                           duration: BowSounds.arrowWhistleDuration)
      HapticPattern.sharpSnap.fire()
      DispatchQueue.main.asyncAfter(deadline: .now() + Self.total) { onComplete() }
    }
  }

  private func clampedElapsed(now: Date) -> Double {
    guard let start else { return 0 }
    return min(max(0, now.timeIntervalSince(start)), Self.total)
  }

  // ── Path — edge → across ~55% height with a slight upward arc → off-screen ─

  private func arrowPos(geo: GeometryProxy, elapsed: Double) -> CGPoint {
    let size = geo.size
    let entry = transition.sendEntryPoint(screenSize: size)
    let exit  = departPoint(size)
    // A mid point pulling the line down to 55% height with a slight arc peak.
    let mid = CGPoint(x: size.width / 2, y: size.height * 0.50)
    let p = easeIn(elapsed / Self.total)
    // Quadratic through entry → mid → exit.
    let q = CGFloat(p)
    return CGPoint(
      x: (1 - q) * (1 - q) * entry.x + 2 * (1 - q) * q * mid.x + q * q * exit.x,
      y: (1 - q) * (1 - q) * entry.y + 2 * (1 - q) * q * mid.y + q * q * exit.y
    )
  }

  private func departPoint(_ size: CGSize) -> CGPoint {
    let rad = transition.exitBearing * .pi / 180
    return CGPoint(x: size.width / 2 + CGFloat(sin(rad)) * size.width * 1.15,
                   y: size.height / 2 - CGFloat(cos(rad)) * size.height * 1.15)
  }

  private func arrowAngle(geo: GeometryProxy, elapsed: Double) -> Double {
    let here = arrowPos(geo: geo, elapsed: elapsed)
    let ahead = arrowPos(geo: geo, elapsed: min(Self.total, elapsed + 0.03))
    return atan2(Double(ahead.y - here.y), Double(ahead.x - here.x))
  }

  // ── The arrow ─────────────────────────────────────────────────────────────

  @ViewBuilder
  private func arrow(geo: GeometryProxy, elapsed: Double) -> some View {
    let pos = arrowPos(geo: geo, elapsed: elapsed)
    let ang = arrowAngle(geo: geo, elapsed: elapsed)
    // Gentle axial spin: scaleY oscillates 0.6 → 1.0 → 0.6.
    let spinY = 0.6 + 0.4 * CGFloat(abs(sin(elapsed * 14)))
    let fade  = elapsed > Self.flightEnd
      ? 1 - CGFloat((elapsed - Self.flightEnd) / (Self.total - Self.flightEnd))
      : 1
    ZStack {
      Capsule()
        .fill(Self.gold.opacity(0.35 * Double(fade)))
        .frame(width: 88, height: 9).blur(radius: 6)
      Capsule()
        .fill(LinearGradient(colors: [Self.gold.opacity(Double(fade)),
                                      Self.goldLite.opacity(Double(fade)), .white],
                             startPoint: .leading, endPoint: .trailing))
        .frame(width: 80, height: 3)
      Circle().fill(.white).frame(width: 9, height: 9)
        .shadow(color: .white, radius: 7).offset(x: 40)
      Text("✦").font(.system(size: 13)).foregroundColor(Self.goldLite).offset(x: 46)
    }
    .scaleEffect(x: 1.0, y: spinY)
    .rotationEffect(.radians(ang))
    .opacity(Double(fade))
    .position(pos)
    .overlay(
      Text(transition.emoji)
        .font(.system(size: 34))
        .position(x: pos.x, y: pos.y - 30)
        .opacity(Double(fade))
    )
  }

  // ── String ghost lines — vibrate and fade in the first 0.3s ──────────────

  @ViewBuilder
  private func stringGhosts(geo: GeometryProxy, elapsed: Double) -> some View {
    if elapsed < Self.launchEnd {
      let entry = transition.sendEntryPoint(screenSize: geo.size)
      let fade = 1 - elapsed / Self.launchEnd
      ForEach(0..<2, id: \.self) { i in
        Capsule()
          .fill(Color.white.opacity(0.5 * fade))
          .frame(width: 3, height: 60)
          .rotationEffect(.degrees(Double(i) * 8 - 4))
          .position(x: entry.x + CGFloat(i) * 6, y: entry.y)
          .blur(radius: 1)
          .allowsHitTesting(false)
      }
    }
  }

  // ── Streak trail — wide soft glow → narrow white ─────────────────────────

  @ViewBuilder
  private func streak(geo: GeometryProxy, elapsed: Double) -> some View {
    ForEach(0..<10, id: \.self) { k in
      let tb = elapsed - Double(k) * 0.02
      if tb > 0 {
        let frac = Double(k) / 10
        let p = arrowPos(geo: geo, elapsed: tb)
        Circle()
          .fill((k < 4 ? Color.white : Self.goldLite).opacity((1 - frac) * 0.5))
          .frame(width: 11 - CGFloat(frac) * 7, height: 11 - CGFloat(frac) * 7)
          .blur(radius: 2)
          .position(p)
          .allowsHitTesting(false)
      }
    }
  }

  private func easeIn(_ t: Double) -> Double { let x = min(max(t,0),1); return x * x }
}
