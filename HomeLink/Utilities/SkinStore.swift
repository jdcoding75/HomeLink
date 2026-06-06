// SkinStore.swift
// HomeLink › Utilities

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
        let saved  = UserDefaults.standard.string(forKey: "activeSkin") ?? ""
        activeSkin = CompassSkin(rawValue: saved) ?? .minimal
    }

    func select(_ skin: CompassSkin, subscription: SubscriptionManager) {
        guard !skin.requiresPro || subscription.tier == .pro else { return }
        activeSkin = skin
        HapticEngine.skinSelected()
    }
}
