// AddressAutocompleteService.swift
// Pointward › Services › Implementations
//
// Live address autocomplete backed by MKLocalSearchCompleter — the same engine
// Apple Maps uses for search-as-you-type suggestions. The completer debounces
// and rate-limits internally, so it's safe to feed it every keystroke (unlike
// CLGeocoder, which only handles one request at a time).
//
// Flow: feed text via updateQuery(_:) → observe `suggestions` → when the user
// taps one, resolve(_:) turns it into the app's standard GeocodedLocation via
// a single MKLocalSearch request.

import Foundation
import Combine
import MapKit

/// One row in the autocomplete dropdown.
struct AddressSuggestion: Identifiable, Equatable {
    let id = UUID()
    let title: String       // e.g. "10 Downing Street"
    let subtitle: String    // e.g. "Westminster, London, England"
    fileprivate let completion: MKLocalSearchCompletion

    /// Single-line form used to fill the text field after selection.
    var fullText: String {
        subtitle.isEmpty ? title : "\(title), \(subtitle)"
    }

    static func == (lhs: AddressSuggestion, rhs: AddressSuggestion) -> Bool {
        lhs.id == rhs.id
    }
}

final class AddressAutocompleteService: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {

    @Published private(set) var suggestions: [AddressSuggestion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    /// Feed the current text-field contents. Safe to call on every keystroke.
    func updateQuery(_ fragment: String) {
        let trimmed = fragment.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 else {
            clear()
            return
        }
        completer.queryFragment = trimmed
    }

    func clear() {
        completer.cancel()
        suggestions = []
    }

    /// Resolve a tapped suggestion to a concrete coordinate + address.
    func resolve(_ suggestion: AddressSuggestion) async throws -> GeocodedLocation {
        let request = MKLocalSearch.Request(completion: suggestion.completion)
        let response: MKLocalSearch.Response
        do {
            response = try await MKLocalSearch(request: request).start()
        } catch let error as MKError where error.code == .loadingThrottled {
            throw GeocodingError.rateLimited
        } catch let error as MKError where error.code == .placemarkNotFound {
            throw GeocodingError.noResults
        } catch {
            throw GeocodingError.underlying(error)
        }
        guard let item = response.mapItems.first else {
            throw GeocodingError.noResults
        }
        let placemark = item.placemark
        return GeocodedLocation(
            displayName: item.name ?? suggestion.title,
            fullAddress: placemark.title ?? suggestion.fullText,
            coordinate:  placemark.coordinate,
            country:     placemark.country,
            postalCode:  placemark.postalCode
        )
    }

    // MARK: - MKLocalSearchCompleterDelegate
    // Callbacks arrive on the main thread (completer is created there).

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = completer.results.map {
            AddressSuggestion(title: $0.title, subtitle: $0.subtitle, completion: $0)
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        suggestions = []
    }
}
