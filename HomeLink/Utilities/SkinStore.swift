// SkinStore.swift
// Pointward › Utilities

import Foundation
import Combine

@MainActor
final class SkinStore: ObservableObject {

    @Published var activeSkin: CompassSkin {
        didSet {
            UserDefaults.standard.set(activeSkin.rawValue, forKey: "activeSkin")
            AppGroupStore.activeSkin = activeSkin.rawValue
        }
    }

    init() {
        // Vintage Brass is the first impression for every new user.
        let saved = UserDefaults.standard.string(forKey: "activeSkin") ?? ""
        var skin  = CompassSkin(rawValue: saved) ?? .vintage

        // If a locked skin is somehow active on the free tier (e.g. state from
        // an earlier build), fall back to the default rather than show locked content.
        let savedTier = UserDefaults.standard.string(forKey: "subscriptionTier") ?? ""
        let tier = SubscriptionTier(rawValue: savedTier) ?? .free
        if skin.requiresUnlock && tier == .free {
            skin = .vintage
        }
        activeSkin = skin
    }

    func select(_ skin: CompassSkin, subscription: SubscriptionManager) {
        guard !skin.requiresUnlock || subscription.tier != .free else { return }
        activeSkin = skin
        HapticEngine.skinSelected()
    }
}
