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
        // [hide-pro] v1 is free — a generous 10-person limit for ALL tiers so the people-limit
        // paywall never bites (no dead "+" button, no $2.99 surface). PRIOR: free 1 · pro 5 ·
        // institutional Int.max. (institutional stays unlimited — already ≥10, no limit issue.)
        switch self {
        case .free:          return 10   // was 1
        case .pro:           return 10   // was 5
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
        // Unified picker: two free compass variants — Pro buys the
        // instruments. (Heart retired; previous: minimal+vintage+heart)
        case .free:          return ["minimal", "vintage"]
        case .pro:      return Set(CompassSkin.allCases.map(\.rawValue))
        case .institutional: return Set(CompassSkin.allCases.map(\.rawValue))
        }
    }
}
