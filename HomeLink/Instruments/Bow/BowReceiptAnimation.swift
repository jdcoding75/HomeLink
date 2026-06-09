// BowReceiptAnimation.swift
// Pointward › Instruments › Bow
//
// ACT 3 of 3 — arrival + emoji reveal.
//
// CURRENT IMPLEMENTATION:
// The live receipt animation for this instrument is driven
// by InstrumentLandingView (the shared dispatcher). It has
// NOT been surgically extracted here yet — same zero-
// behavior-change safety rule as the send animation.
//
// This file is the typed integration point for that
// extraction.
//
// ENTRY RULE (differs from send): the object arrives FROM
// the sender's bearing (real GPS or symbolic) — it does
// NOT need to match the compass-face exit bearing. The
// receipt is its own emotional moment.

import SwiftUI

enum BowReceiptAnimation {
  /// Full-screen receipt duration (seconds). Source of truth:
  /// InstrumentBoundaries.Receipt.bow.
  static let duration: Double = InstrumentBoundaries.Receipt.bow

  /// Sound file + duration for the receipt phase.
  static let soundFile: String = BowSounds.receiptFile
  static let soundDuration: Double = BowSounds.receiptDuration

  /// Emoji reveal linger — shared across all instruments.
  static let revealLinger: Double = InstrumentBoundaries.Reveal.linger
}
