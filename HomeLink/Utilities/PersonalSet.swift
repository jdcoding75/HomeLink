// PersonalSet.swift
// Pointward › Utilities
//
// The curated six — every user carries exactly 6 thoughts on the send
// screen. Free users carry the core six; Expressive Mode users curate
// theirs from the whole library (including custom recordings).

import Foundation

enum PersonalSet {

    static let storageKey = "personalSixTokens"
    static let slotCount  = 6

    /// The core six — the default set, and all a free user can hold.
    static let coreDefault = ["❤️", "💋", "🤗", "✨", "🌸", "🌙"]

    static func load() -> [String] {
        let saved = UserDefaults.standard.stringArray(forKey: storageKey) ?? coreDefault
        // Always exactly six — pad from core if anything went missing
        var tokens = saved
        for core in coreDefault where tokens.count < slotCount && !tokens.contains(core) {
            tokens.append(core)
        }
        return Array(tokens.prefix(slotCount))
    }

    static func save(_ tokens: [String]) {
        UserDefaults.standard.set(Array(tokens.prefix(slotCount)), forKey: storageKey)
    }
}
