// MockGeocodingService.swift
// HomeLink › Services › Implementations

import CoreLocation

final class MockGeocodingService: GeocodingServiceProtocol {

    var shouldFail: Bool          = false
    var failureError: GeocodingError = .networkUnavailable
    var simulatedLatencyMs: UInt64   = 400

    private let fixtures: [String: GeocodedLocation] = [
        "london": GeocodedLocation(
            displayName: "London",
            fullAddress: "London, England, United Kingdom",
            coordinate:  CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
            country: "United Kingdom", postalCode: nil
        ),
        "mum": GeocodedLocation(
            displayName: "Mum's House",
            fullAddress: "42 Example Road, Bristol, England, UK",
            coordinate:  CLLocationCoordinate2D(latitude: 51.4545, longitude: -2.5879),
            country: "United Kingdom", postalCode: "BS1 4DJ"
        ),
        "home": GeocodedLocation(
            displayName: "Home",
            fullAddress: "Home, London, UK",
            coordinate:  CLLocationCoordinate2D(latitude: 51.5200, longitude: -0.0950),
            country: "United Kingdom", postalCode: nil
        ),
        "new york": GeocodedLocation(
            displayName: "New York",
            fullAddress: "New York, NY, United States",
            coordinate:  CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
            country: "United States", postalCode: nil
        ),
    ]

    func geocode(address: String) async throws -> GeocodedLocation {
        try await Task.sleep(nanoseconds: simulatedLatencyMs * 1_000_000)
        if shouldFail { throw failureError }
        let key = address.lowercased().trimmingCharacters(in: .whitespaces)
        if let match = fixtures[key] { return match }
        if let match = fixtures.first(where: { key.contains($0.key) })?.value { return match }
        return GeocodedLocation(
            displayName: address, fullAddress: address,
            coordinate:  CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
            country: "United Kingdom", postalCode: nil
        )
    }

    func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> GeocodedLocation {
        try await Task.sleep(nanoseconds: simulatedLatencyMs * 1_000_000)
        if shouldFail { throw failureError }
        return GeocodedLocation(
            displayName: "Mock Location",
            fullAddress: "\(String(format: "%.4f", coordinate.latitude))°, \(String(format: "%.4f", coordinate.longitude))°",
            coordinate:  coordinate,
            country: nil, postalCode: nil
        )
    }
}
