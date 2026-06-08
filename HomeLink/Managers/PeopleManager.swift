// PeopleManager.swift
// Pointward › Managers

import Foundation
import Combine
import SwiftData
import CoreLocation

@MainActor
final class PeopleManager: ObservableObject {

    @Published var people:         [Person] = []
    @Published var selectedPerson: Person?

    private let subscriptionManager: SubscriptionManager
    private var modelContext: ModelContext?

    init(subscriptionManager: SubscriptionManager) {
        self.subscriptionManager = subscriptionManager
    }

    func configure(with context: ModelContext) {
        self.modelContext = context
        fetchAll()
    }

    func fetchAll() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<Person>(sortBy: [SortDescriptor(\.createdAt)])
        people = (try? context.fetch(descriptor)) ?? []
        if selectedPerson == nil { selectedPerson = people.first }
    }

    func canAddPerson() -> Bool {
        people.count < subscriptionManager.tier.maxPeople
    }

    func addPerson(_ person: Person) throws {
        guard canAddPerson() else { throw PeopleError.upgradeRequired }
        modelContext?.insert(person)
        try modelContext?.save()
        fetchAll()
    }

    func save() throws {
        try modelContext?.save()
        fetchAll()
    }

    func deletePerson(_ person: Person) throws {
        modelContext?.delete(person)
        try modelContext?.save()
        fetchAll()
        if selectedPerson?.id == person.id { selectedPerson = people.first }
    }

    func select(_ person: Person) {
        selectedPerson = person
    }

    /// Resolve an incoming connection's friend id to the local person card it's
    /// linked to — `nil` when no card is linked yet. That nil is the gate for
    /// "a thought arrived but needs setup": a ping from an unlinked sender must
    /// not pop catch mode until the user links them to a person.
    func person(forPairedUserID friendID: UUID) -> Person? {
        people.first { $0.pairedUserID == friendID.uuidString }
    }

    /// Make sure some local person carries the connected friend's Supabase id —
    /// per-person status, pointing reports, and ping naming all key off it.
    /// When the connection knows which card it belongs to (owner_person_id),
    /// binds that exact person; otherwise falls back to selected/first.
    func bindConnection(friendID: UUID, toPersonID personID: UUID? = nil) {
        guard !people.contains(where: { $0.pairedUserID == friendID.uuidString }) else { return }
        let target = personID.flatMap { id in people.first(where: { $0.id == id }) }
                     ?? selectedPerson ?? people.first
        guard let target else { return }
        target.pairedUserID = friendID.uuidString
        try? save()
    }

    /// Insert a fully-built person coming from an accepted invite —
    /// connection-initiated, so it bypasses the free-tier person gate.
    func insertFromInvite(_ person: Person) {
        modelContext?.insert(person)
        try? modelContext?.save()
        fetchAll()
        if selectedPerson == nil { selectedPerson = person }
    }

    /// Accepting an invite auto-adds the person it came labeled as.
    /// Connection-initiated, so it bypasses the free-tier person gate.
    /// Location starts at the recipient's own position (distance ~0) until
    /// they edit the person and set a real address.
    @discardableResult
    func addFromInvite(name: String, emoji: String, friendID: UUID,
                       near coordinate: CLLocationCoordinate2D?) -> Person? {
        if let existing = people.first(where: { $0.pairedUserID == friendID.uuidString }) {
            return existing
        }
        let person = Person(
            name: name,
            emoji: emoji,
            latitude: coordinate?.latitude ?? 0,
            longitude: coordinate?.longitude ?? 0,
            displayAddress: "",
            locationDisplayName: name
        )
        person.pairedUserID = friendID.uuidString
        modelContext?.insert(person)
        try? modelContext?.save()
        fetchAll()
        if selectedPerson == nil { selectedPerson = person }
        return person
    }

    enum PeopleError: Error, LocalizedError {
        case upgradeRequired
        var errorDescription: String? { "Unlock Pointward to add more people — one-time purchase, no subscription." }
    }
}
