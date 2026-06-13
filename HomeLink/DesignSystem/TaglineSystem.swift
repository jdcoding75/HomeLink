// TaglineSystem.swift
// Pointward › DesignSystem

import Foundation

enum TaglineSystem {

    static let defaultTagline = "Thinking of you."
    static let maxLength = 60

    // INSTRUMENT HINTS — default message tone per instrument.
    // Edit here only. These are starting points — user can always override.
    // Pro/Free gate: TBD — end-game configuration session.
    //
    // Keyed by SenderStyle.rawValue (String, not the enum, so this file stays
    // usable from any target). Look up with hint(forStyle:) or instrumentHints[style.rawValue].
    static let instrumentHints: [String: String] = [
        "glow":        "sending this straight to where you are ✦",   // Compass
        "bowArrow":    "shooting you a thought ✦",                   // Bow
        "fingerFlick": "flicked this your way ✦",                    // Flick
        "rocket":      "launched something just for you ✦",          // Rocket
        "firefly":     "carried this to you on the wind ✦",          // Wind
        "wand":        "a little magic headed your way ✦",           // Wand
        "plane":       "air mail · on its way to you ✦",             // Plane
    ]

    /// The instrument hint for a SenderStyle raw value (nil if none).
    static func hint(forStyleRaw raw: String) -> String? { instrumentHints[raw] }

    static let presets: [String] = [
        "Thinking of you.",
        "You're my home.",
        "Always close.",
        "My heart points to you.",
        "Never far.",
    ]

    /// The full poetic library — the emotional anchor of the compass screen.
    /// One is chosen at random per session (no timers, no cycling).
    static let poeticLibrary: [String] = [
        "Where you are, I feel.",
        "Distance has a direction.",
        "Near is a feeling.",
        "You're the pull.",
        "I turn toward you.",
        "You're my true north.",
        "No distance exists between two minds.",
        "Felt before it was sent.",
        "There before you finished missing them.",
        "Already there · love travels instantly.",
        "Distance is only physical.",
        "Speed of love · immeasurable.",
        "Closer than the miles suggest.",
        "My heart points to you.",
        "The needle always knows.",
        "I feel you move.",
        "You're the direction I always return to.",
        "Distance far. Thoughts close.",
    ]

    /// A random poetic tagline — assigned to each new person so they start
    /// with a voice that then travels with every thought.
    static var random: String { poeticLibrary.randomElement() ?? defaultTagline }

    /// Cycle to the next tagline after the current one (wraps). nil/unknown
    /// starts at the top of the library.
    static func next(after current: String?) -> String {
        guard let current, let i = poeticLibrary.firstIndex(of: current) else {
            return poeticLibrary.first ?? defaultTagline
        }
        return poeticLibrary[(i + 1) % poeticLibrary.count]
    }

    static func validate(_ text: String) -> TaglineValidation {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty           { return .empty }
        if trimmed.count > maxLength { return .tooLong }
        return .valid(trimmed)
    }

    enum TaglineValidation {
        case empty
        case valid(String)
        case tooLong

        var sanitised: String? {
            switch self {
            case .empty:        return nil
            case .valid(let t): return t
            case .tooLong:      return nil
            }
        }
    }

    static func counterText(_ current: Int) -> String {
        "\(current) / \(maxLength)"
    }

    enum CounterState { case normal, warning, atLimit }

    static func counterState(_ current: Int) -> CounterState {
        if current >= maxLength      { return .atLimit }
        if current >= maxLength - 10 { return .warning }
        return .normal
    }
}
