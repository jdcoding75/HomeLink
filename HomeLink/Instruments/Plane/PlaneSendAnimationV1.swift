// PlaneSendAnimationV1.swift
// Pointward › Instruments › Plane
//
// V1 MARKER — the ORIGINAL, ACTIVE plane send.
//
// The live V1 plane send is the `planeSend` branch inside the shared
// SenderAnimationView dispatcher. It is intentionally NOT extracted into a
// standalone View — the safety rule is zero behaviour change. This marker
// records that V1 is the active version and pins its timing next to the
// instrument.
//
// V2 — the full-screen redesign — lives in PlaneSendAnimationV2.swift and is
// wired ONLY into the Animation Test Lab until explicitly promoted.

import SwiftUI

enum PlaneSendAnimationV1 {
    /// Live implementation: SenderAnimationView.planeSend.
    static let duration: Double = InstrumentBoundaries.Send.plane
    static let isActive = true
}
