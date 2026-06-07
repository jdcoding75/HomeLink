// OnboardingView.swift
// Pointward › Views
//
// The opening — six screens that feel like unwrapping something precious,
// not filling out a form. Hero compass → the concept → send a thought →
// Pro teaser → giving back → set your compass. Under 60 seconds.
//
// (The previous single-flow ritual onboarding lives in git history.)
//
// Shown on first launch while hasCompletedOnboarding == false.

import SwiftUI
import CoreLocation
import UserNotifications

struct OnboardingView: View {

    @EnvironmentObject var people:       PeopleManager
    @EnvironmentObject var subscription: SubscriptionManager

    let geocodingService: GeocodingServiceProtocol

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    // MARK: - Flow state

    @State private var page = 0
    @State private var showCompletion = false

    // Screen 6 — the form
    @State private var name:  String = ""
    @State private var emoji: String = "❤️"
    @State private var addressText: String = ""
    @StateObject private var autocomplete = AddressAutocompleteService()
    @State private var selectedAddressText: String? = nil
    @State private var geocodeState:     GeocodeState = .idle
    @State private var geocodedLocation: GeocodedLocation? = nil
    @State private var geocodeTask:      Task<Void, Never>? = nil

    private let locationManager = CLLocationManager()
    @State private var notificationsRequested = false

    private static let lavender = Color(hex: "#c4a8d4")
    private static let glow     = Color(hex: "#9b7fc0")
    private let coreEmojis = ["❤️", "💋", "🤗", "✨", "🌸", "🌙"]

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(hex: "#0d0d14").ignoresSafeArea()

            if showCompletion {
                CompletionMoment(name: name.trimmingCharacters(in: .whitespaces),
                                 emoji: emoji) {
                    finishToApp()
                }
                .transition(.opacity)
            } else {
                VStack(spacing: 0) {
                    TabView(selection: $page) {
                        heroScreen.tag(0)
                        compassScreen.tag(1)
                        thoughtScreen.tag(2)
                        proScreen.tag(3)
                        givingScreen.tag(4)
                        setupScreen.tag(5)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.4), value: page)

                    pageDots
                        .padding(.bottom, 14)
                }

                // Skip — screens 2-5 only, straight to setup
                if (1...4).contains(page) {
                    VStack {
                        HStack {
                            Spacer()
                            Button("skip") {
                                withAnimation(.easeInOut(duration: 0.4)) { page = 5 }
                            }
                            .font(.system(size: 13))
                            .foregroundColor(DesignTokens.Color.textMuted)
                            .padding(.trailing, 22)
                            .padding(.top, 14)
                        }
                        Spacer()
                    }
                    .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.5), value: showCompletion)
        .preferredColorScheme(.dark)
    }

    private var pageDots: some View {
        HStack(spacing: 7) {
            ForEach(0..<6, id: \.self) { i in
                Circle()
                    .fill(i == page ? Self.lavender : DesignTokens.Color.borderMid)
                    .frame(width: i == page ? 7 : 5, height: i == page ? 7 : 5)
            }
        }
        .animation(.easeOut(duration: 0.25), value: page)
    }

    /// A real compass face — exactly what the app shows.
    private func miniCompass(skin: CompassSkin, bearing: Double,
                             locked: Bool = false, size: CGFloat) -> some View {
        ZStack {
            SkinFaceView(skin: skin, bearing: bearing, locked: locked,
                         quietMode: false, pingRingActive: false)
            NeedleView(bearing: bearing, skin: skin, locked: locked)
        }
        .frame(width: 240, height: 240)
        .scaleEffect(size / 240)
        .frame(width: size, height: size)
    }

    // MARK: - Screen 1 · Hero

    @State private var heroBearing: Double = 150
    @State private var heroBreath  = false
    @State private var heroTagline = false
    @State private var heroButton  = false

    private var heroScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Self.glow.opacity(heroBreath ? 0.30 : 0.16))
                    .frame(width: 300, height: 300)
                    .blur(radius: 38)
                miniCompass(skin: .vintage, bearing: heroBearing,
                            locked: heroButton, size: 280)
            }

            Text("Pointward")
                .font(.system(size: 40, weight: .semibold, design: .serif))
                .foregroundColor(DesignTokens.Color.textPrimary)
                .padding(.top, 18)

            Text("a compass for the people you love")
                .font(.system(size: 15, design: .serif).italic())
                .foregroundColor(Self.lavender)
                .opacity(heroTagline ? 1 : 0)
                .padding(.top, 6)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.4)) { page = 1 }
            } label: {
                Text("begin →")
                    .font(DesignTokens.Font.label)
                    .foregroundColor(DesignTokens.Color.textPrimary)
                    .padding(.horizontal, 44)
                    .padding(.vertical, 14)
                    .background(DesignTokens.Color.accentStrong)
                    .cornerRadius(DesignTokens.Radius.button)
            }
            .opacity(heroButton ? 1 : 0)
            .padding(.bottom, 40)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                heroBreath = true
            }
            // The needle wanders, then settles NNW
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.spring(response: 1.8, dampingFraction: 0.55)) {
                    heroBearing = -22.5   // NNW
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeIn(duration: 0.8)) { heroTagline = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeIn(duration: 0.7)) { heroButton = true }
            }
        }
    }

    // MARK: - Screen 2 · The compass

    @State private var conceptRight: Double = 200
    @State private var conceptLocked = false

    private var compassScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            // The real behavior: the rose rotates with the world while the
            // needle stays pointed at the person.
            ZStack {
                SkinFaceView(skin: .minimal, bearing: 40, locked: conceptLocked,
                             quietMode: false, pingRingActive: false)
                    .rotationEffect(.degrees(conceptRight))   // the rose turning
                NeedleView(bearing: 40, skin: .minimal, locked: conceptLocked)
            }
            .frame(width: 240, height: 240)
            .scaleEffect(190.0 / 240.0)
            .frame(width: 190, height: 190)
            .shadow(color: Self.glow.opacity(conceptLocked ? 0.45 : 0), radius: 22)

            Text("your compass always knows which way")
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundColor(DesignTokens.Color.textPrimary)
                .padding(.top, 36)

            Text("point your compass toward\nthe people that matter")
                .font(.system(size: 14, design: .serif).italic())
                .foregroundColor(Self.lavender.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            Spacer()

            nextButton
        }
        .onAppear { alignConcept() }
    }

    private func alignConcept() {
        conceptLocked = false
        conceptRight = Double.random(in: -120 ... -40)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.spring(response: 1.6, dampingFraction: 0.6)) {
                conceptRight = 0   // the rose settles, needle never moved
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            withAnimation(.easeIn(duration: 0.5)) { conceptLocked = true }
        }
        // Loop the moment
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
            if page == 1 && !showCompletion { alignConcept() }
        }
    }

    // MARK: - Screen 3 · Send a thought

    @State private var thoughtFly = false

    private var thoughtScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                miniCompass(skin: .minimal, bearing: -30, size: 190)

                // 💜 shoots from center outward with a trail — the real thing
                ForEach(0..<5, id: \.self) { i in
                    Text("💜")
                        .font(.system(size: 13))
                        .opacity(thoughtFly ? 0 : 0.7 - Double(i) * 0.12)
                        .offset(x: thoughtFly ? -95 : 0, y: thoughtFly ? -165 : 0)
                        .animation(.easeIn(duration: 1.1).delay(0.12 + Double(i) * 0.08),
                                   value: thoughtFly)
                }
                Text("💜")
                    .font(.system(size: 26))
                    .scaleEffect(thoughtFly ? 1.6 : 0.7)
                    .opacity(thoughtFly ? 0 : 1)
                    .offset(x: thoughtFly ? -110 : 0, y: thoughtFly ? -190 : 0)
                    .animation(.easeIn(duration: 1.2).delay(0.05), value: thoughtFly)
                    .shadow(color: Self.glow.opacity(0.8), radius: 10)
            }
            .frame(height: 230)

            // The emoji row lives on the compass — show it that way
            HStack(spacing: 8) {
                ForEach(["❤️","💋","🤗","✨","🌸","🌙"], id: \.self) { e in
                    Text(e)
                        .font(.system(size: 17))
                        .frame(width: 34, height: 34)
                        .background(DesignTokens.Color.backgroundCard.opacity(0.7))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(DesignTokens.Color.border.opacity(0.6), lineWidth: 1)
                        )
                }
            }
            .padding(.top, 14)

            Text("send a thought from the compass")
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundColor(DesignTokens.Color.textPrimary)
                .padding(.top, 30)

            Text("no words needed · just point and send")
                .font(.system(size: 14, design: .serif).italic())
                .foregroundColor(Self.lavender.opacity(0.85))
                .padding(.top, 8)

            Spacer()

            nextButton
        }
        .onAppear { loopThought() }
    }

    private func loopThought() {
        thoughtFly = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { thoughtFly = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if page == 2 && !showCompletion { loopThought() }
        }
    }

    // MARK: - Screen 4 · Pro teaser

    private var proScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            HStack(alignment: .center, spacing: 16) {
                miniCompass(skin: .minimal, bearing: -22.5, size: 92)
                    .shadow(color: Self.glow.opacity(0.3), radius: 12)
                miniCompass(skin: .vintage, bearing: -22.5, locked: true, size: 132)
                    .shadow(color: Self.glow.opacity(0.5), radius: 18)
                miniCompass(skin: .heart, bearing: -22.5, size: 92)
                    .shadow(color: Self.glow.opacity(0.3), radius: 12)
            }

            Text("and so much more with Pro")
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundColor(DesignTokens.Color.textPrimary)
                .padding(.top, 36)

            Text("funny distances · custom emojis ·\nhold to send · and the gecko 🦎")
                .font(.system(size: 14, design: .serif).italic())
                .foregroundColor(Self.lavender.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            Spacer()

            nextButton
        }
    }

    // MARK: - Screen 5 · Giving back

    @State private var givingBreath = false

    private var givingScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color(hex: "#c4845a").opacity(givingBreath ? 0.28 : 0.14))
                    .frame(width: 150, height: 150)
                    .blur(radius: 28)
                Text("🎖️")
                    .font(.system(size: 64))
                    .scaleEffect(givingBreath ? 1.04 : 1.0)
            }

            Text("Pointward gives back")
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundColor(DesignTokens.Color.textPrimary)
                .padding(.top, 26)

            Text("50% of every Pro purchase supports\nfamilies separated by distance")
                .font(.system(size: 14, design: .serif).italic())
                .foregroundColor(Self.lavender.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            if let charity = CharityConfig.current {
                Text("currently supporting \(charity.name)")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Color.textMuted)
                    .padding(.top, 10)
            }

            Spacer()

            nextButton
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                givingBreath = true
            }
        }
    }

    // MARK: - Screen 6 · Get started

    private var setupScreen: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("who do you point toward?")
                    .font(.system(size: 27, weight: .semibold, design: .serif))
                    .foregroundColor(DesignTokens.Color.textPrimary)
                    .padding(.top, 64)

                Text("add someone to begin")
                    .font(.system(size: 14, design: .serif).italic())
                    .foregroundColor(DesignTokens.Color.textMuted)
                    .padding(.top, 6)
                    .padding(.bottom, 30)

                VStack(alignment: .leading, spacing: 18) {
                    // Name
                    TextField("Mum, Dad, Home...", text: $name)
                        .formInput()

                    // Their emoji — the core six as chips
                    HStack(spacing: 10) {
                        ForEach(coreEmojis, id: \.self) { e in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    emoji = e
                                }
                            } label: {
                                Text(e)
                                    .font(.system(size: 22))
                                    .frame(width: 46, height: 46)
                                    .background(emoji == e
                                                ? DesignTokens.Color.accentStrong
                                                : DesignTokens.Color.backgroundCard)
                                    .cornerRadius(13)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 13)
                                            .stroke(emoji == e
                                                    ? DesignTokens.Color.accentMid
                                                    : DesignTokens.Color.border, lineWidth: 1)
                                    )
                                    .scaleEffect(emoji == e ? 1.08 : 1.0)
                            }
                        }
                    }

                    // Address with live autocomplete
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("their address or city", text: $addressText)
                            .formInput()
                            .autocorrectionDisabled()
                            .onChange(of: addressText) { _, new in
                                handleAddressInput(new)
                            }
                            .onSubmit { geocodeTypedAddress() }

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
                }
                .padding(.horizontal, 30)

                Spacer(minLength: 26)

                // The moment of commitment — glows when ready
                Button {
                    startCompletion()
                } label: {
                    Text("set my compass →")
                        .font(DesignTokens.Font.label)
                        .foregroundColor(DesignTokens.Color.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(DesignTokens.Spacing.md)
                        .background(DesignTokens.Color.accentStrong)
                        .cornerRadius(DesignTokens.Radius.button)
                        .shadow(color: Self.glow.opacity(canFinish ? 0.55 : 0), radius: 12)
                }
                .disabled(!canFinish)
                .opacity(canFinish ? 1 : 0.4)
                .animation(.easeOut(duration: 0.3), value: canFinish)
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var canFinish: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        if case .success = geocodeState { return true }
        return false
    }

    private var nextButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.4)) { page += 1 }
        } label: {
            Text("next →")
                .font(DesignTokens.Font.label)
                .foregroundColor(DesignTokens.Color.textPrimary)
                .padding(.horizontal, 44)
                .padding(.vertical, 14)
                .background(DesignTokens.Color.accentStrong)
                .cornerRadius(DesignTokens.Radius.button)
        }
        .padding(.bottom, 40)
    }

    // MARK: - Completion

    private func startCompletion() {
        guard let location = geocodedLocation else { return }
        let person = Person(
            name:    name.trimmingCharacters(in: .whitespaces),
            emoji:   emoji,
            geocoded: location,
            tagline: nil
        )
        try? people.addPerson(person)

        // Permissions, at the natural moment
        locationManager.requestWhenInUseAuthorization()
        if !notificationsRequested {
            Task {
                _ = try? await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound, .badge])
            }
            notificationsRequested = true
        }

        withAnimation(.easeInOut(duration: 0.5)) { showCompletion = true }
    }

    private func finishToApp() {
        hasCompletedOnboarding = true
    }

    // MARK: - Address autocomplete (same implementation as AddPersonView)

    private func handleAddressInput(_ text: String) {
        guard text != selectedAddressText else { return }
        selectedAddressText = nil
        geocodeTask?.cancel()
        geocodedLocation = nil
        geocodeState     = .idle
        autocomplete.updateQuery(text)
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
}

// MARK: - Completion moment

/// "your compass is set ✦" — the emoji glows, the needle settles toward
/// them, a soft haptic lands, and the app opens.
private struct CompletionMoment: View {

    let name: String
    let emoji: String
    let onDone: () -> Void

    @State private var needle: Double = 140
    @State private var glow      = false
    @State private var nameShown = false
    @State private var setShown  = false

    private static let lavender = Color(hex: "#c4a8d4")
    private static let purple   = Color(hex: "#9b7fc0")

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            if nameShown {
                Text(name)
                    .font(.system(size: 30, weight: .semibold, design: .serif))
                    .foregroundColor(DesignTokens.Color.textPrimary)
                    .transition(.opacity)
                    .padding(.bottom, 22)
            }

            ZStack {
                Circle()
                    .fill(Self.purple.opacity(glow ? 0.32 : 0.12))
                    .frame(width: 220, height: 220)
                    .blur(radius: 32)

                Text(emoji)
                    .font(.system(size: 80))
                    .scaleEffect(glow ? 1.06 : 1.0)
                    .shadow(color: Self.purple.opacity(0.8), radius: 22)

                // The needle finds them
                NeedleView(bearing: needle, skin: .minimal, locked: glow)
                    .frame(width: 240, height: 240)
                    .scaleEffect(1.15)
                    .opacity(0.85)
            }

            if setShown {
                Text("your compass is set ✦")
                    .font(.system(size: 15, design: .serif).italic())
                    .foregroundColor(Self.lavender)
                    .transition(.opacity)
                    .padding(.top, 26)
            }

            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 1.4, dampingFraction: 0.6)) {
                needle = -20
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                HapticEngine.connectionFelt()   // the settle
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    glow = true
                }
                withAnimation(.easeIn(duration: 0.5)) { nameShown = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeIn(duration: 0.5)) { setShown = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) {
                onDone()
            }
        }
    }
}
