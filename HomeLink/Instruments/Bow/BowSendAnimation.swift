// BowSendAnimation.swift
// Pointward › Instruments › Bow
//
// ACT 2 of 3 — the full-screen send journey.
//
// CURRENT IMPLEMENTATION:
// The live send animation for this instrument is the
// "bow" branch inside SenderAnimationView (the shared
// dispatcher). It has NOT been surgically extracted here
// yet — doing so cannot be guaranteed behavior-identical
// while it lives inside a single generic view, and the
// safety rule for this work is zero behavior change.
//
// This file is the typed integration point for that
// extraction: timing + sound are sourced here so the
// values live next to the instrument. When the dispatcher
// branch is moved, drop the View into this namespace.
//
// HANDOFF: receives InstrumentTransition from the compass
// face (ACT 1) and begins the object at
// transition.sendEntryPoint(screenSize:) — see
// InstrumentTransition for the continuity rule.

import SwiftUI

enum BowSendAnimation {
  /// Full-screen send duration (seconds). Source of truth:
  /// InstrumentBoundaries.Send.bow.
  static let duration: Double = InstrumentBoundaries.Send.bow

  /// Sound file + duration for the send phase.
  static let soundFile: String = BowSounds.sendFile
  static let soundDuration: Double = BowSounds.sendDuration

  /// World background for the send journey (matches the
  /// compass face per InstrumentBackground rule #2).
  /// Wire the matching gradient when the View is extracted.
}
