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
    /// [phase2 stage C] Local `Person.id`s who have OPENED (in full) a thought I sent
    /// them — drives the "opened ✦" read-receipt on the People list / card. Re-derived
    /// from the poll each launch / foreground (no model field; resets + refills).
    @Published private(set) var contactsWithOpenedReceipt: Set<UUID> = []

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
        // [phase2 build6] RECENCY SORT — most-recent SENDER first. Fetch unsorted,
        // then sort in Swift: SwiftData SortDescriptor places `nil` on an optional
        // Date? unreliably, and we need an explicit nils-last rule.
        //   primary:   lastReceivedAt DESCENDING, nils LAST (link contacts on top)
        //   secondary: createdAt DESCENDING (the nil group stays newest-first)
        // people.first therefore becomes the most-recent sender (approved launch
        // default) — and stays well-defined for an all-nil list (fresh user /
        // Alex-only): it falls through to createdAt-desc, never empty/crashing.
        let all = (try? context.fetch(FetchDescriptor<Person>())) ?? []
        people = all.sorted { a, b in
            switch (a.lastReceivedAt, b.lastReceivedAt) {
            case let (l?, r?): if l != r { return l > r }   // both have a value
            case (.some, nil): return true                  // a recent, b never → a first
            case (nil, .some): return false                 // b recent → b first
            case (nil, nil):   break                         // both never → secondary
            }
            return a.createdAt > b.createdAt                 // secondary: newest created first
        }
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
                                code: p.code,
                                shortCode: p.shortCode))   // [fix] was omitted → mirror blanked shortCode to "" on every cache
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

    // [9b · B3] pairing-era funcs DELETED — person(forPairedUserID:), bindConnection,
    // insertFromInvite, addFromInvite (all app-callers were #if-false/B1-deleted; only
    // PairingScenarioTests used them, retired this batch). The link-era replacement is
    // person(forSenderID:) + upsertContact below.

    // ── [phase2 build5] Contact auto-create ON RECEIVE (pairing-FREE) ─────

    /// Resolve a link-era contact by its immutable senderID (= Message.senderID).
    /// The Phase-2 dedup key — replaces the pairing-era `person(forPairedUserID:)`.
    func person(forSenderID senderID: String) -> Person? {
        people.first { $0.senderID == senderID }
    }

    /// Silently create-or-update the contact for a received message's SENDER,
    /// keyed on the immutable senderID. Called from the receive hooks
    /// (IncomingMessageView / ShortCodeEntryView) — NEVER from the send flow,
    /// which has no recipient identity (see reports/build5_audit.md).
    ///
    /// Dedup: many messages from ONE sender (e.g. a short-code claim of N) collapse
    /// to exactly ONE contact — found → update, not found → one create.
    ///
    /// Silent (no prompt) and gate-free (a received message is connection-initiated,
    /// like the invite paths) — TRUTH product principles #1/#6.
    @discardableResult
    func upsertContact(senderID: String, displayName: String?) -> Person? {
        guard modelContext != nil, !senderID.isEmpty else { return nil }
        let incoming = (displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        if let existing = person(forSenderID: senderID) {
            // UPDATE — bump recency. The recipient OWNS their local name (TRUTH:
            // "recipient can edit locally — their copy only"). We therefore only
            // FILL a name we never had; any non-empty local name is treated as the
            // user's and is NEVER overwritten by a later auto-update.
            existing.lastReceivedAt = .now
            if existing.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !incoming.isEmpty {
                existing.name = incoming
            }
            try? save()
            return existing
        }

        // CREATE. No emoji — auto-created contacts have NO emoji (the contact-level
        // default emoji was removed as overcomplexity; how an emoji-less contact
        // renders is a Build 6 concern, not handled here).
        let person = Person(
            name:                incoming,
            emoji:               "",          // intentionally NO emoji
            latitude:            0,
            longitude:           0,
            locationDisplayName: incoming,
            // MIRROR-WRITE BRIDGE: today's per-person history bucket fetches by
            // `pairedUserID` (CompassView.loadCompassThoughts). Duplicating senderID
            // into pairedUserID keeps auto-created contacts visible in the CURRENT
            // bucket until Build 9 unifies it.
            // ⚠️ [build9 FLAG] pairedUserID is doing DOUBLE DUTY here — it mirrors
            // senderID, it is NOT a pairing connection. When Build 9 retires the
            // pairing data layer it MUST keep `senderID` (the real key) and only
            // drop the pairedUserID mirror — never discard senderID data.
            pairedUserID:        senderID,
            tagline:             TaglineSystem.random,
            senderID:            senderID,
            lastReceivedAt:      .now)
        modelContext?.insert(person)
        try? modelContext?.save()
        fetchAll()
        // First real contact for a fresh user → make them active (and Alex steps
        // aside), mirroring the invite paths so the history bucket has a subject.
        if selectedPerson == nil || selectedPerson.map(DemoPerson.isDemo) == true {
            selectedPerson = person
        }
        removeDemoPersonIfPresent()
        return person
    }

    /// [build10 shot2] FILL-VIA-LINK: stamp a known location onto the auto-created
    /// SENDER contact so the compose-back compass can aim at the REAL sender (instead
    /// of the seeded bearing). Coordinates come from `users[sender_id]` (read via
    /// SupabaseService.fetchPublicProfile) — present only when that user set a Home
    /// Location. No-op when the contact is missing or the coords are absent/zero
    /// (the caller leaves the seeded bearing). Returns the updated contact.
    @discardableResult
    func applySenderLocation(senderID: String, latitude: Double?, longitude: Double?) -> Person? {
        guard let lat = latitude, let lng = longitude, !(lat == 0 && lng == 0) else { return nil }
        guard let person = person(forSenderID: senderID) else { return nil }
        person.latitude  = lat
        person.longitude = lng
        try? save()
        return person
    }

    /// [phase2 stage A] (S1) Record that a sent link's message went to a local
    /// contact — `messageID → personID`. Stage B/C reads this to map a returned
    /// connection back to the right contact and stamp its `senderID` (no duplicate).
    /// Idempotent on `messageID` (a re-fired send / retry won't double-insert).
    func recordSentLink(messageID: UUID, personID: UUID) {
        guard let context = modelContext else { return }
        let existing = try? context.fetch(
            FetchDescriptor<SentLink>(predicate: #Predicate { $0.messageID == messageID }))
        guard (existing ?? []).isEmpty else { return }
        context.insert(SentLink(messageID: messageID, personID: personID))
        try? context.save()
    }

    /// [phase2 stage B] Stamp local contacts with the receiver's `senderID` once they
    /// connect. For each connection row `(connectedUserID = Y, viaMessageID = X)`: map
    /// X → the local contact via the (S1) `SentLink`, then set `senderID = Y` (+
    /// `pairedUserID = Y` mirror, so PATH-1's direct channel works). Idempotent (skips
    /// already-stamped); skips a row whose `via` is nil or whose `SentLink` is missing
    /// (e.g. sent from another device). Enables Stage-C PATH 1 (not built here).
    func stampConnections(_ rows: [SupabaseService.LinkConnection]) {
        guard let context = modelContext else { return }
        var didChange = false
        for row in rows {
            guard let via = row.viaMessageID else {
                continue   // no join key (deleted message → via set null) — skip
            }
            guard let link = try? context.fetch(
                FetchDescriptor<SentLink>(predicate: #Predicate { $0.messageID == via })).first
            else {
                continue   // no SentLink (sent from another device / pruned) — skip
            }
            guard let person = people.first(where: { $0.id == link.personID }) else { continue }
            guard (person.senderID ?? "").isEmpty else { continue }   // already stamped
            let y = row.connectedUserID.uuidString
            person.senderID    = y
            person.pairedUserID = y                                    // mirror → PATH-1 channel
            didChange = true
        }
        if didChange { try? context.save(); fetchAll() }
    }

    /// [phase2 stage C] Map the ids of my OPENED sent messages → the contacts I sent
    /// them to (via the S1 `SentLink`), and publish the set for the "opened ✦"
    /// read-receipt indicator. Re-derived wholesale each poll (idempotent).
    func refreshReadReceipts(openedMessageIDs: [UUID]) {
        guard let context = modelContext else { return }
        var ids = Set<UUID>()
        for mid in openedMessageIDs {
            if let link = try? context.fetch(
                FetchDescriptor<SentLink>(predicate: #Predicate { $0.messageID == mid })).first {
                ids.insert(link.personID)
            }
        }
        if ids != contactsWithOpenedReceipt { contactsWithOpenedReceipt = ids }
    }

    enum PeopleError: Error, LocalizedError {
        case upgradeRequired
        var errorDescription: String? { "Unlock Pointward to add more people — one-time purchase, no subscription." }
    }
}
