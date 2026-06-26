// CompassManager.swift
// Pointward › Managers

import Foundation
import CoreLocation
import Combine
#if canImport(CoreMotion)        // [compass-falsefire] device-orientation (gravity) guard
import CoreMotion
#endif

@MainActor
final class CompassManager: NSObject, ObservableObject {

    @Published var state: CompassState = .empty
    @Published var isHeadingAvailable  = false
    #if DEBUG
    /// [restore-tap selftest] When true, updateCompassState forces alignment (relativeBearing=0)
    /// so the live holdTick can reach lock in the Simulator. Driven only by -compassSelfTest.
    var forceAlignedTest = false
    func pokeStateForTest() { isHeadingAvailable = true; updateCompassState() }
    #endif

    private let skinStore: SkinStore
    private let locationManager = CLLocationManager()
    #if canImport(CoreMotion)
    // [compass-falsefire] A phone AIMED at a person is held roughly upright/tilted; a phone
    // set FLAT on a table is NOT — and its magnetometer heading is degenerate there. We read
    // gravity.z to suppress the hold-to-fire while the phone lies flat. See CompassView holdTick.
    private let motion = CMMotionManager()
    #endif
    // [compass-falsefire · COMMIT B] Upright (gravity.z) signal SUPERSEDED by the stillness
    // guard below — orientation blocked normal flat-ish aiming holds. Preserved:
    // /// True while the phone is upright enough to be aiming; FALSE when flat on a surface.
    // @Published private(set) var isDeviceUpright = true
    // /// |gravity.z| below this = upright/aiming; at/above = flat. Device-tunable (~32° from flat).
    // private let uprightZBand: Double = 0.85

    /// [compass-falsefire · stillness] TRUE only when the phone has been essentially MOTIONLESS
    /// (set down) for `stillDwell` — a hand-held aiming hold always has enough micro-tremor to
    /// stay FALSE. The holdTick gates on `!isDeviceStill`. Defaults FALSE so it never blocks
    /// before the first sample / where CoreMotion is absent (default OPEN).
    @Published private(set) var isDeviceStill = false
    /// Device-tunable STARTING values. Both magnitudes must stay below these for `stillDwell`s.
    private let stillAccelThreshold: Double    = 0.02   // g — userAcceleration magnitude (gravity removed)
    private let stillRotationThreshold: Double = 0.05   // rad/s — rotationRate magnitude
    private let stillDwell: TimeInterval       = 0.6    // s sustained below BOTH → still
    /// CMDeviceMotion.timestamp when the current motionless streak began; nil while moving.
    private var stillSince: TimeInterval? = nil
    /// [still-and-flat] TRUE when the phone lies flat on a surface (gravity normal ≈ out of the screen).
    /// The holdTick suppresses the send ONLY when still AND flat (= genuinely set down) — a steady UPRIGHT
    /// aiming hold reads still but NOT flat, so it's no longer blocked. Default FALSE (open) pre-sample /
    /// where CoreMotion is absent.
    @Published private(set) var isDeviceFlat = false
    private let flatZBand: Double = 0.85   // |gravity.z| >= this = flat (the preserved old uprightZBand)
    /// [permission-rework-2026-06] TRUE when location auth is denied/restricted — drives the
    /// compass screen's soft fallback (warm message + Settings deep-link). Set from the
    /// authorization-change delegate. Default FALSE (no nag before a decision).
    @Published private(set) var locationDenied = false
    // Published so list views can show live distances per person
    @Published private(set) var userLocation: CLLocation?
    // [location-restore-2026-06] one-time guard so the first GPS fix writes to the server
    // profile once per session. (Plain `private var`, NOT @State — CompassManager is an
    // ObservableObject class, not a SwiftUI View.)
    private var hasWrittenLocationThisSession = false
    private var currentHeading: Double = 0
    /// [1/6] Low-pass-filtered heading — heavy smoothing (0.2 new · 0.8 old)
    /// removes magnetometer jitter so the marker is dead still when the phone
    /// is. Published `currentHeading` only moves when this smoothed value
    /// crosses the 3° gate.
    private var smoothedHeading: Double = 0
    private var targetPerson: Person?
    private var wasLocked = false
    // [cleanup] lockedSince removed — it became write-only after B4 removed its readers
    // (reportPointingIfNeeded / startPresenceTimer).
    // [9b · B4] lastPointingReport + presenceTimer removed with the mutual-pointing
    // report path (reportPointingIfNeeded / startPresenceTimer).
    private let lockThresholdDegrees: Double  = 5.0
    private let farFromHomeThresholdKm: Double = 500.0

    init(skinStore: SkinStore) {
        self.skinStore = skinStore
        super.init()
        locationManager.delegate        = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        // [perm-defer] Launch-time location request REMOVED so it never fires over the
        // received-thought animation. Location is still requested — just later: in
        // `start(tracking:)` (:48, when the compass actually tracks a person, post-onboarding)
        // and in onboarding `saveAboutYou` (OnboardingView.swift:734, the final tap). Original
        // preserved:
        // locationManager.requestWhenInUseAuthorization()
    }

    func start(tracking person: Person) {
        targetPerson = person
        // Surface the person's identity immediately — name/emoji/tagline must
        // never wait for a GPS fix (which may never arrive in the Simulator).
        seedState(with: person)
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
        startDeviceMotion()   // [compass-falsefire] gravity guard on with heading
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
        stopDeviceMotion()   // [compass-falsefire]
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

    // ── [compass-falsefire] Device-orientation (gravity) updates ──────────
    // Started/stopped on the SAME lifecycle as the magnetometer (start/resume ↔
    // stop/pause) so it carries the same foreground-only battery discipline.
    private func startDeviceMotion() {
        #if canImport(CoreMotion)
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 30.0   // 30 Hz — a cheap orientation gate
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            MainActor.assumeIsolated {                   // .main queue == MainActor (see setMockHeading)
                // [compass-falsefire · stillness] Replaces the gravity.z upright read. A phone set
                // DOWN is essentially motionless; an in-hand aiming hold always carries micro-tremor.
                // Both magnitudes must stay below threshold for `stillDwell`s → isDeviceStill.
                guard let self, let d = data else { return }
                let ua = d.userAcceleration, rr = d.rotationRate
                let accelMag = (ua.x * ua.x + ua.y * ua.y + ua.z * ua.z).squareRoot()
                let rotMag   = (rr.x * rr.x + rr.y * rr.y + rr.z * rr.z).squareRoot()
                if accelMag < self.stillAccelThreshold && rotMag < self.stillRotationThreshold {
                    if self.stillSince == nil { self.stillSince = d.timestamp }
                    if let since = self.stillSince, d.timestamp - since >= self.stillDwell {
                        self.isDeviceStill = true
                    }
                } else {
                    self.stillSince = nil
                    self.isDeviceStill = false
                }
                // [still-and-flat] Flat-on-a-surface signal (gravity normal out of the screen). Combined
                // with isDeviceStill at the holdTick so ONLY a set-down (flat AND motionless) phone is
                // suppressed — a steady upright aim is still but not flat → fires.
                self.isDeviceFlat = abs(d.gravity.z) >= self.flatZBand
                // PRIOR (upright guard): self.isDeviceUpright = abs(g.z) < self.uprightZBand
            }
        }
        #endif
    }
    private func stopDeviceMotion() {
        #if canImport(CoreMotion)
        if motion.isDeviceMotionActive { motion.stopDeviceMotionUpdates() }
        #endif
        // [compass-falsefire · stillness] default NOT-still (OPEN) when not sampling — never block on resume.
        isDeviceStill = false
        isDeviceFlat  = false   // [still-and-flat] default open when not sampling
        stillSince = nil
        // PRIOR: isDeviceUpright = true
    }

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
        stopDeviceMotion()   // [compass-falsefire] gravity guard off with heading
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
        startDeviceMotion()   // [compass-falsefire] gravity guard back on with heading
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

    /// [tagline-rework-2026-06] Seeded fallback bearing toward the CURRENT target — the SAME
    /// FNV-1a value the needle uses when `rawBearingToTarget` is nil (no GPS / seeded). Lets the
    /// compass tagline always show a stable degree. nil only when no target is tracked.
    var seededBearingToTarget: Double? {
        targetPerson.map { Self.seededAbsoluteBearing(for: $0) }
    }

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
        var relativeBearing = (absoluteBearing - currentHeading + 360)
            .truncatingRemainder(dividingBy: 360)
        #if DEBUG
        // [restore-tap selftest] Force perfect alignment so the live holdTick can lock in the
        // Simulator (no magnetometer). Toggled only by the -compassSelfTest harness.
        if forceAlignedTest { relativeBearing = 0 }
        #endif
        let bearingDiff  = min(relativeBearing, 360 - relativeBearing)
        let isNowLocked  = bearingDiff <= lockThresholdDegrees
        if isNowLocked && !wasLocked {
            HapticEngine.connectionFelt()   // lock haptic — LIVE, kept
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
        // [location-restore-2026-06] Write first real GPS fix to server profile — behavior
        // moved here from OnboardingView.commitProfile (removed in d57fb02 location strip).
        // Only fires once per session (guard against repeat writes).
        if !hasWrittenLocationThisSession, let loc = locations.last {
            hasWrittenLocationThisSession = true
            Task {
                await SupabaseService.shared.updateUserProfile(
                    name: UserProfile.snapshot?.displayName ?? "",
                    emoji: UserProfile.snapshot?.emoji ?? "❤️",
                    latitude: loc.coordinate.latitude,
                    longitude: loc.coordinate.longitude
                )
            }
        }
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
            locationDenied = false   // [permission-rework-2026-06]
            // Permission may arrive after start(tracking:) — kick updates off now
            if targetPerson != nil {
                manager.startUpdatingLocation()
                manager.startUpdatingHeading()
            }
        case .denied, .restricted:
            locationDenied = true    // [permission-rework-2026-06] drives the compass soft-fallback overlay
        default:
            break
        }
    }
}
