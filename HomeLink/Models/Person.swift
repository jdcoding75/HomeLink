// Person.swift
// Pointward › Models

import Foundation
import SwiftData
import CoreLocation

@Model
final class Person {

    var id:                  UUID
    var name:                String
    var emoji:               String
    var latitude:            Double
    var longitude:           Double
    var displayAddress:      String
    var locationDisplayName: String
    var isDynamic:           Bool
    var pairedUserID:        String?
    var tagline:             String?
    var skinOverride:        String?
    var createdAt:           Date
    /// [phase2 build5] The immutable LINK-ERA key = Message.senderID = users.id.
    /// Set when a contact is auto-created on RECEIVE (PeopleManager.upsertContact).
    /// This is the real, pairing-free routing/dedup key going forward. Additive
    /// optional → SwiftData lightweight-migrates (no .sql). See `pairedUserID`'s
    /// double-duty note in PeopleManager.upsertContact.
    var senderID:            String?
    /// [phase2 build5] When this contact last SENT us a message — populated now so
    /// Build 6's most-recent People-tab sort has data. Not consumed for display here.
    var lastReceivedAt:      Date?

    init(
        id:                  UUID    = UUID(),
        name:                String,
        emoji:               String  = "🏠",
        latitude:            Double,
        longitude:           Double,
        displayAddress:      String  = "",
        locationDisplayName: String  = "",
        isDynamic:           Bool    = false,
        pairedUserID:        String? = nil,
        tagline:             String? = nil,
        skinOverride:        String? = nil,
        senderID:            String? = nil,
        lastReceivedAt:      Date?   = nil
    ) {
        self.id                  = id
        self.name                = name
        self.emoji               = emoji
        self.latitude            = latitude
        self.longitude           = longitude
        self.displayAddress      = displayAddress
        self.locationDisplayName = locationDisplayName.isEmpty ? name : locationDisplayName
        self.isDynamic           = isDynamic
        self.pairedUserID        = pairedUserID
        self.tagline             = tagline
        self.skinOverride        = skinOverride
        self.createdAt           = .now
        self.senderID            = senderID
        self.lastReceivedAt      = lastReceivedAt
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var resolvedTagline: String {
        if let t = tagline, !t.isEmpty { return t }
        return TaglineSystem.defaultTagline
    }

    convenience init(
        name:     String,
        emoji:    String = "🏠",
        geocoded: GeocodedLocation,
        tagline:  String? = nil
    ) {
        self.init(
            name:                name,
            emoji:               emoji,
            latitude:            geocoded.coordinate.latitude,
            longitude:           geocoded.coordinate.longitude,
            displayAddress:      geocoded.fullAddress,
            locationDisplayName: geocoded.displayName,
            tagline:             tagline
        )
    }
}
