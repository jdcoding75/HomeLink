// OnboardingView.swift
// Pointward › Views
//
// The opening — six screens that feel like unwrapping something precious,
// not filling out a form. Hero → the four instruments → the flick mechanic →
// Pro teaser (the bow) → giving back → set your compass. Under 60 seconds.
//
// (The previous single-flow ritual onboarding lives in git history.)
//
// Shown on first launch while hasCompletedOnboarding == false.

import SwiftUI
import CoreLocation
import UserNotifications
import ContactsUI
import AuthenticationServices
import CryptoKit

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
    @State private var showContactPicker = false

    private static let lavender = Color(hex: "#c4a8d4")
    private static let glow     = Color(hex: "#9b7fc0")
    private let coreEmojis = ["❤️", "💋", "🤗", "✨", "🌸", "🌙"]

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(hex: "#0d0d14").ignoresSafeArea()

            VStack(spacing: 0) {
                // [1/4] NEW ORDER: hero · sign in · about you (self profile) ·
                // your code · instruments · pro · giving · let's go.
                TabView(selection: $page) {
                    heroScreen.tag(0)
                    signInScreen.tag(1)        // sign in before your profile
                    aboutYouScreen.tag(2)      // [1/4] YOUR profile
                    yourCodeScreen.tag(3)      // [1/4] share your code
                    instrumentsScreen.tag(4)
                    proScreen.tag(5)
                    givingScreen.tag(6)
                    letsGoScreen.tag(7)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.4), value: page)

                pageDots
                    .padding(.bottom, 14)
            }

            // Skip — only the showcase screens (instruments · pro · giving)
            // jump to the finish. The profile + code screens carry their own.
            if (4...6).contains(page) {
                VStack {
                    HStack {
                        Spacer()
                        Button("skip") {
                            withAnimation(.easeInOut(duration: 0.4)) { page = 7 }
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
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showContactPicker) {
            ContactPickerView { contact in
                applyContact(contact)
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Contacts (same behavior as AddPersonView)

    private func applyContact(_ contact: CNContact) {
        let nickname = contact.nickname.trimmingCharacters(in: .whitespaces)
        let given    = contact.givenName.trimmingCharacters(in: .whitespaces)
        let family   = contact.familyName.trimmingCharacters(in: .whitespaces)
        let resolved = !nickname.isEmpty ? nickname : (!given.isEmpty ? given : family)
        if !resolved.isEmpty {
            name = resolved
        }
        // Pre-fill and geocode their address so "set my compass" is one
        // tap away when the contact card already knows where they live
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

    private var pageDots: some View {
        HStack(spacing: 7) {
            ForEach(0..<8, id: \.self) { i in
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

            VStack(spacing: 3) {
                Text("your emotional instrument")
                    .font(.system(size: 15, design: .serif).italic())
                    .foregroundColor(Self.lavender)
                Text("point toward the people you love")
                    .font(.system(size: 12, design: .serif).italic())
                    .foregroundColor(Self.lavender.opacity(0.7))
            }
            .opacity(heroTagline ? 1 : 0)
            .padding(.top, 6)
            // (previous: "a compass for the people you love")

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

    // MARK: - Screen 2 · Sign in with Apple

    @State private var signInBusy   = false
    @State private var signedIn     = SupabaseService.localUserID != nil
    @State private var signInError: String?
    @State private var currentNonce = ""

    private var signInScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            if signedIn {
                // Success moment — soft green check, then onward
                VStack(spacing: 14) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 54))
                        .foregroundColor(Color(hex: "#5dcaa5").opacity(0.9))
                        .shadow(color: Color(hex: "#5dcaa5").opacity(0.5), radius: 16)
                    Text("signed in ✦")
                        .font(.system(size: 22, weight: .semibold, design: .serif))
                        .foregroundColor(DesignTokens.Color.textPrimary)
                }
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            } else {
                Text("sign in to connect")
                    .font(.system(size: 30, weight: .semibold, design: .serif))
                    .foregroundColor(DesignTokens.Color.textPrimary)

                Text("needed to send and receive thoughts")
                    .font(.system(size: 13, design: .serif).italic())
                    .foregroundColor(Self.lavender.opacity(0.8))
                    .padding(.top, 8)
                    .padding(.bottom, 36)

                SignInWithAppleButton(.signIn) { request in
                    currentNonce = Self.randomNonce()
                    request.requestedScopes = [.fullName]
                    request.nonce = Self.sha256(currentNonce)
                } onCompletion: { result in
                    handleAppleResult(result)
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
                .cornerRadius(DesignTokens.Radius.button)
                .padding(.horizontal, 44)
                .disabled(signInBusy)
                .opacity(signInBusy ? 0.6 : 1)

                if signInBusy {
                    ProgressView()
                        .tint(DesignTokens.Color.accentSoft)
                        .padding(.top, 18)
                }

                if let signInError {
                    Text(signInError)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 14)
                }

                // The escape hatch — the compass works fully offline
                Button {
                    withAnimation(.easeInOut(duration: 0.4)) { page = 2 }
                } label: {
                    Text("use offline only →")
                        .font(.system(size: 13))
                        .foregroundColor(DesignTokens.Color.textMuted)
                }
                .padding(.top, 26)

                Text("you can connect later from Settings")
                    .font(.system(size: 11, design: .serif).italic())
                    .foregroundColor(DesignTokens.Color.textDim)
                    .padding(.top, 6)
            }

            Spacer()

            if signedIn {
                nextButton
            }
        }
        .animation(.easeOut(duration: 0.4), value: signedIn)
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure:
            // Includes user-cancelled — stay quiet, they can retry or skip
            signInError = nil
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                signInError = "Sign in didn't complete — try again."
                return
            }
            signInBusy = true
            signInError = nil
            Task {
                defer { signInBusy = false }
                do {
                    try await SupabaseService.shared.signInWithApple(idToken: idToken,
                                                                     nonce: currentNonce)
                    try await SupabaseService.shared.ensureUser(appleUserID: credential.user)
                    // Mint the pairing code in the background so Connect is instant
                    Task { _ = try? await SupabaseService.shared.myPairingCode() }
                    withAnimation(.easeOut(duration: 0.4)) { signedIn = true }
                    HapticEngine.connectionFelt()
                    // Brief success moment, then onward
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                        if page == 1 {
                            withAnimation(.easeInOut(duration: 0.4)) { page = 2 }
                        }
                    }
                } catch {
                    signInError = error.localizedDescription
                }
            }
        }
    }

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFabcdef")
        return String((0..<length).map { _ in charset.randomElement()! })
    }

    private static func sha256(_ input: String) -> String {
        let hash = SHA256.hash(data: Data(input.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Screen 3 · The four instruments

    @State private var carouselIndex = 0

    private var instrumentsScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            // The carousel — each instrument takes the stage for 2 s,
            // its mechanic playing in miniature beneath the icon
            let instrument = Instrument.allCases[carouselIndex]
            VStack(spacing: 16) {
                Text(instrument.icon)
                    .font(.system(size: 64))
                    .shadow(color: Self.glow.opacity(0.5), radius: 16)

                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(DesignTokens.Color.backgroundCard.opacity(0.7))
                    InstrumentPreview(instrument: instrument)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .frame(width: 170, height: 110)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(DesignTokens.Color.border, lineWidth: 1)
                )

                VStack(spacing: 3) {
                    Text(instrument.displayName)
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundColor(DesignTokens.Color.textPrimary)
                    Text(instrument.tagline)
                        .font(.system(size: 12, design: .serif).italic())
                        .foregroundColor(Self.lavender.opacity(0.85))
                }
            }
            .id(carouselIndex)   // crossfade the whole stage per instrument
            .transition(.opacity.combined(with: .scale(scale: 0.94)))
            .frame(height: 270)

            // Which instrument is on stage
            HStack(spacing: 6) {
                ForEach(0..<Instrument.allCases.count, id: \.self) { i in
                    Circle()
                        .fill(i == carouselIndex ? Self.lavender
                                                 : DesignTokens.Color.borderMid)
                        .frame(width: 5, height: 5)
                }
            }
            .padding(.top, 10)

            Text("four ways to send a feeling")
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundColor(DesignTokens.Color.textPrimary)
                .padding(.top, 26)

            Text("each one a different experience")
                .font(.system(size: 14, design: .serif).italic())
                .foregroundColor(Self.lavender.opacity(0.85))
                .padding(.top, 8)

            Spacer()

            nextButton
        }
        .onAppear { cycleInstruments() }
    }

    /// 2-second pause on each instrument, looping while the screen shows.
    private func cycleInstruments() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            guard page == 4 else { return }   // instruments is page 4 now
            withAnimation(.easeInOut(duration: 0.35)) {
                carouselIndex = (carouselIndex + 1) % Instrument.allCases.count
            }
            cycleInstruments()
        }
    }

    // MARK: - Screen 2 (previous) · The compass — superseded, kept

    @State private var conceptRight: Double = 200
    @State private var conceptLocked = false

    private var compassScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            // The real behavior: the face is fixed (N at top), only the
            // needle moves — it finds the person and settles.
            ZStack {
                SkinFaceView(skin: .minimal, bearing: conceptRight, locked: conceptLocked,
                             quietMode: false, pingRingActive: false)
                NeedleView(bearing: conceptRight, skin: .minimal, locked: conceptLocked)
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
                conceptRight = 40   // the needle finds them and settles
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

    // MARK: - Screen 3 · Send a thought (the flick — most visual mechanic)

    @State private var flickPressed = false
    @State private var flickProgress: CGFloat = 0

    private var thoughtScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            // The flick, staged: 💜 waits in its pocket, gets pressed,
            // then launches across the stage on a curve with a trail
            ZStack {
                let start   = CGSize(width: -60, height: 80)
                let end     = CGSize(width: 120, height: -150)
                let control = CGSize(width: 10, height: -190)

                // The pocket — where the thought is loaded
                Capsule()
                    .fill(DesignTokens.Color.backgroundCard)
                    .frame(width: 56, height: 22)
                    .overlay(Capsule().stroke(DesignTokens.Color.borderMid, lineWidth: 1))
                    .offset(x: start.width, y: start.height + 16)

                // The fingertip beneath, pressing
                Circle()
                    .fill(Color(hex: "#ece4f5").opacity(0.6))
                    .frame(width: 18, height: 18)
                    .offset(x: start.width, y: start.height + (flickPressed ? 12 : 16))
                    .animation(.easeInOut(duration: 0.25), value: flickPressed)

                // Trail — soft lavender circles hanging on the path
                ForEach(0..<6, id: \.self) { i in
                    Circle()
                        .fill(Self.lavender.opacity(0.35))
                        .frame(width: 8, height: 8)
                        .blur(radius: 2)
                        .opacity(flickProgress > 0 ? 1 - Double(flickProgress) * 0.9 : 0)
                        .modifier(CurvedFlightEffect(progress: flickProgress, start: start,
                                                     control: control, end: end))
                        .animation(AnimationSystem.easeOutCubic(0.9)
                                    .delay(0.05 * Double(i + 1)), value: flickProgress)
                }

                // The thought itself
                Text("💜")
                    .font(.system(size: 30))
                    .scaleEffect(flickPressed ? 0.82 : 1.0)
                    .scaleEffect(1 + flickProgress * 0.5)   // grows as it travels
                    .opacity(1 - Double(flickProgress) * 0.85)
                    .shadow(color: Self.glow.opacity(0.8), radius: 10)
                    .modifier(CurvedFlightEffect(progress: flickProgress, start: start,
                                                 control: control, end: end))
                    .animation(.easeInOut(duration: 0.25), value: flickPressed)
                    .animation(AnimationSystem.easeOutCubic(0.9), value: flickProgress)
            }
            .frame(height: 250)

            Text("load · aim · launch")
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundColor(DesignTokens.Color.textPrimary)
                .padding(.top, 26)

            Text("pro instruments unlock new ways to send")
                .font(.system(size: 14, design: .serif).italic())
                .foregroundColor(Self.lavender.opacity(0.85))
                .padding(.top, 8)

            Spacer()

            nextButton
        }
        .onAppear { loopFlick() }
    }

    private func loopFlick() {
        var snap = Transaction(); snap.disablesAnimations = true
        withTransaction(snap) { flickProgress = 0; flickPressed = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { flickPressed = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            flickPressed = false
            flickProgress = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            if page == 3 && !showCompletion { loopFlick() }
        }
    }

    // MARK: - Screen 4 · Pro teaser

    private var proScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            // The bow — drawn back, trembling, released. The most
            // dramatic mechanic carries the Pro moment.
            ZStack {
                Circle()
                    .fill(Self.glow.opacity(0.18))
                    .frame(width: 240, height: 240)
                    .blur(radius: 34)
                InstrumentPreview(instrument: .bow)
                    .frame(width: 220, height: 220)
            }
            .frame(height: 250)

            // The other three wait in the wings
            HStack(spacing: 14) {
                ForEach(Instrument.allCases) { instrument in
                    Text(instrument.icon)
                        .font(.system(size: instrument == .bow ? 26 : 20))
                        .opacity(instrument == .bow ? 1 : 0.6)
                }
            }
            .padding(.top, 4)

            Text("unlock all four instruments")
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundColor(DesignTokens.Color.textPrimary)
                .padding(.top, 26)

            Text("$2.99 · one time · yours forever")
                .font(.system(size: 14, design: .serif).italic())
                .foregroundColor(Self.lavender.opacity(0.85))
                .padding(.top, 8)

            Spacer()

            nextButton
        }
    }

    // (previous Pro teaser — three compass skins — superseded, kept)
    private var proScreenSkins: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                miniCompass(skin: .minimal, bearing: -22.5, size: 92)
                    .shadow(color: Self.glow.opacity(0.3), radius: 12)
                miniCompass(skin: .vintage, bearing: -22.5, locked: true, size: 132)
                    .shadow(color: Self.glow.opacity(0.5), radius: 18)
                miniCompass(skin: .heart, bearing: -22.5, size: 92)
                    .shadow(color: Self.glow.opacity(0.3), radius: 12)
            }
            Text("funny distances · custom emojis ·\nhold to send · and the gecko 🦎")
                .font(.system(size: 14, design: .serif).italic())
                .foregroundColor(Self.lavender.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.top, 8)
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

    // MARK: - Screen 3 · About you (YOUR profile)

    @State private var codeReady: String? = nil
    @State private var codeBusy = false

    private var aboutYouScreen: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("tell us about you ✦")
                    .font(.system(size: 27, weight: .semibold, design: .serif))
                    .foregroundColor(DesignTokens.Color.textPrimary)
                    .padding(.top, 56)

                Text("this is what others will see")
                    .font(.system(size: 14, design: .serif).italic())
                    .foregroundColor(DesignTokens.Color.textMuted)
                    .padding(.top, 6)
                    .padding(.bottom, 28)

                VStack(alignment: .leading, spacing: 18) {
                    // Your name
                    fieldLabel("your name")
                    TextField("your name", text: $name)
                        .formInput()

                    // Your emoji — tap to change (the full picker)
                    fieldLabel("your emoji")
                    EmojiPickerRow(selected: $emoji)

                    // Where you are — MKLocalSearch autocomplete
                    fieldLabel("where you are")
                    addressAutocompleteField

                    Text("your location lets people you connect with point\ntoward you — share only what you're comfortable with")
                        .font(.system(size: 11, design: .serif).italic())
                        .foregroundColor(DesignTokens.Color.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 30)

                Spacer(minLength: 26)

                Button {
                    saveAboutYou()
                } label: {
                    Text("continue →")
                        .font(DesignTokens.Font.label)
                        .foregroundColor(DesignTokens.Color.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(DesignTokens.Spacing.md)
                        .background(DesignTokens.Color.accentStrong)
                        .cornerRadius(DesignTokens.Radius.button)
                        .shadow(color: Self.glow.opacity(canContinueProfile ? 0.55 : 0), radius: 12)
                }
                .disabled(!canContinueProfile)
                .opacity(canContinueProfile ? 1 : 0.4)
                .animation(.easeOut(duration: 0.3), value: canContinueProfile)
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    /// Name is required; an address is encouraged but optional.
    private var canContinueProfile: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(DesignTokens.Font.overline)
            .foregroundColor(DesignTokens.Color.textMuted)
    }

    /// The shared address field with live MKLocalSearch suggestions.
    private var addressAutocompleteField: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("your address or city", text: $addressText)
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
                    Text("finding you…")
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

    /// Save YOUR profile to SwiftData (+ mirror to Supabase), request the
    /// natural permissions, then advance to your code.
    private func saveAboutYou() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        var geocoded: GeocodedLocation? = nil
        if case .success(let location) = geocodeState { geocoded = location }
        people.saveProfile(name: trimmed, emoji: emoji, geocoded: geocoded)

        // Mirror to Supabase users (best-effort) when a location was set.
        if let geocoded {
            Task {
                await SupabaseService.shared.updateUserProfile(
                    name: trimmed, emoji: emoji,
                    latitude: geocoded.coordinate.latitude,
                    longitude: geocoded.coordinate.longitude)
            }
        }

        // Permissions, at the natural moment.
        locationManager.requestWhenInUseAuthorization()
        if !notificationsRequested {
            Task {
                _ = try? await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound, .badge])
            }
            notificationsRequested = true
        }

        HapticEngine.connectionFelt()
        withAnimation(.easeInOut(duration: 0.4)) { page = 3 }
    }

    // MARK: - Screen 4 · Your connection code

    private var yourCodeScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("your connection code ✦")
                .font(.system(size: 27, weight: .semibold, design: .serif))
                .foregroundColor(DesignTokens.Color.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Text("share this with people you love")
                .font(.system(size: 14, design: .serif).italic())
                .foregroundColor(Self.lavender.opacity(0.85))
                .padding(.top, 8)
                .padding(.bottom, 30)

            // The code, big, on a soft lavender card
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Self.lavender.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Self.lavender.opacity(0.45), lineWidth: 1)
                    )
                    .shadow(color: Self.glow.opacity(0.3), radius: 14)

                if let code = codeReady {
                    Text(code.replacingOccurrences(of: "-", with: " · "))
                        .font(.system(size: 34, weight: .semibold, design: .monospaced))
                        .foregroundColor(DesignTokens.Color.textPrimary)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .padding(.horizontal, 20)
                } else if codeBusy {
                    ProgressView().tint(Self.lavender)
                } else {
                    Text("sign in to get your code")
                        .font(.system(size: 14, design: .serif).italic())
                        .foregroundColor(DesignTokens.Color.textMuted)
                }
            }
            .frame(height: 100)
            .padding(.horizontal, 36)

            // Share
            if let code = codeReady {
                ShareLink(item: Self.shareCodeMessage(code: code)) {
                    HStack(spacing: 8) {
                        Text("📱")
                        Text("share my code")
                    }
                    .font(DesignTokens.Font.label)
                    .foregroundColor(DesignTokens.Color.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(DesignTokens.Spacing.md)
                    .background(DesignTokens.Color.accentStrong)
                    .cornerRadius(DesignTokens.Radius.button)
                }
                .padding(.horizontal, 36)
                .padding(.top, 26)
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.4)) { page = 4 }
            } label: {
                Text(codeReady == nil ? "continue →" : "I'll share later →")
                    .font(.system(size: 14))
                    .foregroundColor(DesignTokens.Color.textMuted)
            }
            .padding(.bottom, 10)

            Text("you can always find your code in Settings")
                .font(.system(size: 11, design: .serif).italic())
                .foregroundColor(DesignTokens.Color.textDim)
                .padding(.bottom, 36)
        }
        .onAppear { mintCodeIfNeeded() }
    }

    /// The pre-filled share message for your code.
    private static func shareCodeMessage(code: String) -> String {
        "Connect with me on Pointward ✦\n\(AppLinks.pairLink(code: code))"
    }

    /// Mint YOUR connection code, carrying your profile, once signed in.
    private func mintCodeIfNeeded() {
        guard codeReady == nil, !codeBusy else { return }
        guard SupabaseService.localUserID != nil else { return }   // offline → no code
        codeBusy = true
        Task {
            defer { codeBusy = false }
            let profile = people.profile
            let lat = (profile?.hasLocation == true) ? profile?.latitude : nil
            let lng = (profile?.hasLocation == true) ? profile?.longitude : nil
            do {
                let code = try await SupabaseService.shared.createProfileInvite(
                    name: profile?.displayName ?? name.trimmingCharacters(in: .whitespaces),
                    emoji: profile?.emoji ?? emoji,
                    latitude: lat, longitude: lng)
                codeReady = code
                people.setProfileCode(code)
            } catch {
                // Stays on "sign in to get your code"; not fatal to onboarding.
            }
        }
    }

    // MARK: - Screen 8 · Let's go

    @State private var letsGoGlow = false

    private var letsGoScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Self.glow.opacity(letsGoGlow ? 0.30 : 0.14))
                    .frame(width: 200, height: 200)
                    .blur(radius: 32)
                Text(emoji)
                    .font(.system(size: 78))
                    .scaleEffect(letsGoGlow ? 1.05 : 1.0)
                    .shadow(color: Self.glow.opacity(0.7), radius: 22)
            }

            Text("you're all set ✦")
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .foregroundColor(DesignTokens.Color.textPrimary)
                .padding(.top, 24)

            Text("point toward the people you love")
                .font(.system(size: 14, design: .serif).italic())
                .foregroundColor(Self.lavender.opacity(0.85))
                .padding(.top, 8)

            Spacer()

            Button {
                finishToApp()
            } label: {
                Text("enter Pointward →")
                    .font(DesignTokens.Font.label)
                    .foregroundColor(DesignTokens.Color.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(DesignTokens.Spacing.md)
                    .background(DesignTokens.Color.accentStrong)
                    .cornerRadius(DesignTokens.Radius.button)
                    .shadow(color: Self.glow.opacity(0.5), radius: 12)
            }
            .padding(.horizontal, 36)
            .padding(.bottom, 40)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                letsGoGlow = true
            }
        }
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
