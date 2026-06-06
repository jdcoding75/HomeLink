// OnboardingView.swift
// HomeLink › Views
//
// Shown on first launch when hasCompletedOnboarding == false.
// Five steps: welcome → name+emoji → tagline → address → permissions.
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
    @State private var tagline:        String = ""
    @State private var selectedPreset: String = TaglineSystem.presets[0]

    // Step 4
    @State private var addressText:      String = ""
    @State private var geocodeState:     GeocodeState = .idle
    @State private var geocodedLocation: GeocodedLocation? = nil
    @State private var geocodeTask:      Task<Void, Never>? = nil

    // Step 5
    @State private var notificationsRequested = false

    // MARK: - Body

    var body: some View {
        ZStack {
            DesignTokens.Color.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress dots — hidden on step 1 (welcome)
                if step > 1 {
                    progressDots
                        .padding(.top, 16)
                        .padding(.bottom, 4)
                        .transition(.opacity)
                }

                // Step content
                ScrollView {
                    VStack {
                        switch step {
                        case 1:  welcomeStep
                        case 2:  nameStep
                        case 3:  taglineStep
                        case 4:  addressStep
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
        .animation(.easeOut(duration: 0.28), value: step)
    }

    // MARK: - Progress dots

    private var progressDots: some View {
        HStack(spacing: 6) {
            // Step 1 is welcome — dots represent steps 2–5
            ForEach(2...5, id: \.self) { s in
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

            Text("welcome to HomeLink")
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
                          body: "the needle lives on your home screen, lock screen, and dynamic island")
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

    // MARK: - Step 3: Tagline

    private var taglineStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Live preview
            VStack(spacing: 6) {
                Text(name.isEmpty ? "them" : name)
                    .font(DesignTokens.Font.compassName)
                    .foregroundColor(DesignTokens.Color.textPrimary)
                Text(resolvedTagline)
                    .font(.system(size: 13).italic())
                    .foregroundColor(DesignTokens.Color.accentMid)
                    .multilineTextAlignment(.center)
                    .animation(.easeOut(duration: 0.3), value: resolvedTagline)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(DesignTokens.Color.backgroundLift)
            .cornerRadius(DesignTokens.Radius.card)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.card)
                    .stroke(DesignTokens.Color.border, lineWidth: 1)
            )
            .padding(.vertical, 24)

            Text("add a tagline")
                .font(DesignTokens.Font.compassName)
                .foregroundColor(DesignTokens.Color.textPrimary)
                .padding(.bottom, 6)

            Text("something that captures how they feel — or skip and we'll use the default")
                .font(DesignTokens.Font.compassDistance)
                .foregroundColor(DesignTokens.Color.textMuted)
                .lineSpacing(3)
                .padding(.bottom, 24)

            VStack(spacing: 6) {
                ForEach(TaglineSystem.presets, id: \.self) { preset in
                    taglinePresetChip(preset)
                }
            }
            .padding(.bottom, 20)

            formLabel("or write your own  ·  \(TaglineSystem.counterText(tagline.count))")
            TextField(TaglineSystem.defaultTagline, text: $tagline)
                .formInput()
                .onChange(of: tagline) { _, new in
                    if new.count > TaglineSystem.maxLength {
                        tagline = String(new.prefix(TaglineSystem.maxLength))
                    }
                    if !TaglineSystem.presets.contains(new) { selectedPreset = "" }
                }
        }
    }

    // MARK: - Step 4: Address

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
                    .onChange(of: addressText) { _, new in handleAddressInput(new) }
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

            geocodeStatusView
                .animation(.easeOut(duration: 0.3), value: geocodeState)
        }
    }

    // MARK: - Step 5: Permissions

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

            Text("HomeLink needs to know where you are to calculate the direction to point the needle")
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

                if step > 1 && step < 5 {
                    Button("skip") { advance() }
                        .font(DesignTokens.Font.caption)
                        .foregroundColor(DesignTokens.Color.textMuted)
                        .opacity(step == 4 ? 0 : 1) // address step can't be skipped
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
        case 5:  return "open my compass"
        default: return "next"
        }
    }

    private var ctaEnabled: Bool {
        switch step {
        case 1:  return true
        case 2:  return !name.trimmingCharacters(in: .whitespaces).isEmpty
        case 3:  return true
        case 4:
            if case .success = geocodeState { return true }
            return false
        default: return true
        }
    }

    // MARK: - Actions

    private func handleCTA() {
        if step == 5 {
            finish()
        } else {
            advance()
        }
    }

    private func advance() {
        withAnimation(.easeOut(duration: 0.25)) { step += 1 }
    }

    private func finish() {
        guard let location = geocodedLocation else { return }

        let trimmedTagline = tagline.trimmingCharacters(in: .whitespaces)
        let person = Person(
            name:    name.trimmingCharacters(in: .whitespaces),
            emoji:   emoji,
            geocoded: location,
            tagline: trimmedTagline.isEmpty ? nil : trimmedTagline
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

    // MARK: - Address geocoding

    private func handleAddressInput(_ text: String) {
        geocodeTask?.cancel()
        geocodedLocation = nil
        guard text.count >= 3 else { geocodeState = .idle; return }
        geocodeState = .searching
        geocodeTask  = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            geocodeState = .geocoding(text)
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
        addressText      = ""
        geocodeState     = .idle
        geocodedLocation = nil
    }

    // MARK: - Helpers

    private var resolvedTagline: String {
        let t = tagline.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? TaglineSystem.defaultTagline : t
    }

    private func taglinePresetChip(_ preset: String) -> some View {
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
