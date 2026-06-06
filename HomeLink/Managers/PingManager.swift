// PingManager.swift
// Pointward › Managers

import Foundation
import Combine

@MainActor
final class PingManager: ObservableObject {

    @Published var pendingPing: ReceivedPing?
    @Published var isSending   = false
    /// "Mum felt your thought ✓" — set when a sent ping gets opened remotely.
    @Published var feltNotice: String?
    /// "Mum is pointing toward you 🧭" — their compass just locked onto us.
    @Published var pointingNotice: String?

    private let networkService: NetworkServiceProtocol

    struct ReceivedPing: Equatable {
        let fromName:  String
        let emoji:     String
        let timestamp: Date
        var remoteID:  UUID? = nil   // Supabase ping id, for read receipts
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

    func showFelt(name: String) {
        feltNotice = "\(name) felt your thought ✓"
        Task {
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            feltNotice = nil
        }
    }

    /// Gentle "they're pointing at you" moment — soft double haptic, 4s toast.
    func showPointing(name: String) {
        guard UserDefaults.standard.object(forKey: "notifyPointing") as? Bool ?? true else { return }
        pointingNotice = "\(name) is pointing toward you"
        HapticEngine.pingReceived()
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            pointingNotice = nil
        }
    }

    func receivePing(fromName: String, emoji: String, remoteID: UUID? = nil) {
        let ping = ReceivedPing(fromName: fromName, emoji: emoji, timestamp: .now, remoteID: remoteID)
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
