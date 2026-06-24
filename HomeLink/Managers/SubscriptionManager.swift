// SubscriptionManager.swift
// Pointward › Managers
//
// REAL StoreKit 2 — the one-time $2.99 non-consumable Pro upgrade
// (PointwardProduct.proUpgrade). Loads the product, runs a purchase, listens
// for transaction updates, and resolves entitlements on launch + on demand.
//
// IMPORTANT compatibility note: `tier` is ALSO mirrored to
// UserDefaults["subscriptionTier"] on every change, because non-view code
// (SenderStyle, HapticEngine, SkinStore) reads the tier straight from there.
// `.pro`'s raw value is "unlocked" (legacy persistence) — keep that in sync.

import Foundation
import Combine
import StoreKit

@MainActor
final class SubscriptionManager: ObservableObject {

    /// The single source of truth. Mirrored to UserDefaults so the whole app's
    /// existing tier reads keep working.
    @Published private(set) var tier: SubscriptionTier = .free {
        didSet {
            UserDefaults.standard.set(tier.rawValue, forKey: "subscriptionTier")
            // Also mirror to the explicit "subscription_tier" key so tier
            // persistence is restorable from either name.
            UserDefaults.standard.set(tier.rawValue, forKey: "subscription_tier")
            if tier == .pro {
                // Pro gating checks BOTH tier and the ProFeatures flag, so a real
                // purchase must enable features too (the DEBUG default did this).
                UserDefaults.standard.set(true, forKey: ProFeatures.storageKey)
            } else {
                skinStore?.enforceTier(.free)
            }
        }
    }

    @Published private(set) var isPurchasing = false
    @Published var purchaseError: String?
    /// The loaded Pro product (nil until `loadProducts` finishes).
    @Published private(set) var proProduct: Product?

    /// Wired by ServiceContainer so downgrades reset the skin immediately.
    private weak var skinStore: SkinStore?
    private var transactionListener: Task<Void, Never>?

    init(skinStore: SkinStore? = nil) {
        self.skinStore = skinStore
        // Seed from the persisted value (in DEBUG a testing default may set this
        // to "unlocked"); StoreKit entitlements then confirm/upgrade below.
        // Restore the persisted tier on launch — from the legacy key first
        // (existing purchasers), falling back to "subscription_tier".
        let saved = UserDefaults.standard.string(forKey: "subscriptionTier")
            ?? UserDefaults.standard.string(forKey: "subscription_tier") ?? ""
        tier = SubscriptionTier(rawValue: saved) ?? .free

        // [ci-test-safe] Skip StoreKit launch work under XCTest — the Transaction.updates/
        // currentEntitlements async streams + the Product.products network call run on every
        // host launch and are unsafe/wasteful in a headless test host (no StoreKit config).
        // The env var is nil in every real launch → production StoreKit is byte-identical.
        // transactionListener stays nil under tests (deinit cancels nil safely — :62).
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            transactionListener = listenForTransactions()
            Task { await loadProducts() }
            Task { await checkEntitlements() }
        }
    }

    deinit { transactionListener?.cancel() }

    // ── Display ──────────────────────────────────────────────────────────

    /// Localized price ("$2.99") once loaded; a friendly fallback otherwise.
    var proPriceText: String { proProduct?.displayPrice ?? "$2.99" }
    var productsLoaded: Bool { proProduct != nil }

    // ── StoreKit ─────────────────────────────────────────────────────────

    func loadProducts() async {
        do {
            let products = try await Product.products(for: PointwardProduct.all)
            proProduct = products.first { $0.id == PointwardProduct.proUpgrade }
        } catch {
            Self.log("loadProducts failed: \(error.localizedDescription)")
        }
    }

    /// Buy the Pro upgrade. On a verified success, unlocks Pro and finishes the
    /// transaction.
    func purchase() async {
        if proProduct == nil { await loadProducts() }      // lazy retry
        guard let product = proProduct else {
            purchaseError = "The store isn't ready yet — try again in a moment."
            return
        }
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                tier = .pro
            case .userCancelled:
                break
            case .pending:
                // Ask-to-buy / SCA — entitlement will arrive via the listener.
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    /// Kept for existing call sites — the paywall "unlock" button calls this.
    func upgrade() async { await purchase() }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await checkEntitlements()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    /// Resolve current entitlements → Pro if the upgrade is owned.
    func checkEntitlements() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == PointwardProduct.proUpgrade,
               transaction.revocationDate == nil {
                tier = .pro
                return
            }
        }
        // No entitlement found. We do NOT auto-downgrade here: a DEBUG testing
        // default (or a just-completed purchase mid-sync) shouldn't be wiped.
        // Refund/restore handling flows through restorePurchases().
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self else { continue }
                if case .verified(let transaction) = result {
                    await self.checkEntitlements()
                    await transaction.finish()
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:         throw StoreError.failedVerification
        case .verified(let safe): return safe
        }
    }

    // ── Local downgrade (dev / sign-out) ─────────────────────────────────

    func resetToFree() {
        tier = .free   // didSet mirrors to UserDefaults + enforces the free skin
    }

    enum StoreError: Error, LocalizedError {
        case failedVerification
        var errorDescription: String? { "Couldn't verify the purchase with the App Store." }
    }

    private static func log(_ message: String) {
        #if DEBUG
        print("[StoreKit] \(message)")
        #endif
    }
}
