// WindReceiptAnimation.swift
// Pointward › Instruments › Wind
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

enum WindReceiptAnimation {
  /// Full-screen receipt duration (seconds). Source of truth:
  /// InstrumentBoundaries.Receipt.wind.
  static let duration: Double = InstrumentBoundaries.Receipt.wind

  /// Sound file + duration for the receipt phase.
  static let soundFile: String = WindSounds.receiptFile
  static let soundDuration: Double = WindSounds.receiptDuration

  /// Emoji reveal linger — shared across all instruments.
  static let revealLinger: Double = InstrumentBoundaries.Reveal.linger
}

// MARK: - Receipt → reveal (uses the shared EmojiRevealView)
//
// ACT 3 plays in two beats: the per-instrument LANDING (the leaf arriving on
// the breeze) and then THE EMOJI REVEAL — the shared emotional peak. The wind's
// instrument sounds play during the landing; the emoji's own sound (and the
// reveal haptic) fire ONLY at the bloom inside EmojiRevealView, never during
// the landing.
struct WindReceiptAnimationView: View {
    let emoji: String
    var message: String? = nil
    var tagline: String? = nil
    let fromName: String
    /// The reveal was dismissed (tap) — the receipt is complete.
    let onFinished: () -> Void

    @State private var landed = false

    var body: some View {
        ZStack {
            Color(hex: "#0d0d14").ignoresSafeArea()

            if landed {
                // THE PEAK — the shared reveal, with the hug squeeze for 🤗.
                EmojiRevealView(
                    emoji: emoji,
                    message: message,
                    tagline: tagline,
                    fromName: fromName,
                    onDismiss: onFinished
                )
                .transition(.opacity)
            } else {
                // The wind landing — the leaf arrives, the emoji emerges, then
                // we cross into the reveal.
                InstrumentLandingView(style: .firefly, emoji: emoji) {
                    withAnimation(.easeInOut(duration: 0.3)) { landed = true }
                }
            }
        }
    }
}
