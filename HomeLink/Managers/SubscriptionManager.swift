// SubscriptionManager.swift
// HomeLink › Managers

import Foundation
import Combine

@MainActor
final class SubscriptionManager: ObservableObject {

    @Published private(set) var tier: SubscriptionTier

    init() {
        let saved = UserDefaults.standard.string(forKey: "subscriptionTier") ?? ""
        tier = SubscriptionTier(rawValue: saved) ?? .free
    }

    func upgrade() async {
        tier = .pro
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
