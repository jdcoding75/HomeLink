// CompassSkins.swift
// Pointward › DesignSystem

import SwiftUI

enum CompassSkin: String, CaseIterable, Identifiable {
    case minimal    = "minimal"
    case classic    = "classic"
    case heart      = "heart"
    case celestial  = "celestial"
    case vintage    = "vintage"
    case aurora     = "aurora"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .minimal:   return "Minimal"
        case .classic:   return "Classic Rose"
        case .heart:     return "Heart Compass"
        case .celestial: return "Celestial"
        case .vintage:   return "Vintage Brass"
        case .aurora:    return "Aurora"
        }
    }

    var description: String {
        switch self {
        case .minimal:   return "clean · modern · default"
        case .classic:   return "traditional compass with cardinal points"
        case .heart:     return "love always finds its direction"
        case .celestial: return "stars · constellations · night sky"
        case .vintage:   return "antique pocket watch aesthetic"
        case .aurora:    return "northern lights · dreamy glow"
        }
    }

    var tagline: String {
        switch self {
        case .minimal:   return TaglineSystem.defaultTagline
        case .classic:   return "True north, found."
        case .heart:     return "My heart points to you."
        case .celestial: return "Written in the stars."
        case .vintage:   return "Always close."
        case .aurora:    return "Never far."
        }
    }

    /// Free tier ships with Minimal only; the $1.99 unlock opens the rest.
    /// Keep in sync with SubscriptionTier.unlockedSkinIDs.
    var requiresUnlock: Bool {
        switch self {
        case .minimal:                       return false
        case .classic, .heart, .vintage,
             .celestial, .aurora:            return true
        }
    }

    var northAccentColor: Color {
        switch self {
        case .minimal:   return Color(hex: "#c4a8d4")   // lavender
        case .classic:   return Color(hex: "#8B0000")   // deep red
        case .heart:     return Color(hex: "#ff69b4")   // rose pink
        case .celestial: return Color(hex: "#e8f4f8")   // starlight white
        case .vintage:   return Color(hex: "#FFD700")   // polished gold
        case .aurora:    return Color(hex: "#5dcaa5")   // bright teal
        }
    }

    var southAccentColor: Color {
        switch self {
        case .minimal:   return Color(hex: "#3a2e50")   // deep violet
        case .classic:   return Color(hex: "#f5f0e8")   // cream
        case .heart:     return Color(hex: "#8b0038")   // deep rose
        case .celestial: return Color(hex: "#1a1a3e")   // deep space
        case .vintage:   return Color(hex: "#8b6914")   // aged brass
        case .aurora:    return Color(hex: "#085041")   // deep ocean
        }
    }

    var pivotColor: Color {
        switch self {
        case .aurora:    return Color(hex: "#1D9E75")
        case .heart:     return Color(hex: "#e0a8c8")
        default:         return Color(hex: "#7c6b8e")
        }
    }
}
