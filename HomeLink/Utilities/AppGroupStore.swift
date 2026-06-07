// AppGroupStore.swift
// Pointward › Utilities
// App Group: group.com.jdcoding75.pointward

import Foundation
import WidgetKit

struct AppGroupStore {

    static let suiteName = "group.com.jdcoding75.pointward"
    private static let defaults = UserDefaults(suiteName: suiteName)!

    static var activePersonName: String {
        get { defaults.string(forKey: "activePersonName") ?? "" }
        set { defaults.set(newValue, forKey: "activePersonName"); reloadWidgets() }
    }
    static var activePersonEmoji: String {
        get { defaults.string(forKey: "activePersonEmoji") ?? "🏠" }
        set { defaults.set(newValue, forKey: "activePersonEmoji"); reloadWidgets() }
    }
    static var activeTagline: String {
        get { defaults.string(forKey: "activeTagline") ?? TaglineSystem.defaultTagline }
        set { defaults.set(newValue, forKey: "activeTagline"); reloadWidgets() }
    }
    static var activeSkin: String {
        get { defaults.string(forKey: "activeSkin") ?? CompassSkin.vintage.rawValue }
        set { defaults.set(newValue, forKey: "activeSkin"); reloadWidgets() }
    }
    static var activeBearing: Double {
        get { defaults.double(forKey: "activeBearing") }
        set { defaults.set(newValue, forKey: "activeBearing") }
    }
    static var activeDistanceKm: Double {
        get { defaults.double(forKey: "activeDistanceKm") }
        set { defaults.set(newValue, forKey: "activeDistanceKm") }
    }
    static var pendingPingEmoji: String? {
        get { defaults.string(forKey: "pendingPingEmoji") }
        set { defaults.set(newValue, forKey: "pendingPingEmoji"); reloadWidgets() }
    }
    static var pendingPingFromName: String? {
        get { defaults.string(forKey: "pendingPingFromName") }
        set { defaults.set(newValue, forKey: "pendingPingFromName") }
    }
    static var pendingPingTimestamp: Date? {
        get { defaults.object(forKey: "pendingPingTimestamp") as? Date }
        set { defaults.set(newValue, forKey: "pendingPingTimestamp") }
    }
    static func clearPendingPing() {
        defaults.removeObject(forKey: "pendingPingEmoji")
        defaults.removeObject(forKey: "pendingPingFromName")
        defaults.removeObject(forKey: "pendingPingTimestamp")
        reloadWidgets()
    }
    // Debounced: rapid successive property writes (every compass tick sets
    // several keys) collapse into at most one widget reload per 15 seconds.
    private static var lastWidgetReload: Date = .distantPast

    private static func reloadWidgets() {
        guard Date.now.timeIntervalSince(lastWidgetReload) >= 15 else { return }
        lastWidgetReload = .now
        WidgetCenter.shared.reloadAllTimelines()
    }
}
