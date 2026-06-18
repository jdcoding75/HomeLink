// CLGeocodingService.swift
// Pointward › Services › Implementations
//
// Geocoding via MapKit's MKGeocodingRequest / MKReverseGeocodingRequest on iOS 26+
// (the modern replacement for CLGeocoder + CLPlacemark), with a CLGeocoder FALLBACK
// for iOS < 26 — an `#available` split so the app can ship a lower deployment floor.
// [build10] Both paths return the SAME GeocodedLocation shape; callers are unchanged.
// The MKMapItem (26+) path leaves country/postalCode nil (not surfaced by MKMapItem);
// the CLGeocoder fallback fills them from CLPlacemark (richer, harmless — unused downstream).

import MapKit
import CoreLocation

final class CLGeocodingService: GeocodingServiceProtocol {

    func geocode(address: String) async throws -> GeocodedLocation {
        let trimmed = address.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { throw GeocodingError.invalidAddress }

        if #available(iOS 26.0, *) {
            // iOS 26+ : MKGeocodingRequest (the modern MapKit API)
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
        } else {
            // iOS < 26 fallback : CLGeocoder (available since iOS 5; async since 15)
            let placemarks: [CLPlacemark]
            do {
                placemarks = try await CLGeocoder().geocodeAddressString(trimmed)
            } catch {
                throw mapped(error)
            }
            guard let best = placemarks.first,
                  let coordinate = best.location?.coordinate else {
                throw GeocodingError.noResults
            }
            return geocoded(from: best, coordinate: coordinate)
        }
    }

    func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> GeocodedLocation {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        if #available(iOS 26.0, *) {
            // iOS 26+ : MKReverseGeocodingRequest (the modern MapKit API)
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
        } else {
            // iOS < 26 fallback : CLGeocoder reverse (async since iOS 15)
            let placemarks: [CLPlacemark]
            do {
                placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            } catch {
                throw mapped(error)
            }
            guard let best = placemarks.first else { throw GeocodingError.noResults }
            return geocoded(from: best, coordinate: coordinate)
        }
    }

    // MARK: - MKMapItem → GeocodedLocation  (iOS 26+; MKMapItem.address is 26-only)

    @available(iOS 26.0, *)
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

    @available(iOS 26.0, *)
    private func displayName(from item: MKMapItem) -> String {
        if let name = item.name, !name.isEmpty { return name }
        if let short = item.address?.shortAddress, !short.isEmpty { return short }
        if let full = item.address?.fullAddress, !full.isEmpty { return full }
        return "Unknown location"
    }

    @available(iOS 26.0, *)
    private func fullAddress(from item: MKMapItem) -> String {
        if let full = item.address?.fullAddress, !full.isEmpty { return full }
        return item.name ?? ""
    }

    // MARK: - CLPlacemark → GeocodedLocation (pre-iOS-26 fallback)

    private func geocoded(from placemark: CLPlacemark,
                          coordinate: CLLocationCoordinate2D) -> GeocodedLocation {
        GeocodedLocation(
            displayName: displayName(from: placemark),
            fullAddress: fullAddress(from: placemark),
            coordinate:  coordinate,
            country:     placemark.country,      // CLPlacemark exposes these (richer than MKMapItem)
            postalCode:  placemark.postalCode
        )
    }

    private func displayName(from placemark: CLPlacemark) -> String {
        if let name = placemark.name, !name.isEmpty { return name }
        if let city = placemark.locality, !city.isEmpty { return city }
        return "Unknown location"
    }

    private func fullAddress(from placemark: CLPlacemark) -> String {
        var parts: [String] = []
        let street = [placemark.subThoroughfare, placemark.thoroughfare]
            .compactMap { $0 }.joined(separator: " ")
        if !street.isEmpty { parts.append(street) }
        if let city = placemark.locality, !city.isEmpty { parts.append(city) }
        let region = [placemark.administrativeArea, placemark.postalCode]
            .compactMap { $0 }.joined(separator: " ")
        if !region.isEmpty { parts.append(region) }
        if let country = placemark.country, !country.isEmpty { parts.append(country) }
        let joined = parts.joined(separator: ", ")
        return joined.isEmpty ? (placemark.name ?? "") : joined
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
