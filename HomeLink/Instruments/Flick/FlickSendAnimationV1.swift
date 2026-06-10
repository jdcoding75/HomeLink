// FlickSendAnimationV1.swift
// Pointward › Instruments › Flick
//
// V1 MARKER — the ORIGINAL, ACTIVE flick send.
//
// The live V1 flick send is the `fingerFlickSend` branch inside the shared
// SenderAnimationView dispatcher. It is intentionally NOT extracted into a
// standalone View — the safety rule is zero behaviour change. This marker
// records that V1 is the active version and pins its timing next to the
// instrument.
//
// V2 — the full-screen redesign — lives in FlickSendAnimationV2.swift and is
// wired ONLY into the Animation Test Lab until explicitly promoted.

import SwiftUI

enum FlickSendAnimationV1 {
    /// Live implementation: SenderAnimationView.fingerFlickSend.
    static let duration: Double = InstrumentBoundaries.Send.flick
    static let isActive = true
}
