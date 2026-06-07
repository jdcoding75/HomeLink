// PeopleListView.swift
// Pointward › Views

import SwiftUI
import CoreLocation

struct PeopleListView: View {

    @EnvironmentObject var people:  PeopleManager
    @EnvironmentObject var compass: CompassManager

    let geocodingService: GeocodingServiceProtocol

    @State private var showAdd    = false
    @State private var editPerson: Person? = nil
    @State private var detailPerson: Person? = nil
    @State private var showUnlock = false
    @State private var friendLastSeen: Date? = nil   // presence of the connected friend

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
                        addButton
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.top, DesignTokens.Spacing.md)
                    .padding(.bottom, DesignTokens.Spacing.md)

                    // Person cards
                    VStack(spacing: 12) {
                        ForEach(people.people) { person in
                            PersonCard(
                                person: person,
                                isSelected: people.selectedPerson?.id == person.id,
                                distanceText: distanceText(for: person),
                                isConnected: isConnected(person),
                                lastSeenText: lastSeenText(for: person)
                            ) {
                                // Tap card → select + open the detail view
                                people.select(person)
                                compass.start(tracking: person)
                                HapticEngine.personSelected()
                                detailPerson = person
                            } onEdit: {
                                editPerson = person
                            }
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)

                    Spacer(minLength: DesignTokens.Spacing.xl)
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddPersonView(geocodingService: geocodingService)
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
        .onAppear { fetchFriendPresence() }
    }

    // MARK: - Helpers

    /// Live distance from the user's last known location, when we have one.
    private func distanceText(for person: Person) -> String? {
        guard let location = compass.userLocation else { return nil }
        let km = BearingCalculator.distanceKm(from: location.coordinate,
                                              to: person.coordinate)
        return BearingCalculator.formattedDistance(km)
    }

    /// Connected = this person carries the paired friend's Supabase id.
    private func isConnected(_ person: Person) -> Bool {
        guard let friend = SupabaseService.connectedFriendID else { return false }
        return person.pairedUserID == friend.uuidString
    }

    private func lastSeenText(for person: Person) -> String? {
        guard isConnected(person), let date = friendLastSeen else { return nil }
        return PersonDetailView.presenceText(for: date)
    }

    private func fetchFriendPresence() {
        guard let friend = SupabaseService.connectedFriendID else { return }
        Task {
            friendLastSeen = await SupabaseService.shared.fetchLastSeen(of: friend)
        }
    }

    // MARK: - Subviews

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

// MARK: - PersonCard

// A relationship, not a contact-list row: large glowing avatar, bold name,
// their tagline in lavender, distance whispered beneath.
struct PersonCard: View {
    let person: Person
    let isSelected: Bool
    let distanceText: String?
    let isConnected: Bool
    let lastSeenText: String?
    let onTap: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Avatar — large, with a soft glow behind it
            ZStack {
                Circle()
                    .fill(Color(hex: "#9b7fc0").opacity(isSelected ? 0.32 : 0.15))
                    .frame(width: 60, height: 60)
                    .blur(radius: 12)
                Text(person.emoji)
                    .font(.system(size: 30))
                    .frame(width: 60, height: 60)
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
                Text(person.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(DesignTokens.Color.textPrimary)

                Text(person.resolvedTagline)
                    .font(.system(size: 12).italic())
                    .foregroundColor(DesignTokens.Color.accentMid)
                    .lineLimit(1)

                Text(distanceText
                     ?? (person.displayAddress.isEmpty
                         ? person.locationDisplayName
                         : person.displayAddress))
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Color.textMuted)
                    .lineLimit(1)

                // Connection status — green when their compasses are linked
                HStack(spacing: 5) {
                    Circle()
                        .fill(isConnected ? Color(hex: "#5dcaa5")
                                          : DesignTokens.Color.textDim.opacity(0.6))
                        .frame(width: 6, height: 6)
                    Text(isConnected
                         ? (lastSeenText.map { "connected ✓ · \($0)" } ?? "connected ✓")
                         : "not yet linked")
                        .font(.system(size: 10))
                        .foregroundColor(isConnected ? Color(hex: "#5dcaa5")
                                                     : DesignTokens.Color.textDim)
                        .lineLimit(1)
                }
                .padding(.top, 1)
            }

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
