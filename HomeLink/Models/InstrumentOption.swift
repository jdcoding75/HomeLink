// InstrumentOption.swift
// Pointward › Models
//
// ONE PICKER FOR EVERYTHING — instrument and skin unified into a single
// selection. The two compass variants are the free tier; the Pro
// instruments live below them. Selecting an option drives BOTH stores
// (InstrumentStore for routing, SkinStore for the compass face) so all
// existing plumbing keeps working untouched.
//
//   FREE   🧭 minimal · 🧭 vintage brass (default)
//   PRO    🏹 bow & arrow · 👆 flick · 🚀 rocket · 🌬️ wind
//
// (Heart compass retired — its slot in the lineup belongs to the bow.)

import Foundation

enum InstrumentOption: String, CaseIterable, Identifiable {
    // Free — the compass, two ways
    case compassMinimal = "compassMinimal"
    case compassVintage = "compassVintage"
    // case compassHeart = "compassHeart"   // retired — bow took the slot
    // Pro — the instruments
    case bow    = "bow"
    case flick  = "flick"
    case rocket = "rocket"   // fuel · aim · blast off
    case wind   = "wind"     // replaced the firefly
    case wand   = "wand"     // load · shake · release
    case plane  = "plane"    // ✈️ coming soon — wind · release · glide

    var id: String { rawValue }

    var requiresPro: Bool {
        switch self {
        case .compassMinimal, .compassVintage:           return false
        case .bow, .flick, .rocket, .wind, .wand, .plane: return true
        }
    }

    /// [5/6] The plane is a Coming-Soon teaser — visible, not selectable.
    var comingSoon: Bool { self == .plane }

    var displayName: String {
        switch self {
        case .compassMinimal: return "minimal"
        case .compassVintage: return "vintage brass"
        // case .compassHeart: return "heart"
        case .bow:            return "bow & arrow"
        case .flick:          return "flick"
        case .rocket:         return "rocket"
        case .wind:           return "wind"
        case .wand:           return "wand"
        case .plane:          return "plane"
        }
    }

    var icon: String {
        switch self {
        case .compassMinimal, .compassVintage: return "🧭"
        case .bow:    return "🏹"
        case .flick:  return "👆"
        case .rocket: return "🚀"
        case .wind:   return "🌬️"
        case .wand:   return "🪄"
        case .plane:  return "✈️"
        }
    }

    var tagline: String {
        switch self {
        case .compassMinimal: return "clean · modern"
        case .compassVintage: return "antique pocket watch"
        // case .compassHeart: return "love finds its direction"
        case .bow:            return "draw · aim · release"
        case .flick:          return "load · aim · launch"
        case .rocket:         return "fuel · aim · blast off"
        case .wind:           return "breathe · release"
        case .wand:           return "load · shake · release"
        case .plane:          return "wind · release · glide"
        }
    }

    /// The underlying instrument this option routes to. (Plane is Coming Soon,
    /// so it parks on the compass until it ships — never actually selected.)
    var instrument: Instrument {
        switch self {
        case .compassMinimal, .compassVintage: return .compass
        case .bow:    return .bow
        case .flick:  return .flick
        case .wind:   return .firefly
        case .rocket: return .rocket
        case .wand:   return .wand
        case .plane:  return .compass
        }
    }

    /// The compass skin this option dresses the face with (compass only).
    var skin: CompassSkin? {
        switch self {
        case .compassMinimal: return .minimal
        case .compassVintage: return .vintage
        // case .compassHeart: return .heart
        default:              return nil
        }
    }

    // ── Persistence ──────────────────────────────────────────────────────

    static let storageKey = "selectedInstrumentOption"

    static var selected: InstrumentOption {
        get {
            let raw = UserDefaults.standard.string(forKey: storageKey) ?? ""
            // A persisted heart selection (pre-retirement) lands on vintage
            return InstrumentOption(rawValue: raw) ?? .compassVintage
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: storageKey)
        }
    }

    /// Apply a selection — drives both stores so routing, skin, send
    /// style, and wire format all follow one choice.
    @MainActor
    static func apply(_ option: InstrumentOption,
                      instrumentStore: InstrumentStore,
                      skinStore: SkinStore) {
        guard !option.comingSoon else { return }
        selected = option
        instrumentStore.selected = option.instrument
        if let skin = option.skin {
            skinStore.activeSkin = skin
        }
    }

    /// First-run derivation from the previous two-selection system.
    /// Reads raw UserDefaults so it can run before any store exists.
    static func migrateLegacySelection() {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: storageKey) == nil else { return }
        let instrumentRaw = defaults.string(forKey: InstrumentStore.storageKey) ?? ""
        let skinRaw       = defaults.string(forKey: "activeSkin") ?? ""
        let derived: InstrumentOption
        switch Instrument(rawValue: instrumentRaw) ?? .compass {
        case .bow:     derived = .bow
        case .flick:   derived = .flick
        case .rocket:  derived = .rocket
        case .wand:    derived = .wand
        case .firefly: derived = .wind
        case .compass:
            switch CompassSkin(rawValue: skinRaw) ?? .vintage {
            case .minimal: derived = .compassMinimal
            // heart retired — its users land on vintage brass
            default:       derived = .compassVintage
            }
        }
        defaults.set(derived.rawValue, forKey: storageKey)
    }
}
