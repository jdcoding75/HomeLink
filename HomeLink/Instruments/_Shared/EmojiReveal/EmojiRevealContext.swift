// EmojiRevealContext.swift
// Pointward › Instruments › _Shared › EmojiReveal
//
// Defines WHO is seeing the reveal
// and WHAT background/ambient plays.
//
// RULE: There is only ONE reveal screen.
// Not a sent screen AND a received screen.
// ONE screen — context changes the copy.
// Instrument changes the ambient layer.
// Emoji changes the animation + sound.
// That is all that ever changes.
//
// This is the single source of truth
// for all reveal moments in the app.
// Adding a new instrument = add one
// ambient case. Nothing else changes.

import SwiftUI

// WHO is seeing the reveal
enum RevealContext {
  case sent(recipientName: String)
  case received(fromName: String)

  var headlineText: String {
    switch self {
    case .sent(let name):
      return "sent to \(name) ✦"
    case .received(let name):
      return "from \(name) ✦"
    }
  }

  var subText: String {
    switch self {
    case .sent(let name):
      return "\(name) will feel this ✦"
    case .received:
      return ""
    }
  }
}

// WHAT ambient layer plays behind emoji
// Each instrument registers its world here
// This is what makes reveal feel continuous
// with the send/receipt animation world
enum RevealAmbient {
  case wind      // drifting clouds on daySky
  case rocket    // slow star drift on deepSpace
  case wand      // settling sparkles on magicalDark
  case compass   // soft glow pulse on deepPurple
  case flick     // cork texture fade on corkBoard
  case bow       // clean — no ambient on archery
  case plane     // distant clouds on daySky

  // Background gradient for this instrument
  var background: AnyView {
    switch self {
    case .wind, .plane:
      return AnyView(
        LinearGradient(
          colors: [
            Color(hex: "#1a3a5c"),
            Color(hex: "#2d6a8f"),
            Color(hex: "#4a9abb"),
            Color(hex: "#7ec8e3")
          ],
          startPoint: .top,
          endPoint: .bottom
        ).ignoresSafeArea()
      )
    case .rocket:
      return AnyView(
        LinearGradient(
          colors: [
            Color(hex: "#000008"),
            Color(hex: "#0a0a18"),
            Color(hex: "#0d0d20")
          ],
          startPoint: .top,
          endPoint: .bottom
        ).ignoresSafeArea()
      )
    case .wand:
      return AnyView(
        LinearGradient(
          colors: [
            Color(hex: "#0d0b18"),
            Color(hex: "#150f28"),
            Color(hex: "#0d0d14")
          ],
          startPoint: .top,
          endPoint: .bottom
        ).ignoresSafeArea()
      )
    case .compass:
      return AnyView(
        Color(hex: "#0d0d14")
          .ignoresSafeArea()
      )
    case .flick:
      return AnyView(
        LinearGradient(
          colors: [
            Color(hex: "#2a1f12"),
            Color(hex: "#3d2e1a"),
            Color(hex: "#2a1f12")
          ],
          startPoint: .top,
          endPoint: .bottom
        ).ignoresSafeArea()
      )
    case .bow:
      return AnyView(
        LinearGradient(
          colors: [
            Color(hex: "#0d1218"),
            Color(hex: "#141e24"),
            Color(hex: "#0d1218")
          ],
          startPoint: .top,
          endPoint: .bottom
        ).ignoresSafeArea()
      )
    }
  }

  // Ambient particle/element layer
  // Plays behind emoji during reveal
  // Matches the instrument's world
  @ViewBuilder
  var ambientLayer: some View {
    switch self {
    case .wind, .plane:
      // Drifting clouds — same as send/receipt
      WindRevealClouds()
    case .rocket:
      // Slow star drift
      RocketRevealStars()
    case .wand:
      // Settling sparkles fading out
      WandRevealSparkles()
    case .compass, .bow:
      // Clean — no ambient
      EmptyView()
    case .flick:
      // Cork texture — static
      EmptyView()
    }
  }
}

// Map an instrument (or the sender style it travels with) to its ambient,
// so history replay shows the SAME world the thought was received in.
extension RevealAmbient {
  static func forInstrument(_ instrument: Instrument) -> RevealAmbient {
    switch instrument {
    case .firefly: return .wind
    case .rocket:  return .rocket
    case .wand:    return .wand
    case .compass: return .compass
    case .flick:   return .flick
    case .bow:     return .bow
    case .plane:   return .plane
    }
  }

  static func forStyle(_ style: SenderStyle) -> RevealAmbient {
    switch style {
    case .firefly:             return .wind
    case .rocket:              return .rocket
    case .wand:                return .wand
    case .bowArrow:            return .bow
    case .fingerFlick:         return .flick
    case .plane:               return .plane
    case .glow, .shootingStar: return .compass
    }
  }
}

// Wind clouds for reveal background
// Same style as WindSendAnimation clouds
struct WindRevealClouds: View {
  var body: some View {
    ZStack {
      // Same 4-5 clouds as send/receipt
      // Drifting slowly
      // Opacity 0.3-0.5 so emoji reads clearly
      ForEach(0..<4, id: \.self) { i in
        CloudShape(index: i)
      }
    }
    .allowsHitTesting(false)
  }
}

// Placeholder structs for other instruments
// Filled in when each instrument is built
struct RocketRevealStars: View {
  var body: some View { EmptyView() }
}
struct WandRevealSparkles: View {
  var body: some View { EmptyView() }
}
struct CloudShape: View {
  let index: Int
  var body: some View {
    // Position clouds at consistent spots
    // Same as WindSendAnimation cloud positions
    let configs: [(CGFloat, CGFloat, CGFloat, CGFloat, Double)] = [
      (130, 38, 55, 28, 0.5),
      (88,  26, 128, 76, 0.35),
      (158, 42, -18, 36, 0.45),
      (100, 30, 180, 170, 0.25)
    ]
    let c = configs[index % configs.count]
    return AnyView(
      Capsule()
        .fill(Color.white.opacity(c.4))
        .frame(width: c.0, height: c.1)
        .offset(x: c.2, y: c.3)
    )
  }
}
