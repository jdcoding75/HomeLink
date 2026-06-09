// Products.swift
// Pointward › Models
//
// StoreKit 2 product identifiers. The Pro upgrade is a single one-time
// non-consumable ($2.99) — configured in App Store Connect with this exact id.

import Foundation

enum PointwardProduct {
    /// Non-Consumable · $2.99 · "Pointward Pro" in App Store Connect.
    static let proUpgrade = "com.jdcoding75.pointward.pro"

    static let all = [proUpgrade]
}
