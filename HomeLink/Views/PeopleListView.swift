// PeopleListView.swift
// HomeLink › Views

import SwiftUI

struct PeopleListView: View {

    @EnvironmentObject var people:       PeopleManager
    @EnvironmentObject var subscription: SubscriptionManager
    @EnvironmentObject var compass:      CompassManager

    let geocodingService: GeocodingServiceProtocol

    @State private var showAdd    = false
    @State private var editPerson: Person? = nil
    @State private var showPaywall = false

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
                    VStack(spacing: 10) {
                        ForEach(people.people) { person in
                            PersonCard(
                                person: person,
                                isSelected: people.selectedPerson?.id == person.id
                            ) {
                                // Tap card → select
                                people.select(person)
                                compass.start(tracking: person)
                                HapticEngine.connectionFelt()
                            } onEdit: {
                                editPerson = person
                            }
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)

                    // Paywall strip when at free limit
                    if !subscription.tier.canAddMore(current: people.people.count) {
                        paywallStrip
                            .padding(.horizontal, DesignTokens.Spacing.lg)
                            .padding(.top, DesignTokens.Spacing.sm)
                    }

                    Spacer(minLength: DesignTokens.Spacing.xl)
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddPersonView(geocodingService: geocodingService)
        }
        .sheet(item: $editPerson) { person in
            EditPersonView(person: person, geocodingService: geocodingService)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    // MARK: - Subviews

    private var addButton: some View {
        Button {
            if people.canAddPerson() {
                showAdd = true
            } else {
                HapticEngine.paywallReached()
                showPaywall = true
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

    private var paywallStrip: some View {
        Button { showPaywall = true } label: {
            HStack(spacing: 12) {
                Text("🔒")
                    .font(.system(size: 20))
                VStack(alignment: .leading, spacing: 2) {
                    Text("add unlimited people")
                        .font(DesignTokens.Font.label)
                        .foregroundColor(DesignTokens.Color.textPrimary)
                    Text("upgrade to HomeLink Pro")
                        .font(DesignTokens.Font.caption)
                        .foregroundColor(DesignTokens.Color.textMuted)
                }
                Spacer()
                Text("upgrade")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignTokens.Color.accentSoft)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(DesignTokens.Color.accentStrong)
                    .cornerRadius(DesignTokens.Radius.pill)
                    .overlay(
                        Capsule().stroke(DesignTokens.Color.accentMid, lineWidth: 1)
                    )
            }
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.Color.backgroundLift)
            .cornerRadius(DesignTokens.Radius.card)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.card)
                    .stroke(DesignTokens.Color.borderMid, lineWidth: 1)
            )
        }
    }
}

// MARK: - PersonCard

struct PersonCard: View {
    let person: Person
    let isSelected: Bool
    let onTap: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            Text(person.emoji)
                .font(.system(size: 24))
                .frame(width: 48, height: 48)
                .background(DesignTokens.Color.backgroundLift)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected
                                ? DesignTokens.Color.accentMid
                                : DesignTokens.Color.border,
                                lineWidth: 1)
                )

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(DesignTokens.Font.label)
                    .foregroundColor(DesignTokens.Color.textPrimary)

                Text(person.displayAddress.isEmpty
                     ? person.locationDisplayName
                     : person.displayAddress)
                    .font(DesignTokens.Font.caption)
                    .foregroundColor(DesignTokens.Color.textMuted)
                    .lineLimit(1)

                Text(person.resolvedTagline)
                    .font(.system(size: 11).italic())
                    .foregroundColor(DesignTokens.Color.accentMid)
                    .lineLimit(1)
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
        .padding(DesignTokens.Spacing.md)
        .background(isSelected
                    ? DesignTokens.Color.backgroundLift
                    : DesignTokens.Color.backgroundCard)
        .cornerRadius(DesignTokens.Radius.card)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.card)
                .stroke(isSelected
                        ? DesignTokens.Color.accentMid
                        : DesignTokens.Color.border,
                        lineWidth: 1)
        )
        .onTapGesture { onTap() }
        .animation(.easeOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - SubscriptionTier helper

private extension SubscriptionTier {
    func canAddMore(current: Int) -> Bool {
        current < maxPeople
    }
}
