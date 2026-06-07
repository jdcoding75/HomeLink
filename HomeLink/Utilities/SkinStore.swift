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
        // Vintage Brass is the first impression for Pro users.
        let saved = UserDefaults.standard.string(forKey: "activeSkin") ?? ""
        var skin  = CompassSkin(rawValue: saved) ?? .vintage

        // Hard guard — free users always get Minimal, regardless of anything
        // previously persisted (e.g. state from an earlier build). Runs at
        // every app launch, before the first frame renders.
        let savedTier = UserDefaults.standard.string(forKey: "subscriptionTier") ?? ""
        let tier = SubscriptionTier(rawValue: savedTier) ?? .free
        if tier == .free && skin != .minimal {
            skin = .minimal
        }
        activeSkin = skin
    }

    /// HARD GUARD: free users can never display a Pro skin, regardless of
    /// anything previously persisted. Called at launch.
    func enforceTier(_ tier: SubscriptionTier) {
        if tier == .free && activeSkin != .minimal {
            activeSkin = .minimal
        }
    }

    func select(_ skin: CompassSkin, subscription: SubscriptionManager) {
        guard !skin.requiresUnlock || subscription.tier != .free else { return }
        activeSkin = skin
        HapticEngine.skinSelected()
    }
}
