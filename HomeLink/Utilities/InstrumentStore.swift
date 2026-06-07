// InstrumentStore.swift
// Pointward › Utilities
//
// Which instrument the user holds. Same pattern as SkinStore: persisted,
// published, hard-guarded so free users always hold the compass.

import Foundation
import Combine

@MainActor
final class InstrumentStore: ObservableObject {

    static let storageKey = "selectedInstrument"

    @Published var selected: Instrument {
        didSet {
            UserDefaults.standard.set(selected.rawValue, forKey: Self.storageKey)
        }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.storageKey) ?? ""
        var instrument = Instrument(rawValue: saved) ?? .compass

        // Hard guard at launch — free users always hold the compass,
        // regardless of anything previously persisted.
        let savedTier = UserDefaults.standard.string(forKey: "subscriptionTier") ?? ""
        let tier = SubscriptionTier(rawValue: savedTier) ?? .free
        if tier == .free && instrument != .compass {
            instrument = .compass
        }
        selected = instrument
    }

    /// Runtime guard (downgrades, restore failures).
    func enforceTier(_ tier: SubscriptionTier) {
        if tier == .free && selected != .compass {
            selected = .compass
        }
    }
}
