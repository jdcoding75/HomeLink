// PeopleManager.swift
// Pointward › Managers

import Foundation
import Combine
import SwiftData
import CoreLocation

// [conn-di-seam] The server calls PeopleManager makes for the connection cluster
// (the 256e854 fallback's profile resolve + P2's delete-disconnect). Default =
// SupabaseService.shared (production); tests inject a mock. Reversible.
protocol ConnectionService {
    func fetchPublicProfile(of user: UUID) async -> SupabaseService.PublicProfile?
    func deleteConnection(other: UUID) async -> Bool
}
extension SupabaseService: ConnectionService {}

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
    private let connectionService: ConnectionService   // [conn-di-seam]
    private var modelContext: ModelContext?

    init(subscriptionManager: SubscriptionManager,
         connectionService: ConnectionService = SupabaseService.shared) {   // [conn-di-seam] defaults → prod
        self.subscriptionManager = subscriptionManager
        self.connectionService = connectionService
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
        // [keep-demo] Demo Dan is now a PERMANENT try-out sandbox — he is NOT auto-removed
        // when a real person is added. The user deletes him manually from the People tab,
        // like any contact. PRIOR auto-removal (retired, preserved):
        // // [5/6] A real person has arrived — Alex steps aside.
        // removeDemoPersonIfPresent()
    }

    // ── [5/6] Demo person (Alex) lifecycle ───────────────────────────────

    /// The auto-created demo card (Alex), if it's present.
    var demoPerson: Person? { people.first(where: DemoPerson.isDemo) }

    /// True when the ONLY card is the demo person — drives the compass "demo"
    /// badge and the one-time "replace with someone real" hint.
    var hasOnlyDemoPerson: Bool {
        people.count == 1 && DemoPerson.isDemo(people[0])
    }

    // [demo-seed-once] Persisted "Demo Dan was seeded once on this install" flag — replaces the old
    // `people.isEmpty` guard so the seed (a) fires on BOTH paths even when pairing/link-arrival already
    // made a real contact, and (b) NEVER re-seeds after the user deletes him.
    private static let demoSeededKey = "hasSeededDemoDan"

    /// [demo-seed-once · migration (b)] One-time at the first launch of this version: an EXISTING install
    /// (already onboarded, or already has contacts) gets `hasSeededDemoDan` pre-set so a prior DELETER is
    /// not re-served Demo Dan on upgrade. A FRESH install (not onboarded AND no people, checked BEFORE this
    /// session's onboarding completes) leaves the flag false → `ensureDemoPersonIfNeeded` seeds normally.
    /// Runs exactly once (own `didMigrateDemoSeedFlag` marker).
    func migrateDemoSeedFlagIfNeeded(onboarded: Bool) {
        let migratedKey = "didMigrateDemoSeedFlag"
        guard !UserDefaults.standard.bool(forKey: migratedKey) else { return }
        UserDefaults.standard.set(true, forKey: migratedKey)
        if onboarded || !people.isEmpty {
            UserDefaults.standard.set(true, forKey: Self.demoSeededKey)
        }
    }

    /// Create the friendly demo person (Alex) ONCE per fresh install — on BOTH paths (direct + link-
    /// arrival), gated on a persisted flag, never re-seeding after the user deletes him. [demo-seed-once]
    func ensureDemoPersonIfNeeded() {
        guard modelContext != nil else { return }
        // [demo-seed-once] Seed EXACTLY ONCE per install (persisted) — regardless of whether a real
        // contact already exists; never re-seeds after a delete. (Was `guard people.isEmpty`.)
        guard !UserDefaults.standard.bool(forKey: Self.demoSeededKey) else { return }
        // Duplicate guard: a prior version may already have him (Person.id is NOT @unique → a 2nd insert
        // would DUPLICATE Demo Dan). If he's already present, just record the flag and stop.
        if demoPerson != nil { UserDefaults.standard.set(true, forKey: Self.demoSeededKey); return }
        let alex = DemoPerson.make()
        modelContext?.insert(alex)
        try? modelContext?.save()
        UserDefaults.standard.set(true, forKey: Self.demoSeededKey)   // durable — survives a later delete
        fetchAll()
        // [demo-seed-once] Don't steal an existing selection (e.g. the link-arrival inviter) — only
        // default-select Demo Dan when nothing else is selected (direct install, the sole contact).
        if selectedPerson == nil { selectedPerson = alex }
    }

    /// Remove the demo person once a real card exists. [keep-demo] RETIRED as an
    /// AUTOMATIC step — Demo Dan now persists as a permanent try-out sandbox, so both
    /// callers (addPerson / upsertContact) were commented out. Kept (uncalled) for
    /// restore + possible manual use; deleting Demo Dan is done from the People tab.
    func removeDemoPersonIfPresent() {
        guard let alex = demoPerson, people.count > 1 else { return }
        // [p2-delete-disconnect] deletePerson is now async; demo has no real server row
        // (mock id → 0-row delete), so fire-and-forget the local delete.
        Task { try? await deletePerson(alex) }
    }

    func save() throws {
        try modelContext?.save()
        fetchAll()
    }

    // [p2-delete-disconnect] A CONNECTED contact (senderID set) → clear MY server
    // link_connections row FIRST, so the 256e854 sync fallback can't re-surface the
    // deleted contact. If the server disconnect FAILS (offline / RLS), do NOT
    // local-delete (the row would survive and re-create the contact next sync) — throw
    // instead. A manual contact (no senderID) has no server row → local-delete as before.
    func deletePerson(_ person: Person) async throws {
        if let sid = person.senderID, !sid.isEmpty, let other = UUID(uuidString: sid) {
            guard await connectionService.deleteConnection(other: other) else {
                throw PeopleError.disconnectFailed
            }
        }
        // [conn-reconnect-fix] Delete this contact's SentLinks too — a dangling SentLink (its
        // Person gone) would shadow stampConnections for any reused/stale via (audit §2-B).
        let pid = person.id
        if let context = modelContext,
           let links = try? context.fetch(
               FetchDescriptor<SentLink>(predicate: #Predicate { $0.personID == pid })) {
            for l in links { context.delete(l) }
        }
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

    // ── [p1-conn-visibility] DISPLAY-ONLY reconciliation helpers (no merge) ──────

    /// (d) Same-name disambiguation for the People list + pickers: when ≥2 contacts
    /// share the same name, the 2nd/3rd… (ordered by createdAt, stable) get a
    /// "(2)"/"(3)" suffix; the first keeps the plain name. DISPLAY-ONLY — NEVER written
    /// into `Person.name`, NEVER used in messages/thoughts/"from [Name]".
    func disambiguatedName(for person: Person) -> String {
        let key = person.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return person.name }
        let sameName = people
            .filter { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == key }
            .sorted { $0.createdAt < $1.createdAt }
        guard sameName.count >= 2,
              let idx = sameName.firstIndex(where: { $0.id == person.id }) else { return person.name }
        return idx == 0 ? person.name : "\(person.name) (\(idx + 1))"
    }

    /// [contacts-pick] DEFAULT DELIVERY CHANNEL for a newly-picked contact: phone
    /// (SMS) first, email as the fallback, nil when neither exists. Pure + unit-tested
    /// (testDefaultSendChannel*). Stored on `Person.sendChannel`; the pre-addressed
    /// first send (sms:/mailto:) that consumes it is a FOLLOW-UP.
    static func defaultSendChannel(phone: String?, email: String?) -> String? {
        if let p = phone, !p.trimmingCharacters(in: .whitespaces).isEmpty { return "sms" }
        if let e = email, !e.trimmingCharacters(in: .whitespaces).isEmpty { return "email" }
        return nil
    }

    /// (c) Same-ID annotation (visibility only): if a DIFFERENT contact carries the
    /// SAME `senderID` (rare with the (b) guard, but surfaced if present), the other
    /// holder's name — so the list can show "same id as [Jess]". nil when the id is
    /// unique/absent. Takes NO action (no merge); user resolves via rename/delete.
    func sameIDOtherName(for person: Person) -> String? {
        guard let sid = person.senderID, !sid.isEmpty else { return nil }
        guard let other = people.first(where: { $0.id != person.id && $0.senderID == sid }) else { return nil }
        let n = other.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "another contact" : n
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
    func upsertContact(senderID: String, displayName: String?, makeActive: Bool = true) -> Person? {
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
        // [conn-display-fix] makeActive defaults true (existing callers unchanged);
        // the connection-sync fallback passes false so surfacing a synced connection
        // never changes the currently selected/active person.
        if makeActive, (selectedPerson == nil || selectedPerson.map(DemoPerson.isDemo) == true) {
            selectedPerson = person
        }
        // [keep-demo] Demo Dan stays as a permanent sandbox — auto-removal retired (the
        // arriving real contact still becomes active above). PRIOR (preserved):
        // removeDemoPersonIfPresent()
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
    func stampConnections(_ rows: [SupabaseService.LinkConnection]) async {
        guard let context = modelContext else { return }
        var didChange = false
        for row in rows {
            guard let via = row.viaMessageID else {
                continue   // no join key (deleted message → via set null) — skip
            }
            // WARM PATH (primary, name/contact hint): a local SentLink resolves a LIVE contact →
            // stamp it. [conn-reconnect-fix] If the SentLink is ABSENT *or* its Person is missing/
            // deleted (a DANGLING SentLink — audit §2-B/C), FALL THROUGH to the connected_user_id
            // fallback instead of `continue` — so the sender re-greens from the row's DURABLE
            // connected_user_id regardless of stale via / dangling SentLink / re-add.
            let link = try? context.fetch(
                FetchDescriptor<SentLink>(predicate: #Predicate { $0.messageID == via })).first
            if let link, let person = people.first(where: { $0.id == link.personID }) {
                if !(person.senderID ?? "").isEmpty { continue }          // already stamped
                let y = row.connectedUserID.uuidString
                // [p1-conn-visibility] SAME-ID GUARD: never let TWO contacts carry the same id.
                if let existing = self.person(forSenderID: y), existing.id != person.id { continue }
                person.senderID    = y
                person.pairedUserID = y                                   // mirror → PATH-1 channel
                didChange = true
            } else {
                // [conn-reconnect-fix] FALL-THROUGH (was: `else { continue }` on person-missing).
                // No live SentLink contact (absent, dangling, reinstall, other-device) → the
                // connection is REAL + server-persisted; stamp from connected_user_id (the durable
                // key) via upsertContact (dedups on senderID → no duplicate; makeActive:false →
                // never changes the active person). upsertContact / applySenderLocation save + fetchAll.
                let y = row.connectedUserID
                let profile = await connectionService.fetchPublicProfile(of: y)
                upsertContact(senderID: y.uuidString,
                              displayName: profile?.displayName,
                              makeActive: false)
                applySenderLocation(senderID: y.uuidString,
                                    latitude: profile?.latitude,
                                    longitude: profile?.longitude)
            }
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
        // [p2-delete-disconnect] server disconnect failed → contact NOT deleted (so it
        // can't silently re-surface); user can retry when back online.
        case disconnectFailed
        var errorDescription: String? {
            switch self {
            case .upgradeRequired:
                return "Unlock Pointward to add more people — one-time purchase, no subscription."
            case .disconnectFailed:
                return "Couldn't disconnect on the server — check your connection and try again."
            }
        }
    }
}
