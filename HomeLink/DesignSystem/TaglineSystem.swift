// TaglineSystem.swift
// Pointward › DesignSystem

import Foundation

enum TaglineSystem {

    static let defaultTagline = "Love has a direction."
    static let maxLength = 60

    static let presets: [String] = [
        "Love has a direction.",
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
        "Love has a direction.",
        "You're my true north.",
        "No distance exists between two minds.",
        "Felt before it was sent.",
        "There before you finished missing them.",
        "Already there · love travels instantly.",
        "Distance is only physical.",
        "Speed of love · immeasurable.",
        "Closer than the miles suggest.",
        "You're closer than the miles.",
        "My heart points to you.",
        "Where you are, I point.",
        "The needle always knows.",
        "I feel you move.",
        "Near is where the heart points.",
        "You're the direction I always return to.",
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
