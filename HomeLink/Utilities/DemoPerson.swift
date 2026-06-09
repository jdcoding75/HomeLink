// DemoPerson.swift
// Pointward › Utilities
//
// [5/6] ALEX — the friendly demo person. When a brand-new user has no one to
// point toward yet, Alex makes the compass feel alive from the very first
// launch: a real card, a real direction (San Francisco), a warm tagline.
//
// Alex is created automatically when SwiftData has zero people, carries NO
// pairedUserID (so nothing actually travels), wears a subtle "demo" badge on
// the compass, and steps aside the moment the user adds someone real.
//
// Identity is keyed off a stable sentinel UUID so the card is recognisable
// across launches WITHOUT adding a stored flag to the Person SwiftData model.

import Foundation
import CoreLocation

enum DemoPerson {

    /// Stable sentinel id — lets us recognise the demo card everywhere
    /// (badge, hint, "is this real data?") without a schema migration.
    static let id = UUID(uuidString: "A1EC0DE0-0000-4000-8000-000000000001")!
    static let name     = "Alex"
    static let emoji    = "🌟"
    static let tagline  = "near is a feeling ✦"
    /// San Francisco.
    static let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

    /// True when this card is the auto-created demo person (Alex).
    static func isDemo(_ person: Person) -> Bool { person.id == id }

    /// A fresh Alex card. No pairedUserID — sending is a no-op preview.
    static func make() -> Person {
        Person(
            id:                  id,
            name:                name,
            emoji:               emoji,
            latitude:            coordinate.latitude,
            longitude:           coordinate.longitude,
            displayAddress:      "San Francisco, CA",
            locationDisplayName: "San Francisco",
            pairedUserID:        nil,
            tagline:             tagline)
    }
}
