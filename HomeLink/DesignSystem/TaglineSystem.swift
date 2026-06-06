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
