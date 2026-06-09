// InstrumentBackground.swift
// Pointward › Instruments › _Shared
//
// BACKGROUND RULES — all instruments:
// 1. Always dark enough for lavender text
// 2. Compass face background MATCHES
//    send animation world background
// 3. Transition compass → send: 300ms crossfade
//    NEVER a hard cut
// 4. All backgrounds use #0d0d14 as base
// 5. No background brighter than 40% luminosity

import SwiftUI

enum InstrumentBackground {

  // WIND + PLANE: Daytime sky
  // Warm blue — hopeful and open
  // Used in: WindCompassFace + WindSendAnimation
  //          PlaneCompassFace + PlaneSendAnimation
  static let daySky = LinearGradient(
    colors: [
      Color(hex: "#1a3a5c"),
      Color(hex: "#2d6a8f"),
      Color(hex: "#4a9abb"),
      Color(hex: "#7ec8e3")
    ],
    startPoint: .top,
    endPoint: .bottom
  )

  // Compass face version (radial for circle)
  static let daySkyCompassFace = RadialGradient(
    colors: [
      Color(hex: "#2d6a8f"),
      Color(hex: "#4a9abb"),
      Color(hex: "#7ec8e3")
    ],
    center: .init(x: 0.5, y: 0.3),
    startRadius: 0,
    endRadius: 120
  )

  // ROCKET: Deep space
  static let deepSpace = LinearGradient(
    colors: [
      Color(hex: "#000008"),
      Color(hex: "#0a0a18"),
      Color(hex: "#0d0d20")
    ],
    startPoint: .top,
    endPoint: .bottom
  )

  static let deepSpaceCompassFace = RadialGradient(
    colors: [
      Color(hex: "#0a0a18"),
      Color(hex: "#000008")
    ],
    center: .center,
    startRadius: 0,
    endRadius: 120
  )

  // COMPASS: Deep purple brand
  static let deepPurple = LinearGradient(
    colors: [
      Color(hex: "#0d0d14"),
      Color(hex: "#12101c"),
      Color(hex: "#0d0d14")
    ],
    startPoint: .top,
    endPoint: .bottom
  )

  static let deepPurpleCompassFace = RadialGradient(
    colors: [
      Color(hex: "#1e1828"),
      Color(hex: "#0d0d14")
    ],
    center: .center,
    startRadius: 0,
    endRadius: 120
  )

  // WAND: Magical dark
  static let magicalDark = LinearGradient(
    colors: [
      Color(hex: "#0d0b18"),
      Color(hex: "#150f28"),
      Color(hex: "#0d0d14")
    ],
    startPoint: .top,
    endPoint: .bottom
  )

  static let magicalDarkCompassFace = RadialGradient(
    colors: [
      Color(hex: "#150f28"),
      Color(hex: "#0d0b18")
    ],
    center: .center,
    startRadius: 0,
    endRadius: 120
  )

  // FLICK: Cork board
  static let corkBoard = LinearGradient(
    colors: [
      Color(hex: "#2a1f12"),
      Color(hex: "#3d2e1a"),
      Color(hex: "#2a1f12")
    ],
    startPoint: .top,
    endPoint: .bottom
  )

  static let corkBoardCompassFace = RadialGradient(
    colors: [
      Color(hex: "#3d2e1a"),
      Color(hex: "#2a1f12")
    ],
    center: .center,
    startRadius: 0,
    endRadius: 120
  )

  // BOW: Archery range dark
  static let archeryRange = LinearGradient(
    colors: [
      Color(hex: "#0d1218"),
      Color(hex: "#141e24"),
      Color(hex: "#0d1218")
    ],
    startPoint: .top,
    endPoint: .bottom
  )

  static let archeryRangeCompassFace = RadialGradient(
    colors: [
      Color(hex: "#141e24"),
      Color(hex: "#0d1218")
    ],
    center: .center,
    startRadius: 0,
    endRadius: 120
  )

  // SHARED TEXT COLORS
  // Used consistently on ALL backgrounds:
  static let primaryText = Color(hex: "#e8e0f0")
  static let secondaryText = Color(hex: "#9b8fa8")
  static let accentText = Color(hex: "#c4a8d4")
}
