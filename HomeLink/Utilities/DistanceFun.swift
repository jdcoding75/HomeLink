// DistanceFun.swift
// Pointward › Utilities
//
// The three-layer distance system: funny units (tap to cycle), light-speed
// time (tap to toggle), and a thought-speed tagline picked randomly once per
// session — pure local randomization, no timers, no network.

import Foundation

enum DistanceFun {

    // MARK: - Line 1: funny units

    static let funnyLabels = [
        "football fields",
        "chocolate bars",
        "double decker buses",
        "pizza boxes",
        "Empire State Buildings",
        "hours by car",
        "hours by plane",
        "leopard geckos",
    ]
    static var funnyCount: Int { funnyLabels.count }

    /// Pro Mode shows just these four — football fields, chocolate
    /// bars, pizza boxes, hours by car.
    static let proUnits = [0, 1, 3, 5]

    static func nextProIndex(after index: Int) -> Int {
        guard let position = proUnits.firstIndex(of: index) else {
            return proUnits[0]
        }
        return proUnits[(position + 1) % proUnits.count]
    }

    /// "1,294 football fields away" · "about 2 hours by car"
    static func funnyText(km: Double, index: Int) -> String {
        let meters = km * 1000
        switch index {
        case 0:  return "\(compact(meters / 109.7)) football fields away"
        case 1:  return "\(compact(meters / 0.1524)) chocolate bars away"
        case 2:  return "\(compact(meters / 11.23)) double decker buses away"
        case 3:  return "\(compact(meters / 0.45)) pizza boxes away"
        case 4:  return "\(compact(meters / 443.2)) Empire State Buildings stacked"
        case 5:  return "about \(hoursText(km / 90)) by car"
        case 6:  return "about \(hoursText(km / 880)) by plane"
        default: return "\(compact(meters / 0.22)) leopard geckos end to end"
        }
    }

    private static func compact(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        }
        if value >= 10_000 {
            return String(format: "%.0fk", value / 1_000)
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value.rounded())) ?? "\(Int(value))"
    }

    private static func hoursText(_ hours: Double) -> String {
        if hours < 1 {
            let minutes = max(1, Int((hours * 60).rounded()))
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        }
        if hours < 10 { return String(format: "%.1f hours", hours) }
        return "\(Int(hours.rounded())) hours"
    }

    // MARK: - Line 2: light speed

    /// "0.5 ms at light speed" — from the real distance.
    static func lightSpeedText(km: Double) -> String {
        let seconds = km / 299_792.458
        if seconds < 0.001 {
            return String(format: "%.0f µs at light speed", seconds * 1_000_000)
        }
        if seconds < 1 {
            return String(format: "%.1f ms at light speed", seconds * 1_000)
        }
        return String(format: "%.2f seconds at light speed", seconds)
    }

    // MARK: - Line 3: thought speed

    static let thoughtTaglines = [
        "no distance exists between two minds",
        "thought speed · the fastest thing there is",
        "felt before it was sent",
        "no delay · thoughts don't travel, they arrive",
        "there before you finished missing them",
        "already there · love travels instantly",
        "closer than the miles suggest",
        "distance is only physical",
        "arrives before you finish thinking it",
        "speed of love · immeasurable",
    ]
}
