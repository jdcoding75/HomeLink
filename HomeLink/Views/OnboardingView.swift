// OnboardingView.swift
// Pointward › Views
//
// Shown on first launch when hasCompletedOnboarding == false.
// Five steps: welcome → name+emoji → address → permissions → compass set.
// (Taglines moved to Edit Person — keep first-run friction low.)
// The last step is a ritual, not a form: the needle swings, settles on them,
// and the screen breathes before the user opens their compass.
// On completion writes hasCompletedOnboarding = true and dismisses itself.
// RootView then shows the main tab interface.

import SwiftUI
import CoreLocation

struct OnboardingView: View {

    // MARK: - Environment
    @EnvironmentObject var people:       PeopleManager
    @EnvironmentObject var subscription: SubscriptionManager

    let geocodingService: GeocodingServiceProtocol

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    // MARK: - Step state
    @State private var step: Int = 1

    // Step 2
    @State private var name:  String = ""
    @State private var emoji: String = "🏠"

    // Step 3
    @State private var addressText:      String = ""
    @StateObject private var autocomplete = AddressAutocompleteService()
    @State private var selectedAddressText: String? = nil  // skip re-searching text we just filled in
    @State private var geocodeState:     GeocodeState = .idle
    @State private var geocodedLocation: GeocodedLocation? = nil
    @State private var geocodeTask:      Task<Void, Never>? = nil

    // Step 4
    @State private var notificationsRequested = false
    // Owned here so the location popup fires the moment the user taps the
    // permissions-step CTA (authorization is app-wide; any instance works)
    private let locationManager = CLLocationManager()

    // Step 5 — compass set ritual staging
    @State private var ritualNeedleAngle: Double = 150
    @State private var ritualGlow         = false
    @State private var ritualPulse        = false   // ongoing soft emoji pulse
    @State private var ritualRingExpand   = false   // one-shot expanding glow ring
    @State private var ritualNameShown    = false
    @State private var ritualTaglineShown = false
    @State private var ritualSetShown     = false
    @State private var ritualButtonShown  = false

    // MARK: - Body

    var body: some View {
        ZStack {
            DesignTokens.Color.background.ignoresSafeArea()

            // Deeper purple breath behind the final ritual
            if step == 5 {
                RadialGradient(
                    colors: [Color(hex: "#2a1d45").opacity(0.8), .clear],
                    center: .center, startRadius: 30, endRadius: 380
                )
                .ignoresSafeArea()
                .transition(.opacity)
            }

            VStack(spacing: 0) {
                // Progress dots — hidden on welcome and on the ritual
                if step > 1 && step < 5 {
                    progressDots
                        .padding(.top, 16)
                        .padding(.bottom, 4)
                        .transition(.opacity)
                }

                if step == 5 {
                    // The ritual owns the whole screen — no scroll, no form chrome
                    compassSetStep
                } else {
                    // Step content
                    ScrollView {
                        VStack {
                            switch step {
                            case 1:  welcomeStep
                            case 2:  nameStep
                            case 3:  addressStep
                            default: permissionsStep
                            }
                        }
                        .padding(.horizontal, 28)
                        .padding(.bottom, 40)
                    }

                    // CTA
                    ctaBar
                }
            }
        }
        .animation(.easeOut(duration: 0.28), value: step)
    }

    // MARK: - Progress dots

    private var progressDots: some View {
        HStack(spacing: 6) {
            // Step 1 is welcome — dots represent steps 2–4
            ForEach(2...4, id: \.self) { s in
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

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 32)

            // Brand orb
            ZStack {
                Circle()
                    .stroke(DesignTokens.Color.accentMid.opacity(0.3), lineWidth: 1)
                    .frame(width: 96, height: 96)
                Circle()
                    .stroke(DesignTokens.Color.accentMid.opacity(0.12), lineWidth: 1)
                    .frame(width: 114, height: 114)
                Circle()
                    .stroke(DesignTokens.Color.accentMid.opacity(0.06), lineWidth: 1)
                    .frame(width: 130, height: 130)
                Text("🧭")
                    .font(.system(size: 42))
            }
            .padding(.bottom, 28)

            Text("welcome to Pointward")
                .font(DesignTokens.Font.compassName)
                .foregroundColor(DesignTokens.Color.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 10)

            Text("a compass that points toward the people and places you love")
                .font(DesignTokens.Font.compassDistance)
                .foregroundColor(DesignTokens.Color.textMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.bottom, 36)

            // Value props
            VStack(spacing: 0) {
                valueProp(icon: "antenna.radiowaves.left.and.right",
                          title: "fully offline",
                          body: "we geocode your address once, then everything runs on your device — no account, no subscription needed")

                Divider().background(DesignTokens.Color.border)

                valueProp(icon: "lock",
                          title: "private by design",
                          body: "your locations never leave your phone unless you choose to share them")

                Divider().background(DesignTokens.Color.border)

                valueProp(icon: "compass.drawing",
                          title: "always present",
                          body: "the needle lives right on your home screen")
            }
            .background(DesignTokens.Color.backgroundCard)
            .cornerRadius(DesignTokens.Radius.card)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.card)
                    .stroke(DesignTokens.Color.border, lineWidth: 1)
            )

            Spacer(minLength: 24)
        }
    }

    private func valueProp(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(DesignTokens.Color.accentSoft)
                .frame(width: 24)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(DesignTokens.Font.label)
                    .foregroundColor(DesignTokens.Color.textPrimary)
                Text(body)
                    .font(DesignTokens.Font.caption)
                    .foregroundColor(DesignTokens.Color.textMuted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Step 2: Name + Emoji

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Preview orb
            ZStack {
                Circle()
                    .stroke(DesignTokens.Color.accentMid.opacity(0.3), lineWidth: 1)
                    .frame(width: 84, height: 84)
                Text(emoji)
                    .font(.system(size: 38))
                    .id(emoji)
                    .transition(.scale.combined(with: .opacity))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)

            Text("who are you pointing toward?")
                .font(DesignTokens.Font.compassName)
                .foregroundColor(DesignTokens.Color.textPrimary)
                .padding(.bottom, 8)

            Text("this is your compass anchor — you can add more people later")
                .font(DesignTokens.Font.compassDistance)
                .foregroundColor(DesignTokens.Color.textMuted)
                .lineSpacing(3)
                .padding(.bottom, 28)

            formLabel("their name")
            TextField("Mum, Dad, Home, Nan…", text: $name)
                .formInput()
                .padding(.bottom, 20)

            formLabel("their emoji")
            EmojiPickerRow(selected: $emoji)
        }
    }

    // MARK: - Step 3: Address

    private var addressStep: some View {
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
            .padding(.top, 24)
            .padding(.bottom, 20)

            Text("where is \(name.isEmpty ? "they" : name)?")
                .font(DesignTokens.Font.compassName)
                .foregroundColor(DesignTokens.Color.textPrimary)
                .padding(.bottom, 6)

            Text("enter their address — we'll find the coordinates and store them on your device")
                .font(DesignTokens.Font.compassDistance)
                .foregroundColor(DesignTokens.Color.textMuted)
                .lineSpacing(3)
                .padding(.bottom, 24)

            formLabel("address")

            // Input
            HStack {
                TextField("e.g. 10 Downing Street, London", text: $addressText)
                    .foregroundColor(DesignTokens.Color.textPrimary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .onChange(of: addressText) { _, new in handleAddressInput(new) }
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

            // Live autocomplete suggestions (MKLocalSearchCompleter) — same
            // dropdown as AddPersonView
            if !autocomplete.suggestions.isEmpty {
                AddressSuggestionsList(suggestions: autocomplete.suggestions) { sug in
                    selectSuggestion(sug)
                }
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            geocodeStatusView
                .animation(.easeOut(duration: 0.3), value: geocodeState)
        }
    }

    // MARK: - Step 4: Permissions

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Circle()
                    .stroke(DesignTokens.Color.accentMid.opacity(0.25), lineWidth: 1)
                    .frame(width: 84, height: 84)
                Image(systemName: "location.circle")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(DesignTokens.Color.accentSoft)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)

            Text("a couple of permissions")
                .font(DesignTokens.Font.compassName)
                .foregroundColor(DesignTokens.Color.textPrimary)
                .padding(.bottom, 8)

            Text("Pointward needs to know where you are to calculate the direction to point the needle")
                .font(DesignTokens.Font.compassDistance)
                .foregroundColor(DesignTokens.Color.textMuted)
                .lineSpacing(3)
                .padding(.bottom, 24)

            permissionCard(
                icon: "location.fill",
                title: "location — while using app",
                body: "used to calculate bearing and distance to your saved location. never stored, never shared.",
                badge: "required",
                badgeColor: Color(hex: "#5dcaa5")
            )

            permissionCard(
                icon: "gyroscope",
                title: "motion and compass",
                body: "used to orient the needle relative to which way your phone is pointing.",
                badge: "required",
                badgeColor: Color(hex: "#5dcaa5")
            )

            permissionCard(
                icon: "bell",
                title: "notifications",
                body: "only used if someone sends you a ping. you can always enable this later in settings.",
                badge: "optional",
                badgeColor: DesignTokens.Color.accentMid
            )
        }
    }

    private func permissionCard(icon: String, title: String, body: String,
                                 badge: String, badgeColor: Color) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(DesignTokens.Color.accentSoft)
                .frame(width: 26)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DesignTokens.Font.label)
                    .foregroundColor(DesignTokens.Color.textPrimary)
                Text(body)
                    .font(DesignTokens.Font.caption)
                    .foregroundColor(DesignTokens.Color.textMuted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                Text(badge)
                    .font(.system(size: 10))
                    .foregroundColor(badgeColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(badgeColor.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(badgeColor.opacity(0.3), lineWidth: 1))
            }
        }
        .padding(14)
        .background(DesignTokens.Color.backgroundCard)
        .cornerRadius(DesignTokens.Radius.card)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.card)
                .stroke(DesignTokens.Color.border, lineWidth: 1)
        )
        .padding(.bottom, 10)
    }

    // MARK: - Step 5: Compass set — the ritual

    private var compassSetStep: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 60)

            // The compass moment — glow, rings, needle settling on them
            ZStack {
                // Soft lavender ring that expands from the center, then settles
                Circle()
                    .stroke(Color(hex: "#c4a8d4").opacity(ritualRingExpand ? 0 : 0.6), lineWidth: 1.5)
                    .frame(width: 230, height: 230)
                    .scaleEffect(ritualRingExpand ? 1.0 : 0.25)

                // Soft lock glow — breathes on after the needle settles,
                // then keeps pulsing gently
                Circle()
                    .fill(Color(hex: "#9b7fc0").opacity(
                        ritualGlow ? (ritualPulse ? 0.36 : 0.24) : 0.10))
                    .frame(width: 150, height: 150)
                    .blur(radius: 28)

                Circle()
                    .stroke(DesignTokens.Color.accentMid.opacity(ritualGlow ? 0.5 : 0.25), lineWidth: 1)
                    .frame(width: 190, height: 190)

                Circle()
                    .stroke(DesignTokens.Color.accentMid.opacity(0.1), lineWidth: 1)
                    .frame(width: 222, height: 222)

                // Needle — swings in and settles with a spring
                ZStack {
                    Triangle()
                        .fill(DesignTokens.Color.accentSoft)
                        .frame(width: 10, height: 64)
                        .offset(y: -38)
                    Triangle()
                        .fill(DesignTokens.Color.accentStrong)
                        .frame(width: 8, height: 40)
                        .rotationEffect(.degrees(180))
                        .offset(y: 26)
                }
                .rotationEffect(.degrees(ritualNeedleAngle))

                // Their emoji — large at center, pulsing softly once settled
                Text(emoji)
                    .font(.system(size: 58))
                    .scaleEffect(ritualPulse ? 1.05 : 1.0)
                    .shadow(color: Color(hex: "#9b7fc0").opacity(ritualGlow ? 0.8 : 0.25), radius: 18)
            }
            .padding(.bottom, 44)

            // Their name — fades in elegantly above the words
            Text(name)
                .font(DesignTokens.Font.compassName)
                .foregroundColor(DesignTokens.Color.textPrimary)
                .opacity(ritualNameShown ? 1 : 0)
                .offset(y: ritualNameShown ? 0 : 6)
                .padding(.bottom, 6)

            // Tagline, soft beneath
            Text(TaglineSystem.defaultTagline)
                .font(.system(size: 13).italic())
                .foregroundColor(DesignTokens.Color.accentMid)
                .opacity(ritualTaglineShown ? 1 : 0)
                .padding(.bottom, 20)

            Text("YOUR COMPASS IS SET")
                .font(.system(size: 11, weight: .medium))
                .kerning(2.5)
                .foregroundColor(DesignTokens.Color.textMuted)
                .opacity(ritualSetShown ? 1 : 0)

            Spacer()

            // Appears once the moment has had room to land (~2s)
            if ritualButtonShown {
                Button { finish() } label: {
                    Text("open my compass")
                        .font(DesignTokens.Font.label)
                        .foregroundColor(DesignTokens.Color.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(DesignTokens.Spacing.md)
                        .background(DesignTokens.Color.accentStrong)
                        .cornerRadius(DesignTokens.Radius.button)
                }
                .padding(.horizontal, 28)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Spacer(minLength: 40)
        }
        .onAppear { runRitual() }
    }

    private func runRitual() {
        // Needle swings in and settles with a spring
        withAnimation(.spring(response: 1.1, dampingFraction: 0.55).delay(0.4)) {
            ritualNeedleAngle = 0
        }
        // Name, then tagline, surface gently
        withAnimation(.easeOut(duration: 0.5).delay(0.8))  { ritualNameShown    = true }
        withAnimation(.easeIn(duration: 0.6).delay(1.2))   { ritualTaglineShown = true }
        // Lock glow fires after the needle has settled, with an expanding
        // lavender ring that blooms out from the center
        withAnimation(.easeInOut(duration: 1.0).delay(1.5)) { ritualGlow        = true }
        withAnimation(.easeOut(duration: 1.3).delay(1.5))   { ritualRingExpand  = true }
        withAnimation(.easeOut(duration: 0.5).delay(1.7))  { ritualSetShown     = true }
        // Button arrives last — let the moment breathe
        withAnimation(.easeOut(duration: 0.5).delay(2.0))  { ritualButtonShown  = true }

        // A gentle haptic as the needle settles
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            HapticEngine.connectionFelt()
            // From here the emoji glow breathes slowly, forever
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                ritualPulse = true
            }
        }
    }

    // MARK: - Geocode status view (shared with Add/EditPersonView pattern)

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
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color(hex: "#5dcaa5"))
                    .font(.system(size: 18))
                VStack(alignment: .leading, spacing: 2) {
                    Text(loc.displayName)
                        .font(DesignTokens.Font.label)
                        .foregroundColor(DesignTokens.Color.textPrimary)
                    Text(String(format: "%.4f°, %.4f° · stored offline",
                                loc.coordinate.latitude, loc.coordinate.longitude))
                        .font(.system(size: 11))
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

    // MARK: - CTA bar

    private var ctaBar: some View {
        VStack(spacing: 0) {
            Divider().background(DesignTokens.Color.border)
            VStack(spacing: 8) {
                Button { handleCTA() } label: {
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

                if step > 1 && step < 4 {
                    Button("skip") { advance() }
                        .font(DesignTokens.Font.caption)
                        .foregroundColor(DesignTokens.Color.textMuted)
                        .opacity(step == 3 ? 0 : 1) // address step can't be skipped
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
        }
        .background(DesignTokens.Color.background)
    }

    private var ctaLabel: String {
        switch step {
        case 1:  return "get started"
        case 4:  return "set my compass"
        default: return "next"
        }
    }

    private var ctaEnabled: Bool {
        switch step {
        case 1:  return true
        case 2:  return !name.trimmingCharacters(in: .whitespaces).isEmpty
        case 3:
            if case .success = geocodeState { return true }
            return false
        default: return true
        }
    }

    // MARK: - Actions

    private func handleCTA() {
        // Leaving the permissions step — fire the iOS location popup at this
        // exact moment, then advance into the compass-set ritual (step 5);
        // the ritual's own button calls finish().
        if step == 4 {
            locationManager.requestWhenInUseAuthorization()
        }
        advance()
    }

    private func advance() {
        withAnimation(.easeOut(duration: 0.25)) { step += 1 }
    }

    private func finish() {
        guard let location = geocodedLocation else { return }

        // Taglines are added later via Edit Person — default is used until then
        let person = Person(
            name:    name.trimmingCharacters(in: .whitespaces),
            emoji:   emoji,
            geocoded: location,
            tagline: nil
        )

        try? people.addPerson(person)

        // Request location permission — the system dialog fires here
        // CLLocationManager.requestWhenInUseAuthorization() is called inside
        // CompassManager.start() when the compass screen first appears.
        // Notification permission is optional; request it here.
        if !notificationsRequested {
            Task {
                _ = try? await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound, .badge])
            }
            notificationsRequested = true
        }

        HapticEngine.connectionFelt()
        hasCompletedOnboarding = true
    }

    // MARK: - Address autocomplete (same implementation as AddPersonView)

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

    // MARK: - Helpers

    private func formLabel(_ text: String) -> some View {
        Text(text)
            .font(DesignTokens.Font.overline)
            .foregroundColor(DesignTokens.Color.textMuted)
            .padding(.bottom, 8)
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(geocodingService: MockGeocodingService())
        .environmentObject(PeopleManager(subscriptionManager: SubscriptionManager()))
        .environmentObject(SubscriptionManager())
        .preferredColorScheme(.dark)
}
