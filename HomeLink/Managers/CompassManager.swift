// CompassManager.swift
// Pointward › Managers

import Foundation
import CoreLocation
import Combine

@MainActor
final class CompassManager: NSObject, ObservableObject {

    @Published var state: CompassState = .empty
    @Published var isHeadingAvailable  = false

    private let skinStore: SkinStore
    private let locationManager = CLLocationManager()
    // Published so list views can show live distances per person
    @Published private(set) var userLocation: CLLocation?
    private var currentHeading: Double = 0
    private var targetPerson: Person?
    private var wasLocked = false
    private var lockedSince: Date = .distantFuture        // steady-gaze tracking
    private var lastPointingReport: Date = .distantPast   // throttle bearing writes
    // AUTO-PUSH FIX: the 1° heading throttle stops updateCompassState from
    // firing while the phone is held perfectly still — exactly the steady
    // gaze the presence signal needs. This timer re-checks every 2 s while
    // locked, independent of heading events.
    private var presenceTimer: Timer?
    private let lockThresholdDegrees: Double  = 5.0
    private let farFromHomeThresholdKm: Double = 500.0

    init(skinStore: SkinStore) {
        self.skinStore = skinStore
        super.init()
        locationManager.delegate        = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        // Ask immediately — before any startUpdatingLocation() call — so the
        // system popup appears as soon as the app needs location.
        locationManager.requestWhenInUseAuthorization()
    }

    func start(tracking person: Person) {
        targetPerson = person
        // Surface the person's identity immediately — name/emoji/tagline must
        // never wait for a GPS fix (which may never arrive in the Simulator).
        seedState(with: person)
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
        // If we already have a location from earlier, refresh bearing/distance now
        updateCompassState()
    }

    /// Publish person identity right away, using the best-known location if any.
    private func seedState(with person: Person) {
        let activeSkin = resolvedSkin(for: person)
        var distance = 0.0
        var bearing  = 0.0
        if let userLocation {
            distance = BearingCalculator.distanceKm(from: userLocation.coordinate,
                                                    to: person.coordinate)
            bearing  = (BearingCalculator.bearing(from: userLocation.coordinate,
                                                  to: person.coordinate)
                        - currentHeading + 360).truncatingRemainder(dividingBy: 360)
        }
        wasLocked = false
        state = CompassState(
            bearingDegrees:   bearing,
            distanceKm:       distance,
            personID:         person.id,
            personName:       person.name,
            personEmoji:      person.emoji,
            tagline:          person.tagline,
            pendingPingEmoji: state.pendingPingEmoji,
            isLocked:         false,
            isFarFromHome:    userLocation != nil && distance > farFromHomeThresholdKm,
            activeSkin:       activeSkin
        )
        AppGroupStore.activePersonName  = person.name
        AppGroupStore.activePersonEmoji = person.emoji
        AppGroupStore.activeTagline     = person.resolvedTagline
        AppGroupStore.activeSkin        = activeSkin.rawValue
    }

    private func resolvedSkin(for person: Person) -> CompassSkin {
        if let override = person.skinOverride, let skin = CompassSkin(rawValue: override) {
            return skin
        }
        return skinStore.activeSkin
    }

    /// Re-evaluates the steady-lock condition every 2 s while locked —
    /// heading events alone stop arriving when the phone is held still.
    private func startPresenceTimer() {
        stopPresenceTimer()
        presenceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                guard self.wasLocked,
                      let target = self.targetPerson,
                      let userLocation = self.userLocation else { return }
                if Date.now.timeIntervalSince(self.lockedSince) >= 10 {
                    let bearing = BearingCalculator.bearing(from: userLocation.coordinate,
                                                            to: target.coordinate)
                    self.reportPointingIfNeeded(target: target, bearing: bearing)
                }
            }
        }
    }

    private func stopPresenceTimer() {
        presenceTimer?.invalidate()
        presenceTimer = nil
    }

    /// Steady-lock only, paired-person only, at most once per FIVE minutes —
    /// the silent presence signal behind the partner's edge glow.
    private func reportPointingIfNeeded(target: Person, bearing: Double) {
        guard let friend = SupabaseService.connectedFriendID,
              target.pairedUserID == friend.uuidString,
              Date.now.timeIntervalSince(lastPointingReport) > 300
        else { return }
        lastPointingReport = .now
        Task { await SupabaseService.shared.reportPointing(bearing: bearing) }
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
        if isNowLocked && !wasLocked {
            HapticEngine.connectionFelt()
            lockedSince = .now
            startPresenceTimer()      // steady-gaze checks survive a still phone
        }
        if !isNowLocked && wasLocked {
            stopPresenceTimer()
        }
        // Ambient presence: only after the needle has RESTED on them for
        // 10+ seconds — a held gaze, not a glance. Throttled to 5 minutes.
        if isNowLocked, Date.now.timeIntervalSince(lockedSince) >= 10 {
            reportPointingIfNeeded(target: target, bearing: rawBearing)
        }
        wasLocked = isNowLocked
        let activeSkin = resolvedSkin(for: target)
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
        // Throttle: ignore sub-degree magnetometer jitter — this gates both
        // the math and the SwiftUI redraws to meaningful changes only.
        let heading = newHeading.magneticHeading
        let delta = abs(heading - currentHeading)
        let wrapped = min(delta, 360 - delta)
        guard wrapped >= 1.0 || !isHeadingAvailable else { return }

        currentHeading     = heading
        isHeadingAvailable = true
        updateCompassState()
    }
    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool { true }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            // Permission may arrive after start(tracking:) — kick updates off now
            if targetPerson != nil {
                manager.startUpdatingLocation()
                manager.startUpdatingHeading()
            }
        default:
            break
        }
    }
}
