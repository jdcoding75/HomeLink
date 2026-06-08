// InstrumentOption.swift
// Pointward › Models
//
// ONE PICKER FOR EVERYTHING — instrument and skin unified into a single
// selection. One compass (vintage brass), perfected, is the free tier; the
// Pro instruments live below it. Selecting an option drives BOTH stores
// (InstrumentStore for routing, SkinStore for the compass face) so all
// existing plumbing keeps working untouched.
//
//   FREE   🧭 vintage brass (default)
//   PRO    🏹 bow · 👆 flick · 🚀 rocket · 🌬️ wind · 🪄 wand · ✈️ plane
//
// (Heart compass retired — bow took its slot. [2/5] Minimal compass retired —
//  one perfected vintage compass is the free tier.)

import Foundation

enum InstrumentOption: String, CaseIterable, Identifiable {
    // Free — the compass, perfected (one variant)
    // [2/5] case compassMinimal = "compassMinimal"   // retired → vintage brass
    case compassVintage = "compassVintage"
    // case compassHeart = "compassHeart"   // retired — bow took the slot
    // Pro — the instruments
    case bow    = "bow"
    case flick  = "flick"
    case rocket = "rocket"   // fuel · aim · blast off
    case wind   = "wind"     // replaced the firefly
    case wand   = "wand"     // load · shake · release
    case plane  = "plane"    // ✈️ wind · let fly · glide

    var id: String { rawValue }

    var requiresPro: Bool {
        switch self {
        case .compassVintage:                            return false
        case .bow, .flick, .rocket, .wind, .wand, .plane: return true
        }
    }

    /// [3/5] The plane has launched — nothing is coming-soon anymore.
    var comingSoon: Bool { false }

    var displayName: String {
        switch self {
        // case .compassMinimal: return "minimal"
        case .compassVintage: return "vintage brass"
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
        case .compassVintage: return "🧭"
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
        // case .compassMinimal: return "clean · modern"
        case .compassVintage: return "antique pocket watch"
        case .bow:            return "draw · aim · release"
        case .flick:          return "load · aim · launch"
        case .rocket:         return "fuel · aim · blast off"
        case .wind:           return "breathe · release"
        case .wand:           return "load · shake · release"
        case .plane:          return "wind · let fly"
        }
    }

    /// The underlying instrument this option routes to.
    var instrument: Instrument {
        switch self {
        case .compassVintage: return .compass
        case .bow:    return .bow
        case .flick:  return .flick
        case .wind:   return .firefly
        case .rocket: return .rocket
        case .wand:   return .wand
        case .plane:  return .plane
        }
    }

    /// The compass skin this option dresses the face with (compass only).
    var skin: CompassSkin? {
        switch self {
        // case .compassMinimal: return .minimal
        case .compassVintage: return .vintage
        default:              return nil
        }
    }

    // ── Persistence ──────────────────────────────────────────────────────

    static let storageKey = "selectedInstrumentOption"

    static var selected: InstrumentOption {
        get {
            let raw = UserDefaults.standard.string(forKey: storageKey) ?? ""
            // A persisted minimal/heart selection (both retired) lands on vintage.
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
        case .plane:   derived = .plane
        case .firefly: derived = .wind
        case .compass:
            // [2/5] minimal retired — minimal AND heart users land on vintage.
            switch CompassSkin(rawValue: skinRaw) ?? .vintage {
            default:       derived = .compassVintage
            }
        }
        defaults.set(derived.rawValue, forKey: storageKey)
    }
}
