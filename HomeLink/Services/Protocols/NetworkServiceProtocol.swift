// NetworkServiceProtocol.swift
// HomeLink › Services › Protocols

protocol NetworkServiceProtocol {
    func sendPing(toPairedUserID: String, emoji: String) async throws
    func registerPushToken(_ token: String) async throws
}
