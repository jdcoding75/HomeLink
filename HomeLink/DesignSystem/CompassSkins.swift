// CompassSkins.swift
// HomeLink › DesignSystem

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
        case .minimal:   return "minimal"
        case .classic:   return "classic rose"
        case .heart:     return "heart compass"
        case .celestial: return "celestial"
        case .vintage:   return "vintage brass"
        case .aurora:    return "aurora"
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

    var requiresPro: Bool {
        switch self {
        case .minimal, .classic, .heart:    return false
        case .celestial, .vintage, .aurora: return true
        }
    }

    var northAccentColor: Color {
        switch self {
        case .aurora:    return Color(hex: "#5dcaa5")
        case .celestial: return Color(hex: "#e8e0f0")
        case .vintage:   return Color(hex: "#e8e0f0")
        default:         return Color(hex: "#c4a8d4")
        }
    }

    var southAccentColor: Color {
        switch self {
        case .aurora:  return Color(hex: "#085041")
        case .vintage: return Color(hex: "#6b5f7a")
        default:       return Color(hex: "#3a2e50")
        }
    }

    var pivotColor: Color {
        switch self {
        case .aurora: return Color(hex: "#1D9E75")
        default:      return Color(hex: "#7c6b8e")
        }
    }
}
