// CompassState.swift
// Pointward › Models

import Foundation

struct CompassState: Equatable {

    var bearingDegrees:  Double
    /// REAL-COMPASS BEHAVIOUR: the rose card rotates as the phone turns so
    /// N always points to true north (faceRotationDegrees = -currentHeading),
    /// while the needle keeps pointing at the person. The user turns the
    /// phone until the needle points up — exactly like a real compass.
    var faceRotationDegrees: Double = 0
    var distanceKm:      Double
    var personID:        UUID?
    var personName:      String
    var personEmoji:     String
    /// [item15] The target's contact photo (CNContact.thumbnailImageData), when present —
    /// drives the direction-indicator disc; nil → the initial. Additive, default nil.
    var personPhotoData: Data? = nil
    var tagline:         String?
    var pendingPingEmoji: String?
    var isLocked:        Bool
    var isFarFromHome:   Bool
    var activeSkin:      CompassSkin

    var resolvedTagline: String {
        if let t = tagline, !t.isEmpty { return t }
        return activeSkin.tagline
    }

    var formattedDistance: String {
        BearingCalculator.formattedDistance(distanceKm)
    }

    static let empty = CompassState(
        bearingDegrees:   0,
        distanceKm:       0,
        personID:         nil,
        personName:       "",
        personEmoji:      "🏠",
        tagline:          nil,
        pendingPingEmoji: nil,
        isLocked:         false,
        isFarFromHome:    false,
        activeSkin:       .minimal
    )
}
