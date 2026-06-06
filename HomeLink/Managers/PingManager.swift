// PingManager.swift
// HomeLink › Managers

import Foundation
import Combine

@MainActor
final class PingManager: ObservableObject {

    @Published var pendingPing: ReceivedPing?
    @Published var isSending   = false

    private let networkService: NetworkServiceProtocol

    struct ReceivedPing: Equatable {
        let fromName:  String
        let emoji:     String
        let timestamp: Date
    }

    init(networkService: NetworkServiceProtocol) {
        self.networkService = networkService
    }

    func sendPing(to person: Person, emoji: String) async {
        isSending = true
        defer { isSending = false }
        let pairedID = person.pairedUserID ?? "local-stub"
        try? await networkService.sendPing(toPairedUserID: pairedID, emoji: emoji)
        HapticEngine.pingSent()
    }

    func receivePing(fromName: String, emoji: String) {
        let ping = ReceivedPing(fromName: fromName, emoji: emoji, timestamp: .now)
        pendingPing = ping
        AppGroupStore.pendingPingEmoji     = emoji
        AppGroupStore.pendingPingFromName  = fromName
        AppGroupStore.pendingPingTimestamp = .now
        HapticEngine.pingReceived()
        Task {
            try? await Task.sleep(nanoseconds: 600_000_000_000)
            if pendingPing?.timestamp == ping.timestamp { clearPendingPing() }
        }
    }

    func clearPendingPing() {
        pendingPing = nil
        AppGroupStore.clearPendingPing()
    }
}
