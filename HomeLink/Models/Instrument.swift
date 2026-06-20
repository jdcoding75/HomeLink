// Instrument.swift
// Pointward › Models
//
// THE INSTRUMENTS — one selection defines everything: the main-screen
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
    case plane    = "plane"     // pro — wind · let fly · glide
    // [special moments — peer animations] First-class peers of the 7 instruments:
    // their own face + send + (Stage-3) receipt; selected like any instrument.
    case birthday = "birthday"  // pro — special moment: light the candles
    case firework = "firework"  // pro — special moment: light the fuse

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
        case .plane:   return "plane"
        case .birthday: return "birthday"
        case .firework: return "firework"
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
        case .plane:   return "wind · let fly"
        case .birthday: return "light the candles"
        case .firework: return "light the fuse"
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
        case .plane:   return "✈️"
        case .birthday: return "🎂"
        case .firework: return "🎆"
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
        case .plane:   return .plane
        case .birthday: return .birthday
        case .firework: return .firework
        }
    }

    /// Whether SENDING requires aiming at the person. Compass aligns by phone
    /// rotation; bow/flick/rocket by finger GESTURE. Wind (breath), wand
    /// (shake), and plane (auto-aim, tap-only) need no aiming action at all —
    /// "magic finds them" / the plane points itself. Testable data mirroring
    /// what the instrument views implement structurally.
    var requiresAlignment: Bool {
        switch self {
        case .compass, .bow, .flick, .rocket: return true
        case .firefly, .wand, .plane:         return false   // breath · shake · auto-aim
        case .birthday, .firework:            return false   // special moments — tap/drag on the face, no aim
        }
    }

    /// [AUDIT] The single rule: ONLY the compass aligns by ROTATING THE PHONE
    /// (device heading). Every other instrument that aims does so by finger
    /// gesture — bow spin · flick swipe · rocket spin — never by phone rotation.
    /// Wind/wand/plane don't aim at all. This is the invariant the alignment
    /// audit enforces and the alignment tests pin.
    var alignsByPhoneRotation: Bool { self == .compass }

    /// The wind instrument is backed by the `.firefly` case (the case name is
    /// kept for wire-format stability — see `displayName`). `.wind` is a clear,
    /// self-documenting alias so call sites can say what they mean
    /// (`playSend(.wind)`) without a new enum case that would break the wire
    /// format or switch exhaustiveness. `Instrument.wind == .firefly`.
    static let wind = Instrument.firefly
}
