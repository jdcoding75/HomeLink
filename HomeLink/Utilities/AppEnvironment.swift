// AppEnvironment.swift
// Pointward › Utilities

import Foundation
import Combine

@MainActor
final class AppEnvironment: ObservableObject {
    let geocodingService: GeocodingServiceProtocol

    init(geocodingService: GeocodingServiceProtocol) {
        self.geocodingService = geocodingService
    }
}
