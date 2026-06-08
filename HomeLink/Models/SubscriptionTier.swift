// SubscriptionTier.swift
// Pointward › Models

import Foundation

/// Phase 1 model: free to download, one-time $2.99 purchase unlocks everything.
/// No subscription — `.pro` is permanent once purchased.
enum SubscriptionTier: String, Codable {
    case free
    // case unlocked     // renamed to .pro (rawValue kept for persistence)
    case pro = "unlocked"   // one-time $2.99 purchase
    case institutional   // reserved for School Edition

    var maxPeople: Int {
        switch self {
        case .free:          return 1
        case .pro:      return 5   // was Int.max — "up to 5 people"
        case .institutional: return Int.max
        }
    }

    /// Display labels: "free" / "pro"
    var displayName: String {
        switch self {
        case .free:          return "free"
        case .pro:           return "pro"
        case .institutional: return "school"
        }
    }

    var canSendPings: Bool    { self != .free }
    var canUseWidgets: Bool   { self != .free }

    var unlockedSkinIDs: Set<String> {
        switch self {
        // Unified picker: the three compass variants are everyone's —
        // Pro buys the instruments. (previous: ["minimal"])
        case .free:          return ["minimal", "vintage", "heart"]
        case .pro:      return Set(CompassSkin.allCases.map(\.rawValue))
        case .institutional: return Set(CompassSkin.allCases.map(\.rawValue))
        }
    }
}
