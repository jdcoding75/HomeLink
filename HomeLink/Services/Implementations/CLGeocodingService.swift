// CLGeocodingService.swift
// Pointward › Services › Implementations
//
// Geocoding via MapKit (MKGeocodingRequest / MKReverseGeocodingRequest) — the
// iOS 26 replacement for the now-deprecated CLGeocoder + CLPlacemark. The type
// name is kept (the DI container references it) even though it no longer uses
// CLGeocoder. The structured `country` / `postalCode` that CLPlacemark exposed
// are not surfaced by MKMapItem and are unused downstream, so they map to nil.

import MapKit
import CoreLocation

final class CLGeocodingService: GeocodingServiceProtocol {

    func geocode(address: String) async throws -> GeocodedLocation {
        let trimmed = address.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { throw GeocodingError.invalidAddress }
        guard let request = MKGeocodingRequest(addressString: trimmed) else {
            throw GeocodingError.invalidAddress
        }
        let items: [MKMapItem]
        do {
            items = try await request.mapItems
        } catch {
            throw mapped(error)
        }
        guard let best = items.first else { throw GeocodingError.noResults }
        return geocoded(from: best, coordinate: best.location.coordinate)
    }

    func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> GeocodedLocation {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else {
            throw GeocodingError.invalidAddress
        }
        let items: [MKMapItem]
        do {
            items = try await request.mapItems
        } catch {
            throw mapped(error)
        }
        guard let best = items.first else { throw GeocodingError.noResults }
        return geocoded(from: best, coordinate: coordinate)
    }

    // MARK: - MKMapItem → GeocodedLocation

    private func geocoded(from item: MKMapItem,
                          coordinate: CLLocationCoordinate2D) -> GeocodedLocation {
        GeocodedLocation(
            displayName: displayName(from: item),
            fullAddress: fullAddress(from: item),
            coordinate:  coordinate,
            country:     nil,   // not exposed by MKMapItem; unused downstream
            postalCode:  nil
        )
    }

    private func displayName(from item: MKMapItem) -> String {
        if let name = item.name, !name.isEmpty { return name }
        if let short = item.address?.shortAddress, !short.isEmpty { return short }
        if let full = item.address?.fullAddress, !full.isEmpty { return full }
        return "Unknown location"
    }

    private func fullAddress(from item: MKMapItem) -> String {
        if let full = item.address?.fullAddress, !full.isEmpty { return full }
        return item.name ?? ""
    }

    // MARK: - Errors

    private func mapped(_ error: Error) -> GeocodingError {
        // CLError can still surface from the underlying location stack; keep the
        // prior mapping. Everything else falls through to .underlying.
        if let clError = error as? CLError {
            switch clError.code {
            case .network:                                          return .networkUnavailable
            case .geocodeFoundNoResult, .geocodeFoundPartialResult: return .noResults
            case .geocodeCanceled:                                  return .invalidAddress
            default:                                                return .underlying(error)
            }
        }
        return .underlying(error)
    }
}
