// EmojiRevealView.swift
// Pointward › Instruments › _Shared › EmojiReveal
//
// THE SINGLE REVEAL SCREEN — for BOTH sent confirmation and received reveal.
// Context determines copy · Ambient determines background · Emoji determines
// the animation + sound. THERE IS NO OTHER REVEAL SCREEN.
//
// The per-emoji animation is chosen by RevealAnimationRegistry (a [emoji: kind]
// dict) — not if/else. Each kind has a start<Kind>() below driving a shared set
// of transform/effect state. 🤗 (hug) and 👊 (punch) migrated first, unchanged.
//
// Full-screen kinds (🤜🤛 💭 💥 🎆 🎓) read positions from geo.size — never a
// hardcoded dimension. These are working PLACEHOLDERS — refined later.

import SwiftUI

struct EmojiRevealView: View {
  let emoji: String
  let message: String?
  let tagline: String?
  let context: RevealContext
  let ambient: RevealAmbient
  let onDismiss: () -> Void

  // Text + glow + bloom (shared by every reveal)
  @State private var bloomed = false
  @State private var messageVisible = false
  @State private var taglineVisible = false
  @State private var contextVisible = false
  @State private var dismissVisible = false
  @State private var glowScale: CGFloat = 1.0

  // 🤗 hug squeeze (unchanged)
  @State private var hugOpen = false
  @State private var hugClose = false

  // 👊 punch (renamed from fist*) — slams in from the left, 3 pumps
  @State private var punchOffsetX: CGFloat = -120
  @State private var punchScaleX: CGFloat = 0
  @State private var punchScaleY: CGFloat = 0

  // Generic emoji transform driven by the NEW placeholder kinds (identity for
  // hug/punch/bloom so they are unaffected).
  @State private var eScaleX: CGFloat = 1
  @State private var eScaleY: CGFloat = 1
  @State private var eOffX: CGFloat = 0
  @State private var eOffY: CGFloat = 0
  @State private var eRot: Double = 0

  // Effects (overlays per kind)
  @State private var ringScale: CGFloat = 0
  @State private var ringOpacity: Double = 0
  @State private var leftFistX: CGFloat = 0
  @State private var rightFistX: CGFloat = 0
  @State private var fistFlash: Double = 0
  @State private var particlesOn = false
  @State private var heartsOn = false

  private var kind: RevealKind { RevealAnimationRegistry.animation(for: emoji).kind }
  private var glowColor: Color { RevealAnimationRegistry.animation(for: emoji).glow }

  var body: some View {
    GeometryReader { geo in
      ZStack {
        ambient.background
        ambient.ambientLayer

        // Soft glow behind the emoji
        Circle()
          .fill(RadialGradient(colors: [glowColor.opacity(0.15), .clear],
                               center: .center, startRadius: 0, endRadius: 140))
          .frame(width: 280, height: 280)
          .scaleEffect(glowScale)

        VStack(spacing: 0) {
          Spacer()

          // The centred emoji — hidden for 🤜🤛 (its fists live in the effects).
          if kind != .fistBump {
            Text(emoji)
              .font(.system(size: 156))
              .scaleEffect(x: hugOpen ? 1.45 : hugClose ? 0.82 : 1.0,
                           y: hugOpen ? 0.75 : hugClose ? 1.15 : 1.0)
              .scaleEffect(bloomed ? 1.0 : 0.8)
              .scaleEffect(x: kind == .punch ? punchScaleX : 1,
                           y: kind == .punch ? punchScaleY : 1)
              .offset(x: kind == .punch ? punchOffsetX : 0)
              .scaleEffect(x: eScaleX, y: eScaleY)
              .rotationEffect(.degrees(eRot))
              .offset(x: eOffX, y: eOffY)
              .animation(.spring(response: 1.0, dampingFraction: 0.6), value: bloomed)
              .animation(.easeInOut(duration: hugOpen ? 0.25 : 0.3), value: hugOpen)
              .animation(.easeInOut(duration: 0.3), value: hugClose)
          }

          if let msg = message, !msg.isEmpty {
            Text(msg)
              .font(.system(size: 20, design: .serif).italic())
              .foregroundColor(DesignTokens.Color.textPrimary)
              .multilineTextAlignment(.center)
              .padding(.horizontal, 40).padding(.top, 20)
              .opacity(messageVisible ? 1 : 0)
              .animation(.easeOut(duration: 0.5), value: messageVisible)
          }
          if let tag = tagline, !tag.isEmpty {
            Text(tag)
              .font(.system(size: 14, design: .serif).italic())
              .foregroundColor(DesignTokens.Color.textSecondary)
              .padding(.top, 8)
              .opacity(taglineVisible ? 1 : 0)
              .animation(.easeOut(duration: 0.5), value: taglineVisible)
          }

          Text(context.headlineText)
            .font(.system(size: 17, design: .serif).italic())
            .foregroundColor(Color(hex: "#c4a8d4").opacity(0.75))
            .padding(.top, 10)
            .opacity(contextVisible ? 1 : 0)
            .animation(.easeOut(duration: 0.5), value: contextVisible)

          if !context.subText.isEmpty {
            Text(context.subText)
              .font(.system(size: 13, design: .serif).italic())
              .foregroundColor(DesignTokens.Color.textMuted)
              .padding(.top, 6)
              .opacity(contextVisible ? 1 : 0)
              .animation(.easeOut(duration: 0.5), value: contextVisible)
          }

          Spacer()
        }

        // Per-kind effect overlays (fists, rings, particles)
        effectsLayer(geo.size)

        // Dismiss hint
        VStack {
          Spacer()
          Text("tap anywhere to keep ✦")
            .font(.system(size: 11).italic())
            .foregroundColor(.white.opacity(0.3))
            .padding(.bottom, 30)
            .opacity(dismissVisible ? 1 : 0)
            .animation(.easeOut(duration: 0.4), value: dismissVisible)
        }
      }
      .frame(width: geo.size.width, height: geo.size.height)
      .contentShape(Rectangle())
      .onTapGesture { onDismiss() }
      .onAppear { startReveal(size: geo.size) }
    }
    .ignoresSafeArea()
  }

  // MARK: - Effects layer

  @ViewBuilder
  private func effectsLayer(_ size: CGSize) -> some View {
    let c = CGPoint(x: size.width / 2, y: size.height / 2)
    switch kind {
    case .fistBump:
      Text("🤜").font(.system(size: 130)).position(x: c.x + leftFistX, y: c.y)
      Text("🤛").font(.system(size: 130)).position(x: c.x + rightFistX, y: c.y)
      Color.white.opacity(fistFlash).ignoresSafeArea().allowsHitTesting(false)
    case .explosion:
      Circle().stroke(glowColor, lineWidth: 4)
        .frame(width: size.width * 0.8, height: size.width * 0.8)
        .scaleEffect(ringScale).opacity(ringOpacity).position(c)
        .allowsHitTesting(false)
      if particlesOn {
        RevealParticles(symbols: ["•"], count: 16, color: glowColor,
                        scatter: true, origin: c, spread: size.width * 0.5)
      }
    case .kiss, .envelope:
      if heartsOn {
        RevealParticles(symbols: ["💗", "💕"], count: 5, color: glowColor,
                        scatter: false, origin: c, spread: 170)
      }
    case .gift, .birthday:
      if particlesOn {
        RevealParticles(symbols: ["🎉", "🎊", "✨"], count: 12, color: glowColor,
                        scatter: true, origin: c, spread: 200)
      }
    case .fireworks, .graduation:
      if particlesOn {
        RevealParticles(symbols: ["🎉", "🎊", "✨", "•"], count: 16, color: glowColor,
                        scatter: true, origin: c, spread: size.width * 0.45)
      }
    default:
      EmptyView()
    }
  }

  // MARK: - Sequence

  private func startReveal(size: CGSize) {
    // Bloom + glow breathe (every reveal)
    after(0.1) {
      withAnimation { bloomed = true }
      withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { glowScale = 1.06 }
    }

    // Sound + haptic + motion per kind
    switch kind {
    case .bloom, .hug:
      EmojiRevealSound.play(emoji)
      after(0.3) { HapticPattern.heartbeat.fire() }
    case .punch:
      after(0.3) { HapticPattern.heartbeat.fire() }   // sound fires on the 3rd pump
    default:
      HapticEngine.revealHaptic(for: emoji)           // new kinds: their own haptic
    }

    switch kind {
    case .bloom:       break
    case .hug:         startHug()
    case .punch:       startPunch()
    case .kiss:        startKiss()
    case .fistBump:    startFistBump(size)
    case .thought:     startThought(size)
    case .envelope:    startEnvelope()
    case .explosion:   startExplosion(size)
    case .gift:        startGift()
    case .fireworks:   startFireworks(size)
    case .graduation:  startGraduation(size)
    case .birthday:    startBirthday()
    }

    // Text sequence + auto dismiss (every reveal)
    after(0.6) { withAnimation { messageVisible = true } }
    after(0.9) { withAnimation { taglineVisible = true } }
    after(1.2) { withAnimation { contextVisible = true } }
    after(1.8) { withAnimation { dismissVisible = true } }
    after(6.0) { onDismiss() }
  }

  private func after(_ t: Double, _ work: @escaping () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + t, execute: work)
  }

  // MARK: - 🤗 Hug (unchanged)

  private func startHug() {
    [0.9, 1.5, 2.1].forEach { delay in
      after(delay)        { withAnimation { hugOpen = true;  hugClose = false } }
      after(delay + 0.25) { withAnimation { hugOpen = false; hugClose = true } }
      after(delay + 0.55) { withAnimation { hugClose = false } }
    }
  }

  // MARK: - 👊 Punch (unchanged — sound on the 3rd pump)

  private func startPunch() {
    let punch = Animation.timingCurve(0.1, 0, 0.05, 1, duration: 0.14)
    after(0.2)  { withAnimation(.easeOut(duration: 0.16)) { punchScaleX = 1.45; punchScaleY = 1.45; punchOffsetX = 8 } }
    after(0.36) { withAnimation(.easeOut(duration: 0.15)) { punchScaleX = 0.88; punchScaleY = 0.88; punchOffsetX = 6 } }
    after(0.51) { withAnimation(.spring(response: 0.28, dampingFraction: 0.6)) { punchScaleX = 1.0; punchScaleY = 1.0; punchOffsetX = 0 } }
    func pump(base: Double, punchScale: CGFloat, punchX: CGFloat, sound: Bool) {
      after(base)        { withAnimation(.easeIn(duration: 0.18)) { punchScaleX = 0.72; punchScaleY = 0.72; punchOffsetX = 38 } }
      after(base + 0.18) { if sound { EmojiRevealSound.play("👊") }
                           withAnimation(punch) { punchScaleX = punchScale; punchScaleY = punchScale; punchOffsetX = punchX } }
      after(base + 0.32) { withAnimation(.easeOut(duration: 0.12)) { punchScaleX = 0.88; punchScaleY = 0.88; punchOffsetX = 10 } }
      after(base + 0.44) { withAnimation(.spring(response: 0.28, dampingFraction: 0.6)) { punchScaleX = 1.0; punchScaleY = 1.0; punchOffsetX = 0 } }
    }
    pump(base: 1.2, punchScale: 1.52, punchX: -18, sound: false)
    pump(base: 2.0, punchScale: 1.52, punchX: -18, sound: false)
    pump(base: 2.8, punchScale: 1.60, punchX: -22, sound: true)
  }

  // MARK: - 😘 Kiss — pucker → pop → hearts

  private func startKiss() {
    after(0.7)  { EmojiRevealSound.play("😘")
                  withAnimation(.easeIn(duration: 0.12)) { eScaleX = 0.85; eScaleY = 0.85 } }
    after(0.84) { withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { eScaleX = 1.2; eScaleY = 1.2 } }
    after(1.15) { withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { eScaleX = 1.0; eScaleY = 1.0 }; heartsOn = true }
  }

  // MARK: - 🤜🤛 Fist bump — two fists meet at centre

  private func startFistBump(_ size: CGSize) {
    leftFistX  = -size.width * 0.6   // entry from the left edge
    rightFistX =  size.width * 0.6   // entry from the right edge
    // [phase3] The fists TOUCH but NEVER cross: leftFistX stays negative,
    // rightFistX positive, closest at ∓42 (knuckles meet, no overlap past centre).
    after(0.3)  { withAnimation(.easeIn(duration: 0.45)) { leftFistX = -70; rightFistX = 70 } }
    after(0.78) { EmojiRevealSound.play("🤜🤛")
                  withAnimation(.easeOut(duration: 0.1)) { leftFistX = -42; rightFistX = 42; fistFlash = 0.7 } }
    after(0.9)  { withAnimation(.easeOut(duration: 0.25)) { fistFlash = 0 } }
    after(0.95) { withAnimation(.spring(response: 0.45, dampingFraction: 0.5)) { leftFistX = -56; rightFistX = 56 } }
  }

  // MARK: - 💭 Thought bubble — rises from the bottom

  private func startThought(_ size: CGSize) {
    eOffY = size.height * 0.35; eScaleX = 0.5; eScaleY = 0.5
    after(0.1)  { withAnimation(.easeOut(duration: 1.0)) { eOffY = 0; eScaleX = 1; eScaleY = 1 } }
    after(1.1)  { withAnimation(.easeInOut(duration: 0.18)) { eOffX = 10 } }
    after(1.3)  { withAnimation(.easeInOut(duration: 0.18)) { eOffX = -10 } }
    after(1.5)  { EmojiRevealSound.play("💭")
                  withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { eOffX = 0; eScaleX = 1.12; eScaleY = 1.12 } }
    after(1.75) { withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { eScaleX = 1; eScaleY = 1 } }
  }

  // MARK: - 💌 Envelope — flutters, a heart floats out

  private func startEnvelope() {
    after(0.3)  { withAnimation(.easeInOut(duration: 0.15)) { eRot = 8 } }
    after(0.45) { withAnimation(.easeInOut(duration: 0.15)) { eRot = -8 } }
    after(0.6)  { withAnimation(.easeInOut(duration: 0.15)) { eRot = 0 } }
    after(0.7)  { EmojiRevealSound.play("💌")
                  withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { eScaleX = 1.15; eScaleY = 1.15 }; heartsOn = true }
    after(1.0)  { withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { eScaleX = 1; eScaleY = 1 } }
  }

  // MARK: - 💥 Explosion — shake → burst + shockwave ring + debris

  private func startExplosion(_ size: CGSize) {
    eScaleX = 0.7; eScaleY = 0.7
    for k in 0..<6 { after(0.1 + 0.05 * Double(k)) { withAnimation(.linear(duration: 0.05)) { eOffX = (k % 2 == 0 ? 8 : -8) } } }
    after(0.45) {
      EmojiRevealSound.play("💥")
      withAnimation(.easeOut(duration: 0.2)) { eScaleX = 1.6; eScaleY = 1.6; eOffX = 0 }
      ringScale = 0; ringOpacity = 0.8; particlesOn = true
      withAnimation(.easeOut(duration: 0.7)) { ringScale = 1; ringOpacity = 0 }
    }
    after(0.9) { withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { eScaleX = 1; eScaleY = 1 } }
  }

  // MARK: - 🎁 Gift — shake → pop → confetti

  private func startGift() {
    for k in 0..<5 { after(0.06 * Double(k)) { withAnimation(.linear(duration: 0.06)) { eRot = (k % 2 == 0 ? 6 : -6) } } }
    after(0.32) { withAnimation(.easeOut(duration: 0.12)) { eRot = 0 } }
    after(0.35) { EmojiRevealSound.play("🎁")
                  withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { eOffY = -30; eScaleX = 1.15; eScaleY = 1.15 }; particlesOn = true }
    after(0.7)  { withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { eOffY = 0; eScaleX = 1; eScaleY = 1 } }
  }

  // MARK: - 🎆 Fireworks — rises then bursts

  private func startFireworks(_ size: CGSize) {
    eOffY = size.height * 0.3; eScaleX = 0.7; eScaleY = 0.7
    after(0.1) { withAnimation(.easeOut(duration: 0.6)) { eOffY = -size.height * 0.05; eScaleX = 1; eScaleY = 1 } }
    after(0.7) { EmojiRevealSound.play("🎆"); particlesOn = true
                 withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { eScaleX = 1.2; eScaleY = 1.2 } }
    after(1.0) { withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { eScaleX = 1; eScaleY = 1 } }
  }

  // MARK: - 🎓 Graduation — cap spins up from the bottom

  private func startGraduation(_ size: CGSize) {
    eOffY = size.height * 0.6
    after(0.1)  { withAnimation(.easeOut(duration: 0.6)) { eOffY = -size.height * 0.18; eRot = 360 } }
    after(0.7)  { particlesOn = true; EmojiRevealSound.play("🎓") }
    after(0.75) { withAnimation(.easeIn(duration: 0.4)) { eOffY = 40 } }
    after(1.15) { withAnimation(.spring(response: 0.35, dampingFraction: 0.45)) { eOffY = 0 } }
  }

  // MARK: - 🎂 Birthday — bloom → candle flicker → confetti

  private func startBirthday() {
    EmojiRevealSound.play("🎂")
    for k in 0..<4 { after(0.2 + 0.15 * Double(k)) {
      withAnimation(.easeInOut(duration: 0.15)) { eScaleX = (k % 2 == 0 ? 1.04 : 0.98); eScaleY = (k % 2 == 0 ? 1.04 : 0.98) }
    } }
    after(0.9)  { withAnimation(.easeIn(duration: 0.2)) { eScaleX = 0.92; eScaleY = 0.92 } }   // blow out
    after(1.1)  { particlesOn = true
                  withAnimation(.spring(response: 0.35, dampingFraction: 0.45)) { eScaleX = 1.0; eScaleY = 1.0 } }
  }
}

// MARK: - Reveal particles (confetti / hearts / debris)

private struct RevealParticles: View {
  let symbols: [String]
  let count: Int
  let color: Color
  let scatter: Bool          // true = all directions; false = upward fan
  let origin: CGPoint
  let spread: CGFloat
  @State private var go = false

  var body: some View {
    ZStack {
      ForEach(0..<count, id: \.self) { i in
        let angle = scatter
          ? (Double(i) / Double(count)) * 2 * .pi
          : (-.pi / 2 + (Double(i) / Double(max(count - 1, 1)) - 0.5) * 1.4)
        let dist = spread * CGFloat(0.6 + 0.4 * Double((i * 37) % 10) / 10)
        Text(symbols[i % symbols.count])
          .font(.system(size: 20))
          .foregroundStyle(color)
          .position(origin)
          .offset(x: go ? CGFloat(cos(angle)) * dist : 0,
                  y: go ? CGFloat(sin(angle)) * dist : 0)
          .opacity(go ? 0 : 1)
          .scaleEffect(go ? 0.6 : 1.0)
      }
    }
    .onAppear { withAnimation(.easeOut(duration: 1.1)) { go = true } }
    .allowsHitTesting(false)
  }
}
