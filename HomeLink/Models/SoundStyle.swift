// SoundStyle.swift
// Pointward › Models
//
// [3/5] SOUND PERSONALITY — replaces the old "record your own" custom sound
// feature. Every instrument carries one of three curated personalities:
//
//   warm     — soft and intimate   (quieter, single clean voice)
//   playful  — light and fun       (full voice, a touch brighter)
//   dramatic — big and impactful   (louder, layered/enhanced body)
//
// The choice is stored per instrument (UserDefaults "soundStyle_<instrument>")
// and read on the playback path so the user's own sends and the catches they
// reveal take on their chosen character. No microphone, no recordings.

import Foundation

enum SoundStyle: String, CaseIterable, Identifiable {
    case warm
    case playful
    case dramatic

    var id: String { rawValue }

    /// The sensible default — a friendly middle ground.
    static let `default`: SoundStyle = .playful

    var displayName: String {
        switch self {
        case .warm:     return "warm"
        case .playful:  return "playful"
        case .dramatic: return "dramatic"
        }
    }

    var blurb: String {
        switch self {
        case .warm:     return "soft and intimate"
        case .playful:  return "light and fun"
        case .dramatic: return "big and impactful"
        }
    }

    var icon: String {
        switch self {
        case .warm:     return "heart.fill"
        case .playful:  return "sparkles"
        case .dramatic: return "bolt.fill"
        }
    }

    /// Volume scaling applied on the playback path — warm leans quiet and
    /// close, dramatic leans loud and present.
    var volumeScale: Float {
        switch self {
        case .warm:     return 0.78
        case .playful:  return 1.0
        case .dramatic: return 1.28
        }
    }

    /// Dramatic prefers the layered/enhanced rendering (more body) whenever a
    /// pro-enhanced buffer exists; the others stay clean.
    var prefersEnhanced: Bool { self == .dramatic }

    // ── Persistence (per instrument) ───────────────────────────────────────

    static func storageKey(for instrument: Instrument) -> String {
        "soundStyle_\(instrument.rawValue)"
    }

    static func selected(for instrument: Instrument) -> SoundStyle {
        let raw = UserDefaults.standard.string(forKey: storageKey(for: instrument)) ?? ""
        return SoundStyle(rawValue: raw) ?? .default
    }

    static func select(_ style: SoundStyle, for instrument: Instrument) {
        UserDefaults.standard.set(style.rawValue, forKey: storageKey(for: instrument))
    }

    /// The personality for the user's CURRENTLY selected instrument — what the
    /// SoundEngine reads when playing send/catch voices.
    static var current: SoundStyle {
        selected(for: InstrumentOption.selected.instrument)
    }

    /// A representative voice token for an instrument, used to audition a
    /// personality in the picker (and a reasonable fallback elsewhere).
    static func previewToken(for instrument: Instrument) -> String {
        switch instrument {
        case .compass: return "catch.arrival"
        case .bow:     return "style.whoosh"
        case .firefly: return "style.chime"
        case .flick:   return "style.shimmer"
        case .rocket:  return "rocket.blast"
        case .wand:    return "style.bell"
        case .plane:   return "plane.wind"
        }
    }
}
