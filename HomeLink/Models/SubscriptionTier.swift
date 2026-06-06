// SubscriptionTier.swift
// HomeLink › Models

import Foundation

enum SubscriptionTier: String, Codable {
    case free
    case pro
    case institutional   // reserved for School Edition

    var maxPeople: Int {
        switch self {
        case .free:          return 1
        case .pro:           return Int.max
        case .institutional: return Int.max
        }
    }

    var canSendPings: Bool    { self != .free }
    var canUseWidgets: Bool   { self != .free }

    var unlockedSkinIDs: Set<String> {
        switch self {
        case .free:          return ["minimal", "classic", "heart"]
        case .pro:           return Set(CompassSkin.allCases.map(\.rawValue))
        case .institutional: return Set(CompassSkin.allCases.map(\.rawValue))
        }
    }
}
