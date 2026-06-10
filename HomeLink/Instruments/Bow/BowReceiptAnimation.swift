// BowReceiptAnimation.swift
// Pointward › Instruments › Bow
//
// ACT 3 of 3 — the full-screen BOW receipt journey + emoji reveal.
//
// THE GEMINI REDESIGN. A luminous gold arrow flies in FROM the sender's
// bearing across the same daytime sky as the compass face and the send, the
// emoji riding its tip. As it nears the bucket the shaft fades to a dashed
// ghost and then DISSOLVES into a cloud of gold + white sparkles that carry
// the arrow's momentum forward and converge on the bucket mouth — the new
// signature beat. The sparkles drop in, the bucket glows with a soft cyan
// upward radiance, the emoji settles VISIBLE inside the mouth, then blooms
// into the shared EmojiRevealView.
//
//   ENTRY    (0.0–1.2s)  left edge → toward the bucket, grows; whistle plays
//   APPROACH (1.2–2.2s)  homes in, emoji riding the arrowhead tip
//   DISSOLVE (2.2–3.0s)  shaft → dashed → gold+white sparkles; dissolve plays
//   LAND     (3.0–3.5s)  sparkles drop in; cyan glow; emoji visible in bucket
//   BLOOM    (3.5s+)     → EmojiRevealView (.received)                  = 3.5s
//
// ENTRY RULE (differs from send): the arrow arrives FROM the sender's bearing.
// The receipt is its own emotional moment.

import SwiftUI

struct BowReceiptAnimation: View {

  // ── Receives (matches WindReceiptAnimation's signature) ────────────────
  let senderBearing: Double      // degrees the thought arrives FROM
  let emoji: String
  var message: String? = nil
  var tagline: String? = nil
  let fromName: String
  var onRevealed: () -> Void = {}
  var onFinished: () -> Void = {}

  // ── Source-of-truth timing + sound ─────────────────────────────────────
  static let duration: Double = InstrumentBoundaries.Receipt.bow   // 3.5
  static let revealLinger: Double = InstrumentBoundaries.Reveal.linger

  // Phase boundaries (seconds). 1.2 + 1.0 + 0.8 + 0.5 = 3.5.
  private static let entryEnd:    Double = 1.2
  private static let approachEnd: Double = 2.2
  private static let dissolveEnd: Double = 3.0
  private static let total:       Double = 3.5

  // Bucket — the shared wooden skin, on the right per the Gemini scene.
  private static let bucketW: CGFloat = 150
  private static let bucketH: CGFloat = 128

  private static let gold      = Color(hex: "#D4A017")
  private static let goldLite  = Color(hex: "#F2D279")
  private static let cyan      = Color(hex: "#50B4F0")
  private static let wood      = Color(hex: "#8B4513")
  private static let woodDark  = Color(hex: "#6E3A1E")
  private static let brass     = Color(hex: "#C9A86A")

  // Stable per-particle randomness for the dissolve cloud (no random at render
  // time — derived from the index, like the rest of the codebase).
  private static let sparkleCount = 26
  private static let sparkleSeeds: [(a: Double, r: CGFloat, sz: CGFloat, white: Bool)] = {
    (0..<sparkleCount).map { i in
      let a = (Double(i) / Double(sparkleCount)) * 2 * .pi + Double(i % 5) * 0.21
      let r = CGFloat(28 + (i * 37) % 92)
      let sz = CGFloat(3 + (i * 13) % 5)
      return (a, r, sz, i % 2 == 0)
    }
  }()

  @State private var start: Date? = nil
  @State private var skyIn = false
  @State private var bucketGlow = false
  @State private var revealing = false

  private var rad: Double { senderBearing * .pi / 180 }

  var body: some View {
    GeometryReader { geo in
      ZStack {
        if revealing {
          EmojiRevealView(emoji: emoji, message: message, tagline: tagline,
                          context: .received(fromName: fromName),
                          ambient: .bow,
                          onDismiss: onFinished)
            .transition(.opacity)
        } else {
          TimelineView(.animation) { timeline in
            let elapsed = clampedElapsed(now: timeline.date)
            ZStack {
              // BACKGROUND — the same daytime sky, crossfaded in.
              Color(hex: "#0d0d14").ignoresSafeArea()
              InstrumentBackground.daySky
                .ignoresSafeArea()
                .opacity(skyIn ? 1 : 0)

              bucket(geo: geo)
              streak(geo: geo, elapsed: elapsed)
              arrow(geo: geo, elapsed: elapsed)
              sparkles(geo: geo, elapsed: elapsed)
              emojiInBucket(geo: geo, elapsed: elapsed)
              messageView(geo: geo, elapsed: elapsed)
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
    withAnimation(.easeInOut(duration: 0.3)) { skyIn = true }
    // Whistle on the inbound flight (entry + approach ≈ 2.2s of travel).
    InstrumentSoundPlayer.shared.playCue(file: BowSounds.arrowWhistleFile,
                                         duration: BowSounds.arrowWhistleDuration)
    HapticPattern.singleSoft.fire()

    // DISSOLVE — the shaft breaks into sparkles.
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.approachEnd) {
      InstrumentSoundPlayer.shared.playCue(file: BowSounds.sparkleDissolveFile,
                                           duration: BowSounds.sparkleDissolveDuration)
      HapticPattern.doubleSoft.fire()
    }
    // LAND — sparkles drop into the bucket; cyan glow blooms; soft thud.
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.dissolveEnd) {
      InstrumentSoundPlayer.shared.playReceipt(.bow)
      HapticPattern.singleMedium.fire()
      withAnimation(.easeOut(duration: 0.5)) { bucketGlow = true }
    }
    // BLOOM — the reveal. "Felt means felt" fires here.
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.total) {
      onRevealed()
      withAnimation(.easeInOut(duration: 0.3)) { revealing = true }
    }
  }

  private func clampedElapsed(now: Date) -> Double {
    guard let start else { return 0 }
    return min(max(0, now.timeIntervalSince(start)), Self.total)
  }

  // ── Geometry ──────────────────────────────────────────────────────────

  private func bucketPoint(_ size: CGSize) -> CGPoint {
    CGPoint(x: size.width * 0.72, y: size.height - 110)
  }

  /// Entry point — left edge, slightly above middle (Gemini scene 1).
  private func entryPoint(_ size: CGSize) -> CGPoint {
    CGPoint(x: -size.width * 0.1, y: size.height * 0.35)
  }

  private func midWaypoint(_ size: CGSize) -> CGPoint {
    CGPoint(x: size.width * 0.42, y: size.height * 0.30)
  }

  /// The arrow tip's position for any moment up to the dissolve.
  private func arrowPos(geo: GeometryProxy, elapsed: Double) -> CGPoint {
    let size = geo.size
    if elapsed <= Self.entryEnd {
      // ENTRY — edge → a mid waypoint (slight upward arc), easeOut.
      return lerp(entryPoint(size), midWaypoint(size), easeOut(elapsed / Self.entryEnd))
    } else {
      // APPROACH → DISSOLVE start — mid waypoint → bucket mouth, easeInOut.
      let p = easeInOut(min(1, (elapsed - Self.entryEnd) / (Self.dissolveEnd - Self.entryEnd)))
      return lerp(midWaypoint(size), bucketPoint(size), p)
    }
  }

  /// Direction of travel (radians, screen 0° = right) for orienting the arrow.
  private func arrowAngle(geo: GeometryProxy, elapsed: Double) -> Double {
    let here = arrowPos(geo: geo, elapsed: elapsed)
    let ahead = arrowPos(geo: geo, elapsed: min(Self.dissolveEnd, elapsed + 0.04))
    return atan2(Double(ahead.y - here.y), Double(ahead.x - here.x))
  }

  // ── The arrow — a thin luminous gold line, white blazing tip, emoji above ─

  @ViewBuilder
  private func arrow(geo: GeometryProxy, elapsed: Double) -> some View {
    if elapsed < Self.dissolveEnd {
      let pos = arrowPos(geo: geo, elapsed: elapsed)
      let ang = arrowAngle(geo: geo, elapsed: elapsed)
      let grow = 0.8 + 0.35 * CGFloat(min(1, elapsed / Self.approachEnd))
      // Fade the shaft to a dashed ghost across the DISSOLVE window.
      let dissolveP = elapsed > Self.approachEnd
        ? CGFloat((elapsed - Self.approachEnd) / (Self.dissolveEnd - Self.approachEnd))
        : 0
      let shaftOpacity = 1 - dissolveP

      ZStack {
        // Soft outer glow line
        Capsule()
          .fill(Self.gold.opacity(0.35 * Double(shaftOpacity)))
          .frame(width: 88, height: 9)
          .blur(radius: 6)
        // The gold → white shaft
        Capsule()
          .fill(LinearGradient(colors: [Self.gold.opacity(Double(shaftOpacity)),
                                        Self.goldLite.opacity(Double(shaftOpacity)),
                                        .white],
                               startPoint: .leading, endPoint: .trailing))
          .frame(width: 80, height: 3)
          .opacity(shaftOpacity > 0.05 ? 1 : 0)
          // dashed feel as it dissolves
          .overlay(
            Capsule().stroke(Color.white.opacity(Double(dissolveP) * 0.8),
                             style: StrokeStyle(lineWidth: 3, dash: [4, 5]))
              .frame(width: 80, height: 3)
          )
        // Blazing white tip point at the leading end (+x)
        Circle()
          .fill(.white)
          .frame(width: 9, height: 9)
          .shadow(color: .white, radius: 7)
          .offset(x: 40)
        // ✦ sparkle at the tip
        Text("✦")
          .font(.system(size: 13))
          .foregroundColor(Self.goldLite)
          .offset(x: 46)
      }
      .rotationEffect(.radians(ang))
      .scaleEffect(grow)
      .position(pos)
      // Emoji rides ABOVE the tip, upright and readable.
      .overlay(
        Text(emoji)
          .font(.system(size: 34))
          .position(x: pos.x, y: pos.y - 30)
          .opacity(Double(shaftOpacity))
      )
    }
  }

  // ── Streak trail — wide soft glow narrowing to white, behind the arrow ───

  @ViewBuilder
  private func streak(geo: GeometryProxy, elapsed: Double) -> some View {
    if elapsed < Self.dissolveEnd {
      ForEach(0..<10, id: \.self) { k in
        let tb = elapsed - Double(k) * 0.035
        if tb > 0 {
          let frac = Double(k) / 10
          let p = arrowPos(geo: geo, elapsed: tb)
          Circle()
            .fill((k < 4 ? Color.white : Self.goldLite).opacity((1 - frac) * 0.5))
            .frame(width: 10 - CGFloat(frac) * 6, height: 10 - CGFloat(frac) * 6)
            .blur(radius: 2)
            .position(p)
            .allowsHitTesting(false)
        }
      }
    }
  }

  // ── DISSOLVE — gold+white sparkles carry momentum into the bucket mouth ──

  @ViewBuilder
  private func sparkles(geo: GeometryProxy, elapsed: Double) -> some View {
    if elapsed >= Self.approachEnd {
      // Where the shaft was when it began to dissolve.
      let origin = arrowPos(geo: geo, elapsed: Self.approachEnd)
      let bucket = bucketPoint(geo.size)
      // 0 at dissolve start → 1 once landed in the bucket.
      let p = CGFloat(min(1, (elapsed - Self.approachEnd) / (Self.total - Self.approachEnd)))
      ForEach(0..<Self.sparkleCount, id: \.self) { i in
        let s = Self.sparkleSeeds[i]
        // Start scattered around the origin (carrying forward momentum), then
        // converge on the bucket mouth.
        let scatter = CGPoint(x: origin.x + CGFloat(cos(s.a)) * s.r,
                              y: origin.y + CGFloat(sin(s.a)) * s.r)
        let pos = lerp(scatter, bucket, easeInOut(Double(p)))
        Circle()
          .fill(s.white ? Color.white : Self.goldLite)
          .frame(width: s.sz, height: s.sz)
          .shadow(color: (s.white ? Color.white : Self.gold).opacity(0.8), radius: 4)
          .position(pos)
          .opacity(Double(1 - p) * 0.5 + 0.5)   // dim slightly as they sink in
          .allowsHitTesting(false)
      }
    }
  }

  // ── The bucket — shared wooden barrel, cyan inner radiance on land ───────

  private func bucket(geo: GeometryProxy) -> some View {
    let p = bucketPoint(geo.size)
    return ZStack {
      // Soft cyan upward radiance from inside the mouth (rgba(80,180,240,0.25)).
      Ellipse()
        .fill(RadialGradient(colors: [Self.cyan.opacity(bucketGlow ? 0.25 : 0), .clear],
                             center: .center, startRadius: 2, endRadius: 90))
        .frame(width: Self.bucketW * 1.2, height: 120)
        .offset(y: -Self.bucketH / 2)
        .blur(radius: 6)
      BucketHandleShape()
        .stroke(Self.brass, style: StrokeStyle(lineWidth: 4, lineCap: .round))
        .frame(width: Self.bucketW * 0.9, height: 52)
        .offset(y: -Self.bucketH / 2 - 16)
      BucketShape()
        .fill(LinearGradient(colors: [Self.wood, Self.woodDark],
                             startPoint: .top, endPoint: .bottom))
        .frame(width: Self.bucketW, height: Self.bucketH)
        .overlay(
          VStack {
            Capsule().fill(Self.brass).frame(height: 6)
              .padding(.horizontal, -2).padding(.top, 12)
            Spacer()
            Capsule().fill(Self.brass).frame(height: 6)
              .padding(.horizontal, 6).padding(.bottom, 14)
          }
          .frame(width: Self.bucketW, height: Self.bucketH)
          .opacity(0.85)
        )
        .shadow(color: .black.opacity(0.4), radius: 10, y: 6)
    }
    .position(p)
  }

  // ── Emoji settles VISIBLE inside the bucket mouth after the land ─────────

  @ViewBuilder
  private func emojiInBucket(geo: GeometryProxy, elapsed: Double) -> some View {
    if elapsed >= Self.dissolveEnd {
      let p = bucketPoint(geo.size)
      let settle = easeOut(min(1, (elapsed - Self.dissolveEnd) / (Self.total - Self.dissolveEnd)))
      Text(emoji)
        .font(.system(size: 46))
        .scaleEffect(0.6 + 0.4 * CGFloat(settle))
        .position(x: p.x, y: p.y - Self.bucketH * 0.18)
        .opacity(settle)
        .allowsHitTesting(false)
    }
  }

  // ── Messages ─────────────────────────────────────────────────────────────

  @ViewBuilder
  private func messageView(geo: GeometryProxy, elapsed: Double) -> some View {
    VStack {
      Spacer()
      Text(message(elapsed: elapsed))
        .font(.system(size: 20, design: .serif).italic())
        .foregroundColor(InstrumentBackground.accentText)
        .shadow(color: .black.opacity(0.4), radius: 6)
        .padding(.bottom, 60)
        .contentTransition(.opacity)
        .animation(.easeInOut(duration: 0.5), value: message(elapsed: elapsed))
    }
  }

  private func message(elapsed: Double) -> String {
    let name = fromName.isEmpty ? "someone" : fromName
    if elapsed < Self.entryEnd     { return "\(name) took aim ✦" }
    if elapsed < Self.dissolveEnd  { return "a thought, arriving ✦" }
    return "landed ✦"
  }

  // ── Easing + interpolation ────────────────────────────────────────────────

  private func easeOut(_ t: Double) -> Double { let x = min(max(t,0),1); return 1 - pow(1 - x, 3) }
  private func easeInOut(_ t: Double) -> Double {
    let x = min(max(t,0),1); return x < 0.5 ? 4*x*x*x : 1 - pow(-2*x + 2, 3) / 2
  }
  private func lerp(_ a: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint {
    CGPoint(x: a.x + (b.x - a.x) * CGFloat(t), y: a.y + (b.y - a.y) * CGFloat(t))
  }
}
