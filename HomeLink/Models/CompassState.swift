// CompassState.swift
// Pointward › Models

import Foundation

struct CompassState: Equatable {

    var bearingDegrees:  Double
    /// Rotation of the whole rose: -heading, so N stays at true North.
    var faceRotationDegrees: Double = 0
    var distanceKm:      Double
    var personID:        UUID?
    var personName:      String
    var personEmoji:     String
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
