// InstrumentBoundaries.swift
// Pointward › Instruments › _Shared
//
// HARD LIMITS — never exceeded by any instrument.
// When in doubt: make it shorter.
// Emotional peak must come quickly.
// Anticipation is good. Waiting is not.

import Foundation

enum InstrumentBoundaries {

  // COMPASS FACE (inside circle)
  enum CompassFace {
    static let idleAnimationMax: Double = 8.0
    // Instrument visual must fit INSIDE circle
    // Never overflow compass ring boundary
    // Text never overlaps compass circle ever
  }

  // SEND ANIMATION (full screen)
  enum Send {
    static let minimum: Double = 0.7   // bow/flick
    static let standard: Double = 4.0  // rocket/wand/plane
    static let maximum: Double = 6.5   // wind only

    static let compass: Double = 3.5
    static let bow:     Double = 0.8
    static let flick:   Double = 0.7
    static let rocket:  Double = 4.0
    static let wind:    Double = 6.5
    static let wand:    Double = 2.0
    static let plane:   Double = 5.0
  }

  // RECEIPT ANIMATION (full screen)
  enum Receipt {
    static let minimum: Double = 1.0
    static let standard: Double = 4.0
    static let maximum: Double = 7.2   // wind only

    static let compass: Double = 1.5
    static let bow:     Double = 1.1
    static let flick:   Double = 1.0
    static let rocket:  Double = 4.0
    static let wind:    Double = 7.2
    static let wand:    Double = 1.1
    static let plane:   Double = 5.0
  }

  // REVEAL (emoji full screen)
  // Same for ALL instruments
  enum Reveal {
    static let linger: Double = 6.0
    static let emojiSize: Double = 140  // pt minimum
    static let breatheCycle: Double = 3.0
  }

  // SOUND RULES
  // Sound duration MUST equal animation duration
  // Fade in: first 2% of duration
  // Fade out: last 5% of duration
  // Send sound: never plays during receipt
  // Receipt sound: never plays during send
  // Emoji sound: ONLY at reveal moment

  // PARTICLE LIMITS
  enum Particles {
    static let minimum: Int = 6
    static let standard: Int = 20
    static let maximum: Int = 72  // wand only
  }

  // HAPTIC RULES
  // Max 3 haptic events per animation phase
  // Never haptic during reveal linger
  // Emoji reveal: always heartbeat pattern
  // Pro users: 1.3x intensity multiplier
}
