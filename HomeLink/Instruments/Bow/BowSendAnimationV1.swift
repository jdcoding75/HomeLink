// BowSendAnimationV1.swift
// Pointward › Instruments › Bow
//
// V1 MARKER — the ORIGINAL, ACTIVE bow send.
//
// The live V1 bow send is the `bowArrowSend` branch inside the shared
// SenderAnimationView dispatcher. It is intentionally NOT extracted into a
// standalone View (doing so cannot be guaranteed behaviour-identical while it
// lives inside the generic dispatcher — the safety rule is zero behaviour
// change). This marker records that V1 is the active version and pins its
// timing next to the instrument.
//
// V2 — the full-screen redesign — lives in BowSendAnimationV2.swift and is
// wired ONLY into the Animation Test Lab until explicitly promoted.

import SwiftUI

enum BowSendAnimationV1 {
    /// Live implementation: SenderAnimationView.bowArrowSend.
    static let duration: Double = InstrumentBoundaries.Send.bow
    static let isActive = true
}
