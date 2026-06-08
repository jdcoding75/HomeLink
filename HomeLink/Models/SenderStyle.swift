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
    case fingerFlick   = "fingerFlick"     // pro
    case bowArrow      = "bowArrow"        // pro

    var id: String { rawValue }

    var requiresPro: Bool {
        self != .glow
    }

    var displayName: String {
        switch self {
        case .glow:         return "glow"
        case .shootingStar: return "shooting star"
        case .firefly:      return "firefly"
        case .fingerFlick:  return "finger flick"
        case .bowArrow:     return "bow & arrow"
        }
    }

    var emoji: String {
        switch self {
        case .glow:         return "✨"
        case .shootingStar: return "🌟"
        case .firefly:      return "🫧"
        case .fingerFlick:  return "👆"
        case .bowArrow:     return "🏹"
        }
    }

    /// The card blurb in Pro setup.
    var blurb: String {
        switch self {
        case .glow:         return "warm and direct"
        case .shootingStar: return "fast and brilliant"
        case .firefly:      return "slow and intimate"
        case .fingerFlick:  return "quick and playful"
        case .bowArrow:     return "drawn and released"
        }
    }

    /// Total send duration — charge + launch + flight + impact.
    /// (Dramatic rebuild: sends are events now, not blinks.)
    var sendDuration: Double {
        switch self {
        case .glow:         return 1.20   // charge 200 · launch 100 · flight 700 · impact 200
        case .shootingStar: return 0.90   // charge 150 · streak 500 · impact 250
        case .firefly:      return 3.60   // wind: gather 300 · drift 3000 · land 300
        case .fingerFlick:  return 1.30   // transform 300 · compress 200 · snap 80 · flight 800
        case .bowArrow:     return 1.55   // transform 300 · draw 400 · hold 150 · flight 700
        }
    }

    /// Catch-mode travel (edge → center) duration, per spec.
    var catchTravelDuration: Double {
        switch self {
        case .glow:         return 0.40
        case .shootingStar: return 0.25   // faster than glow
        case .firefly:      return 0.60   // organic drift
        case .fingerFlick:  return 0.45   // bounces once mid-flight
        case .bowArrow:     return 0.50   // pulled out, flies home
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

    /// Same guard for non-view code (SupabaseService) — reads the tier
    /// straight from UserDefaults.
    static var effectiveForCurrentUser: SenderStyle {
        let saved = UserDefaults.standard.string(forKey: "subscriptionTier") ?? ""
        return effective(for: SubscriptionTier(rawValue: saved) ?? .free)
    }

    /// The style a ping travels with — sender_style from the wire/history,
    /// falling back to glow when missing or unknown (pre-migration rows,
    /// future styles this build doesn't know).
    static func from(_ raw: String?) -> SenderStyle {
        SenderStyle(rawValue: raw ?? "") ?? .glow
    }
}
