// UserProfile.swift
// Pointward › Models
//
// YOUR profile — who YOU are on Pointward. Created during onboarding (the
// "about you" screen) and shared with people when they connect with you:
// your name, your emoji, where you are, and your connection code. The single
// source of identity that travels with every invite you create.
//
// Stored in SwiftData (one row) and mirrored to UserDefaults so non-SwiftData
// code (SupabaseService building invites) can read the snapshot cheaply.

import Foundation
import SwiftData
import CoreLocation

@Model
final class UserProfile {

    var displayName:         String
    var emoji:               String
    var latitude:            Double
    var longitude:           Double
    var displayAddress:      String
    var locationDisplayName: String
    var code:                String      // POINT-XXXX, auto-generated
    var createdAt:           Date

    init(
        displayName:         String,
        emoji:               String = "🧭",
        latitude:            Double = 0,
        longitude:           Double = 0,
        displayAddress:      String = "",
        locationDisplayName: String = "",
        code:                String = ""
    ) {
        self.displayName         = displayName
        self.emoji               = emoji
        self.latitude            = latitude
        self.longitude           = longitude
        self.displayAddress      = displayAddress
        self.locationDisplayName = locationDisplayName
        self.code                = code
        self.createdAt           = .now
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// True once a real location has been set (not the 0,0 placeholder).
    var hasLocation: Bool { latitude != 0 || longitude != 0 }
}

// MARK: - UserDefaults snapshot (for non-SwiftData callers)

extension UserProfile {

    struct Snapshot {
        var displayName: String
        var emoji: String
        var latitude: Double
        var longitude: Double
        var displayAddress: String
        var locationDisplayName: String
        var code: String
        var hasLocation: Bool { latitude != 0 || longitude != 0 }
    }

    private enum Keys {
        static let name    = "profileDisplayName"
        static let emoji   = "profileEmoji"
        static let lat     = "profileLatitude"
        static let lng     = "profileLongitude"
        static let address = "profileDisplayAddress"
        static let locName = "profileLocationName"
        static let code    = "profileCode"
    }

    /// Mirror the live profile to UserDefaults so SupabaseService can read it.
    static func cache(_ s: Snapshot) {
        let d = UserDefaults.standard
        d.set(s.displayName,         forKey: Keys.name)
        d.set(s.emoji,               forKey: Keys.emoji)
        d.set(s.latitude,            forKey: Keys.lat)
        d.set(s.longitude,           forKey: Keys.lng)
        d.set(s.displayAddress,      forKey: Keys.address)
        d.set(s.locationDisplayName, forKey: Keys.locName)
        d.set(s.code,                forKey: Keys.code)
    }

    /// The cached snapshot, or nil if no profile has been created yet.
    static var snapshot: Snapshot? {
        let d = UserDefaults.standard
        guard let name = d.string(forKey: Keys.name), !name.isEmpty else { return nil }
        return Snapshot(
            displayName:         name,
            emoji:               d.string(forKey: Keys.emoji) ?? "🧭",
            latitude:            d.double(forKey: Keys.lat),
            longitude:           d.double(forKey: Keys.lng),
            displayAddress:      d.string(forKey: Keys.address) ?? "",
            locationDisplayName: d.string(forKey: Keys.locName) ?? "",
            code:                d.string(forKey: Keys.code) ?? "")
    }
}
