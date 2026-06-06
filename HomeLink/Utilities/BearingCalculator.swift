// BearingCalculator.swift
// HomeLink › Utilities

import CoreLocation

enum BearingCalculator {

    static func bearing(from origin: CLLocationCoordinate2D,
                        to target: CLLocationCoordinate2D) -> Double {
        let lat1 = origin.latitude.toRadians
        let lat2 = target.latitude.toRadians
        let dLon = (target.longitude - origin.longitude).toRadians
        let y    = sin(dLon) * cos(lat2)
        let x    = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let raw  = atan2(y, x).toDegrees
        return (raw + 360).truncatingRemainder(dividingBy: 360)
    }

    static func distanceKm(from origin: CLLocationCoordinate2D,
                           to target: CLLocationCoordinate2D) -> Double {
        let R    = 6371.0
        let dLat = (target.latitude  - origin.latitude).toRadians
        let dLon = (target.longitude - origin.longitude).toRadians
        let a    = sin(dLat / 2) * sin(dLat / 2)
                 + cos(origin.latitude.toRadians)
                 * cos(target.latitude.toRadians)
                 * sin(dLon / 2) * sin(dLon / 2)
        return R * 2 * atan2(sqrt(a), sqrt(1 - a))
    }

    static func formattedDistance(_ km: Double) -> String {
        km >= 1
            ? "\(Int(km.rounded())) km"
            : "\(Int((km * 1000).rounded())) m"
    }

    static func formattedDistanceWithBearing(_ km: Double, bearing: Double) -> String {
        "\(formattedDistance(km)) · \(cardinalDirection(bearing))"
    }

    static func cardinalDirection(_ degrees: Double) -> String {
        let cardinals = ["N","NNE","NE","ENE","E","ESE","SE","SSE",
                         "S","SSW","SW","WSW","W","WNW","NW","NNW"]
        let index = Int((degrees / 22.5).rounded()) % 16
        return cardinals[index]
    }
}

private extension Double {
    var toRadians: Double { self * .pi / 180 }
    var toDegrees: Double { self * 180 / .pi }
}
