// AnimationDispatch.swift
// Pointward › Instruments › _Shared
//
// [arrival-parity stage0] THE pure dispatch source of truth: which send / receipt
// animation a given (style, emoji) selects. Extracted from the inline ladders in
// CompassView (flightToken Group) + ReceiptView.body so the decision is unit-assertable
// with no SwiftUI / no device. Returns a KIND (not a View); the views render FROM the kind.
// ZERO behavior change — the conditions + order are identical to the originals.

import Foundation

/// Which SEND animation the flightToken ladder selects.
enum SendAnimationKind: Equatable {
    case firework, birthday, wand, bowArrow, plane, fingerFlick
    case shared   // SenderAnimationView catch-all: glow · shootingStar · firefly(wind) · rocket
}

/// Which RECEIPT animation ReceiptView selects.
enum ReceiptKind: Equatable {
    case birthday, firework, wind, rocket, bow, plane, flick, compass
    case standard // standardReceipt catch-all: wand (R4) · shootingStar
}

enum AnimationDispatch {

    /// Mirrors CompassView's flightToken ladder (CompassView.swift flightToken Group).
    /// Special moments key on STYLE **or** the legacy 🎆/🎂 emoji (transition fallback,
    /// retire in Stage 4) — checked first, in the ladder's order (firework, then birthday).
    static func sendAnimationKind(for style: SenderStyle, emoji: String) -> SendAnimationKind {
        if style == .firework || emoji == "🎆" { return .firework }
        if style == .birthday || emoji == "🎂" { return .birthday }
        switch style {
        case .wand:        return .wand
        case .bowArrow:    return .bowArrow
        case .plane:       return .plane
        case .fingerFlick: return .fingerFlick
        case .glow, .shootingStar, .firefly, .rocket:
            return .shared
        case .birthday, .firework:
            return .shared   // unreachable (caught above); keeps the switch exhaustive
        }
    }

    /// Mirrors ReceiptView.body (ReceiptView.swift). Birthday before firework (the receipt
    /// ladder's order); style-or-emoji fallback first.
    static func receiptKind(for style: SenderStyle, emoji: String) -> ReceiptKind {
        if style == .birthday || emoji == "🎂" { return .birthday }
        if style == .firework || emoji == "🎆" { return .firework }
        switch style {
        case .firefly:     return .wind
        case .rocket:      return .rocket
        case .bowArrow:    return .bow
        case .plane:       return .plane
        case .fingerFlick: return .flick
        case .glow:        return .compass
        case .wand, .shootingStar:
            return .standard
        case .birthday, .firework:
            return .standard // unreachable (caught above); keeps the switch exhaustive
        }
    }
}
