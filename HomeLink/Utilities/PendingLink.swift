// PendingLink.swift
// Pointward › Utilities
//
// [double-tap fix · Layer 1 holder] A cold-launch-safe rendezvous for an inbound
// pointward.app/m/<id> message id.
//
// WHY: on a COLD launch from a tapped universal link, the inbound NSUserActivity
// can be delivered at the scene-connection boundary BEFORE SwiftUI attaches
// RootView's .onContinueUserActivity — so the first tap's link is dropped and the
// user must tap a SECOND time (warm). See reports/double_tap_link_audit.md.
//
// This holder is written from BOTH boundaries (the UIKit SceneDelegate's
// connectionOptions on cold launch, and SwiftUI's .onContinueUserActivity /
// onOpenURL / short-code / debug funnels) and DRAINED by RootView once its router
// + data layer are ready (presentPendingMessageIfReady). A `static shared` so the
// SceneDelegate (UIKit, created across the scene-connection boundary) and RootView
// (SwiftUI) can rendezvous without dependency injection through that boundary.
//
// It carries ONLY a message id — the existing IncomingMessageView fetch/receipt/
// connection-record/opened-flip logic is untouched; this just guarantees the id
// survives the cold-launch race and is presented when the hierarchy can host it.

import Foundation
import Combine

@MainActor
final class PendingLink: ObservableObject {

    static let shared = PendingLink()

    /// [item16-fix] FIFO QUEUE of inbound /m/<id> ids awaiting presentation. Was a single
    /// slot (last-write-wins) → two quick /m/ links clobbered each other so only one ever
    /// played. Now each DISTINCT id queues; presenting drains FIFO (arrival order).
    /// @Published so RootView re-checks readiness when a SceneDelegate capture lands after
    /// RootView's onAppear has already run.
    // PRIOR (single-slot last-write-wins, preserved):
    // @Published var messageID: UUID?
    @Published var queue: [UUID] = []

    private init() {}

    var isEmpty: Bool { queue.isEmpty }

    /// Record an inbound message id. Appends (FIFO); DEDUPED — the same id is set from BOTH
    /// the SceneDelegate cold-launch boundary AND the SwiftUI funnel for ONE tap, so the
    /// contains-guard prevents the same message presenting twice.
    // PRIOR: func set(_ id: UUID) { messageID = id }   // last-write-wins (deduped by overwrite)
    func set(_ id: UUID) { if !queue.contains(id) { queue.append(id) } }

    /// Pop the OLDEST id — RootView calls this only at the moment it actually presents, so a
    /// not-yet-ready read never loses an id.
    // PRIOR: func take() -> UUID? { defer { messageID = nil }; return messageID }
    func take() -> UUID? {
        guard !queue.isEmpty else { return nil }
        return queue.removeFirst()
    }
}
