// ExpressionMode.swift
// Pointward › Utilities
//
// The core/expressive split. Pointward's heart is intimate, warm, subtle —
// Expressive Mode (paid) layers the playful emojis, chaotic animations, and
// silly sounds on top. Off by default: the pure emotional core.

import Foundation

enum ExpressionMode {

    static let storageKey = "expressiveModeEnabled"

    /// True when the expressive playground is unlocked AND switched on.
    /// Views should observe via @AppStorage(ExpressionMode.storageKey) for
    /// reactivity; this accessor serves non-view code.
    static var isOn: Bool {
        UserDefaults.standard.bool(forKey: storageKey)
    }

    static func set(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: storageKey)
    }
}
