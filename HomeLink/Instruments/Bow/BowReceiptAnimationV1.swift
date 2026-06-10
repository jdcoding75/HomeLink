// BowReceiptAnimationV1.swift
// Pointward › Instruments › Bow
//
// V1 MARKER — the ORIGINAL, ACTIVE bow receipt.
//
// The live V1 bow receipt is the shared spin-to-catch `standardReceipt` in
// ReceiptView (with the `ArrowLanding` landing beat in InstrumentLandingView).
// It is intentionally NOT extracted into a standalone View — the safety rule is
// zero behaviour change. This marker records that V1 is the active version.
//
// V2 — the full-screen Gemini redesign — lives in BowReceiptAnimationV2.swift
// and is wired ONLY into the Animation Test Lab until explicitly promoted.

import SwiftUI

enum BowReceiptAnimationV1 {
    /// Live implementation: ReceiptView.standardReceipt + InstrumentLandingView.ArrowLanding.
    static let duration: Double = InstrumentBoundaries.Receipt.bow
    static let isActive = true
}
