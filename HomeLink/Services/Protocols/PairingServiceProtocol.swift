// PairingServiceProtocol.swift
// Pointward › Services › Protocols

protocol PairingServiceProtocol {
    func generatePairingCode() async throws -> String
    func completePairing(code: String) async throws -> PairedUser
}

struct PairedUser {
    let id:          String
    let displayName: String
}
