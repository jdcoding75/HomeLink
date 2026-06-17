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
    /// [1/6] Low-pass-filtered heading — heavy smoothing (0.2 new · 0.8 old)
    /// removes magnetometer jitter so the marker is dead still when the phone
    /// is. Published `currentHeading` only moves when this smoothed value
    /// crosses the 3° gate.
    private var smoothedHeading: Double = 0
    private var targetPerson: Person?
    private var wasLocked = false
    private var lockedSince: Date = .distantFuture        // steady-gaze tracking
    // [9b · B4] lastPointingReport + presenceTimer removed with the mutual-pointing
    // report path (reportPointingIfNeeded / startPresenceTimer).
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
    ///
    /// LOCATION POLICY:
    /// REQUIRES_REAL: false (degrades to a seeded per-person bearing)
    /// FAKE_STRATEGY: seeded from senderID when target/user has no real location
    /// DEGRADES_TO: stable seeded direction; numeric distance hidden (rawBearing nil)
    /// MUTUAL_ONLY: false
    private func seedState(with person: Person) {
        let activeSkin = resolvedSkin(for: person)
        let hasRealLocation = (person.latitude != 0 || person.longitude != 0) && userLocation != nil
        var distance = 0.0
        let bearing: Double
        if hasRealLocation, let userLocation {
            distance = BearingCalculator.distanceKm(from: userLocation.coordinate,
                                                    to: person.coordinate)
            let abs = BearingCalculator.bearing(from: userLocation.coordinate, to: person.coordinate)
            rawBearingToTarget = abs                            // real-location signal
            bearing = (abs - currentHeading + 360).truncatingRemainder(dividingBy: 360)
        } else {
            // SEEDED: stable per-person direction, heading-only (no user fix needed).
            let abs = Self.seededAbsoluteBearing(for: person)
            rawBearingToTarget = nil                            // the "this is seeded" signal
            bearing = (abs - currentHeading + 360).truncatingRemainder(dividingBy: 360)
        }
        wasLocked = false
        state = CompassState(
            bearingDegrees:   bearing,
            faceRotationDegrees: -currentHeading,
            distanceKm:       distance,
            personID:         person.id,
            personName:       person.name,
            personEmoji:      person.emoji,
            tagline:          person.tagline,
            pendingPingEmoji: state.pendingPingEmoji,
            isLocked:         false,
            isFarFromHome:    hasRealLocation && distance > farFromHomeThresholdKm,
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

    // [9b · B4] startPresenceTimer / stopPresenceTimer / reportPointingIfNeeded REMOVED —
    // the whole mutual-pointing report path. The presenceTimer's SOLE job was driving
    // reportPointingIfNeeded → SupabaseService.reportPointing (a no-op), so removing it
    // loses no live behavior. (Heading/lock updates arrive via the location-manager
    // delegate, unaffected.)

    func stop() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }

    #if DEBUG
    // [2/4] Mock heading — slowly rotate the heading so alignment can be tested
    // WITHOUT a real magnetometer (the Simulator). DEBUG only, and a REAL
    // heading reading always disables it (see didUpdateHeading) so a stale
    // toggle can never spin the compass on a real device outdoors.
    private var mockHeadingTimer: Timer?
    func setMockHeading(_ on: Bool) {
        stopMockHeadingTimer()
        guard on else { return }
        isHeadingAvailable = true
        mockHeadingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.currentHeading = (self.currentHeading + 2).truncatingRemainder(dividingBy: 360)
                self.updateCompassState()
            }
        }
    }
    private func stopMockHeadingTimer() {
        mockHeadingTimer?.invalidate()
        mockHeadingTimer = nil
    }
    #endif

    // ── Battery: foreground-only sensors ─────────────────────────────────
    // The magnetometer (heading) and GPS are the compass's biggest battery
    // draw. There is nothing to point at while backgrounded, so we stop both
    // on the way out and resume on return — wired from RootView's scenePhase. [5/8]

    /// App backgrounded — stop heading/location updates and drop to the
    /// coarsest accuracy so any residual system use is cheap.
    func pauseForBackground() {
        guard targetPerson != nil else { return }
        locationManager.stopUpdatingHeading()
        locationManager.stopUpdatingLocation()
        // [9b · B4] stopPresenceTimer() removed (presenceTimer retired with mutual-pointing).
        #if DEBUG
        stopMockHeadingTimer()   // never let a test toggle spin in the background
        #endif
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// App foregrounded — restore full accuracy and resume updates for the
    /// person we were already tracking.
    func resumeFromForeground() {
        guard targetPerson != nil else { return }
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
        updateCompassState()   // correct the face immediately on return
    }

    func setPendingPing(emoji: String?) {
        state = CompassState(
            bearingDegrees:   state.bearingDegrees,
            faceRotationDegrees: state.faceRotationDegrees,
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

    /// ABSOLUTE bearing toward the tracked person (0° = true north) —
    /// the mutual-pointing check compares this against the partner's
    /// reported bearing. nil until a location fix exists.
    @Published private(set) var rawBearingToTarget: Double?

    /// [phase2 build7] A deterministic 0–360° bearing for a contact, derived from
    /// the immutable key. Used as the SEEDED fallback when there's no real
    /// location — same person always appears from the SAME direction (feels
    /// intentional, not broken).
    ///
    /// LOCATION POLICY:
    /// REQUIRES_REAL: false
    /// FAKE_STRATEGY: seeded from senderID (fallback person.id) → 0–360°
    /// DEGRADES_TO: a stable per-person compass direction (same every launch)
    /// MUTUAL_ONLY: false
    ///
    /// FNV-1a over the key's UTF-8 bytes — STABLE across launches/devices. NOT
    /// Swift's `Hashable.hashValue` (per-process randomized → a different
    /// direction every launch).
    static func seededAbsoluteBearing(for person: Person) -> Double {
        let key = (person.senderID?.isEmpty == false) ? person.senderID! : person.id.uuidString
        var hash: UInt64 = 1469598103934665603              // FNV-1a offset basis
        for byte in key.utf8 {
            hash = (hash ^ UInt64(byte)) &* 1099511628211    // FNV-1a prime
        }
        return Double(hash % 360)
    }

    /// LOCATION POLICY:
    /// REQUIRES_REAL: false (degrades to a seeded per-person bearing)
    /// FAKE_STRATEGY: seeded from senderID when target/user has no real location
    /// DEGRADES_TO: stable seeded direction; numeric distance hidden (rawBearing nil)
    /// MUTUAL_ONLY: false (mutual pointing is guarded separately — see reportPointing)
    private func updateCompassState() {
        guard let target = targetPerson else { return }
        // REAL only when the TARGET has a real coordinate AND we have a user fix.
        // Otherwise SEEDED — which needs only `currentHeading` (magnetometer,
        // location-independent), so it must paint even when the USER has no fix.
        let hasRealLocation = (target.latitude != 0 || target.longitude != 0) && userLocation != nil
        let absoluteBearing: Double
        let distance: Double
        if hasRealLocation, let userLocation {
            let userCoord = userLocation.coordinate
            absoluteBearing = BearingCalculator.bearing(from: userCoord, to: target.coordinate)
            rawBearingToTarget = absoluteBearing                 // real-location signal
            distance = BearingCalculator.distanceKm(from: userCoord, to: target.coordinate)
        } else {
            absoluteBearing = Self.seededAbsoluteBearing(for: target)
            rawBearingToTarget = nil                             // the "this is seeded" signal
            distance = 0                                          // no real distance; UI hides it
        }
        let relativeBearing = (absoluteBearing - currentHeading + 360)
            .truncatingRemainder(dividingBy: 360)
        let bearingDiff  = min(relativeBearing, 360 - relativeBearing)
        let isNowLocked  = bearingDiff <= lockThresholdDegrees
        if isNowLocked && !wasLocked {
            HapticEngine.connectionFelt()   // lock haptic — LIVE, kept
            lockedSince = .now
        }
        // [9b · B4] startPresenceTimer/stopPresenceTimer + the reportPointingIfNeeded
        // ambient-presence call removed — the mutual-pointing source (reportPointing) is
        // a no-op, so this only fed dead pointing reports. Lock haptic/state above stay.
        wasLocked = isNowLocked
        let activeSkin = resolvedSkin(for: target)
        state = CompassState(
            bearingDegrees:   relativeBearing,
            faceRotationDegrees: -currentHeading,
            distanceKm:       distance,
            personID:         target.id,
            personName:       target.name,
            personEmoji:      target.emoji,
            tagline:          target.tagline,
            pendingPingEmoji: state.pendingPingEmoji,
            isLocked:         isNowLocked,
            isFarFromHome:    hasRealLocation && distance > farFromHomeThresholdKm,
            activeSkin:       activeSkin
        )
        AppGroupStore.activeBearing    = relativeBearing
        AppGroupStore.activeDistanceKm = hasRealLocation ? distance : 0   // widget: no null-island km for seeded
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
        #if DEBUG
        // A real heading reading is authoritative — it disables any stale
        // mock-heading test toggle so the marker can never spin on its own on
        // a real device. (Mock heading survives only in the Simulator, where
        // these real readings never arrive.)
        stopMockHeadingTimer()
        #endif
        let raw = newHeading.magneticHeading

        // [1/6] LOW-PASS FILTER — fold each raw reading in at 20 %, taking the
        // shortest arc so it wraps cleanly across 0°/360°. This alone kills the
        // magnetometer jitter that made the marker spin/wander while still.
        if !isHeadingAvailable {
            smoothedHeading = raw
        } else {
            var diff = raw - smoothedHeading
            if diff > 180 { diff -= 360 }
            if diff < -180 { diff += 360 }
            smoothedHeading = (smoothedHeading + diff * 0.2)
                .truncatingRemainder(dividingBy: 360)
            if smoothedHeading < 0 { smoothedHeading += 360 }
        }

        // 3° gate on the SMOOTHED heading vs what's published — the marker only
        // moves on a meaningful turn, and is dead still when the phone is.
        let delta = abs(smoothedHeading - currentHeading)
        let wrapped = min(delta, 360 - delta)
        guard wrapped >= 3.0 || !isHeadingAvailable else {
            isHeadingAvailable = true
            return
        }

        currentHeading     = smoothedHeading   // smoothedHeading used everywhere
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
