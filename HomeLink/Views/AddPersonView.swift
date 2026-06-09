// AddPersonView.swift
// Pointward › Views
//
// Presented as a sheet from PeopleListView when the user taps "+".
// Owns the full add-person flow:
//   Step 1 — name + emoji
//   Step 2 — tagline (preset or custom)
//   Step 3 — address with live geocoding
//
// GeocodingService is injected from the environment so Previews and
// tests can swap in MockGeocodingService with zero friction.

import SwiftUI
import CoreLocation
import Contacts

struct AddPersonView: View {

    // MARK: - Environment
    @EnvironmentObject var people:   PeopleManager
    @Environment(\.dismiss) var dismiss

    // Injected so previews can use MockGeocodingService
    let geocodingService: GeocodingServiceProtocol

    // MARK: - Step state
    @State private var step: Int = 1

    // Step 1
    @State private var name: String = ""
    @State private var emoji: String = "🏠"

    // Step 2
    @State private var tagline: String = ""
    @State private var selectedPreset: String = TaglineSystem.presets[0]

    // Step 3
    @State private var addressText: String = ""
    @StateObject private var autocomplete = AddressAutocompleteService()
    @State private var selectedAddressText: String? = nil  // skip re-searching text we just filled in
    @State private var geocodeTask: Task<Void, Never>? = nil
    @State private var geocodeState: GeocodeState = .idle
    @State private var geocodedLocation: GeocodedLocation? = nil

    // Contacts / invite
    @State private var showContactPicker = false
    @State private var showInviteShare = false

    // Unlock / error
    @State private var showUnlock = false
    @State private var saveError: String? = nil

    // MARK: - Body

    var body: some View {
        ZStack {
            DesignTokens.Color.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                sheetHeader

                // Progress
                progressDots
                    .padding(.bottom, 8)

                // Step content
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        switch step {
                        case 1:  stepOne
                        case 2:  stepTwo
                        default: stepThree
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.bottom, DesignTokens.Spacing.xl)
                }

                // CTA
                ctaBar
            }
        }
        .sheet(isPresented: $showUnlock) {
            PaywallView()
        }
        .sheet(isPresented: $showContactPicker) {
            ContactPickerView { contact in
                applyContact(contact)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showInviteShare, onDismiss: { dismiss() }) {
            ActivityShareSheet(items: [inviteMessage])
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Header

    private var sheetHeader: some View {
        HStack {
            if step > 1 {
                Button("back") { withAnimation(.easeOut(duration: 0.25)) { step -= 1 } }
                    .font(DesignTokens.Font.label)
                    .foregroundColor(DesignTokens.Color.accentSoft)
            }
            Spacer()
            Text(step == 1 ? "add person" : step == 2 ? "tagline" : "location")
                .font(DesignTokens.Font.label)
                .foregroundColor(DesignTokens.Color.textPrimary)
            Spacer()
            Button("cancel") { dismiss() }
                .font(DesignTokens.Font.label)
                .foregroundColor(DesignTokens.Color.textMuted)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
    }

    // MARK: - Progress dots

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(1...3, id: \.self) { s in
                Capsule()
                    .fill(s == step
                          ? DesignTokens.Color.accentSoft
                          : s < step
                              ? DesignTokens.Color.accentMid
                              : DesignTokens.Color.borderMid)
                    .frame(width: s == step ? 20 : 6, height: 6)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: step)
            }
        }
    }

    // MARK: - Step 1: Name + Emoji

    private var stepOne: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Live preview orb
            ZStack {
                Circle()
                    .stroke(DesignTokens.Color.accentMid.opacity(0.3), lineWidth: 1)
                    .frame(width: 84, height: 84)
                Text(emoji)
                    .font(.system(size: 38))
                    .transition(.scale.combined(with: .opacity))
                    .id(emoji)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.Spacing.lg)

            formLabel("their name")
            TextField("Mum, Dad, Home, Nan…", text: $name)
                .formInput()
                .padding(.bottom, DesignTokens.Spacing.sm)

            // Or pick straight from the address book
            Button {
                showContactPicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 14))
                    Text("choose from contacts")
                        .font(DesignTokens.Font.label)
                }
                .foregroundColor(DesignTokens.Color.accentSoft)
                .frame(maxWidth: .infinity)
                .padding(DesignTokens.Spacing.md)
                .background(DesignTokens.Color.backgroundCard)
                .cornerRadius(DesignTokens.Radius.button)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.button)
                        .stroke(DesignTokens.Color.borderMid, lineWidth: 1)
                )
            }
            .padding(.bottom, DesignTokens.Spacing.md)

            formLabel("their emoji")
            EmojiPickerRow(selected: $emoji)
                .padding(.bottom, DesignTokens.Spacing.sm)
        }
    }

    // MARK: - Step 2: Tagline

    private var stepTwo: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Mini preview
            taglinePreviewCard
                .padding(.vertical, DesignTokens.Spacing.lg)

            formLabel("choose a preset")
            VStack(spacing: 6) {
                ForEach(TaglineSystem.presets, id: \.self) { preset in
                    presetChip(preset)
                }
            }
            .padding(.bottom, DesignTokens.Spacing.md)

            formLabel("or write your own  ·  \(TaglineSystem.counterText(tagline.count))")
            TextField(TaglineSystem.defaultTagline, text: $tagline)
                .formInput()
                .onChange(of: tagline) { _, new in
                    if new.count > TaglineSystem.maxLength {
                        tagline = String(new.prefix(TaglineSystem.maxLength))
                    }
                    // Deselect preset if user types something custom
                    if !TaglineSystem.presets.contains(new) {
                        selectedPreset = ""
                    }
                }
        }
    }

    private var taglinePreviewCard: some View {
        VStack(spacing: 6) {
            Text("10px") // invisible spacer trick
                .font(.system(size: 1)).opacity(0)
            Text(name.isEmpty ? "their name" : name)
                .font(DesignTokens.Font.compassName)
                .foregroundColor(DesignTokens.Color.textPrimary)
            Text(resolvedTagline)
                .font(.system(size: 13).italic())
                .foregroundColor(DesignTokens.Color.accentMid)
                .multilineTextAlignment(.center)
                .animation(.easeOut(duration: 0.3), value: resolvedTagline)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Color.backgroundLift)
        .cornerRadius(DesignTokens.Radius.card)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.card)
                .stroke(DesignTokens.Color.border, lineWidth: 1)
        )
    }

    private func presetChip(_ preset: String) -> some View {
        let isSelected = selectedPreset == preset && tagline == preset
        return Button {
            selectedPreset = preset
            tagline        = preset
        } label: {
            HStack {
                Text(preset)
                    .font(.system(size: 13).italic())
                    .foregroundColor(isSelected
                                     ? DesignTokens.Color.accentSoft
                                     : DesignTokens.Color.textSecondary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DesignTokens.Color.accentSoft)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, 10)
            .background(isSelected
                        ? DesignTokens.Color.accentStrong
                        : DesignTokens.Color.backgroundCard)
            .cornerRadius(DesignTokens.Radius.button)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.button)
                    .stroke(isSelected
                            ? DesignTokens.Color.accentMid
                            : DesignTokens.Color.border,
                            lineWidth: 1)
            )
        }
    }

    // MARK: - Step 3: Address + Geocode

    private var stepThree: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Offline badge
            HStack(spacing: 6) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 11))
                Text("geocodes once · then fully offline")
                    .font(.system(size: 11))
            }
            .foregroundColor(DesignTokens.Color.accentMid)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(DesignTokens.Color.accentMid.opacity(0.1))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(DesignTokens.Color.accentMid.opacity(0.25), lineWidth: 1))
            .padding(.vertical, DesignTokens.Spacing.md)

            formLabel("their address")

            // Address input with clear button
            HStack {
                TextField("e.g. 10 Downing Street, London", text: $addressText)
                    .foregroundColor(DesignTokens.Color.textPrimary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .onChange(of: addressText) { _, new in
                        handleAddressInput(new)
                    }
                    .onSubmit { geocodeTypedAddress() }
                if !addressText.isEmpty {
                    Button { clearAddress() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(DesignTokens.Color.textMuted)
                    }
                }
            }
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.Color.backgroundCard)
            .cornerRadius(DesignTokens.Radius.button)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.button)
                    .stroke(DesignTokens.Color.border, lineWidth: 1)
            )
            .padding(.bottom, 8)

            // Live autocomplete suggestions (MKLocalSearchCompleter)
            if !autocomplete.suggestions.isEmpty {
                AddressSuggestionsList(suggestions: autocomplete.suggestions) { sug in
                    selectSuggestion(sug)
                }
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Geocode status
            geocodeStatusView
                .animation(.easeOut(duration: 0.3), value: geocodeState)

            // Error
            if let err = saveError {
                Text(err)
                    .font(DesignTokens.Font.caption)
                    .foregroundColor(.red)
                    .padding(.top, 8)
            }
        }
    }

    @ViewBuilder
    private var geocodeStatusView: some View {
        switch geocodeState {
        case .idle:
            EmptyView()

        case .searching:
            HStack(spacing: 10) {
                ProgressView()
                    .tint(DesignTokens.Color.accentSoft)
                    .scaleEffect(0.8)
                Text("searching…")
                    .font(DesignTokens.Font.caption)
                    .foregroundColor(DesignTokens.Color.textMuted)
            }
            .padding(DesignTokens.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.Color.backgroundCard)
            .cornerRadius(DesignTokens.Radius.button)

         case .geocoding(let address):
            HStack(spacing: 10) {
                ProgressView()
                    .tint(DesignTokens.Color.accentSoft)
                    .scaleEffect(0.8)
                Text("finding \"\(address)\"…")
                    .font(DesignTokens.Font.caption)
                    .foregroundColor(DesignTokens.Color.textMuted)
                    .lineLimit(1)
            }
            .padding(DesignTokens.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.Color.backgroundCard)
            .cornerRadius(DesignTokens.Radius.button)

        case .success(let location):
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color(hex: "#5dcaa5"))
                    .font(.system(size: 18))
                VStack(alignment: .leading, spacing: 2) {
                    Text(location.displayName)
                        .font(DesignTokens.Font.label)
                        .foregroundColor(DesignTokens.Color.textPrimary)
                    Text(coordString(location.coordinate))
                        .font(DesignTokens.Font.caption)
                        .foregroundColor(DesignTokens.Color.textMuted)
                    Text("stored offline · no further network needed")
                        .font(.system(size: 10))
                        .foregroundColor(DesignTokens.Color.textDim)
                }
                Spacer()
            }
            .padding(DesignTokens.Spacing.md)
            .background(Color(hex: "#5dcaa5").opacity(0.08))
            .cornerRadius(DesignTokens.Radius.button)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.button)
                    .stroke(Color(hex: "#5dcaa5").opacity(0.25), lineWidth: 1)
            )

        case .failure(let message):
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.circle")
                    .foregroundColor(.red)
                Text(message)
                    .font(DesignTokens.Font.caption)
                    .foregroundColor(.red)
            }
            .padding(DesignTokens.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.08))
            .cornerRadius(DesignTokens.Radius.button)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.button)
                    .stroke(Color.red.opacity(0.25), lineWidth: 1)
            )
        }
    }

    // MARK: - CTA bar

    private var ctaBar: some View {
        VStack(spacing: 0) {
            Divider().background(DesignTokens.Color.border)
            Button {
                handleCTA()
            } label: {
                Text(ctaLabel)
                    .font(DesignTokens.Font.label)
                    .foregroundColor(DesignTokens.Color.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(DesignTokens.Spacing.md)
                    .background(DesignTokens.Color.accentStrong)
                    .cornerRadius(DesignTokens.Radius.button)
            }
            .disabled(!ctaEnabled)
            .opacity(ctaEnabled ? 1 : 0.35)
            .padding(DesignTokens.Spacing.md)
        }
        .background(DesignTokens.Color.background)
    }

    private var ctaLabel: String {
        switch step {
        case 1:  return "next"
        case 2:  return "next"
        default: return "save"
        }
    }

    private var ctaEnabled: Bool {
        switch step {
        case 1:  return !name.trimmingCharacters(in: .whitespaces).isEmpty
        case 2:  return true   // tagline is optional
        default:
            if case .success = geocodeState { return true }
            return false
        }
    }

    // MARK: - Actions

    private func handleCTA() {
        saveError = nil
        if step < 3 {
            withAnimation(.easeOut(duration: 0.25)) { step += 1 }
            return
        }
        savePerson()
    }

    private func handleAddressInput(_ text: String) {
        // Skip the onChange triggered by us filling the field from a suggestion
        guard text != selectedAddressText else { return }
        selectedAddressText = nil

        geocodeTask?.cancel()
        geocodedLocation = nil
        geocodeState     = .idle
        autocomplete.updateQuery(text)
    }

    private func selectSuggestion(_ sug: AddressSuggestion) {
        selectedAddressText = sug.fullText
        addressText         = sug.fullText
        autocomplete.clear()
        geocodeState = .geocoding(sug.title)

        geocodeTask?.cancel()
        geocodeTask = Task {
            do {
                let result = try await autocomplete.resolve(sug)
                guard !Task.isCancelled else { return }
                geocodedLocation = result
                geocodeState     = .success(result)
            } catch let error as GeocodingError {
                guard !Task.isCancelled else { return }
                geocodeState = .failure(error.errorDescription ?? "Location not found.")
            } catch {
                guard !Task.isCancelled else { return }
                geocodeState = .failure(error.localizedDescription)
            }
        }
    }

    /// Fallback: user typed a full address and hit return without tapping a suggestion.
    private func geocodeTypedAddress() {
        let text = addressText.trimmingCharacters(in: .whitespaces)
        guard text.count >= 3 else { return }
        autocomplete.clear()
        geocodeState = .geocoding(text)

        geocodeTask?.cancel()
        geocodeTask = Task {
            do {
                let result = try await geocodingService.geocode(address: text)
                guard !Task.isCancelled else { return }
                geocodedLocation = result
                geocodeState     = .success(result)
            } catch let error as GeocodingError {
                guard !Task.isCancelled else { return }
                geocodeState = .failure(error.errorDescription ?? "Location not found.")
            } catch {
                guard !Task.isCancelled else { return }
                geocodeState = .failure(error.localizedDescription)
            }
        }
    }

    private func clearAddress() {
        geocodeTask?.cancel()
        autocomplete.clear()
        selectedAddressText = nil
        addressText         = ""
        geocodeState        = .idle
        geocodedLocation    = nil
    }

    private func savePerson() {
        guard let location = geocodedLocation else { return }

        guard people.canAddPerson() else {
            // Free tier holds one person — the unlock opens the rest
            showUnlock = true
            return
        }

        let finalTagline = tagline.trimmingCharacters(in: .whitespaces)
        let person = Person(
            name:    name.trimmingCharacters(in: .whitespaces),
            emoji:   emoji,
            geocoded: location,
            tagline: finalTagline.isEmpty ? nil : finalTagline
        )

        do {
            try people.addPerson(person)
            HapticEngine.connectionFelt()
            // Offer to invite them — the sheet's onDismiss closes this view
            showInviteShare = true
        } catch {
            saveError = error.localizedDescription
        }
    }

    // MARK: - Contacts

    private func applyContact(_ contact: CNContact) {
        let nickname = contact.nickname.trimmingCharacters(in: .whitespaces)
        let given    = contact.givenName.trimmingCharacters(in: .whitespaces)
        let family   = contact.familyName.trimmingCharacters(in: .whitespaces)
        let resolved = !nickname.isEmpty ? nickname : (!given.isEmpty ? given : family)
        if !resolved.isEmpty {
            name  = resolved
            emoji = Self.suggestedEmoji(for: resolved, fallback: emoji)
        }

        // Pre-fill the address step if the contact has a postal address —
        // and geocode it right away so the address arrives at step 3 already
        // confirmed (otherwise geocodeState stays .idle and save is disabled).
        if let postal = contact.postalAddresses.first?.value {
            let formatted = CNPostalAddressFormatter.string(from: postal, style: .mailingAddress)
                .replacingOccurrences(of: "\n", with: ", ")
                .trimmingCharacters(in: .whitespaces)
            if !formatted.isEmpty {
                selectedAddressText = formatted   // don't re-trigger the suggestion search
                addressText         = formatted
                geocodeTypedAddress()
            }
        }
    }

    /// Light-touch emoji guess from the contact's name; falls back to the current pick.
    private static func suggestedEmoji(for name: String, fallback: String) -> String {
        let n = name.lowercased()
        if n.contains("mum") || n.contains("mom") || n.contains("mother")   { return "💜" }
        if n.contains("dad") || n.contains("father")                        { return "🏠" }
        if n.contains("nana") || n.contains("gran") || n.contains("nan ")   { return "🌸" }
        if n.contains("home")                                               { return "🏠" }
        return fallback
    }

    private var inviteMessage: String {
        "I added you on Pointward \(emoji) — my compass now always points your way. Get Pointward and add me back: https://pointward.app"
    }

    // MARK: - Helpers

    private var resolvedTagline: String {
        let t = tagline.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? TaglineSystem.defaultTagline : t
    }

    private func coordString(_ coord: CLLocationCoordinate2D) -> String {
        String(format: "%.4f°, %.4f° · stored offline", coord.latitude, coord.longitude)
    }

    private func formLabel(_ text: String) -> some View {
        Text(text)
            .font(DesignTokens.Font.overline)
            .foregroundColor(DesignTokens.Color.textMuted)
            .padding(.bottom, 8)
    }
}

// MARK: - Supporting types

/// Tappable dropdown of live address suggestions — shared by
/// AddPersonView and EditPersonView (Apple Maps-style autocomplete).
struct AddressSuggestionsList: View {
    let suggestions: [AddressSuggestion]
    let onSelect: (AddressSuggestion) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(suggestions) { sug in
                Button {
                    onSelect(sug)
                } label: {
                    HStack {
                        Image(systemName: "mappin.circle")
                            .font(.system(size: 14))
                            .foregroundColor(DesignTokens.Color.accentMid)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sug.title)
                                .font(DesignTokens.Font.label)
                                .foregroundColor(DesignTokens.Color.textPrimary)
                                .lineLimit(1)
                            if !sug.subtitle.isEmpty {
                                Text(sug.subtitle)
                                    .font(DesignTokens.Font.caption)
                                    .foregroundColor(DesignTokens.Color.textMuted)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Image(systemName: "arrow.up.left")
                            .font(.system(size: 11))
                            .foregroundColor(DesignTokens.Color.textDim)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                if sug != suggestions.last {
                    Divider()
                        .background(DesignTokens.Color.border)
                        .padding(.leading, DesignTokens.Spacing.md)
                }
            }
        }
        .background(DesignTokens.Color.backgroundCard)
        .cornerRadius(DesignTokens.Radius.button)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.button)
                .stroke(DesignTokens.Color.border, lineWidth: 1)
        )
    }
}

enum GeocodeState: Equatable {
    case idle
    case searching
    case geocoding(String)
    case success(GeocodedLocation)
    case failure(String)
}

// MARK: - EmojiPickerRow

struct EmojiPickerRow: View {
    @Binding var selected: String
    @State private var customInput = ""
    @FocusState private var customFocused: Bool

    private let options = ["🏠","💜","🌿","🌙","✨","🤗","🌸","☀️","🐾","🎸","⛺️","🌊"]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // A custom pick that isn't in the presets shows as its own chip
                if !options.contains(selected) && !selected.isEmpty {
                    chip(selected)
                }

                ForEach(options, id: \.self) { e in
                    chip(e)
                }

                // "+" — any emoji via the native keyboard
                ZStack {
                    // Invisible field summons the system (emoji) keyboard
                    TextField("", text: $customInput)
                        .focused($customFocused)
                        .opacity(0.02)
                        .frame(width: 46, height: 46)
                        .onChange(of: customInput) { _, new in
                            guard let last = new.last else { return }
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                selected = String(last)
                            }
                            customInput   = ""
                            customFocused = false
                        }
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(DesignTokens.Color.accentSoft)
                        .frame(width: 46, height: 46)
                        .background(DesignTokens.Color.backgroundCard)
                        .cornerRadius(13)
                        .overlay(
                            RoundedRectangle(cornerRadius: 13)
                                .stroke(customFocused
                                        ? DesignTokens.Color.accentMid
                                        : DesignTokens.Color.border,
                                        style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        )
                        .allowsHitTesting(false)
                }
                .onTapGesture { customFocused = true }
            }
            .padding(.bottom, 4)
        }
    }

    private func chip(_ e: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                selected = e
            }
        } label: {
            Text(e)
                .font(.system(size: 22))
                .frame(width: 46, height: 46)
                .background(selected == e
                            ? DesignTokens.Color.accentStrong
                            : DesignTokens.Color.backgroundCard)
                .cornerRadius(13)
                .overlay(
                    RoundedRectangle(cornerRadius: 13)
                        .stroke(selected == e
                                ? DesignTokens.Color.accentMid
                                : DesignTokens.Color.border,
                                lineWidth: 1)
                )
                .scaleEffect(selected == e ? 1.08 : 1.0)
        }
    }
}

// MARK: - TextField modifier

extension View {
    func formInput() -> some View {
        self
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.Color.backgroundCard)
            .cornerRadius(DesignTokens.Radius.button)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.button)
                    .stroke(DesignTokens.Color.border, lineWidth: 1)
            )
            .foregroundColor(DesignTokens.Color.textPrimary)
    }
}

// MARK: - Preview

#Preview {
    AddPersonView(geocodingService: MockGeocodingService())
        .environmentObject(PeopleManager(subscriptionManager: SubscriptionManager()))
        .preferredColorScheme(.dark)
}
