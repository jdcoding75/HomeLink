// PairAcceptView.swift
// Pointward › Views
//
// THE ACCEPTANCE — what the recipient sees when they tap a pairing link or
// enter a code. Replaces the old auto-link (which blindly grabbed the
// selected/first person card — the "linked the wrong person" bug).
//
//   Step 1 · WHO    a warm full-screen moment: the sender's emoji glowing,
//                   "[Name] wants to connect"
//   Step 2 · CHOICE two cards — add them as a NEW person (name/emoji
//                   pre-filled, address to complete), or LINK them to
//                   someone already on the compass
//   Step 3 · LINKED the celebration — instruments meet, "connected ✦"
//
// Used by the universal-link sheet (RootView) and manual code entry
// (ConnectView).

import SwiftUI
import CoreLocation
import os

struct PairAcceptView: View {

    private static let log = Logger(subsystem: "com.jdcoding75.pointward", category: "pairing")

    let code: String
    let onDone: () -> Void

    @EnvironmentObject var people: PeopleManager
    @EnvironmentObject var compass: CompassManager

    private enum Step { case who, addNew, linkExisting, celebrating }
    @State private var step: Step = .who
    @State private var cardsShown = false

    @State private var inviteName:  String?
    @State private var inviteEmoji: String?
    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var linkedPerson: Person?

    // Add-new form
    @State private var newName  = ""
    @State private var newEmoji = "💜"
    @State private var addressText = ""
    @StateObject private var autocomplete = AddressAutocompleteService()
    @State private var selectedAddressText: String? = nil
    @State private var geocodeState: GeocodeState = .idle
    @State private var geocodedLocation: GeocodedLocation? = nil
    @State private var geocodeTask: Task<Void, Never>? = nil

    private static let lavender = Color(hex: "#c4a8d4")
    private static let glow     = Color(hex: "#9b7fc0")
    private let coreEmojis = ["❤️", "💋", "🤗", "✨", "🌸", "🌙"]

    private var displayName: String { inviteName ?? "someone" }

    var body: some View {
        ZStack {
            DesignTokens.Color.background.ignoresSafeArea()
            RadialGradient(
                colors: [Self.glow.opacity(0.15), .clear],
                center: .center, startRadius: 20, endRadius: 300
            )
            .ignoresSafeArea()

            switch step {
            case .who:          whoStep
            case .addNew:       addNewStep
            case .linkExisting: linkExistingStep
            case .celebrating:
                PairingCelebrationView(person: linkedPerson) { onDone() }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { lookupWho() }
    }

    // MARK: - Step 1 · who wants to connect (+ the two choices)

    private var whoStep: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 46)

                // The sender, glowing softly
                ZStack {
                    Circle()
                        .fill(Self.glow.opacity(0.28))
                        .frame(width: 110, height: 110)
                        .blur(radius: 22)
                    Text(inviteEmoji ?? "🧭")
                        .font(.system(size: 48))
                }
                .padding(.bottom, 14)

                Text("\(displayName) wants to connect")
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .foregroundColor(DesignTokens.Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                Text("thoughts will travel between your instruments")
                    .font(.system(size: 13, design: .serif).italic())
                    .foregroundColor(Self.lavender.opacity(0.8))
                    .padding(.top, 8)
                    .padding(.bottom, 26)

                // The code, for transparency
                Text(code.replacingOccurrences(of: "-", with: " · "))
                    .font(.system(size: 17, weight: .semibold, design: .monospaced))
                    .foregroundColor(DesignTokens.Color.accentSoft.opacity(0.8))
                    .padding(.bottom, 26)

                if let errorMessage {
                    Text(errorMessage)
                        .font(DesignTokens.Font.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .padding(.bottom, 14)
                }
                if isBusy {
                    ProgressView()
                        .tint(DesignTokens.Color.accentSoft)
                        .padding(.bottom, 14)
                }

                // ── The two choices ───────────────────────────────────────
                if cardsShown {
                    VStack(spacing: 14) {
                        choiceCard(
                            icon: "person.badge.plus",
                            title: "add \(displayName) as new person",
                            subtitle: "a fresh card on your compass"
                        ) {
                            newName  = inviteName ?? ""
                            newEmoji = inviteEmoji ?? "💜"
                            withAnimation(.easeOut(duration: 0.3)) { step = .addNew }
                        }

                        if !people.people.isEmpty {
                            choiceCard(
                                icon: "person.2",
                                title: "link to someone you know",
                                subtitle: "they're already on your compass"
                            ) {
                                withAnimation(.easeOut(duration: 0.3)) { step = .linkExisting }
                            }
                        }

                        Button("not now", action: onDone)
                            .font(DesignTokens.Font.caption)
                            .foregroundColor(DesignTokens.Color.textMuted)
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, 26)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer(minLength: 30)
            }
        }
    }

    private func choiceCard(icon: String, title: String, subtitle: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(Self.lavender)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium, design: .serif))
                        .foregroundColor(DesignTokens.Color.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(.system(size: 12, design: .serif).italic())
                        .foregroundColor(DesignTokens.Color.textMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Color.textDim)
            }
            .padding(16)
            .background(DesignTokens.Color.backgroundCard)
            .cornerRadius(DesignTokens.Radius.card)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.card)
                    .stroke(Self.lavender.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
    }

    // MARK: - Step 2a · add as new person

    private var addNewStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("add \(displayName)")
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .foregroundColor(DesignTokens.Color.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)

                Text("their name, their feeling, where they are")
                    .font(.system(size: 13, design: .serif).italic())
                    .foregroundColor(DesignTokens.Color.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 6)

                TextField("their name", text: $newName)
                    .formInput()

                HStack(spacing: 10) {
                    ForEach(coreEmojis, id: \.self) { e in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                newEmoji = e
                            }
                        } label: {
                            Text(e)
                                .font(.system(size: 22))
                                .frame(width: 46, height: 46)
                                .background(newEmoji == e
                                            ? DesignTokens.Color.accentStrong
                                            : DesignTokens.Color.backgroundCard)
                                .cornerRadius(13)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 13)
                                        .stroke(newEmoji == e
                                                ? DesignTokens.Color.accentMid
                                                : DesignTokens.Color.border, lineWidth: 1)
                                )
                        }
                    }
                }

                // Address with live autocomplete — completing it points the
                // needle somewhere true; it can also wait until later
                VStack(alignment: .leading, spacing: 6) {
                    TextField("their address or city (optional)", text: $addressText)
                        .formInput()
                        .autocorrectionDisabled()
                        .onChange(of: addressText) { _, new in
                            guard new != selectedAddressText else { return }
                            selectedAddressText = nil
                            geocodeTask?.cancel()
                            geocodedLocation = nil
                            geocodeState = .idle
                            autocomplete.updateQuery(new)
                        }

                    if !autocomplete.suggestions.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(autocomplete.suggestions) { suggestion in
                                Button {
                                    selectSuggestion(suggestion)
                                } label: {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(suggestion.title)
                                            .font(.system(size: 14))
                                            .foregroundColor(DesignTokens.Color.textPrimary)
                                        if !suggestion.subtitle.isEmpty {
                                            Text(suggestion.subtitle)
                                                .font(.system(size: 11))
                                                .foregroundColor(DesignTokens.Color.textMuted)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                if suggestion.id != autocomplete.suggestions.last?.id {
                                    Divider().background(DesignTokens.Color.border)
                                }
                            }
                        }
                        .background(DesignTokens.Color.backgroundCard)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(DesignTokens.Color.borderMid, lineWidth: 1)
                        )
                    }

                    switch geocodeState {
                    case .geocoding:
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.7)
                            Text("finding them…")
                        }
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Color.textMuted)
                    case .success(let location):
                        Text("✓ \(location.displayName)")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#5dcaa5"))
                    case .failure(let message):
                        Text(message)
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                    default:
                        EmptyView()
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(DesignTokens.Font.caption)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                }

                Button {
                    acceptAddingNew()
                } label: {
                    Text(isBusy ? "connecting…" : "connect →")
                        .font(DesignTokens.Font.label)
                        .foregroundColor(DesignTokens.Color.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(DesignTokens.Spacing.md)
                        .background(DesignTokens.Color.accentStrong)
                        .cornerRadius(DesignTokens.Radius.button)
                }
                .disabled(isBusy || newName.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(newName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)

                Button("← back") {
                    withAnimation(.easeOut(duration: 0.25)) { step = .who }
                }
                .font(DesignTokens.Font.caption)
                .foregroundColor(DesignTokens.Color.textMuted)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 28)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Step 2b · link to someone already here

    private var linkExistingStep: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("who is \(displayName)?")
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .foregroundColor(DesignTokens.Color.textPrimary)
                    .padding(.top, 40)

                Text("pick the person on your compass")
                    .font(.system(size: 13, design: .serif).italic())
                    .foregroundColor(DesignTokens.Color.textMuted)
                    .padding(.top, 6)
                    .padding(.bottom, 20)

                if let errorMessage {
                    Text(errorMessage)
                        .font(DesignTokens.Font.caption)
                        .foregroundColor(.red)
                        .padding(.bottom, 12)
                }

                VStack(spacing: 0) {
                    ForEach(people.people) { person in
                        Button {
                            acceptLinking(to: person)
                        } label: {
                            HStack(spacing: 14) {
                                Text(person.emoji).font(.system(size: 26))
                                Text(person.name)
                                    .font(.system(size: 17, weight: .medium, design: .serif))
                                    .foregroundColor(DesignTokens.Color.textPrimary)
                                Spacer()
                                if let distance = distanceText(for: person) {
                                    Text(distance)
                                        .font(.system(size: 12))
                                        .foregroundColor(DesignTokens.Color.textMuted)
                                        .monospacedDigit()
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 13)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(isBusy)

                        if person.id != people.people.last?.id {
                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 1)
                                .padding(.leading, 58)
                        }
                    }
                }
                .background(DesignTokens.Color.backgroundCard)
                .cornerRadius(DesignTokens.Radius.card)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.card)
                        .stroke(DesignTokens.Color.border, lineWidth: 1)
                )
                .padding(.horizontal, 26)

                if isBusy {
                    ProgressView()
                        .tint(DesignTokens.Color.accentSoft)
                        .padding(.top, 16)
                }

                Button("← back") {
                    withAnimation(.easeOut(duration: 0.25)) { step = .who }
                }
                .font(DesignTokens.Font.caption)
                .foregroundColor(DesignTokens.Color.textMuted)
                .padding(.top, 18)
            }
        }
    }

    private func distanceText(for person: Person) -> String? {
        guard let location = compass.userLocation else { return nil }
        let km = BearingCalculator.distanceKm(from: location.coordinate,
                                              to: person.coordinate)
        return BearingCalculator.formattedDistance(km)
    }

    // MARK: - Actions

    private func lookupWho() {
        Task {
            do {
                let info = try await SupabaseService.shared.lookupInvite(code)
                withAnimation(.easeOut(duration: 0.3)) {
                    inviteName  = info.name
                    inviteEmoji = info.emoji
                }
            } catch let error as SupabaseServiceError where error == .codeNotFound {
                Self.log.warning("accept: code \(code, privacy: .public) not found")
                errorMessage = error.localizedDescription
            } catch {
                Self.log.error("accept: invite lookup failed: \(error.localizedDescription, privacy: .public)")
            }
            // The choices breathe in after the who-moment lands
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeOut(duration: 0.45)) { cardsShown = true }
            }
        }
    }

    private func selectSuggestion(_ suggestion: AddressSuggestion) {
        selectedAddressText = suggestion.fullText
        addressText         = suggestion.fullText
        autocomplete.clear()
        geocodeState = .geocoding(suggestion.title)
        geocodeTask?.cancel()
        geocodeTask = Task {
            do {
                let result = try await autocomplete.resolve(suggestion)
                guard !Task.isCancelled else { return }
                geocodedLocation = result
                geocodeState     = .success(result)
            } catch {
                guard !Task.isCancelled else { return }
                geocodeState = .failure("couldn't find that address")
            }
        }
    }

    /// Shared guard + redeem. Returns the partner id, or nil after showing
    /// the error.
    /// Shared guard + redeem. The chosen card's id rides along as
    /// friend_person_id so BOTH sides of the connection know which person
    /// the link belongs to. Returns the partner id, or nil after showing
    /// the error.
    private func redeemFirst(cardID: UUID) async -> UUID? {
        guard SupabaseService.localUserID != nil else {
            errorMessage = "Sign in first — Settings → account — then try again."
            return nil
        }
        do {
            let result = try await SupabaseService.shared.redeem(code, friendPersonID: cardID)
            return result.ownerID
        } catch {
            Self.log.error("accept: redeem failed — \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func acceptAddingNew() {
        isBusy = true
        errorMessage = nil
        Task {
            defer { isBusy = false }
            // Build the card FIRST so its id can travel with the claim —
            // geocoded when an address was found, otherwise near the
            // recipient (editable later). Inserted only after redeem lands.
            let person: Person
            if let geocoded = geocodedLocation {
                person = Person(name: newName.trimmingCharacters(in: .whitespaces),
                                emoji: newEmoji, geocoded: geocoded)
            } else {
                let coordinate = compass.userLocation?.coordinate
                person = Person(name: newName.trimmingCharacters(in: .whitespaces),
                                emoji: newEmoji,
                                latitude: coordinate?.latitude ?? 0,
                                longitude: coordinate?.longitude ?? 0,
                                locationDisplayName: newName)
            }
            guard let partnerID = await redeemFirst(cardID: person.id) else { return }
            person.pairedUserID = partnerID.uuidString
            people.insertFromInvite(person)
            Self.log.info("accept: paired ✓ as NEW person \(person.name, privacy: .public)")
            celebrate(with: person)
        }
    }

    private func acceptLinking(to person: Person) {
        isBusy = true
        errorMessage = nil
        Task {
            defer { isBusy = false }
            guard let partnerID = await redeemFirst(cardID: person.id) else { return }
            person.pairedUserID = partnerID.uuidString
            try? people.save()
            Self.log.info("accept: paired ✓ linked to EXISTING person \(person.name, privacy: .public)")
            celebrate(with: person)
        }
    }

    private func celebrate(with person: Person) {
        linkedPerson = person
        HapticEngine.connectionFelt()
        withAnimation(.easeOut(duration: 0.4)) { step = .celebrating }
    }
}
