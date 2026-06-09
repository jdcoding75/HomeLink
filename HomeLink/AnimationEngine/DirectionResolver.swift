// DirectionResolver.swift
// Pointward › AnimationEngine
//
// SINGLE SOURCE OF TRUTH for direction.
//
// RULE:
// Unpaired users → symbolic direction
//   (slowly rotates, feels intentional)
// Paired users → real GPS bearing
//
// ALL instruments use this.
// No instrument calculates direction alone.
// Change direction logic here → changes everywhere.

import Foundation
import CoreLocation

struct DirectionResolver {

    // MARK: - Public API

    /// The bearing to use for all animation
    /// direction decisions.
    /// Never call compass heading directly.
    /// Always call this.
    static func bearing(
        person: Person?,
        compassHeading: Double
    ) -> Double {
        guard let person = person else {
            return symbolicBearing()
        }
        if person.pairedUserID != nil {
            // Paired: real GPS direction
            return compassHeading
        } else {
            // Unpaired: symbolic direction
            return symbolicBearing()
        }
    }

    /// Current direction mode for UI display.
    static func mode(for person: Person?) -> DirectionMode {
        guard let person = person else {
            return .symbolic
        }
        return person.pairedUserID != nil
            ? .real
            : .symbolic
    }

    // MARK: - Symbolic Direction

    /// A slowly, smoothly rotating bearing
    /// for unpaired users.
    ///
    /// Rotates at 3 degrees per second.
    /// One full rotation every 2 minutes.
    /// Feels intentional and alive.
    /// Never random. Never stuck.
    /// Like a compass searching for true north.
    static func symbolicBearing() -> Double {
        let interval = Date().timeIntervalSince1970
        return (interval * 3.0)
            .truncatingRemainder(dividingBy: 360)
    }

    /// For demo person Alex — uses a gentle
    /// symbolic bearing that looks like the
    /// compass is alive and searching.
    static var demoBearing: Double {
        symbolicBearing()
    }
}

enum DirectionMode {
    case symbolic   // unpaired — gentle rotation
    case real       // paired — GPS bearing

    var label: String {
        switch self {
        case .symbolic: return "searching ✦"
        case .real:     return "pointing ✦"
        }
    }
}
