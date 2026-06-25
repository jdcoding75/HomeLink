// AddPersonView.swift
// Pointward › Views
//
// Presented as a sheet from PeopleListView when the user taps "+".
// Owns the full add-person flow:
//   Step 1 — name + emoji
//   Step 2 — address with live geocoding
//
// (Per-person taglines were removed — taglines now travel with thoughts
//  automatically, and the compass has its own rotating taglines.)
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
    // [copy-declutter ITEM 8a] step machine removed — single-screen form.
    // @State private var step: Int = 1

    // Step 1
    @State private var name: String = ""
    @State private var emoji: String = "🏠"

    // Step 2
    @State private var addressText: String = ""
    @StateObject private var autocomplete = AddressAutocompleteService()
    @State private var selectedAddressText: String? = nil  // skip re-searching text we just filled in
    @State private var geocodeTask: Task<Void, Never>? = nil
    @State private var geocodeState: GeocodeState = .idle
    @State private var geocodedLocation: GeocodedLocation? = nil

    // Contacts / invite
    @State private var showContactPicker = false
    // [contacts-pick] 1c/2c-ii — captured from the picked iOS contact, carried onto
    // the Person at save. Channel defaults phone(SMS)→email (PeopleManager.defaultSendChannel).
    @State private var contactPhone: String? = nil
    @State private var contactEmail: String? = nil
    @State private var sendChannel:  String? = nil
    @State private var photoData:    Data?   = nil
    // [cleanup #4a/#4b] forced invite-share on add — REMOVED (add = create + dismiss).
    // @State private var showInviteShare = false

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

                // [copy-declutter ITEM 8a] progressDots removed — single-screen form.

                // Single-screen form: contacts → name → optional address
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // [copy-declutter ITEM 8a] merged stepOne + stepThree onto one screen
                        stepOne
                        stepThree
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
        // [cleanup #4a/#4b] forced invite-share sheet on add — REMOVED. Adding a
        // person no longer auto-presents a share / sends an "I added you" SMS.
        // .sheet(isPresented: $showInviteShare, onDismiss: { dismiss() }) {
        //     ActivityShareSheet(items: [inviteMessage])
        //         .presentationDetents([.medium, .large])
        // }
    }

    // MARK: - Header

    private var sheetHeader: some View {
        HStack {
            // [copy-declutter ITEM 8a] step "back" button removed (single-screen form)
            Spacer()
            Text("add person")
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

    // [copy-declutter ITEM 8a] step progress dots removed — single-screen form (preserved).
    #if false
    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(1...2, id: \.self) { s in
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
    #endif

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

            // [contacts-pick] 1a — LEAD with the iOS Contacts pick (the HERO/primary
            // action): picking gives a stable identity anchor (name/phone/email/address)
            // → fewer dup/wrong-person contacts + no naming drift, and captures the
            // delivery channel. Manual entry is the secondary affordance below.
            Button {
                showContactPicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 16, weight: .medium))
                    Text("choose from contacts")
                        .font(DesignTokens.Font.label)
                }
                .foregroundColor(DesignTokens.Color.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(DesignTokens.Spacing.md)
                .background(DesignTokens.Color.accentStrong)
                .cornerRadius(DesignTokens.Radius.button)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.button)
                        .stroke(DesignTokens.Color.accentMid.opacity(0.5), lineWidth: 1)
                )
            }
            .padding(.bottom, DesignTokens.Spacing.md)

            // Secondary: enter manually. (Picking fills the name; you can still edit it.)
            formLabel("or enter their name")
            TextField("Mum, Dad, Home, Nan…", text: $name)
                .formInput()
                .padding(.bottom, DesignTokens.Spacing.sm)

            // [copy-declutter ITEM 8b] emoji picker hidden (preserved); @State emoji = "🏠"
            // is kept and still flows to Person.emoji at save.
            // formLabel("their emoji")
            // EmojiPickerRow(selected: $emoji)
            //     .padding(.bottom, DesignTokens.Spacing.sm)
        }
    }

    // MARK: - Step 2: Address + Geocode

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

            // [copy-declutter ITEM 8a] address labeled optional — bottom "save" (name-only)
            // already saves a no-address person, so the field is skippable.
            formLabel("their address (optional)")

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

            // [copy-declutter ITEM 8a] inline "skip — add address later" button DROPPED —
            // redundant on the collapsed one-screen form (the bottom name-only "save"
            // already saves a no-address person; the field is labeled optional). Preserved:
            /*
            // [contacts-pick] 1e — don't force an address. Save now and add it later
            // (the compass shows the add-location hint until then). Hidden once an
            // address has resolved (the primary "save" CTA covers that case).
            if !isGeocodeSuccess {
                Button {
                    saveError = nil
                    savePerson()
                } label: {
                    Text("skip — add address later")
                        .font(.system(size: 13, design: .serif).italic())
                        .foregroundColor(DesignTokens.Color.accentSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.Spacing.md)
                }
                .padding(.top, 8)
            }
            */
        }
    }

    // [copy-declutter ITEM 8a] isGeocodeSuccess preserved (only the skip button used it).
    /// True once Step-2 geocoding has resolved a location (drives the CTA + hides skip).
    private var isGeocodeSuccess: Bool {
        if case .success = geocodeState { return true }
        return false
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

    // [copy-declutter ITEM 8a] single-screen form: always "save", enabled on name-only
    // (address is optional). Old step-based rules preserved below.
    private var ctaLabel: String {
        "save"
        // switch step { case 1: return "next"; default: return "save" }
    }

    private var ctaEnabled: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
        // switch step {
        // case 1:  return !name.trimmingCharacters(in: .whitespaces).isEmpty
        // default:
        //     if case .success = geocodeState { return true }
        //     return false
        // }
    }

    // MARK: - Actions

    private func handleCTA() {
        saveError = nil
        // [copy-declutter ITEM 8a] step<2 advance branch removed — single-screen form saves directly.
        // if step < 2 { withAnimation(.easeOut(duration: 0.25)) { step += 1 }; return }
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
        guard people.canAddPerson() else {
            // Free tier holds one person — the unlock opens the rest
            showUnlock = true
            return
        }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        // [contacts-pick] 1e — address is now SKIPPABLE. With a geocoded location we
        // build the located contact as before; without one we create a zero-location
        // contact (the People list shows the gentle "add location" hint until an
        // address is set later in EditPersonView). Save is no longer gated on geocode.
        let person: Person
        if let location = geocodedLocation {
            person = Person(name: trimmedName, emoji: emoji, geocoded: location)
        } else {
            person = Person(name: trimmedName, emoji: emoji, latitude: 0, longitude: 0)
        }

        // [contacts-pick] 1c/2c-ii — carry the captured delivery channel + photo onto
        // the contact (nil for a manual add with no picked contact).
        person.contactPhone = contactPhone
        person.contactEmail = contactEmail
        person.sendChannel  = sendChannel
        person.photoData    = photoData

        do {
            try people.addPerson(person)
            HapticEngine.connectionFelt()   // cosmetic "added" haptic (kept)
            // [cleanup #4a/#4b] Add = JUST create the contact, then close. The
            // pairing-era forced invite-share (which sent the cold "I added you on
            // Pointward" SMS — #4b) is removed. The link model invites via a real
            // sent THOUGHT, not an "added you" ping.
            // [pre-cleanup] Offer to invite them — the sheet's onDismiss closes this view
            // showInviteShare = true
            dismiss()
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
        // [contacts-pick] 1b — pick → FILL → edit (never type → pick → OVERWRITE):
        // fill the name from the contact only when the user hasn't already typed one;
        // they edit it on top afterwards (e.g. "Jessica Smith" → "Momma").
        if !resolved.isEmpty, name.trimmingCharacters(in: .whitespaces).isEmpty {
            name  = resolved
            emoji = Self.suggestedEmoji(for: resolved, fallback: emoji)
        }

        // [contacts-pick] 1c — capture the DELIVERY CHANNEL (phone/SMS first, email
        // fallback). Guard each key with isKeyAvailable — the picker hands back a
        // contact fetched with a limited key set; reading an unfetched key throws.
        if contact.isKeyAvailable(CNContactPhoneNumbersKey),
           let phone = contact.phoneNumbers.first?.value.stringValue
               .trimmingCharacters(in: .whitespaces), !phone.isEmpty {
            contactPhone = phone
        }
        if contact.isKeyAvailable(CNContactEmailAddressesKey),
           let email = (contact.emailAddresses.first?.value as String?)?
               .trimmingCharacters(in: .whitespaces), !email.isEmpty {
            contactEmail = email
        }
        sendChannel = PeopleManager.defaultSendChannel(phone: contactPhone, email: contactEmail)

        // [contacts-pick] 2c-ii — minimal photo: the contact's thumbnail, rendered in
        // the People-list avatar (else monogram). Guard the key (image data is often
        // NOT fetched by the picker → reading it unguarded would throw).
        if contact.isKeyAvailable(CNContactThumbnailImageDataKey) {
            photoData = contact.thumbnailImageData
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

    // [cleanup #4b] the cold "I added you on Pointward" SMS — REMOVED (was the body
    // of the forced invite-share above). The link model invites via a real thought.
    // private var inviteMessage: String {
    //     "I added you on Pointward \(emoji) — my compass now always points your way. Get Pointward and add me back: https://pointward.app"
    // }

    // MARK: - Helpers

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
