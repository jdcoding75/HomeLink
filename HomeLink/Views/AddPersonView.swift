// AddPersonView.swift
// HomeLink › Views
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
    @State private var suggestions: [GeocodeSuggestion] = []
    @State private var geocodeTask: Task<Void, Never>? = nil
    @State private var geocodeState: GeocodeState = .idle
    @State private var geocodedLocation: GeocodedLocation? = nil

    // Error / paywall
    @State private var showPaywall = false
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
        .sheet(isPresented: $showPaywall) {
            PaywallView()
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
                    .onChange(of: addressText) { _, new in
                        handleAddressInput(new)
                    }
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

            // Suggestions list
            if !suggestions.isEmpty {
                suggestionsList
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

    private var suggestionsList: some View {
        VStack(spacing: 0) {
            ForEach(suggestions) { sug in
                Button {
                    selectSuggestion(sug)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sug.displayName)
                                .font(DesignTokens.Font.label)
                                .foregroundColor(DesignTokens.Color.textPrimary)
                            Text(sug.fullAddress)
                                .font(DesignTokens.Font.caption)
                                .foregroundColor(DesignTokens.Color.textMuted)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.left")
                            .font(.system(size: 11))
                            .foregroundColor(DesignTokens.Color.textDim)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, 10)
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
        geocodeTask?.cancel()
        geocodedLocation = nil
        suggestions      = []

        guard text.count >= 3 else {
            geocodeState = .idle
            return
        }

        geocodeState = .searching

        geocodeTask = Task {
            // Small debounce so we don't fire on every keystroke
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }

            geocodeState = .geocoding(text)

            do {
                let result = try await geocodingService.geocode(address: text)
                guard !Task.isCancelled else { return }
                geocodedLocation = result
                geocodeState     = .success(result)
                suggestions      = []   // clear list once confirmed
            } catch let error as GeocodingError {
                guard !Task.isCancelled else { return }
                geocodeState = .failure(error.errorDescription ?? "Location not found.")
            } catch {
                guard !Task.isCancelled else { return }
                geocodeState = .failure(error.localizedDescription)
            }
        }
    }

    private func selectSuggestion(_ sug: GeocodeSuggestion) {
        addressText  = sug.fullAddress
        suggestions  = []
        geocodeState = .geocoding(sug.displayName)

        geocodeTask?.cancel()
        geocodeTask = Task {
            do {
                let result = try await geocodingService.geocode(address: sug.fullAddress)
                guard !Task.isCancelled else { return }
                geocodedLocation = result
                geocodeState     = .success(result)
            } catch let error as GeocodingError {
                geocodeState = .failure(error.errorDescription ?? "Location not found.")
            } catch {
                geocodeState = .failure(error.localizedDescription)
            }
        }
    }

    private func clearAddress() {
        geocodeTask?.cancel()
        addressText      = ""
        suggestions      = []
        geocodeState     = .idle
        geocodedLocation = nil
    }

    private func savePerson() {
        guard let location = geocodedLocation else { return }

        guard people.canAddPerson() else {
            showPaywall = true
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
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
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

/// Lightweight suggestion model — separate from GeocodedLocation
/// so we can display instant local suggestions before committing a full geocode.
struct GeocodeSuggestion: Identifiable, Equatable {
    let id = UUID()
    let displayName: String
    let fullAddress: String
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
    private let options = ["🏠","💜","🌿","🌙","✨","🫂","🌸","☀️","🐾","🎸","⛺️","🌊"]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { e in
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
            .padding(.bottom, 4)
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
