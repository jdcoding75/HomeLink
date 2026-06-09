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
    /// YOUR profile — created in onboarding, shared when people connect with you.
    @Published var profile:        UserProfile?

    private let subscriptionManager: SubscriptionManager
    private var modelContext: ModelContext?

    init(subscriptionManager: SubscriptionManager) {
        self.subscriptionManager = subscriptionManager
    }

    func configure(with context: ModelContext) {
        self.modelContext = context
        fetchAll()
        loadProfile()
    }

    func fetchAll() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<Person>(sortBy: [SortDescriptor(\.createdAt)])
        people = (try? context.fetch(descriptor)) ?? []
        if selectedPerson == nil { selectedPerson = people.first }
    }

    // MARK: - Self profile

    /// Load the single UserProfile row (and mirror it to the UserDefaults
    /// snapshot so SupabaseService can read it without SwiftData).
    func loadProfile() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<UserProfile>(sortBy: [SortDescriptor(\.createdAt)])
        profile = (try? context.fetch(descriptor))?.first
        if let profile { cacheProfile(profile) }
    }

    /// Create or update YOUR profile. Location is only replaced when a geocoded
    /// result is provided (so a name/emoji-only edit keeps the stored place).
    @discardableResult
    func saveProfile(name: String, emoji: String,
                     geocoded: GeocodedLocation? = nil,
                     code: String? = nil) -> UserProfile {
        let p = profile ?? UserProfile(displayName: name)
        p.displayName = name
        p.emoji       = emoji
        if let geocoded {
            p.latitude            = geocoded.coordinate.latitude
            p.longitude           = geocoded.coordinate.longitude
            p.displayAddress      = geocoded.fullAddress
            p.locationDisplayName = geocoded.displayName
        }
        if let code { p.code = code }
        if profile == nil {
            modelContext?.insert(p)
            profile = p
        }
        try? modelContext?.save()
        cacheProfile(p)
        return p
    }

    /// Persist the freshly-minted connection code onto the profile.
    func setProfileCode(_ code: String) {
        guard let profile else { return }
        profile.code = code
        try? modelContext?.save()
        cacheProfile(profile)
    }

    private func cacheProfile(_ p: UserProfile) {
        UserProfile.cache(.init(displayName: p.displayName, emoji: p.emoji,
                                latitude: p.latitude, longitude: p.longitude,
                                displayAddress: p.displayAddress,
                                locationDisplayName: p.locationDisplayName,
                                code: p.code))
    }

    func canAddPerson() -> Bool {
        // [5/6] The demo person (Alex) is a placeholder, not a real card —
        // it must never count against the free-tier limit, or a free user
        // could never add their first real person.
        let realCount = people.filter { !DemoPerson.isDemo($0) }.count
        return realCount < subscriptionManager.tier.maxPeople
    }

    func addPerson(_ person: Person) throws {
        guard canAddPerson() else { throw PeopleError.upgradeRequired }
        // [1/4] Every new person starts with a tagline (their voice that
        // then travels with each thought) unless one was set explicitly.
        if person.tagline == nil { person.tagline = TaglineSystem.random }
        modelContext?.insert(person)
        try modelContext?.save()
        fetchAll()
        // [5/6] A real person has arrived — Alex steps aside.
        removeDemoPersonIfPresent()
    }

    // ── [5/6] Demo person (Alex) lifecycle ───────────────────────────────

    /// The auto-created demo card (Alex), if it's present.
    var demoPerson: Person? { people.first(where: DemoPerson.isDemo) }

    /// True when the ONLY card is the demo person — drives the compass "demo"
    /// badge and the one-time "replace with someone real" hint.
    var hasOnlyDemoPerson: Bool {
        people.count == 1 && DemoPerson.isDemo(people[0])
    }

    /// Create the friendly demo person (Alex) when there's no one to point
    /// toward yet, so the compass feels alive from first launch. Idempotent —
    /// no-op when any person already exists. [5/6]
    func ensureDemoPersonIfNeeded() {
        guard modelContext != nil, people.isEmpty else { return }
        let alex = DemoPerson.make()
        modelContext?.insert(alex)
        try? modelContext?.save()
        fetchAll()
        selectedPerson = alex
    }

    /// Remove the demo person (Alex) once a real card exists — Alex is a
    /// placeholder, never real data. Safe to call anytime. [5/6]
    func removeDemoPersonIfPresent() {
        guard let alex = demoPerson, people.count > 1 else { return }
        try? deletePerson(alex)
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
        if person.tagline == nil { person.tagline = TaglineSystem.random }
        modelContext?.insert(person)
        try? modelContext?.save()
        fetchAll()
        if selectedPerson == nil || selectedPerson.map(DemoPerson.isDemo) == true {
            selectedPerson = person
        }
        removeDemoPersonIfPresent()   // [5/6] real connection → Alex steps aside
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
        person.tagline = TaglineSystem.random
        modelContext?.insert(person)
        try? modelContext?.save()
        fetchAll()
        if selectedPerson == nil || selectedPerson.map(DemoPerson.isDemo) == true {
            selectedPerson = person
        }
        removeDemoPersonIfPresent()   // [5/6] real connection → Alex steps aside
        return person
    }

    enum PeopleError: Error, LocalizedError {
        case upgradeRequired
        var errorDescription: String? { "Unlock Pointward to add more people — one-time purchase, no subscription." }
    }
}
