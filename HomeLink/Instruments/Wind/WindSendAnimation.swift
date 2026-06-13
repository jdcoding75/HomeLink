// WindSendAnimation.swift
// Pointward › Instruments › Wind
//
// ACT 2 of 3 — the full-screen WIND send journey.
//
// THE APPROVED PROTOTYPE. A leaf, carried on the breeze, continues the journey
// the compass face began: it enters from the screen edge at the SAME bearing it
// exited the compass circle (InstrumentTransition.exitBearing), wanders a lazy
// side-to-side S-curve across a daytime sky shedding dandelion seeds, then drifts
// back out toward that same bearing. 6.5 s end to end — the slowest, most patient
// instrument (InstrumentBoundaries.Send.wind / .maximum).
//
//   ENTER  (1.0s)  edge → centre, easeOut, seeds trailing
//   SWIRL  (4.0s)  lazy S-curve · breathing scale · streaming seeds · messages
//   DEPART (1.5s)  back out toward exitBearing, shrinking, seeds in the wake
//
// HANDOFF: receives InstrumentTransition from the compass face (ACT 1) and begins
// the leaf at transition.sendEntryPoint(screenSize:) — never screen centre.

import SwiftUI

struct WindSendAnimation: View {

  /// The handoff from the compass face (ACT 1). The leaf enters at
  /// `transition.sendEntryPoint` and departs toward the same `exitBearing`.
  let transition: InstrumentTransition
  /// The recipient's name, woven into the drifting messages.
  var personName: String = ""
  /// Fired once when the 6.5 s journey completes.
  var onComplete: () -> Void = {}

  // ── Source-of-truth timing + sound (live beside the instrument) ──────────
  static let duration: Double = InstrumentBoundaries.Send.wind     // 6.5
  static let soundFile: String = WindSounds.sendFile
  static let soundDuration: Double = WindSounds.sendDuration

  // Phase boundaries (seconds). 1.0 + 4.0 + 1.5 = 6.5.
  private static let enterDur:  Double = 1.0
  private static let swirlDur:  Double = 4.0
  private static let departDur: Double = 1.5
  private static let enterEnd:  Double = enterDur                  // 1.0
  private static let swirlEnd:  Double = enterDur + swirlDur       // 5.0
  private static let total:     Double = enterDur + swirlDur + departDur  // 6.5

  // Swirl geometry (per spec).
  // swirlWidthAmp = 0 → NO horizontal excursion (was 0.36, the cause of the
  // inconsistent extra sweep). The leaf now bobs vertically only, so the journey
  // is a clean enter-in + drift-out = exactly 2 sweeps for EVERY exit bearing.
  private static let swirlWidthAmp:  CGFloat = 0.0    // × screen width (0 = no horizontal swirl)
  private static let swirlHeightAmp: CGFloat = 0.15   // × screen height
  // Angular rate (radians/sec) of the horizontal swirl sine. NAMED so it is
  // never confused with swirlWidthAmp again (the two used to both be 0.36, which
  // hid the real bug). With swirlWidthAmp = 0 it has no visible effect today, but
  // it stays named + distinct so the amplitude and frequency roles can't be
  // conflated by a future edit.
  private static let swirlFrequency: CGFloat = 0.36

  private static let leafW: CGFloat = 200
  private static let leafH: CGFloat = 124

  private static let leafGreen     = Color(hex: "#5a8a3a")
  private static let leafGreenLite = Color(hex: "#6fae4a")
  private static let cloudColor    = Color(hex: "#FFFAF0")

  @State private var start: Date? = nil
  @State private var skyIn = false       // 300 ms crossfade from the compass sky
  @State private var revealing = false   // leaf departed → sent confirmation

  var body: some View {
    GeometryReader { geo in
      ZStack {
        if revealing {
          // [4/5] THE SENT CONFIRMATION — the ONE shared reveal screen,
          // context = .sent (this is the sender's side), ambient = .wind
          // (daySky + clouds, continuous with the send). No separate sent
          // screen exists; this is the same EmojiRevealView the receipt uses.
          EmojiRevealView(emoji: transition.emoji,
                          message: transition.message,
                          tagline: transition.tagline,
                          context: .sent(recipientName: personName.isEmpty ? "them" : personName),
                          ambient: .wind,
                          onDismiss: onComplete)
            .transition(.opacity)
        } else {
          TimelineView(.animation) { timeline in
            let elapsed = clampedElapsed(now: timeline.date)
            ZStack {
              // ── BACKGROUND — the same daytime sky as the compass face,
              //    crossfaded in over 300 ms (never a hard cut). ──
              Color(hex: "#0d0d14").ignoresSafeArea()
              InstrumentBackground.daySky
                .ignoresSafeArea()
                .opacity(skyIn ? 1 : 0)

              clouds(geo: geo, elapsed: elapsed)
              seedTrail(geo: geo, elapsed: elapsed)
              leaf(geo: geo, elapsed: elapsed)

              // ── The drifting message ──
              VStack {
                Spacer()
                Text(message(elapsed: elapsed))
                  .font(.system(size: 20, design: .serif).italic())
                  .foregroundColor(InstrumentBackground.accentText)
                  .shadow(color: .black.opacity(0.4), radius: 6)
                  .padding(.bottom, 90)
                  .contentTransition(.opacity)
                  .animation(.easeInOut(duration: 0.5), value: message(elapsed: elapsed))
              }
            }
          }
        }
      }
    }
    .ignoresSafeArea()
    .onAppear {
      start = Date()
      // The approved wind send sound (6.5s, matches the journey).
      InstrumentSoundPlayer.shared.playSend(.wind)
      // Soft ambient breeze layered UNDER the send voice (playCue does not change
      // the send/receipt phase, so it never replaces or stops wind_send).
      InstrumentSoundPlayer.shared.playCue(file: WindSounds.breezeFile, duration: Self.total)
      withAnimation(.easeInOut(duration: 0.3)) { skyIn = true }   // crossfade
      // After the leaf departs → the sent confirmation reveal.
      DispatchQueue.main.asyncAfter(deadline: .now() + Self.total) {
        withAnimation(.easeInOut(duration: 0.3)) { revealing = true }
      }
    }
  }

  // ── Clock ────────────────────────────────────────────────────────────────

  private func clampedElapsed(now: Date) -> Double {
    guard let start else { return 0 }
    return min(max(0, now.timeIntervalSince(start)), Self.total)
  }

  // ── Leaf ───────────────────────────────────────────────────────────────

  @ViewBuilder
  private func leaf(geo: GeometryProxy, elapsed: Double) -> some View {
    let pos   = leafPos(geo: geo, elapsed: elapsed)
    let scale = leafScale(elapsed: elapsed)
    let tilt  = leafTilt(geo: geo, elapsed: elapsed)
    ZStack {
      LeafShape()
        .fill(LinearGradient(colors: [Self.leafGreenLite, Self.leafGreen],
                             startPoint: .top, endPoint: .bottom))
        .overlay(LeafVeins().stroke(Color.white.opacity(0.18), lineWidth: 1))
        .shadow(color: Self.leafGreen.opacity(0.5), radius: 10, y: 4)
      Text(transition.emoji).font(.system(size: 60))
    }
    .frame(width: Self.leafW, height: Self.leafH)
    .scaleEffect(scale)
    .rotationEffect(.degrees(tilt))
    .position(pos)
  }

  /// The leaf's centre on screen for any moment in the 6.5 s journey.
  private func leafPos(geo: GeometryProxy, elapsed: Double) -> CGPoint {
    let size   = geo.size
    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    let edge   = transition.sendEntryPoint(screenSize: size)   // exitBearing edge

    if elapsed <= Self.enterEnd {
      // ENTER — from the screen edge to centre, easeOut.
      let p = easeOut(elapsed / Self.enterDur)
      return lerp(edge, center, p)
    } else if elapsed <= Self.swirlEnd {
      // SWIRL — lazy side-to-side S-curve around centre.
      return swirlPos(localT: elapsed - Self.enterEnd, size: size)
    } else {
      // DEPART — back out along the SAME exitBearing, all the way OFF screen
      // (1.15× reach per axis, RULE 5), easeInOut. `edge` (the entry) is the
      // same direction, so the journey reads as continuous.
      _ = edge
      let from = swirlPos(localT: Self.swirlDur, size: size)
      let p = easeInOut((elapsed - Self.swirlEnd) / Self.departDur)
      return lerp(from, departPoint(size), p)
    }
  }

  /// The off-screen exit — same bearing as the entry, extended to 1.15× of each
  /// axis from centre so the leaf clearly leaves the screen (RULE 5). Uses the
  /// screen convention (0° = up) to match `sendEntryPoint`.
  private func departPoint(_ size: CGSize) -> CGPoint {
    let rad = transition.exitBearing * .pi / 180
    return CGPoint(x: size.width  / 2 + CGFloat(sin(rad)) * size.width  * 1.15,
                   y: size.height / 2 - CGFloat(cos(rad)) * size.height * 1.15)
  }

  /// The S-curve: x oscillates wide, y waves at half the rate — a lazy figure
  /// that reads as a leaf wandering on the breeze. Continuous with ENTER
  /// (localT 0 → centre) and DEPART (localT 4 → the depart origin).
  private func swirlPos(localT: Double, size: CGSize) -> CGPoint {
    // [1/5] Centre on the TRUE full-screen middle (GeometryReader size) so the
    // leaf swirls through the centre and never touches the bottom.
    //
    // SWEEP COUNT — the real fix. The extra, bearing-dependent sweep was caused
    // by the HORIZONTAL swirl: a FIXED screen-space excursion (swirlWidthAmp,
    // toward the right) that opposed the bearing-anchored enter/depart whenever
    // sin(exitBearing) was small, forcing the leaf to double back. Earlier
    // attempts only lowered the horizontal FREQUENCY (0.48→0.36), which never
    // touched the amplitude and so never fixed it. Setting swirlWidthAmp = 0
    // removes the horizontal excursion entirely: the leaf comes in to centre and
    // drifts back out along the same bearing — exactly 2 sweeps for EVERY exit
    // bearing. Only the vertical bob (swirlHeightAmp) remains, which never adds a
    // horizontal sweep.
    //   x = cx + sin(t·swirlFrequency) · width  · swirlWidthAmp   (swirlWidthAmp = 0)
    //   y = cy + sin(t·0.22 + 1.0)     · height · swirlHeightAmp
    let sx = sin(localT * Double(Self.swirlFrequency))
    let sy = sin(localT * 0.22 + 1.0)
    return CGPoint(x: size.width  / 2 + CGFloat(sx) * size.width  * Self.swirlWidthAmp,
                   y: size.height / 2 + CGFloat(sy) * size.height * Self.swirlHeightAmp)
  }

  /// Breathes gently throughout (1 + sin(t·0.4)·0.03); shrinks to nothing as it
  /// departs.
  private func leafScale(elapsed: Double) -> CGFloat {
    let breathe = 1 + CGFloat(sin(elapsed * 0.4)) * 0.03
    if elapsed > Self.swirlEnd {
      let p = easeInOut((elapsed - Self.swirlEnd) / Self.departDur)
      return breathe * (1 - CGFloat(p))
    }
    return breathe
  }

  /// Tilts naturally with the direction of travel — banks into the curve by
  /// sampling the leaf's horizontal velocity a beat ahead.
  private func leafTilt(geo: GeometryProxy, elapsed: Double) -> Double {
    let ahead = leafPos(geo: geo, elapsed: min(Self.total, elapsed + 0.05))
    let here  = leafPos(geo: geo, elapsed: elapsed)
    let dx = ahead.x - here.x
    return Double(max(-20, min(20, dx * 0.5)))   // gentle ±20° bank
  }

  // ── Seeds ────────────────────────────────────────────────────────────────

  /// A comet of dandelion seeds tracing the leaf's recent path — they trail
  /// behind on ENTER, stream continuously through the SWIRL, and lag off in the
  /// wake as the leaf DEPARTS.
  @ViewBuilder
  private func seedTrail(geo: GeometryProxy, elapsed: Double) -> some View {
    let count = InstrumentBoundaries.Particles.standard   // 20
    ForEach(0..<count, id: \.self) { k in
      let tb = elapsed - Double(k) * 0.05
      if tb > 0 {
        let frac = Double(k) / Double(count)
        let p = leafPos(geo: geo, elapsed: tb)
        // A little organic spread so the trail isn't a rigid line.
        let jx = CGFloat(sin(tb * 9 + Double(k))) * 7
        let jy = CGFloat(cos(tb * 7 + Double(k))) * 7
        DandelionSeed(size: 9 - CGFloat(frac) * 4,
                      opacity: (1 - frac) * 0.8)
          .position(x: p.x + jx, y: p.y + jy)
          .allowsHitTesting(false)
      }
    }
  }

  // ── Clouds — 5 drifting, same fluffy style as the compass face ───────────

  private struct CloudSpec: Identifiable {
    let id = UUID()
    let y: CGFloat        // fraction of height
    let scale: CGFloat
    let speed: Double     // points per second
    let phase: CGFloat    // 0…1 start offset
  }

  private static let cloudSpecs: [CloudSpec] = [
    CloudSpec(y: 0.16, scale: 0.70, speed: 14, phase: 0.10),
    CloudSpec(y: 0.30, scale: 1.10, speed:  9, phase: 0.55),
    CloudSpec(y: 0.48, scale: 0.85, speed: 11, phase: 0.30),
    CloudSpec(y: 0.66, scale: 0.55, speed: 16, phase: 0.78),
    CloudSpec(y: 0.80, scale: 0.95, speed:  8, phase: 0.42),
  ]

  @ViewBuilder
  private func clouds(geo: GeometryProxy, elapsed: Double) -> some View {
    let span = geo.size.width + 240
    ForEach(Self.cloudSpecs) { spec in
      let raw = spec.phase * span + CGFloat(elapsed * spec.speed)
      let x = raw.truncatingRemainder(dividingBy: span) - 120
      cloudShape
        .scaleEffect(spec.scale)
        .position(x: x, y: geo.size.height * spec.y)
        .opacity(0.55 + Double(spec.scale) * 0.18)
        .allowsHitTesting(false)
    }
  }

  /// A fluffy cloud — overlapping soft circles for organic edges.
  private var cloudShape: some View {
    ZStack {
      Circle().frame(width: 64, height: 64).offset(x: -30)
      Circle().frame(width: 92, height: 92)
      Circle().frame(width: 70, height: 70).offset(x: 34, y: 6)
      Capsule().frame(width: 150, height: 50).offset(y: 18)
    }
    .foregroundColor(Self.cloudColor.opacity(0.78))
    .blur(radius: 4)
  }

  // ── Messages — patience, cycling through the swirl ───────────────────────

  private func message(elapsed: Double) -> String {
    let name = personName.isEmpty ? "them" : personName
    let lt = elapsed - Self.enterDur     // swirl-local seconds
    if lt < 1.5 { return "drifting toward \(name) ✦" }
    if lt < 3.0 { return "taking its time ✦" }
    // [copy] "patience is the message ✦" removed — no replacement (shows nothing
    // for the final beat). Copy-only change; animation timing/behaviour unchanged.
    return ""
  }

  // ── Easing + interpolation helpers ───────────────────────────────────────

  private func easeOut(_ t: Double) -> Double {
    let x = min(max(t, 0), 1)
    return 1 - pow(1 - x, 3)
  }

  private func easeInOut(_ t: Double) -> Double {
    let x = min(max(t, 0), 1)
    return x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
  }

  private func lerp(_ a: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint {
    CGPoint(x: a.x + (b.x - a.x) * CGFloat(t),
            y: a.y + (b.y - a.y) * CGFloat(t))
  }
}
