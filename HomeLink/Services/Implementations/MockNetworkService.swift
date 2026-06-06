// MockNetworkService.swift
// Pointward › Services › Implementations

import Foundation

final class MockNetworkService: NetworkServiceProtocol {
    func sendPing(toPairedUserID: String, emoji: String) async throws {
        print("[MockNetworkService] sendPing → \(emoji) to \(toPairedUserID)")
        try await Task.sleep(nanoseconds: 300_000_000)
    }
    func registerPushToken(_ token: String) async throws {
        print("[MockNetworkService] registerPushToken → \(token)")
    }
}
