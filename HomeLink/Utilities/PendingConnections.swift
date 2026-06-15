// PendingConnections.swift
// Pointward › Utilities
//
// [phase2 stage B] (S2) The receiver's local queue of opened `/m/` message ids whose
// connection couldn't be written yet — because the open happened while signed OUT (the
// common fresh-install path: the /m/ cover shows over onboarding, before Sign in with
// Apple). Drained after sign-in (+ a launch backstop) via
// SupabaseService.drainPendingConnections(). Pure UserDefaults — no SwiftData.

import Foundation

enum PendingConnections {

    private static let key = "pendingConnections"

    /// The queued message ids, in insertion order.
    static var all: [UUID] {
        (UserDefaults.standard.array(forKey: key) as? [String])?.compactMap(UUID.init) ?? []
    }

    /// Queue an opened message id (idempotent — never duplicates).
    static func append(_ id: UUID) {
        var ids = all
        guard !ids.contains(id) else { return }
        ids.append(id)
        save(ids)
    }

    /// Drop one once its connection is written.
    static func remove(_ id: UUID) {
        save(all.filter { $0 != id })
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    private static func save(_ ids: [UUID]) {
        UserDefaults.standard.set(ids.map(\.uuidString), forKey: key)
    }
}
