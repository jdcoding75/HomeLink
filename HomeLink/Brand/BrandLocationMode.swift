// BrandLocationMode.swift
// Pointward › Brand
//
// ─────────────────────────────────────────────────────────────────
// BRAND LOCATION MODE — COMPLETE SCAFFOLD
// ─────────────────────────────────────────────────────────────────
//
// Design principles:
//   1. Completely isolated from personal/emotional mode.
//      BrandManager never touches Person, PeopleManager, or PingManager.
//   2. Static addresses only — no backend required.
//      Brand coordinates stored in local JSON bundled with the app
//      or downloaded once as a "Brand Pack" in-app purchase.
//   3. Nearest location auto-selected using BearingCalculator.
//   4. White-label ready — BrandPack has an `ownerID` field so the
//      same codebase can be shipped as a white-label app for a brand.
//   5. Modular — adding a new Brand Pack = drop a new JSON file in
//      Resources/BrandPacks/ and register it in BrandPackRegistry.
//
// Current status: SCAFFOLD — models, manager, and integration points
// are fully defined. UI views are stubs ready to flesh out.
// BrandPacks are not shown to users until Phase 2 (post-MVP).
//
// ─────────────────────────────────────────────────────────────────

import Foundation
import CoreLocation
import Combine

// MARK: ── MODELS ─────────────────────────────────────────────────

/// A single brand location (one café, one store, one branch).
struct BrandLocation: Codable, Identifiable, Equatable {
    let id:          String          // stable UUID string — must not change between Pack updates
    let name:        String          // "Monmouth Coffee · Borough Market"
    let shortName:   String          // "Monmouth Coffee" — shown on compass face
    let emoji:       String          // displayed as compass center emoji
    let latitude:    Double
    let longitude:   Double
    let address:     String          // human-readable, displayed in detail view
    let url:         String?         // optional deep link (menu, booking, etc.)
    let tags:        [String]        // ["coffee", "café", "specialty"] — for filtering

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// A collection of related brand locations sold as a single IAP.
struct BrandPack: Codable, Identifiable {
    let id:           String         // matches StoreKit product ID suffix, e.g. "monmouth"
    let ownerID:      String         // brand identifier — used for white-label builds
    let displayName:  String         // "Monmouth Coffee"
    let description:  String         // shown in the brand pack store
    let emoji:        String         // pack-level emoji used in listings
    let accentColor:  String         // hex — tints the compass when this pack is active
    let version:      Int            // bump to force a re-parse on update
    let locations:    [BrandLocation]

    /// StoreKit product ID — "com.jdcoding75.pointward.brandpack.monmouth"
    var productID: String { "com.jdcoding75.pointward.brandpack.\(id)" }
}

/// The state of a brand pack from the user's perspective.
enum BrandPackState: Equatable {
    case bundled       // included free (e.g. a sample pack)
    case purchased     // user paid for it
    case locked        // available to buy
    case downloading   // being fetched after purchase
}

// MARK: ── JSON SCHEMA ────────────────────────────────────────────
//
// Brand Pack JSON lives at: Resources/BrandPacks/{packID}.json
//
// Example — Resources/BrandPacks/monmouth.json:
//
// {
//   "id": "monmouth",
//   "ownerID": "monmouth-coffee-ltd",
//   "displayName": "Monmouth Coffee",
//   "description": "Find your nearest Monmouth Coffee — London's finest.",
//   "emoji": "☕",
//   "accentColor": "#8B4513",
//   "version": 1,
//   "locations": [
//     {
//       "id": "monmouth-borough",
//       "name": "Monmouth Coffee · Borough Market",
//       "shortName": "Monmouth Coffee",
//       "emoji": "☕",
//       "latitude": 51.5055,
//       "longitude": -0.0910,
//       "address": "2 Park St, London SE1 9AB",
//       "url": "https://monmouthcoffee.co.uk",
//       "tags": ["coffee", "café", "specialty", "london"]
//     },
//     {
//       "id": "monmouth-covent-garden",
//       "name": "Monmouth Coffee · Covent Garden",
//       "shortName": "Monmouth Coffee",
//       "emoji": "☕",
//       "latitude": 51.5136,
//       "longitude": -0.1245,
//       "address": "27 Monmouth St, London WC2H 9EU",
//       "url": "https://monmouthcoffee.co.uk",
//       "tags": ["coffee", "café", "specialty", "london"]
//     }
//   ]
// }
//
// ─────────────────────────────────────────────────────────────────

// MARK: ── BRAND PACK REGISTRY ────────────────────────────────────

/// Single source of truth for which packs exist and their purchase state.
/// In Phase 2 this integrates with StoreKit — for now it reads bundled JSON only.
final class BrandPackRegistry {

    static let shared = BrandPackRegistry()
    private init() {}

    /// All packs available in the app (bundled + downloaded).
    /// Phase 2: merge with StoreKit product list.
    private(set) var allPacks: [BrandPack] = []

    /// Purchase state per pack ID.
    private var states: [String: BrandPackState] = [:]

    func load() {
        // Load all *.json files from the BrandPacks bundle directory
        guard let urls = Bundle.main.urls(
            forResourcesWithExtension: "json",
            subdirectory: "BrandPacks"
        ) else { return }

        let decoder = JSONDecoder()
        allPacks = urls.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(BrandPack.self, from: data)
        }
        .sorted { $0.displayName < $1.displayName }

        // Mark all bundled packs as .bundled for now
        for pack in allPacks {
            states[pack.id] = .bundled
        }
    }

    func state(for packID: String) -> BrandPackState {
        states[packID] ?? .locked
    }

    func markPurchased(_ packID: String) {
        states[packID] = .purchased
    }

    /// All locations across all accessible packs (bundled + purchased)
    var accessibleLocations: [BrandLocation] {
        allPacks
            .filter { [.bundled, .purchased].contains(states[$0.id] ?? .locked) }
            .flatMap(\.locations)
    }
}

// MARK: ── BRAND MANAGER ──────────────────────────────────────────

/// Manages the active brand mode state.
/// Completely isolated — never references Person, PeopleManager, or PingManager.
@MainActor
final class BrandManager: ObservableObject {

    // MARK: Published state
    @Published var isActive:         Bool = false
    @Published var activePack:       BrandPack? = nil
    @Published var nearestLocation:  BrandLocation? = nil
    @Published var distanceKm:       Double = 0
    @Published var bearingDegrees:   Double = 0

    // MARK: Private
    private let registry = BrandPackRegistry.shared
    private var userLocation: CLLocation?

    // MARK: Lifecycle

    func activate(pack: BrandPack) {
        activePack = pack
        isActive   = true
        updateNearest()
    }

    func deactivate() {
        isActive        = false
        activePack      = nil
        nearestLocation = nil
    }

    // MARK: Location update (called from CompassManager when brand mode is active)

    func updateUserLocation(_ location: CLLocation) {
        userLocation = location
        updateNearest()
    }

    func updateHeading(_ heading: Double) {
        guard let nearest = nearestLocation,
              let userLoc = userLocation else { return }
        let rawBearing = BearingCalculator.bearing(
            from: userLoc.coordinate,
            to:   nearest.coordinate
        )
        bearingDegrees = (rawBearing - heading + 360)
            .truncatingRemainder(dividingBy: 360)
    }

    // MARK: Private

    private func updateNearest() {
        guard let userLoc = userLocation,
              let pack    = activePack else { return }

        let userCoord = userLoc.coordinate
        let sorted    = pack.locations.sorted {
            BearingCalculator.distanceKm(from: userCoord, to: $0.coordinate)
            < BearingCalculator.distanceKm(from: userCoord, to: $1.coordinate)
        }

        guard let nearest = sorted.first else { return }
        nearestLocation = nearest
        distanceKm      = BearingCalculator.distanceKm(from: userCoord, to: nearest.coordinate)
    }
}

// MARK: ── LOCATION MODE ENUM ─────────────────────────────────────

/// The two mutually exclusive modes the compass can operate in.
/// Stored in AppEnvironment and read by CompassManager and CompassView.
enum LocationMode: Equatable {
    case personal   // default — points at a saved Person
    case brand      // brand mode — points at nearest BrandLocation
}

// MARK: ── COMPASS VIEW INTEGRATION NOTES ────────────────────────
//
// When LocationMode == .brand:
//
//   CompassView reads from BrandManager instead of CompassManager:
//     - nearestLocation.emoji        → emoji presence center
//     - nearestLocation.shortName    → person name label
//     - BearingCalculator.formattedDistance(brandManager.distanceKm) → distance
//     - brandManager.bearingDegrees  → needle rotation
//     - activePack.accentColor       → tints breathing ring
//
// When LocationMode == .personal (default):
//   Everything works exactly as before — BrandManager is completely dormant.
//
// Switch between modes:
//   appEnv.locationMode = .brand    // activates brand compass
//   appEnv.locationMode = .personal // restores personal compass
//
// ─────────────────────────────────────────────────────────────────

// MARK: ── STUB VIEW: BRAND MODE SWITCHER ─────────────────────────
// Full UI to be built in Phase 2. Stub is here so the app compiles.

import SwiftUI

struct BrandModeView: View {
    @EnvironmentObject var brandManager: BrandManager

    var body: some View {
        ZStack {
            DesignTokens.Color.background.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("brand locations")
                    .font(DesignTokens.Font.compassName)
                    .foregroundColor(DesignTokens.Color.textPrimary)

                Text("coming in a future update — point your compass toward your favourite places")
                    .font(DesignTokens.Font.compassDistance)
                    .foregroundColor(DesignTokens.Color.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                // Phase 2: BrandPackGrid goes here
            }
        }
    }
}
