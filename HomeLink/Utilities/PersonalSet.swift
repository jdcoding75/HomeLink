// PersonalSet.swift
// Pointward › Utilities
//
// The curated six — every user carries exactly 6 thoughts on the send
// screen. Free users carry the core six; Pro Mode users curate
// theirs from the whole library (including custom recordings).

import Foundation

enum PersonalSet {

    static let storageKey = "personalSixTokens"
    static let slotCount  = 6

    /// The core six — the default set, and all a free user can hold.
    static let coreDefault = ["❤️", "💋", "🤗", "✨", "🌸", "🌙"]

    static func load() -> [String] {
        // A saved set is honoured as-is (1…6 tokens — the slot picker lets
        // people carry fewer than six). Only a brand-new user gets the core
        // six as a starting point.
        guard let saved = UserDefaults.standard.stringArray(forKey: storageKey),
              !saved.isEmpty else {
            return coreDefault
        }
        return Array(saved.prefix(slotCount))
    }

    static func save(_ tokens: [String]) {
        UserDefaults.standard.set(Array(tokens.prefix(slotCount)), forKey: storageKey)
    }
}
