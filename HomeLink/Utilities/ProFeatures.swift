// ProFeatures.swift
// Pointward › Utilities
//
// The core/pro split. Pointward's heart is intimate, warm, subtle —
// Pro Mode (paid) layers the playful emojis, chaotic animations, and
// silly sounds on top. Off by default: the pure emotional core.

import Foundation

enum ProFeatures {

    static let storageKey = "proFeaturesEnabled"
    // (previous key: "expressiveModeEnabled" — migrated below)

    /// One-time migration: users who enabled the old "Expressive Mode"
    /// keep their setting under the new Pro key.
    static func migrateLegacyKey() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: storageKey) == nil,
           let legacy = defaults.object(forKey: "expressiveModeEnabled") as? Bool {
            defaults.set(legacy, forKey: storageKey)
        }
    }

    /// True when the pro playground is unlocked AND switched on.
    /// Views should observe via @AppStorage(ProFeatures.storageKey) for
    /// reactivity; this accessor serves non-view code.
    static var isOn: Bool {
        UserDefaults.standard.bool(forKey: storageKey)
    }

    static func set(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: storageKey)
    }
}
