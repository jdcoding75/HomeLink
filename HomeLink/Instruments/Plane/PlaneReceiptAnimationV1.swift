// PlaneReceiptAnimationV1.swift
// Pointward › Instruments › Plane
//
// V1 MARKER — the ORIGINAL, ACTIVE plane receipt.
//
// The live V1 plane receipt is the inline `PlaneLanding` beat in
// InstrumentLandingView (under the shared `standardReceipt` in ReceiptView).
// It is intentionally NOT extracted into a standalone View — the safety rule is
// zero behaviour change. This marker records that V1 is the active version.
//
// V2 — the full-screen redesign — lives in PlaneReceiptAnimationV2.swift and is
// wired ONLY into the Animation Test Lab until explicitly promoted.

import SwiftUI

enum PlaneReceiptAnimationV1 {
    /// Live implementation: ReceiptView.standardReceipt + InstrumentLandingView.PlaneLanding.
    static let duration: Double = InstrumentBoundaries.Receipt.plane
    static let isActive = true
}
