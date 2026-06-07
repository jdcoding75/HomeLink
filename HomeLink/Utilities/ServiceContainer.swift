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
    let networkService:      NetworkServiceProtocol
    let pairingService:      PairingServiceProtocol
    let notificationService: NotificationServiceProtocol
    let geocodingService:    GeocodingServiceProtocol
    let compassManager:      CompassManager
    let peopleManager:       PeopleManager
    let pingManager:         PingManager
    let subscriptionManager: SubscriptionManager
    let notificationHandler: NotificationHandler
    let brandManager:        BrandManager

    init() {
        let schema       = Schema([Person.self, Ping.self])
        modelContainer   = try! ModelContainer(for: schema)
        skinStore        = SkinStore()
        networkService   = MockNetworkService()
        pairingService   = MockPairingService()
        notificationService = LocalNotificationService()
        geocodingService = CLGeocodingService()
        subscriptionManager = SubscriptionManager(skinStore: skinStore)
        compassManager   = CompassManager(skinStore: skinStore)
        peopleManager    = PeopleManager(subscriptionManager: subscriptionManager)
        pingManager      = PingManager(networkService: networkService)
        notificationHandler = NotificationHandler(pingManager: pingManager)
        brandManager     = BrandManager()
    }
}
