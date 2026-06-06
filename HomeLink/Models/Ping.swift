// Ping.swift
// HomeLink › Models

import Foundation
import SwiftData

@Model
final class Ping {
    var id:           UUID
    var fromPersonID: UUID
    var fromName:     String
    var emoji:        String
    var timestamp:    Date
    var wasOpened:    Bool

    init(fromPersonID: UUID, fromName: String, emoji: String) {
        self.id           = UUID()
        self.fromPersonID = fromPersonID
        self.fromName     = fromName
        self.emoji        = emoji
        self.timestamp    = .now
        self.wasOpened    = false
    }
}
