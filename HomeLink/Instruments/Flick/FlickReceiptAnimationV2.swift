// FlickReceiptAnimationV2.swift
// Pointward › Instruments › Flick
//
// ACT 3 of 3 — the full-screen FLICK receipt journey + emoji reveal.
//
// A crumpled paper ball sails in from the left on ONE smooth bezier arc — no
// phases, no hesitation — peaks near the top-centre, then drops into the shared
// wooden bucket sitting in the lower-right corner. It lands with a bounce, a
// burst of cream dust, and a soft lavender glow; the emoji settles VISIBLE
// inside the bucket mouth, then blooms into the shared EmojiRevealView.
//
//   TRAVEL (0.0–2.5s)  single quadratic bezier: left edge → bucket mouth,
//                      ball spinning, growing 0.85→1.0→0.85, cream trail
//   LAND   (~2.5s)     easeOutBounce settle; flick_receipt.wav; dust; glow
//   IN-BUCKET (2.5–2.8s) emoji visible inside the bucket
//   BLOOM  (2.8s+)     → EmojiRevealView (.received)                 = 2.8s
//
// Background is the corkBoard world — continuous with the flick reveal ambient.

import SwiftUI

struct FlickReceiptAnimationV2: View {

  // ── Receives (matches the dedicated-receipt signature) ─────────────────
  let senderBearing: Double
  let emoji: String
  var message: String? = nil
  var tagline: String? = nil
  let fromName: String
  var onRevealed: () -> Void = {}
  var onFinished: () -> Void = {}
  /// [catch-bucket-removed-2026-06] DEFAULT false = live (no bucket, re-center to reveal). Lab passes true.
  var showBucket: Bool = false

  // ── Source-of-truth timing ─────────────────────────────────────────────
  static let duration: Double = InstrumentBoundaries.Receipt.flick   // 2.8
  static let revealLinger: Double = InstrumentBoundaries.Reveal.linger

  private static let landAt: Double = 2.5
  private static let total: Double = 2.8

  private static let bucketW: CGFloat = 140
  private static let bucketH: CGFloat = 120

  private static let paper     = Color(hex: "#F8F8F0")
  private static let paperEdge = Color(hex: "#D9D4C2")
  private static let crease    = Color(hex: "#C9C2AC")
  private static let lavender  = Color(hex: "#C4A8D4")
  private static let wood      = Color(hex: "#8B4513")
  private static let woodDark  = Color(hex: "#6E3A1E")
  private static let brass     = Color(hex: "#C9A86A")

  // Stable dust-burst directions (index-derived, no render-time random).
  private static let dustCount = 12
  private static let dustSeeds: [(a: Double, r: CGFloat, sz: CGFloat)] = {
    (0..<dustCount).map { i in
      let a = (Double(i) / Double(dustCount)) * 2 * .pi
      let r = CGFloat(34 + (i * 17) % 30)
      let sz = CGFloat(3 + (i * 7) % 4)
      return (a, r, sz)
    }
  }()

  @State private var start: Date? = nil
  @State private var boardIn = false
  @State private var landed = false
  @State private var revealing = false

  var body: some View {
    GeometryReader { geo in
      ZStack {
        if revealing {
          EmojiRevealView(emoji: emoji, message: message, tagline: tagline,
                          context: .received(fromName: fromName),
                          ambient: .flick,
                          onDismiss: onFinished)
            .transition(.opacity)
        } else {
          TimelineView(.animation) { timeline in
            let elapsed = clampedElapsed(now: timeline.date)
            ZStack {
              // BACKGROUND — the full school DESK (wall + oak surface),
              // crossfaded in. The bucket sits upright on the desk floor.
              Color(hex: "#0d0d14").ignoresSafeArea()
              FlickDeskWorld()
                .ignoresSafeArea()
                .opacity(boardIn ? 1 : 0)

              if showBucket { bucket(geo: geo) }   // [catch-bucket-removed-2026-06]
              dust(geo: geo)
              trail(geo: geo, elapsed: elapsed)
              ball(geo: geo, elapsed: elapsed)
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
    withAnimation(.easeInOut(duration: 0.3)) { boardIn = true }
    // LAND — the thwack, the dust, the glow.
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.landAt) {
      InstrumentSoundPlayer.shared.playReceipt(.flick)   // muffled soft thud
      HapticPattern.singleSoft.fire()                    // gentle — NOT a sharp crack
      withAnimation(.easeOut(duration: 0.5)) { landed = true }
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

  // ── Geometry — one quadratic bezier, left edge → bucket mouth ────────────

  private func bucketPoint(_ size: CGSize) -> CGPoint {
    // [catch-bucket-removed-2026-06] bucketless (live) → re-center to the reveal focal point.
    showBucket ? CGPoint(x: size.width - 80, y: size.height - 95)
               : CGPoint(x: size.width / 2, y: size.height * 0.46)
  }

  private func ballPos(geo: GeometryProxy, elapsed: Double) -> CGPoint {
    let size = geo.size
    let s = CGPoint(x: 20, y: size.height * 0.48)
    let c = CGPoint(x: size.width * 0.32, y: size.height * 0.15)
    let e = bucketPoint(size)
    // Linear progress to the land, with an easeOutBounce settle right at the end.
    var p = min(1, elapsed / Self.landAt)
    if elapsed >= Self.landAt { p = 1 }
    // [phase3] Bounce magnitude reduced 30%: blend 70% easeOutBounce with 30% of
    // a smooth easeOut so the overshoot amplitude is gentler (both end at 1).
    let smooth = 1 - pow(1 - Double(p), 2)
    let bp = 0.7 * easeOutBounce(Double(p)) + 0.3 * smooth
    let q = CGFloat(bp)
    let mx = (1 - q) * (1 - q) * s.x + 2 * (1 - q) * q * c.x + q * q * e.x
    let my = (1 - q) * (1 - q) * s.y + 2 * (1 - q) * q * c.y + q * q * e.y
    return CGPoint(x: mx, y: my)
  }

  // ── The crumpled paper ball — spins, grows then recedes, cream creases ───

  @ViewBuilder
  private func ball(geo: GeometryProxy, elapsed: Double) -> some View {
    if elapsed < Self.landAt {
      let pos = ballPos(geo: geo, elapsed: elapsed)
      let spin = elapsed * 300                                  // 300°/sec
      let p = min(1, elapsed / Self.landAt)
      let grow = 0.85 + 0.15 * CGFloat(sin(p * .pi))           // 0.85 → 1.0 → 0.85
      // The shared crumpled-paper ball (one source of truth).
      CrumpledPaperBall(size: 40, emoji: emoji, emojiOpacity: 0.3, showShadow: false)
        .rotationEffect(.degrees(spin))
        .scaleEffect(grow)
        .position(pos)
    }
  }

  // ── Cream trail dots behind the ball (NOT gold — paper, not magic) ───────

  @ViewBuilder
  private func trail(geo: GeometryProxy, elapsed: Double) -> some View {
    if elapsed < Self.landAt {
      ForEach(0..<8, id: \.self) { k in
        let tb = elapsed - Double(k) * 0.04
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
  }

  // ── The bucket — shared wooden barrel, lavender inner glow on land ───────

  private func bucket(geo: GeometryProxy) -> some View {
    let p = bucketPoint(geo.size)
    return ZStack {
      // Lavender upward radiance from inside the mouth (rgba(196,168,212,0.25)).
      Ellipse()
        .fill(RadialGradient(colors: [Self.lavender.opacity(landed ? 0.25 : 0), .clear],
                             center: .center, startRadius: 2, endRadius: 80))
        .frame(width: Self.bucketW * 1.2, height: 110)
        .offset(y: -Self.bucketH / 2)
        .blur(radius: 6)
      BucketHandleShape()
        .stroke(Self.brass, style: StrokeStyle(lineWidth: 4, lineCap: .round))
        .frame(width: Self.bucketW * 0.9, height: 48)
        .offset(y: -Self.bucketH / 2 - 14)
      BucketShape()
        .fill(LinearGradient(colors: [Self.wood, Self.woodDark],
                             startPoint: .top, endPoint: .bottom))
        .frame(width: Self.bucketW, height: Self.bucketH)
        .overlay(
          VStack {
            Capsule().fill(Self.brass).frame(height: 6)
              .padding(.horizontal, -2).padding(.top, 11)
            Spacer()
            Capsule().fill(Self.brass).frame(height: 6)
              .padding(.horizontal, 6).padding(.bottom, 13)
          }
          .frame(width: Self.bucketW, height: Self.bucketH)
          .opacity(0.85)
        )
        .shadow(color: .black.opacity(0.4), radius: 10, y: 6)
    }
    .position(p)
  }

  // ── Dust burst at the landing ────────────────────────────────────────────

  @ViewBuilder
  private func dust(geo: GeometryProxy) -> some View {
    if landed {
      let p = bucketPoint(geo.size)
      ForEach(0..<Self.dustCount, id: \.self) { i in
        let s = Self.dustSeeds[i]
        Circle()
          .fill(Self.paper.opacity(0.7))
          .frame(width: s.sz, height: s.sz)
          .position(x: p.x + CGFloat(cos(s.a)) * s.r,
                    y: p.y - Self.bucketH * 0.35 + CGFloat(sin(s.a)) * s.r * 0.6)
          .opacity(landed ? 0 : 0.7)
          .animation(.easeOut(duration: 0.7), value: landed)
          .allowsHitTesting(false)
      }
    }
  }

  // ── Emoji settles VISIBLE inside the bucket after the land ───────────────

  @ViewBuilder
  private func emojiInBucket(geo: GeometryProxy, elapsed: Double) -> some View {
    if elapsed >= Self.landAt {
      let p = bucketPoint(geo.size)
      let settle = easeOut(min(1, (elapsed - Self.landAt) / (Self.total - Self.landAt)))
      Text(emoji)
        .font(.system(size: 44))
        .scaleEffect(0.6 + 0.4 * CGFloat(settle))
        .position(x: p.x, y: p.y - Self.bucketH * 0.16)
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
    // [copy 2026-06-25] unified sender sentence. was: "\(name) flicked you a thought ✦"
    if elapsed < Self.landAt { return "\(name) sent you something ✦" }
    return "landed ✦"
  }

  // ── Easing ────────────────────────────────────────────────────────────────

  private func easeOut(_ t: Double) -> Double { let x = min(max(t,0),1); return 1 - pow(1 - x, 3) }

  /// Classic easeOutBounce.
  private func easeOutBounce(_ t: Double) -> Double {
    var x = min(max(t, 0), 1)
    let n1 = 7.5625, d1 = 2.75
    if x < 1 / d1 { return n1 * x * x }
    else if x < 2 / d1 { x -= 1.5 / d1; return n1 * x * x + 0.75 }
    else if x < 2.5 / d1 { x -= 2.25 / d1; return n1 * x * x + 0.9375 }
    else { x -= 2.625 / d1; return n1 * x * x + 0.984375 }
  }
}
