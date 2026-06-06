// CLGeocodingService.swift
// Pointward › Services › Implementations

import CoreLocation

final class CLGeocodingService: GeocodingServiceProtocol {

    private let geocoder = CLGeocoder()

    func geocode(address: String) async throws -> GeocodedLocation {
        guard !address.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw GeocodingError.invalidAddress
        }
        let placemarks: [CLPlacemark]
        do {
            placemarks = try await geocoder.geocodeAddressString(address)
        } catch let error as CLError {
            throw mapped(error)
        } catch {
            throw GeocodingError.underlying(error)
        }
        guard let best = placemarks.first, let location = best.location else {
            throw GeocodingError.noResults
        }
        return GeocodedLocation(
            displayName: displayName(from: best),
            fullAddress: fullAddress(from: best),
            coordinate:  location.coordinate,
            country:     best.country,
            postalCode:  best.postalCode
        )
    }

    func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> GeocodedLocation {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let placemarks: [CLPlacemark]
        do {
            placemarks = try await geocoder.reverseGeocodeLocation(location)
        } catch let error as CLError {
            throw mapped(error)
        } catch {
            throw GeocodingError.underlying(error)
        }
        guard let best = placemarks.first else { throw GeocodingError.noResults }
        return GeocodedLocation(
            displayName: displayName(from: best),
            fullAddress: fullAddress(from: best),
            coordinate:  coordinate,
            country:     best.country,
            postalCode:  best.postalCode
        )
    }

    private func displayName(from p: CLPlacemark) -> String {
        if let name = p.name, !name.isEmpty { return name }
        if let t = p.thoroughfare { return t }
        return p.locality ?? p.country ?? "Unknown location"
    }

    private func fullAddress(from p: CLPlacemark) -> String {
        var parts: [String] = []
        if let n = p.name               { parts.append(n) }
        if let l = p.locality           { parts.append(l) }
        if let a = p.administrativeArea { parts.append(a) }
        if let c = p.country            { parts.append(c) }
        return parts.joined(separator: ", ")
    }

    private func mapped(_ error: CLError) -> GeocodingError {
        switch error.code {
        case .network:                                   return .networkUnavailable
        case .geocodeFoundNoResult, .geocodeFoundPartialResult: return .noResults
        case .geocodeCanceled:                           return .invalidAddress
        default:                                         return .underlying(error)
        }
    }
}
