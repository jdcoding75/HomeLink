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
        // Vintage Brass is everyone's first impression — the unified
        // picker made all three compass variants free.
        let saved = UserDefaults.standard.string(forKey: "activeSkin") ?? ""
        var skin  = CompassSkin(rawValue: saved) ?? .vintage

        // Hard guard — free users never display a LOCKED skin, regardless
        // of anything previously persisted. (Minimal, Vintage Brass, and
        // Heart are all free now; only exotic skins stay gated.)
        let savedTier = UserDefaults.standard.string(forKey: "subscriptionTier") ?? ""
        let tier = SubscriptionTier(rawValue: savedTier) ?? .free
        if tier == .free && skin.requiresUnlock {
            skin = .vintage
        }
        activeSkin = skin
    }

    /// HARD GUARD: free users can never display a locked skin, regardless
    /// of anything previously persisted. Called at launch.
    func enforceTier(_ tier: SubscriptionTier) {
        if tier == .free && activeSkin.requiresUnlock {
            activeSkin = .vintage
        }
    }

    func select(_ skin: CompassSkin, subscription: SubscriptionManager) {
        guard !skin.requiresUnlock || subscription.tier != .free else { return }
        activeSkin = skin
        HapticEngine.skinSelected()
    }
}
