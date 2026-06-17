// OneShotLocationProvider.swift
// Pointward › Utilities
//
// BUILD 10 — the "Use current location" option in onboarding's Home Location step.
//
// A self-contained ONE-SHOT current-location grab: requests when-in-use permission
// (if needed), returns exactly ONE coordinate via CLLocationManager.requestLocation,
// wrapped in an async call. Deliberately SEPARATE from CompassManager (the live
// heading/location tracker) — this is a transient, single-fix request for onboarding,
// not a continuous stream. The caller reverse-geocodes the coordinate through the
// existing GeocodingService and writes it into the SAME geocoded path a typed address
// uses (so commitProfile sends lat/lng identically).

import CoreLocation

final class OneShotLocationProvider: NSObject, CLLocationManagerDelegate {

    enum LocationError: Error { case denied, failed }

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters   // "home" precision; fast
    }

    /// Request permission (if not yet determined) and resolve ONE coordinate.
    /// Throws `.denied` if the user declines, `.failed` on any location error.
    @MainActor
    func requestOnce() async throws -> CLLocationCoordinate2D {
        if continuation != nil { throw LocationError.failed }   // one in flight at a time
        return try await withCheckedThrowingContinuation { cont in
            continuation = cont
            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()           // → didChangeAuthorization
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()                         // → didUpdateLocations
            default:
                finish(.failure(LocationError.denied))            // already denied/restricted
            }
        }
    }

    private func finish(_ result: Result<CLLocationCoordinate2D, Error>) {
        guard let cont = continuation else { return }
        continuation = nil
        cont.resume(with: result)
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        guard continuation != nil else { return }   // not our pending request
        switch m.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            m.requestLocation()
        case .denied, .restricted:
            finish(.failure(LocationError.denied))
        case .notDetermined:
            break   // still waiting on the prompt
        @unknown default:
            finish(.failure(LocationError.denied))
        }
    }

    func locationManager(_ m: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else {
            finish(.failure(LocationError.failed)); return
        }
        finish(.success(coordinate))
    }

    func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
        finish(.failure(LocationError.failed))
    }
}
