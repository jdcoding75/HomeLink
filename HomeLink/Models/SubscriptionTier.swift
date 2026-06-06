// SubscriptionTier.swift
// Pointward › Models

import Foundation

/// Phase 1 model: free to download, one-time $1.99 purchase unlocks everything.
/// No subscription — `.unlocked` is permanent once purchased.
enum SubscriptionTier: String, Codable {
    case free
    case unlocked        // one-time $1.99 purchase
    case institutional   // reserved for School Edition

    var maxPeople: Int {
        switch self {
        case .free:          return 1
        case .unlocked:      return Int.max
        case .institutional: return Int.max
        }
    }

    var canSendPings: Bool    { self != .free }
    var canUseWidgets: Bool   { self != .free }

    var unlockedSkinIDs: Set<String> {
        switch self {
        case .free:          return ["minimal", "vintage"]
        case .unlocked:      return Set(CompassSkin.allCases.map(\.rawValue))
        case .institutional: return Set(CompassSkin.allCases.map(\.rawValue))
        }
    }
}
