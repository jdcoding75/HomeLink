// BearingCalculator.swift
// Pointward › Utilities

import Foundation
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

    /// True when distances should lead with miles.
    /// Settings can override via the "useMiles" key; otherwise follow the locale
    /// (US measurement system → miles first).
    static var prefersMiles: Bool {
        if let override = UserDefaults.standard.object(forKey: "useMiles") as? Bool {
            return override
        }
        return Locale.current.measurementSystem == .us
    }

    /// Dual-unit distance, preferred system first:
    ///   US / miles override → "88 mi · 142 km"
    ///   everywhere else     → "142 km · 88 mi"
    /// Small distances drop to meters (< 1 km) and feet (< 1 mi).
    static func formattedDistance(_ km: Double) -> String {
        let metric   = metricString(km)
        let imperial = imperialString(km)
        return prefersMiles ? "\(imperial) · \(metric)" : "\(metric) · \(imperial)"
    }

    private static func metricString(_ km: Double) -> String {
        km >= 1
            ? "\(Int(km.rounded())) km"
            : "\(Int((km * 1000).rounded())) m"
    }

    private static func imperialString(_ km: Double) -> String {
        let miles = km * 0.621371
        return miles >= 1
            ? "\(Int(miles.rounded())) mi"
            : "\(Int((miles * 5280).rounded())) ft"
    }

    /// The feeling of the distance, not just the number. Shown on CompassView.
    static func emotionalDistance(_ km: Double) -> String {
        switch km {
        case ..<5:    return "just around the corner"
        case ..<50:   return "close enough to visit today"
        case ..<200:  return "a short journey away"
        case ..<500:  return "a few hours apart"
        case ..<1000: return "far enough to miss them"
        default:      return "across the distance"
        }
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
