// ServiceContainer.swift
// Pointward › Utilities
// Bundle ID: com.jdcoding75.pointward

import Foundation
import Combine
import SwiftData

@MainActor
final class ServiceContainer: ObservableObject {

    let modelContainer:      ModelContainer
    let skinStore:           SkinStore
    let instrumentStore:     InstrumentStore
    let networkService:      NetworkServiceProtocol
    // [9b · B2] pairingService (PairingServiceProtocol/MockPairingService) removed —
    // never read; the pairing-invite DI plumbing is retired.
    let notificationService: NotificationServiceProtocol
    let geocodingService:    GeocodingServiceProtocol
    let compassManager:      CompassManager
    let peopleManager:       PeopleManager
    let pingManager:         PingManager
    let subscriptionManager: SubscriptionManager
    let notificationHandler: NotificationHandler
    let brandManager:        BrandManager
    let appStateManager:     AppStateManager

    init() {
        let schema       = Schema([Person.self, Ping.self, UserProfile.self, SentLink.self])
        modelContainer   = try! ModelContainer(for: schema)
        skinStore        = SkinStore()
        instrumentStore  = InstrumentStore()
        networkService   = MockNetworkService()
        notificationService = LocalNotificationService()
        geocodingService = CLGeocodingService()
        subscriptionManager = SubscriptionManager(skinStore: skinStore)
        appStateManager  = AppStateManager()
        compassManager   = CompassManager(skinStore: skinStore)
        peopleManager    = PeopleManager(subscriptionManager: subscriptionManager)
        pingManager      = PingManager(networkService: networkService,
                                       appState: appStateManager)
        notificationHandler = NotificationHandler(pingManager: pingManager)
        brandManager     = BrandManager()
    }
}
