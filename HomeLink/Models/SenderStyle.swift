// SenderStyle.swift
// Pointward › Models
//
// How a thought travels. Glow is the warm free default; shooting star and
// firefly are Pro personalities. The selected style shapes the send
// animation, the catch-mode visuals, and history replays.

import Foundation

enum SenderStyle: String, CaseIterable, Identifiable {
    case glow          = "glow"            // free default
    case shootingStar  = "shootingStar"    // pro
    case firefly       = "firefly"         // pro

    var id: String { rawValue }

    var requiresPro: Bool {
        self != .glow
    }

    var displayName: String {
        switch self {
        case .glow:         return "glow"
        case .shootingStar: return "shooting star"
        case .firefly:      return "firefly"
        }
    }

    var emoji: String {
        switch self {
        case .glow:         return "✨"
        case .shootingStar: return "🌟"
        case .firefly:      return "🫧"
        }
    }

    /// The card blurb in Pro setup.
    var blurb: String {
        switch self {
        case .glow:         return "warm and direct"
        case .shootingStar: return "fast and brilliant"
        case .firefly:      return "slow and intimate"
        }
    }

    /// Total send-flight duration, per spec.
    var sendDuration: Double {
        switch self {
        case .glow:         return 0.35
        case .shootingStar: return 0.30
        case .firefly:      return 1.20   // slow, drifting
        }
    }

    /// Catch-mode travel (edge → center) duration, per spec.
    var catchTravelDuration: Double {
        switch self {
        case .glow:         return 0.40
        case .shootingStar: return 0.25   // faster than glow
        case .firefly:      return 0.60   // organic drift
        }
    }

    // ── Persistence ──────────────────────────────────────────────────────

    static let storageKey = "selectedSenderStyle"

    /// The raw selection (what the picker shows as chosen).
    static var selected: SenderStyle {
        get {
            let raw = UserDefaults.standard.string(forKey: storageKey) ?? ""
            return SenderStyle(rawValue: raw) ?? .glow
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: storageKey)
        }
    }

    /// HARD GUARD: the style that actually plays. Free users always get
    /// glow no matter what is persisted.
    static func effective(for tier: SubscriptionTier) -> SenderStyle {
        let style = selected
        if style.requiresPro && tier == .free { return .glow }
        return style
    }
}
