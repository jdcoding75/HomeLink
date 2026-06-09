// CompassCompassFace.swift
// Pointward › Instruments › Compass
//
// ACT 1 of 3 — the compass instrument's interactive face.
//
// POINTER FILE:
// Unlike the other instruments, the compass face is not a
// small standalone view — it is rendered by CompassView,
// the app's emotional core, which is referenced throughout
// the app. Moving that file is out of scope for a zero-
// behavior-change structural pass, so it intentionally
// stays at Views/CompassView.swift.
//
// This file marks the compass's place in the per-instrument
// folder system and is the home for any compass-face state
// machine added by the animation work.

import SwiftUI

// MARK: - ACT 1 state machine — Compass
//
// IDLE: compass needle pointing
//   - Slow ambient needle sway; orb hint at center
// TRIGGERED: hold begins
//   - Orb starts forming at needle tip; grows with hold progress
// CHARGING: hold continues
//   - Orb grows larger; glows warmer; needle steadies
// READY: aligned and held
//   - Orb at maximum; needle locked; warm pulse
// EXITING: release
//   - Orb separates from needle; needle swings back slightly
//   - Compass face dims briefly; InstrumentTransition fires
//
// Additive scaffold — the live hold mechanic in CompassView
// is not yet rewired onto this machine.
extension CompassFaceStateMachine {
  /// A fresh state machine for the compass face.
  static func compassFace() -> CompassFaceStateMachine { .init(instrument: .compass) }
}
