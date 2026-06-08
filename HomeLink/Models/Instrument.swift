// Instrument.swift
// Pointward › Models
//
// THE FOUR INSTRUMENTS — one selection defines everything: the main-screen
// visual, the send mechanic, the flight, and the catch on the other side.
// This replaces the old compass + sender-style two-selection system.

import Foundation

enum Instrument: String, CaseIterable, Codable, Identifiable {
    case compass  = "compass"   // free
    case bow      = "bow"       // pro
    case firefly  = "firefly"   // pro
    case flick    = "flick"     // pro
    case rocket   = "rocket"    // pro — fuel · aim · blast off
    case wand     = "wand"      // pro — load · shake · release

    var id: String { rawValue }

    var requiresPro: Bool { self != .compass }

    var displayName: String {
        switch self {
        case .compass: return "compass"
        case .bow:     return "bow & arrow"
        case .firefly: return "wind"      // 🌬️ wind replaced the firefly
        case .flick:   return "flick"     //    (case name kept — wire format)
        case .rocket:  return "rocket"
        case .wand:    return "wand"
        }
    }

    var tagline: String {
        switch self {
        case .compass: return "classic · always points true"
        case .bow:     return "draw · aim · release"
        case .firefly: return "breathe · release"   // wind
        case .flick:   return "load · aim · launch"
        case .rocket:  return "fuel · aim · blast off"
        case .wand:    return "load · shake · release"
        }
    }

    var icon: String {
        switch self {
        case .compass: return "🧭"
        case .bow:     return "🏹"
        case .firefly: return "🌬️"   // wind (was 🫧)
        case .flick:   return "👆"
        case .rocket:  return "🚀"
        case .wand:    return "🪄"
        }
    }

    /// The flight + catch personality this instrument sends with —
    /// one selection drives the whole pipeline (wire format included).
    var senderStyle: SenderStyle {
        switch self {
        case .compass: return .glow
        case .bow:     return .bowArrow
        case .firefly: return .firefly
        case .flick:   return .fingerFlick
        case .rocket:  return .rocket
        case .wand:    return .wand
        }
    }
}
