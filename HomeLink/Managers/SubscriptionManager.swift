// SubscriptionManager.swift
// Pointward › Managers

import Foundation
import Combine

@MainActor
final class SubscriptionManager: ObservableObject {

    @Published private(set) var tier: SubscriptionTier

    init() {
        // Free to download — the $1.99 one-time unlock persists across launches.
        let saved = UserDefaults.standard.string(forKey: "subscriptionTier") ?? ""
        tier = SubscriptionTier(rawValue: saved) ?? .free
    }

    /// One-time $1.99 unlock. Phase 1 simulates the purchase locally;
    /// StoreKit wiring lands with App Store setup.
    func upgrade() async {
        tier = .unlocked
        UserDefaults.standard.set(tier.rawValue, forKey: "subscriptionTier")
    }

    func restorePurchases() async {
        // Phase 2: StoreKit Transaction.currentEntitlements
    }

    func resetToFree() {
        tier = .free
        UserDefaults.standard.set(tier.rawValue, forKey: "subscriptionTier")
    }
}
