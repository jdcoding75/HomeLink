// MockPairingService.swift
// Pointward › Services › Implementations

import Foundation

final class MockPairingService: PairingServiceProtocol {
    func generatePairingCode() async throws -> String {
        try await Task.sleep(nanoseconds: 200_000_000)
        return "LINK-4729"
    }
    func completePairing(code: String) async throws -> PairedUser {
        try await Task.sleep(nanoseconds: 300_000_000)
        return PairedUser(id: "mock-user-001", displayName: "Test Partner")
    }
}
