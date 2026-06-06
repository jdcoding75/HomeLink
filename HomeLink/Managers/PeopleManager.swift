// PeopleManager.swift
// HomeLink › Managers

import Foundation
import Combine
import SwiftData

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

    enum PeopleError: Error, LocalizedError {
        case upgradeRequired
        var errorDescription: String? { "Upgrade to HomeLink Pro to add more people." }
    }
}
