// EditPersonView.swift
// Pointward › Views
//
// Presented as a sheet from PeopleListView when the user taps "edit" on a card.
// Pre-populates all fields from the existing Person model.
// Re-geocodes only if the address field changes — preserves the stored coordinate
// if the user edits name/emoji/tagline only (stays offline, no network hit).

import SwiftUI
import CoreLocation

struct EditPersonView: View {

    // MARK: - Input
    let person: Person
    let geocodingService: GeocodingServiceProtocol

    // MARK: - Environment
    @EnvironmentObject var people: PeopleManager
    @Environment(\.dismiss) var dismiss

    // MARK: - Form state (pre-populated from person)
    @State private var name:  String
    @State private var emoji: String
    @State private var tagline: String
    @State private var selectedPreset: String

    // Address state
    @State private var addressText: String
    @StateObject private var autocomplete = AddressAutocompleteService()
    @State private var selectedAddressText: String? = nil  // skip re-searching text we just filled in
    @State private var geocodeState: GeocodeState
    @State private var geocodedLocation: GeocodedLocation?
    @State private var geocodeTask: Task<Void, Never>? = nil
    @State private var addressChanged = false   // only re-geocode if address edited

    // UI state
    @State private var showDeleteConfirm = false
    @State private var saveError: String? = nil

    // MARK: - Init

    init(person: Person, geocodingService: GeocodingServiceProtocol) {
        self.person           = person
        self.geocodingService = geocodingService

        // Pre-populate from model
        _name            = State(initialValue: person.name)
        _emoji           = State(initialValue: person.emoji)
        _tagline         = State(initialValue: person.tagline ?? "")
        _selectedPreset  = State(initialValue: person.tagline ?? "")
        _addressText     = State(initialValue: person.displayAddress)

        // Show the stored location as already-confirmed so the save button is enabled
        let stored = GeocodedLocation(
            displayName: person.locationDisplayName,
            fullAddress: person.displayAddress,
            coordinate:  person.coordinate,
            country:     nil,
            postalCode:  nil
        )
        _geocodeState     = State(initialValue: .success(stored))
        _geocodedLocation = State(initialValue: stored)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            DesignTokens.Color.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        livePreviewCard
                            .padding(.vertical, DesignTokens.Spacing.lg)
                        Divider()
                            .background(DesignTokens.Color.border)
                            .padding(.bottom, DesignTokens.Spacing.lg)
                        nameSection
                        emojiSection
                        taglineSection
                        addressSection
                        deleteSection
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.bottom, 100)
                }
                ctaBar
            }
        }
        .confirmationDialog(
            "delete \(name)?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("delete", role: .destructive) { deletePerson() }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("this can't be undone")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button("cancel") { dismiss() }
                .font(DesignTokens.Font.label)
                .foregroundColor(DesignTokens.Color.textMuted)
            Spacer()
            Text("edit person")
                .font(DesignTokens.Font.label)
                .foregroundColor(DesignTokens.Color.textPrimary)
            Spacer()
            Button("save") { savePerson() }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(saveEnabled
                                 ? DesignTokens.Color.accentSoft
                                 : DesignTokens.Color.textDim)
                .disabled(!saveEnabled)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
    }

    // MARK: - Live preview card

    private var livePreviewCard: some View {
        VStack(spacing: 6) {
            Text(emoji)
                .font(.system(size: 40))
                .id(emoji) // re-animate on emoji change
                .transition(.scale.combined(with: .opacity))

            Text(name.isEmpty ? "their name" : name)
                .font(DesignTokens.Font.compassName)
                .foregroundColor(DesignTokens.Color.textPrimary)

            Text(resolvedTagline)
                .font(.system(size: 13).italic())
                .foregroundColor(DesignTokens.Color.accentMid)
                .multilineTextAlignment(.center)
                .animation(.easeOut(duration: 0.3), value: resolvedTagline)

            if case .success(let loc) = geocodeState {
                Text(loc.displayName)
                    .font(DesignTokens.Font.caption)
                    .foregroundColor(DesignTokens.Color.textMuted)
                    .padding(.top, 2)
            }
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

    // MARK: - Name

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            formLabel("name")
            TextField("Mum, Dad, Home…", text: $name)
                .formInput()
                .padding(.bottom, DesignTokens.Spacing.md)
        }
    }

    // MARK: - Emoji

    private var emojiSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            formLabel("emoji")
            EmojiPickerRow(selected: $emoji)
                .padding(.bottom, DesignTokens.Spacing.md)
        }
    }

    // MARK: - Tagline

    private var taglineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                formLabel("tagline")
                Spacer()
                Text(TaglineSystem.counterText(tagline.count))
                    .font(.system(size: 11))
                    .foregroundColor(counterColor)
            }

            TextField(TaglineSystem.defaultTagline, text: $tagline)
                .formInput()
                .onChange(of: tagline) { _, new in
                    if new.count > TaglineSystem.maxLength {
                        tagline = String(new.prefix(TaglineSystem.maxLength))
                    }
                    if !TaglineSystem.presets.contains(new) { selectedPreset = "" }
                }
                .padding(.bottom, 10)

            VStack(spacing: 6) {
                ForEach(TaglineSystem.presets, id: \.self) { preset in
                    presetChip(preset)
                }
            }
            .padding(.bottom, DesignTokens.Spacing.md)

            Divider().background(DesignTokens.Color.border)
                .padding(.bottom, DesignTokens.Spacing.md)
        }
    }

    // MARK: - Address

    private var addressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            formLabel("location")

            // Current stored location (non-editable summary until user taps change)
            if !addressChanged, case .success(let loc) = geocodeState {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loc.displayName)
                            .font(DesignTokens.Font.label)
                            .foregroundColor(DesignTokens.Color.textPrimary)
                        Text(loc.fullAddress)
                            .font(DesignTokens.Font.caption)
                            .foregroundColor(DesignTokens.Color.textMuted)
                            .lineLimit(1)
                        Text(coordString(loc.coordinate))
                            .font(.system(size: 10))
                            .foregroundColor(DesignTokens.Color.textDim)
                    }
                    Spacer()
                    Button("change") { startAddressEdit() }
                        .font(DesignTokens.Font.caption)
                        .foregroundColor(DesignTokens.Color.accentSoft)
                }
                .padding(DesignTokens.Spacing.md)
                .background(DesignTokens.Color.backgroundCard)
                .cornerRadius(DesignTokens.Radius.button)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.button)
                        .stroke(DesignTokens.Color.border, lineWidth: 1)
                )
                .padding(.bottom, DesignTokens.Spacing.md)

            } else {
                // Active address editor with live autocomplete
                HStack {
                    TextField("search for an address…", text: $addressText)
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

                geocodeStatusView
                    .animation(.easeOut(duration: 0.3), value: geocodeState)
                    .padding(.bottom, 8)

                // Way back if the user tapped "change" by mistake
                Button {
                    revertAddressEdit()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 11))
                        Text("keep current address")
                            .font(DesignTokens.Font.caption)
                    }
                    .foregroundColor(DesignTokens.Color.textMuted)
                }
                .padding(.bottom, DesignTokens.Spacing.md)
            }

            Divider().background(DesignTokens.Color.border)
                .padding(.bottom, DesignTokens.Spacing.md)
        }
    }

    // MARK: - Geocode status (reused from AddPersonView pattern)

    @ViewBuilder
    private var geocodeStatusView: some View {
        switch geocodeState {
        case .idle:
            EmptyView()

        case .searching, .geocoding:
            HStack(spacing: 10) {
                ProgressView().tint(DesignTokens.Color.accentSoft).scaleEffect(0.8)
                Text("finding location…")
                    .font(DesignTokens.Font.caption)
                    .foregroundColor(DesignTokens.Color.textMuted)
            }
            .padding(DesignTokens.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.Color.backgroundCard)
            .cornerRadius(DesignTokens.Radius.button)

        case .success(let loc):
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color(hex: "#5dcaa5"))
                VStack(alignment: .leading, spacing: 1) {
                    Text(loc.displayName)
                        .font(DesignTokens.Font.label)
                        .foregroundColor(DesignTokens.Color.textPrimary)
                    Text(coordString(loc.coordinate))
                        .font(DesignTokens.Font.caption)
                        .foregroundColor(DesignTokens.Color.textMuted)
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

        case .failure(let msg):
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.circle")
                    .foregroundColor(.red)
                Text(msg)
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

    // MARK: - Delete

    private var deleteSection: some View {
        Button {
            showDeleteConfirm = true
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("delete \(name.isEmpty ? "person" : name)")
            }
            .font(DesignTokens.Font.label)
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding(DesignTokens.Spacing.md)
            .background(Color.red.opacity(0.08))
            .cornerRadius(DesignTokens.Radius.button)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.button)
                    .stroke(Color.red.opacity(0.25), lineWidth: 1)
            )
        }
        .padding(.top, DesignTokens.Spacing.sm)
    }

    // MARK: - CTA bar

    private var ctaBar: some View {
        VStack(spacing: 0) {
            if let err = saveError {
                Text(err)
                    .font(DesignTokens.Font.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.top, DesignTokens.Spacing.sm)
            }
            Divider().background(DesignTokens.Color.border)
            Button { savePerson() } label: {
                Text("save changes")
                    .font(DesignTokens.Font.label)
                    .foregroundColor(DesignTokens.Color.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(DesignTokens.Spacing.md)
                    .background(DesignTokens.Color.accentStrong)
                    .cornerRadius(DesignTokens.Radius.button)
            }
            .disabled(!saveEnabled)
            .opacity(saveEnabled ? 1 : 0.35)
            .padding(DesignTokens.Spacing.md)
        }
        .background(DesignTokens.Color.background)
    }

    // MARK: - Preset chip

    private func presetChip(_ preset: String) -> some View {
        let isSelected = tagline == preset
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

    // MARK: - Address editing

    /// "change" tapped — switch to the autocomplete editor with a blank field.
    private func startAddressEdit() {
        geocodeTask?.cancel()
        autocomplete.clear()
        selectedAddressText = nil
        addressText         = ""
        geocodedLocation    = nil
        geocodeState        = .idle
        withAnimation { addressChanged = true }
    }

    /// "keep current address" tapped — restore the stored location untouched.
    private func revertAddressEdit() {
        geocodeTask?.cancel()
        autocomplete.clear()
        selectedAddressText = storedLocation.fullAddress
        addressText         = storedLocation.fullAddress
        geocodedLocation    = storedLocation
        geocodeState        = .success(storedLocation)
        withAnimation { addressChanged = false }
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

    // MARK: - Save / Delete

    private func savePerson() {
        saveError = nil

        // Resolve final location — stored coordinate unless the address was edited
        let finalLocation = addressChanged ? geocodedLocation : storedLocation

        guard let location = finalLocation else {
            saveError = "Please confirm a location before saving."
            return
        }

        let trimmedTagline = tagline.trimmingCharacters(in: .whitespaces)

        // Mutate the SwiftData model directly (it's a reference type)
        person.name                = name.trimmingCharacters(in: .whitespaces)
        person.emoji               = emoji
        person.tagline             = trimmedTagline.isEmpty ? nil : trimmedTagline
        person.latitude            = location.coordinate.latitude
        person.longitude           = location.coordinate.longitude
        person.displayAddress      = location.fullAddress
        person.locationDisplayName = location.displayName

        do {
            try people.save()
            HapticEngine.connectionFelt()
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func deletePerson() {
        do {
            try people.deletePerson(person)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    // MARK: - Computed helpers

    /// The person's currently-saved location, as a GeocodedLocation.
    private var storedLocation: GeocodedLocation {
        GeocodedLocation(
            displayName: person.locationDisplayName,
            fullAddress: person.displayAddress,
            coordinate:  person.coordinate,
            country:     nil,
            postalCode:  nil
        )
    }

    private var saveEnabled: Bool {
        let nameOk = !name.trimmingCharacters(in: .whitespaces).isEmpty
        if addressChanged {
            if case .success = geocodeState { return nameOk }
            return false
        }
        return nameOk
    }

    private var resolvedTagline: String {
        let t = tagline.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? TaglineSystem.defaultTagline : t
    }

    private var counterColor: Color {
        switch TaglineSystem.counterState(tagline.count) {
        case .normal:  return DesignTokens.Color.textDim
        case .warning: return Color(hex: "#c4845a")
        case .atLimit: return .red
        }
    }

    private func coordString(_ coord: CLLocationCoordinate2D) -> String {
        String(format: "%.4f°, %.4f°", coord.latitude, coord.longitude)
    }

    private func formLabel(_ text: String) -> some View {
        Text(text)
            .font(DesignTokens.Font.overline)
            .foregroundColor(DesignTokens.Color.textMuted)
    }
}

// MARK: - Preview

#Preview {
    let person = Person(
        name: "Mum",
        emoji: "🏠",
        latitude: 51.5074,
        longitude: -0.1278,
        displayAddress: "London, UK",
        locationDisplayName: "London",
        tagline: "Never far."
    )
    return EditPersonView(person: person, geocodingService: MockGeocodingService())
        .environmentObject(PeopleManager(subscriptionManager: SubscriptionManager()))
        .preferredColorScheme(.dark)
}
