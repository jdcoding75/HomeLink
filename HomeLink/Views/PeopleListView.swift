// PeopleListView.swift
// Pointward › Views

import SwiftUI
import CoreLocation
import UIKit   // [contacts-pick] UIImage for the contact-photo avatar

struct PeopleListView: View {

    @EnvironmentObject var people:  PeopleManager
    @EnvironmentObject var compass: CompassManager

    let geocodingService: GeocodingServiceProtocol

    @State private var showAdd    = false
    @State private var showCodeEntry = false   // [phase2 4b] short-code receive
    @State private var editPerson: Person? = nil
    @State private var detailPerson: Person? = nil
    @State private var showConnect = false
    @State private var showUnlock = false
    // [pairing-retire step4-presence] friendLastSeen + fetchFriendPresence + lastSeenText
    // REMOVED — the cosmetic "· last seen X ago" badge suffix was gated on the pairing-era
    // global connectedFriendID (already nil/dead for link contacts). The badge stays
    // "connected ✓". This removes PeopleListView's last connectedFriendID read.

    var body: some View {
        ZStack {
            DesignTokens.Color.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Section header row
                    HStack {
                        Text("people")
                            .font(DesignTokens.Font.compassName)
                            .foregroundColor(DesignTokens.Color.textPrimary)
                        Spacer()
                        codeEntryButton   // [phase2 4b] "got a code from someone?"
                        addButton
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.top, DesignTokens.Spacing.md)
                    .padding(.bottom, DesignTokens.Spacing.md)

                    // Person cards
                    VStack(spacing: 12) {
                        let dupes = duplicatedNameKeys
                        ForEach(people.people) { person in
                            PersonCard(
                                person: person,
                                displayName: people.disambiguatedName(for: person),
                                isSelected: people.selectedPerson?.id == person.id,
                                distanceText: distanceText(for: person),
                                isConnected: isConnected(person),
                                isPending: isPending(person),
                                showLocationHint: needsLocation(person),
                                disambiguator: disambiguator(for: person, dupes: dupes),
                                sameIDNote: people.sameIDOtherName(for: person),
                                hideConnectionStatus: isLinkContact(person),
                                hasOpenedReceipt: people.contactsWithOpenedReceipt.contains(person.id),
                                isLinkConnected: isLinkConnected(person)
                            ) {
                                // [contacts-pick] 2a — Tap card → SELECT/switch the
                                // send-target ONLY, then drop back to the compass now
                                // pointing at them (no auto-open of detail). Detail is
                                // the explicit trailing chevron; edit is the pencil.
                                people.select(person)
                                compass.start(tracking: person)
                                HapticEngine.personSelected()
                                NotificationCenter.default.post(name: .pointwardOpenCompass, object: nil)
                            } onEdit: {
                                editPerson = person
                            } onDetail: {
                                detailPerson = person
                            } onAddLocation: {
                                // The location hint taps straight into the edit path.
                                editPerson = person
                            }
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)

                    // ── Generic "connect with someone" retired — invites
                    // now live on each person's own card (PersonDetailView),
                    // so the code always travels with the right identity. ──
                    // Button {
                    //     showConnect = true
                    // } label: {
                    //     HStack {
                    //         Text("connect with someone →")
                    //             .font(.system(size: 14, design: .serif).italic())
                    //             .foregroundColor(DesignTokens.Color.accentSoft)
                    //         Spacer()
                    //     }
                    //     .padding(DesignTokens.Spacing.md)
                    //     .background(DesignTokens.Color.backgroundCard.opacity(0.7))
                    //     .cornerRadius(DesignTokens.Radius.card)
                    //     .overlay(
                    //         RoundedRectangle(cornerRadius: DesignTokens.Radius.card)
                    //             .stroke(DesignTokens.Color.border, lineWidth: 1)
                    //     )
                    // }
                    // .padding(.horizontal, DesignTokens.Spacing.lg)
                    // .padding(.top, 16)

                    Spacer(minLength: DesignTokens.Spacing.xl)
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddPersonView(geocodingService: geocodingService)
        }
        .sheet(isPresented: $showCodeEntry) {
            ShortCodeEntryView()   // [phase2 4b] short-code receive — NOT pairing
        }
        .sheet(item: $editPerson, onDismiss: {
            // Edits to the selected person (name, emoji, address) should show
            // on the compass immediately — re-seed the compass state
            if let person = people.selectedPerson {
                compass.start(tracking: person)
            }
        }) { person in
            EditPersonView(person: person, geocodingService: geocodingService)
        }
        .sheet(isPresented: $showUnlock) {
            PaywallView()
        }
        .sheet(item: $detailPerson) { person in
            PersonDetailView(person: person)
        }
        // (ConnectView unrouted — person cards own connecting now)
        // .sheet(isPresented: $showConnect) {
        //     ConnectView()
        // }
        // A replay is about to present app-wide — get our sheets out of the way
        .onReceive(NotificationCenter.default.publisher(for: .pointwardCloseSheetsForReplay)) { _ in
            detailPerson = nil
            editPerson = nil
            showAdd = false
            showConnect = false
        }
    }

    // MARK: - Helpers

    /// Live distance from the user's last known location, when we have one.
    private func distanceText(for person: Person) -> String? {
        guard let location = compass.userLocation else { return nil }
        let km = BearingCalculator.distanceKm(from: location.coordinate,
                                              to: person.coordinate)
        return BearingCalculator.formattedDistance(km)
    }

    /// [pairing-retire step4] Connected = this LINK-era contact carries a senderID
    /// (auto-created on receive). senderID-ONLY — mirrors PersonDetailView's reconciled
    /// isConnected; no longer reads the pairing-era global connectedFriendID. isPending +
    /// lastSeenText follow automatically (they call isConnected, not connectedFriendID).
    private func isConnected(_ person: Person) -> Bool {
        !(person.senderID ?? "").isEmpty
    }

    /// [1/3] Scenario 4 — one-sided pairing: we recorded a partner id for this
    /// card, but the live connection doesn't confirm it (partner deleted the
    /// app / never reciprocated). Shown dim as "connection pending".
    private func isPending(_ person: Person) -> Bool {
        person.pairedUserID != nil && !isConnected(person)
    }


    // MARK: - [phase2 build6] Display helpers

    /// A LINK-era contact (auto-created on receive, Build 5) carries a senderID.
    /// Gate on senderID — NOT pairedUserID, which Build 5 mirror-writes = senderID,
    /// so it's no longer a reliable "is pairing contact" signal.
    private func isLinkContact(_ person: Person) -> Bool {
        !(person.senderID ?? "").isEmpty
    }

    /// [display-polish] A connection exists when this contact carries a senderID
    /// (received from them, or — post-Stage-C — they opened your thought). Drives
    /// the "connected ✦" indicator. Same signal as `isLinkContact`; named for the
    /// connection-status call site (nil senderID → no indicator, never a false negative).
    private func isLinkConnected(_ person: Person) -> Bool {
        !(person.senderID ?? "").isEmpty
    }

    /// No real address set → the contact card shows the gentle add-location hint
    /// (and the bogus null-island distance/name line is suppressed).
    private func needsLocation(_ person: Person) -> Bool {
        person.latitude == 0 && person.longitude == 0
    }

    /// The lowercased name keys shared by ≥2 contacts — drives disambiguation.
    private var duplicatedNameKeys: Set<String> {
        var counts: [String: Int] = [:]
        for p in people.people {
            let key = p.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !key.isEmpty { counts[key, default: 0] += 1 }
        }
        return Set(counts.filter { $0.value >= 2 }.keys)
    }

    /// For a card whose name collides with another, a subtle suffix line:
    /// "<name> · <place ?? relative-time>". `nil` for unique names (card renders
    /// today's location line unchanged).
    private func disambiguator(for person: Person, dupes: Set<String>) -> String? {
        let key = person.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard dupes.contains(key) else { return nil }
        let suffix = placeComponent(for: person)
            ?? PoeticTime.string(for: person.lastReceivedAt ?? person.createdAt)
        return "\(person.name) · \(suffix)"
    }

    /// First component of locationDisplayName when it's a real place AND not just
    /// the name echoed back (link contacts seed locationDisplayName = name).
    private func placeComponent(for person: Person) -> String? {
        let loc = person.locationDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !loc.isEmpty else { return nil }
        let first = (loc.split(separator: ",").first.map(String.init) ?? loc)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let name = person.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !first.isEmpty, first.lowercased() != name.lowercased() else { return nil }
        return first
    }

    // MARK: - Subviews

    /// [phase2 4b] "someone sent me something, let me get it" — opens the
    /// short-code entry sheet (the no-link receive path). NOT pairing.
    private var codeEntryButton: some View {
        Button { showCodeEntry = true } label: {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(DesignTokens.Color.accentSoft)
                .frame(width: 34, height: 34)
                .background(DesignTokens.Color.backgroundLift)
                .clipShape(Circle())
                .overlay(Circle().stroke(DesignTokens.Color.borderMid, lineWidth: 1))
        }
        .accessibilityLabel("Enter a message code")
    }

    private var addButton: some View {
        Button {
            if people.canAddPerson() {
                showAdd = true
            } else {
                // Free tier holds one person — the unlock opens the rest
                HapticEngine.paywallReached()
                showUnlock = true
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(DesignTokens.Color.accentSoft)
                .frame(width: 34, height: 34)
                .background(DesignTokens.Color.backgroundLift)
                .clipShape(Circle())
                .overlay(Circle().stroke(DesignTokens.Color.borderMid, lineWidth: 1))
        }
    }

}

// MARK: - Notifications

extension Notification.Name {
    /// Posted by the post-onboarding connect prompt — MainTabView jumps to People.
    static let pointwardOpenPeople = Notification.Name("pointwardOpenPeople")

    /// [phase2 4b] Posted (object: message UUID) when the short-code claim has a
    /// newest message to play — RootView routes it into the SAME 4a receive
    /// chain (sets messageOpenRequest → IncomingMessageView cover).
    static let pointwardOpenMessage = Notification.Name("pointwardOpenMessage")
}

// MARK: - PersonCard

// A relationship, not a contact-list row: large glowing avatar, bold name,
// distance whispered beneath.
struct PersonCard: View {
    let person: Person
    var displayName: String? = nil          // [p1-conn-visibility] (d) (2) same-name suffix (display-only)
    let isSelected: Bool
    let distanceText: String?
    let isConnected: Bool
    var isPending: Bool = false   // [1/3] one-sided pairing — dim, "pending"
    var showLocationHint: Bool = false      // [build6] zero-location → add-location hint
    var disambiguator: String? = nil        // [build6] same-name suffix line
    var sameIDNote: String? = nil           // [p1-conn-visibility] (c) other contact holding same senderID
    var hideConnectionStatus: Bool = false  // [build6] suppress pairing row for link contacts
    var hasOpenedReceipt: Bool = false       // [stageC] they opened a thought I sent → "opened ✦"
    var isLinkConnected: Bool = false        // [display-polish] senderID set → show "connected ✦"
    let onTap: () -> Void
    let onEdit: () -> Void
    var onDetail: () -> Void = {}            // [contacts-pick] 2a — trailing chevron → PersonDetailView
    var onAddLocation: () -> Void = {}       // [build6] hint tap → edit path

    /// [build6] Avatar fallback for emoji-less contacts (Build 5 leaves emoji "").
    /// First letter of the name, uppercased; a neutral ✦ when the name is empty.
    private var monogram: String {
        let trimmed = person.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.first.map { String($0).uppercased() } ?? "✦"
    }

    var body: some View {
        HStack(spacing: 16) {
            // Avatar — large, with a soft glow behind it
            ZStack {
                Circle()
                    .fill(Color(hex: "#9b7fc0").opacity(isSelected ? 0.32 : 0.15))
                    .frame(width: 60, height: 60)
                    .blur(radius: 12)
                Group {
                    // [contacts-pick] 2c-ii — PHOTO from the picked iOS contact, when
                    // present; otherwise the INITIAL/monogram. (The per-person emoji is
                    // vestigial since the onboarding emoji-picker cut; person.emoji FIELD
                    // kept. Full photo subsystem — detail/widget — deferred.)
                    if let data = person.photoData, let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                    } else {
                        // [display-polish] Standardize the contact icon on the INITIAL.
                        // if person.emoji.isEmpty {
                        Text(monogram)
                            .font(.system(size: 26, weight: .semibold, design: .serif))
                            .foregroundColor(DesignTokens.Color.accentSoft)
                        // } else {
                        //     Text(person.emoji)
                        //         .font(.system(size: 30))
                        // }
                    }
                }
                    .frame(width: 60, height: 60)
                    .clipped()
                    .background(DesignTokens.Color.backgroundLift)
                    .cornerRadius(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(isSelected
                                    ? DesignTokens.Color.accentMid
                                    : DesignTokens.Color.border,
                                    lineWidth: 1)
                    )
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(displayName ?? person.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(DesignTokens.Color.textPrimary)
                    // [stageC] read-receipt — they opened (in full) a thought I sent.
                    if hasOpenedReceipt {
                        Text("opened ✦")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(DesignTokens.Color.accentSoft)
                    }
                }

                // [p1-conn-visibility] (c) SAME-ID ANNOTATION (visibility only): another
                // contact carries this contact's senderID → surface it so the user can
                // rename/delete. Display-only; no action taken (no merge).
                if let sameIDNote {
                    Text("same id as \(sameIDNote)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DesignTokens.Color.accentSoft)
                        .lineLimit(1)
                }
                // [build6] Location line. Priority: zero-location HINT (also kills
                // the bogus null-island distance / name-echo) → same-name
                // disambiguator → today's distance/address line.
                if showLocationHint {
                    Button(action: onAddLocation) {
                        Text("add location for accurate compass · add now ✦")
                            .font(.system(size: 11, design: .serif).italic())
                            .foregroundColor(DesignTokens.Color.accentSoft)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                } else if let disambiguator {
                    Text(disambiguator)
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Color.textMuted)
                        .lineLimit(1)
                } else {
                    Text(distanceText
                         ?? (person.displayAddress.isEmpty
                             ? person.locationDisplayName
                             : person.displayAddress))
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Color.textMuted)
                        .lineLimit(1)
                }

                // Connection status — green linked · amber pending · grey unlinked
                // [build6] Suppressed for LINK contacts (senderID set) — pairing-era
                // row; would wrongly read "not yet linked". Removed entirely in build 8.
                if !hideConnectionStatus {
                HStack(spacing: 5) {
                    Circle()
                        .fill(isConnected ? Color(hex: "#5dcaa5")
                              : (isPending ? Color(hex: "#D4A017")
                                           : DesignTokens.Color.textDim.opacity(0.6)))
                        .frame(width: 6, height: 6)
                    Text(isConnected
                         ? "connected ✓"
                         : (isPending ? "connection pending · waiting for \(person.name) to reconnect"
                                      : "not yet linked"))
                        .font(.system(size: 10))
                        .foregroundColor(isConnected ? Color(hex: "#5dcaa5")
                                         : (isPending ? Color(hex: "#D4A017")
                                                      : DesignTokens.Color.textDim))
                        .lineLimit(1)
                }
                .padding(.top, 1)
                } else if isLinkConnected {
                    // [display-polish] LINK-era connection indicator — re-surfaces the
                    // green idiom for senderID contacts (the pairing row above is
                    // suppressed for them). senderID nil → render NOTHING (no false
                    // "not yet linked"); calm by default.
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color(hex: "#5dcaa5"))
                            .frame(width: 6, height: 6)
                        Text("connected ✦")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "#5dcaa5"))
                            .lineLimit(1)
                    }
                    .padding(.top, 1)
                }   // [build6] end if !hideConnectionStatus / [display-polish] else link indicator
            }
            // [1/3] Scenario 4 — a pending (one-sided) connection reads dim.
            .opacity(isPending ? 0.55 : 1.0)

            Spacer()

            // Edit button
            Button {
                onEdit()
            } label: {
                Text("edit")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Color.accentSoft)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(DesignTokens.Color.accentStrong.opacity(0.6))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(DesignTokens.Color.accentMid.opacity(0.5), lineWidth: 1)
                    )
            }

            // [contacts-pick] 2a — explicit detail affordance. Tapping the card now
            // just SELECTS (+ returns to the compass); this chevron opens the detail
            // view (invites, connection status, etc.).
            Button {
                onDetail()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DesignTokens.Color.textMuted)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("\(person.name) details")
        }
        .padding(18)
        .background(
            // Subtle depth gradient instead of a flat card
            LinearGradient(
                colors: isSelected
                    ? [Color(hex: "#251c35"), Color(hex: "#181222")]
                    : [Color(hex: "#1a1424"), Color(hex: "#130f1b")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .cornerRadius(DesignTokens.Radius.card)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.card)
                .stroke(isSelected
                        ? DesignTokens.Color.accentMid
                        : DesignTokens.Color.border,
                        lineWidth: isSelected ? 1.4 : 1)
        )
        // Warm lavender glow around the chosen one
        .shadow(color: DesignTokens.Color.accentMid.opacity(isSelected ? 0.35 : 0),
                radius: 12)
        .onTapGesture { onTap() }
        .animation(.easeOut(duration: 0.25), value: isSelected)
    }
}
