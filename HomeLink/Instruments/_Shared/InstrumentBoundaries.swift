// InstrumentBoundaries.swift
// Pointward › Instruments › _Shared
//
// HARD LIMITS — never exceeded by any instrument.
// When in doubt: make it shorter.
// Emotional peak must come quickly.
// Anticipation is good. Waiting is not.

import Foundation
import CoreGraphics

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

// MARK: - Compass face state machine (ACT 1 of 3)
//
// The compass face is not a static visual — it IS the send
// mechanic and the first of three animations:
//   ACT 1: Compass Face (interactive + animated)  ← here
//   ACT 2: Send Animation (full screen journey)
//   ACT 3: Receipt Animation (arrival + reveal)
// The face must flow seamlessly into ACT 2 via the
// .exiting state, which fires an InstrumentTransition.

enum CompassFaceState {
  case idle        // instrument at rest
                   // gentle ambient animation
                   // waiting for user
  case triggered   // user started the mechanic
                   // bow: finger on rim
                   // wind: breath detected
                   // rocket: first fuel tap
                   // wand: first shake
                   // plane: finger on propeller
                   // flick: finger on note
                   // compass: holding toward person
  case charging    // mechanic building up
                   // bow: drawing back
                   // wind: leaf rising
                   // rocket: fueling
                   // wand: charge building
                   // plane: winding up
                   // flick: pulling back
                   // compass: orb growing
  case ready       // fully charged/aimed
                   // object at edge of circle
                   // ready to exit
                   // brief pause here — anticipation
  case exiting     // object leaves compass circle
                   // at exitBearing direction
                   // hands off to send animation
                   // this state triggers transition
}

// Timing per state (max durations):
enum CompassFaceStateDurations {
  static let idleAmbient: Double = 999  // forever
  static let triggered: Double = 0.3   // instant response
  static let charging: Double = 3.0    // max charge time
  static let ready: Double = 0.5       // anticipation pause
  static let exiting: Double = 0.4     // exit the circle

  /// Max duration for a given state (idle is effectively
  /// unbounded — it waits on the user).
  static func maxDuration(for state: CompassFaceState) -> Double {
    switch state {
    case .idle:      return idleAmbient
    case .triggered: return triggered
    case .charging:  return charging
    case .ready:     return ready
    case .exiting:   return exiting
    }
  }
}

// ─────────────────────────────────────
// SCREEN COORDINATE RULES
// Required for ALL instrument animations
// ─────────────────────────────────────
//
// Every instrument animation MUST follow
// these rules exactly. No exceptions.
// This ensures correct rendering on all
// iPhone sizes — SE through Pro Max.
//
// RULE 1: GeometryReader as root
// Every send, receipt, and reveal view
// must use GeometryReader as its
// outermost content view:
//
//   var body: some View {
//     GeometryReader { geo in
//       ZStack { ... }
//     }
//   }
//
// RULE 2: ignoresSafeArea on background
// Background must fill entire screen
// including under Dynamic Island and
// home indicator:
//
//   InstrumentBackground.daySky
//     .ignoresSafeArea()
//
// RULE 3: All positions from geo.size
// Never use UIScreen.main.bounds
// Never hardcode width or height
// Never use parent container size
// Always:
//   let cx = geo.size.width / 2
//   let cy = geo.size.height / 2
//
// RULE 4: Swirl center is screen center
//   x = cx + sin(t*0.72) * geo.size.width * 0.36
//   y = cy + sin(t*0.45+1.0) * geo.size.height * 0.15
// Adjust amplitudes per instrument feel
// but center is ALWAYS geo.size/2
//
// RULE 5: Entry and exit extend off screen
// Objects must enter FROM off screen
// and exit TO off screen:
//   entryX = cx + cos(bearing) * geo.size.width * 0.75
//   entryY = cy + sin(bearing) * geo.size.height * 0.75
//   exitX  = cx + cos(bearing) * geo.size.width * 1.15
//   exitY  = cy + sin(bearing) * geo.size.height * 1.15
//
// RULE 6: Bucket at bottom
//   bx = geo.size.width / 2
//   by = geo.size.height
//        - bucketHeight
//        - geo.size.height * 0.06
//
// RULE 7: Text labels never overlap
// the instrument object.
// Top label: y < 8% of screen height
// Bottom label: y > 82% of screen height
// Nothing in the middle 74% except
// the animation itself.

enum ScreenCoordinates {
  // Safe zones for UI labels
  // Instrument animation owns the middle
  static let topLabelMaxY: CGFloat = 0.08
  static let bottomLabelMinY: CGFloat = 0.82
  static let mechanicBadgeY: CGFloat = 0.92

  // Entry/exit multipliers
  // Object starts/ends off screen
  static let entryReach: CGFloat = 0.75
  static let exitReach: CGFloat = 1.15

  // Swirl amplitude defaults
  // Override per instrument
  static let swirlAmplitudeX: CGFloat = 0.36
  static let swirlAmplitudeY: CGFloat = 0.15

  // Bucket vertical position
  static let bucketBottomMargin: CGFloat = 0.06
}

// ─────────────────────────────────────
// INSTRUMENT GENERATION SPEC
// Everything needed to generate a
// complete new instrument from scratch
// ─────────────────────────────────────
//
// A complete instrument consists of:
//
// FILE 1: [Name]CompassFace.swift
//   - Sky/world background inside
//     compass circle ONLY (clipped)
//   - Instrument object visible from
//     first frame carrying selected emoji
//   - State machine:
//     idle → triggered → charging
//     → ready → exiting
//   - On exiting: fire InstrumentTransition
//     with exitBearing and exitPoint
//   - No needle unless instrument IS
//     the compass
//   - No text overlapping compass circle
//   - Mechanic badge below circle
//
// FILE 2: [Name]SendAnimation.swift
//   - GeometryReader root (RULE 1)
//   - InstrumentBackground (RULE 2)
//   - Receives InstrumentTransition
//   - Object enters at sendEntryPoint
//     (never screen center) (RULE 5)
//   - Swirl through screen center (RULE 4)
//   - Duration = InstrumentBoundaries
//     .Send.[instrument]
//   - Sound: InstrumentSoundPlayer
//     .playSend(instrument)
//   - On complete: present EmojiRevealView
//     context: .sent(recipientName:)
//     ambient: instrument's RevealAmbient
//
// FILE 3: [Name]ReceiptAnimation.swift
//   - GeometryReader root (RULE 1)
//   - InstrumentBackground (RULE 2)
//   - Object enters from senderBearing
//     (RULE 5)
//   - Swirl through screen center (RULE 4)
//   - Auto-catch OR directional catch
//     per instrument design decision
//   - Bucket at bottom (RULE 6)
//     EXCEPT bow → dartboard
//   - Duration = InstrumentBoundaries
//     .Receipt.[instrument]
//   - Sound: InstrumentSoundPlayer
//     .playReceipt(instrument)
//   - On land: present EmojiRevealView
//     context: .received(fromName:)
//     ambient: instrument's RevealAmbient
//
// FILE 4: [Name]Sounds.swift
//   - Documents all sounds for instrument
//   - compassFaceSound (none or named)
//   - sendFile + sendDuration
//   - receiptFile + receiptDuration
//   - Must match InstrumentBoundaries
//     durations exactly
//   - Generator script reference
//
// FILE 5: [Name]SoundGenerator.py
//   - Generates send and receipt wav
//   - Outputs to Sounds/Instruments/
//   - Named [name]_send.wav
//          [name]_receipt.wav
//   - Duration matches boundaries
//
// CATCH MECHANIC DECISION TABLE:
// (set at design time, never changes)
//
//   Compass  → phone direction catch
//              user turns toward sender
//   Flick    → spin bucket to align
//              catching a flying object
//   Bow      → auto-catch (dartboard)
//              arrow just lands
//   Rocket   → auto-catch
//              rocket lands itself
//   Wind     → auto-catch
//              wind finds you
//   Wand     → auto-catch
//              magic finds you
//   Plane    → auto-catch
//              plane lands itself
//
// DIRECTIONAL vs NON-DIRECTIONAL:
//
//   Directional (has person marker
//   and needle in compass face):
//     Compass — always directional
//
//   Non-directional (no needle,
//   no person marker):
//     Wind, Wand, Flick, Bow,
//     Rocket, Plane
//
// BACKGROUND CONTINUITY RULE:
// Compass face background MUST match
// send animation background MUST match
// receipt animation background MUST match
// emoji reveal background
// All four screens = same world
//
// SOUND CONTINUITY RULE:
// Sound character must match the
// instrument's world. Same tonal
// quality compass→send→receipt.
// Duration must match animation exactly.
//
// TO GENERATE A NEW INSTRUMENT:
// 1. Decide: directional or not
// 2. Decide: catch mechanic
// 3. Decide: world/background
// 4. Design compass face object
//    (what sits inside the circle)
// 5. Design send journey
//    (how does it travel)
// 6. Design receipt arrival
//    (how does it arrive and land)
// 7. Create 5 files above
// 8. Register in:
//    - InstrumentBackground (ambient)
//    - EmojiRevealContext (RevealAmbient)
//    - InstrumentSoundPlayer (sound map)
//    - SenderAnimationView (dispatcher)
//    - InstrumentLandingView (dispatcher)
// 9. Generate sounds via Python
// 10. Build and test
