// FlickReceiptAnimationV1.swift
// Pointward › Instruments › Flick
//
// V1 MARKER — the ORIGINAL, ACTIVE flick receipt.
//
// The live V1 flick receipt is the shared spin-to-catch `standardReceipt` in
// ReceiptView (with the `PostItLanding` landing beat in InstrumentLandingView).
// It is intentionally NOT extracted into a standalone View — the safety rule is
// zero behaviour change. This marker records that V1 is the active version.
//
// V2 — the full-screen redesign — lives in FlickReceiptAnimationV2.swift and is
// wired ONLY into the Animation Test Lab until explicitly promoted.

import SwiftUI

enum FlickReceiptAnimationV1 {
    /// Live implementation: ReceiptView.standardReceipt + InstrumentLandingView.PostItLanding.
    static let duration: Double = InstrumentBoundaries.Receipt.flick
    static let isActive = true
}
