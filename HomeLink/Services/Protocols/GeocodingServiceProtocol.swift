// GeocodingServiceProtocol.swift
// HomeLink › Services › Protocols

import CoreLocation

struct GeocodedLocation: Equatable {
    let displayName: String
    let fullAddress: String
    let coordinate:  CLLocationCoordinate2D
    let country:     String?
    let postalCode:  String?

    static func == (lhs: GeocodedLocation, rhs: GeocodedLocation) -> Bool {
        lhs.fullAddress == rhs.fullAddress &&
        lhs.coordinate.latitude  == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

enum GeocodingError: LocalizedError {
    case noResults
    case networkUnavailable
    case rateLimited
    case invalidAddress
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .noResults:          return "No location found for that address."
        case .networkUnavailable: return "No internet connection. Connect once to geocode."
        case .rateLimited:        return "Too many requests. Please wait a moment."
        case .invalidAddress:     return "That address doesn't look right."
        case .underlying(let e):  return e.localizedDescription
        }
    }
}

protocol GeocodingServiceProtocol: AnyObject {
    func geocode(address: String) async throws -> GeocodedLocation
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> GeocodedLocation
}
