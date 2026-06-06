// CompassManager.swift
// HomeLink › Managers

import Foundation
import CoreLocation
import Combine

@MainActor
final class CompassManager: NSObject, ObservableObject {

    @Published var state: CompassState = .empty
    @Published var isHeadingAvailable  = false

    private let skinStore: SkinStore
    private let locationManager = CLLocationManager()
    private var userLocation: CLLocation?
    private var currentHeading: Double = 0
    private var targetPerson: Person?
    private var wasLocked = false
    private let lockThresholdDegrees: Double  = 5.0
    private let farFromHomeThresholdKm: Double = 500.0

    init(skinStore: SkinStore) {
        self.skinStore = skinStore
        super.init()
        locationManager.delegate        = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func start(tracking person: Person) {
        targetPerson = person
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }

    func stop() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }

    func setPendingPing(emoji: String?) {
        state = CompassState(
            bearingDegrees:   state.bearingDegrees,
            distanceKm:       state.distanceKm,
            personID:         state.personID,
            personName:       state.personName,
            personEmoji:      state.personEmoji,
            tagline:          state.tagline,
            pendingPingEmoji: emoji,
            isLocked:         state.isLocked,
            isFarFromHome:    state.isFarFromHome,
            activeSkin:       state.activeSkin
        )
    }

    private func updateCompassState() {
        guard let userLocation, let target = targetPerson else { return }
        let userCoord   = userLocation.coordinate
        let targetCoord = target.coordinate
        let rawBearing  = BearingCalculator.bearing(from: userCoord, to: targetCoord)
        let distance    = BearingCalculator.distanceKm(from: userCoord, to: targetCoord)
        let relativeBearing = (rawBearing - currentHeading + 360)
            .truncatingRemainder(dividingBy: 360)
        let bearingDiff  = min(relativeBearing, 360 - relativeBearing)
        let isNowLocked  = bearingDiff <= lockThresholdDegrees
        if isNowLocked && !wasLocked { HapticEngine.connectionFelt() }
        wasLocked = isNowLocked
        let activeSkin: CompassSkin
        if let override = target.skinOverride, let skin = CompassSkin(rawValue: override) {
            activeSkin = skin
        } else {
            activeSkin = skinStore.activeSkin
        }
        state = CompassState(
            bearingDegrees:   relativeBearing,
            distanceKm:       distance,
            personID:         target.id,
            personName:       target.name,
            personEmoji:      target.emoji,
            tagline:          target.tagline,
            pendingPingEmoji: state.pendingPingEmoji,
            isLocked:         isNowLocked,
            isFarFromHome:    distance > farFromHomeThresholdKm,
            activeSkin:       activeSkin
        )
        AppGroupStore.activeBearing    = relativeBearing
        AppGroupStore.activeDistanceKm = distance
        AppGroupStore.activePersonName = target.name
        AppGroupStore.activePersonEmoji = target.emoji
        AppGroupStore.activeTagline    = target.resolvedTagline
        AppGroupStore.activeSkin       = activeSkin.rawValue
    }
}

extension CompassManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.last
        updateCompassState()
    }
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        currentHeading    = newHeading.magneticHeading
        isHeadingAvailable = true
        updateCompassState()
    }
    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool { true }
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .notDetermined { manager.requestWhenInUseAuthorization() }
    }
}
