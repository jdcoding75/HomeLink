// SentLink.swift
// Pointward › Models
//
// [phase2 stage A] (S1) The sender's local map: which message went to which local
// contact. `createAndShareLink` discards the message id today; we record it here so
// Stage B/C can join a returned connection (link_connections.via_message_id) back to
// the RIGHT local contact and stamp its senderID — without creating a duplicate.
// LOCAL/per-device (SwiftData, no sync) — same scope as the contacts it maps.

import Foundation
import SwiftData

@Model
final class SentLink {

    /// `messages.id` (the /m/<id> UUID) — the join key to
    /// `link_connections.via_message_id` (Stage B/C).
    var messageID: UUID
    /// The local `Person.id` this send was composed toward (Case 9: always present —
    /// a selected person or the demo).
    var personID:  UUID
    var sentAt:    Date

    init(messageID: UUID, personID: UUID, sentAt: Date = .now) {
        self.messageID = messageID
        self.personID  = personID
        self.sentAt    = sentAt
    }
}
