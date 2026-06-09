// InstrumentTransition.swift
// Pointward › Instruments › _Shared
//
// THE HANDOFF RULE:
// The instrument object (leaf/arrow/rocket/etc)
// exits the compass circle at the SAME bearing
// it enters the full screen send animation.
//
// This creates visual continuity:
// Object leaves compass face going northeast →
// Full screen animation begins from same direction
// User sees one continuous journey not two separate
// animations.
//
// RECEIPT ANIMATION:
// Entry direction = sender's bearing (GPS or symbolic)
// Does NOT need to match compass face exit
// The receipt is a separate emotional moment
// Object arrives FROM sender's direction
// That's what matters for receipt

import SwiftUI
import CoreLocation

struct InstrumentTransition {

  // The bearing at which the instrument object
  // exits the compass circle.
  // This MUST be passed to the send animation
  // as its entry point.
  let exitBearing: Double  // 0-360 degrees

  // The screen edge point where the send animation
  // should begin — calculated from exitBearing
  // and screen dimensions.
  func sendEntryPoint(
    screenSize: CGSize
  ) -> CGPoint {
    let cx = screenSize.width / 2
    let cy = screenSize.height / 2
    let rad = exitBearing * .pi / 180

    // Place entry point at screen edge
    // in the direction of exitBearing
    let reach = max(screenSize.width,
                    screenSize.height) * 0.7

    return CGPoint(
      x: cx + CGFloat(sin(rad)) * reach,
      y: cy - CGFloat(cos(rad)) * reach
    )
  }

  // The compass face center in screen coordinates
  // This is where the object starts in compass face
  // and where the send animation object appears to
  // come FROM (continuing the journey)
  static func compassCenter(
    screenSize: CGSize
  ) -> CGPoint {
    CGPoint(
      x: screenSize.width / 2,
      y: screenSize.height * 0.42  // compass position
    )
  }
}

// MARK: - How to use this in practice:
//
// IN CompassFace:
// 1. Instrument object animates inside circle
// 2. When send triggered: object moves toward
//    person bearing (exit direction)
// 3. Record the exit bearing
// 4. Pass InstrumentTransition(exitBearing: bearing)
//    to the send animation
//
// IN SendAnimation:
// 1. Receive InstrumentTransition from compass
// 2. Start object at transition.sendEntryPoint()
//    NOT at screen center
//    NOT at a hardcoded position
// 3. Object continues journey from that point
// 4. Feels like ONE continuous animation
//
// EXAMPLE — Wind:
// Compass face: leaf swirls, exits northeast (45°)
// Send animation: leaf enters from same northeast
//   edge of screen, continues swirling, departs
//
// EXAMPLE — Rocket:
// Compass face: rocket aims northeast (45°)
// Send animation: rocket launches from that bearing
//   not from screen center
//
// RECEIPT ANIMATION (different rule):
// Object enters FROM sender's bearing
// This is always real/symbolic GPS direction
// Not related to compass face exit
// Receipt is a new emotional moment
