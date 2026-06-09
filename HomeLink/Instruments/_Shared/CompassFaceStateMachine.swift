// CompassFaceStateMachine.swift
// Pointward › Instruments › _Shared
//
// The shared driver for ACT 1 — the compass face.
//
// Every instrument's face moves through the SAME five
// states (see CompassFaceState in InstrumentBoundaries):
//
//   idle → triggered → charging → ready → exiting
//
// Each instrument interprets the states differently (bow
// draws, rocket fuels, wand charges…) but the lifecycle,
// the timing ceilings (CompassFaceStateDurations), and the
// hand-off to the send animation are identical. This class
// owns that lifecycle so no instrument re-implements it.
//
// ADOPTION:
// This machine is additive scaffolding — the live gesture
// mechanics in each *CompassFace view are NOT yet rewired
// onto it (that is a deliberate, separately-verified step,
// to keep the working send mechanics behavior-identical).
// Each face exposes a `make…StateMachine()` factory and a
// documented per-state map so the wiring is mechanical when
// it happens.
//
// THE HAND-OFF:
// When the face reaches `.exiting`, it calls `exit(...)`,
// which builds an InstrumentTransition and invokes `onExit`.
// The send animation (ACT 2) listens on `onExit` and begins
// immediately from `transition.exitPoint`, giving one
// seamless journey instead of two separate animations.

import SwiftUI
import Combine

@MainActor
final class CompassFaceStateMachine: ObservableObject {

  /// The current state. Views observe this to drive the
  /// per-state ambient / charge / anticipation animation.
  @Published private(set) var state: CompassFaceState = .idle

  /// 0…1 charge progress while in `.charging`. Instruments
  /// map their own mechanic onto this (draw distance, fuel
  /// taps, shake count, wind-up circles, pull-back, hold).
  @Published private(set) var chargeProgress: Double = 0

  /// The instrument this face represents.
  let instrument: Instrument

  /// Fired exactly once when the object leaves the circle.
  /// The send animation subscribes here.
  var onExit: ((InstrumentTransition) -> Void)?

  init(instrument: Instrument) {
    self.instrument = instrument
  }

  // MARK: - Lifecycle

  /// User started the mechanic (finger down, breath, first
  /// tap/shake, hold begins). idle → triggered.
  func trigger() {
    guard state == .idle else { return }
    state = .triggered
  }

  /// The mechanic is building. triggered/charging → charging.
  /// `progress` is clamped to 0…1; reaching 1 does NOT auto-
  /// advance — the instrument decides when it is `.ready`
  /// (e.g. bow within 5°, rocket fully fueled, 3 wind circles).
  func charge(progress: Double) {
    guard state == .triggered || state == .charging else { return }
    state = .charging
    chargeProgress = min(1, max(0, progress))
  }

  /// Fully charged / aimed. charging → ready. This is the
  /// brief anticipation pause before exit.
  func markReady() {
    guard state == .charging else { return }
    chargeProgress = 1
    state = .ready
  }

  /// The object leaves the circle. ready → exiting, fires the
  /// transition to the send animation. Safe to call from
  /// `.charging` too (instant-release instruments like flick).
  func exit(
    bearing: Double,
    point: CGPoint,
    emoji: String,
    message: String? = nil,
    tagline: String? = nil
  ) {
    guard state == .ready || state == .charging else { return }
    state = .exiting
    let transition = InstrumentTransition(
      exitBearing: bearing,
      exitPoint: point,
      instrument: instrument,
      emoji: emoji,
      message: message,
      tagline: tagline
    )
    onExit?(transition)
  }

  /// Return to rest (cancel, or after the send hand-off
  /// completes). Any state → idle.
  func reset() {
    state = .idle
    chargeProgress = 0
  }
}
