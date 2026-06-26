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

    // Screen 6 — the form
    @State private var name:  String = ""
    // [#6 fix] last name committed via commitProfile() — makes the commit idempotent
    // across the button path, commit-on-leave, and finishToApp (skips redundant writes).
    @State private var lastCommittedName: String = ""
    @State private var emoji: String = "❤️"
    // [location-stripped-2026-06] own-profile location is name-only now — the address /
    // geocode state is PRESERVED (re-enable-ready), not deleted. `locationManager` below
    // stays LIVE: it requests the COMPASS device-location permission (not profile data).
    #if false
    @State private var addressText: String = ""
    @StateObject private var autocomplete = AddressAutocompleteService()
    @State private var selectedAddressText: String? = nil
    @State private var geocodeState:     GeocodeState = .idle
    @State private var geocodedLocation: GeocodedLocation? = nil
    @State private var geocodeTask:      Task<Void, Never>? = nil
    #endif

    private let locationManager = CLLocationManager()   // [location-stripped-2026-06] KEEP — compass device-location permission
    // [build10] "Use current location" — one-shot grab → reverse-geocode → the SAME
    // geocoded path a typed address uses. @State holds one stable instance.
    #if false
    @State private var oneShotLocation = OneShotLocationProvider()   // [location-stripped-2026-06]
    @State private var locating = false                              // [location-stripped-2026-06]
    #endif
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
                    // [build10 fixbatch] trimmed to 2 screens, re-indexed 0–1.
                    // CUT earlier: hero (merged into sign-in bg), yourCode (pairing-era),
                    // letsGo (dead "all set"), proScreen (paywall), givingScreen (charity).
                    // CUT now (fixbatch): instrumentsScreen — the informational "three ways
                    // to connect" MARKETING screen (no input, purely informational) — out of
                    // the launch flow; kept dormant (#if false) for later relocation to
                    // Settings/About. aboutYouScreen is now the LAST step → finishes to the app.
                    signInScreen.tag(0)        // sign in before your profile (now first; compass bg)
                    aboutYouScreen.tag(1)      // YOUR profile — now the LAST step (finishes)
                    // instrumentsScreen.tag(2) // CUT (fixbatch) — marketing screen out of flow (dormant #if false)
                    // proScreen.tag(3)        // CUT (shot3a) — paywall out of flow (dormant #if false)
                    // givingScreen.tag(4)     // CUT (shot3a) — charity out of flow (dormant #if false)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.4), value: page)
                // [#6 fix A] COMMIT-ON-LEAVE: the page TabView is free-swipeable, so a user
                // can swipe past the name step without tapping "continue →". Whenever we
                // LEAVE the name page (old == 1), commit the profile (idempotent) so a typed
                // name is never lost to a swipe — and dismiss the keyboard so the field
                // doesn't linger across the page transition (#6 cause 4).
                .onChange(of: page) { old, _ in
                    if old == 1 {
                        commitProfile()
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }

                pageDots
                    .padding(.bottom, 14)
            }

            // [build10 fixbatch] Skip button REMOVED — it existed only to skip the showcase
            // (instruments) screen to the finish. With the marketing screen cut, there is no
            // showcase step to skip: the flow is sign-in → about-you (which finishes). The
            // sign-in screen has "use offline only" and about-you has "continue →" (now finish).
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
        // [location-stripped-2026-06] own-profile location removed — keep only the NAME prefill.
        // The address pre-fill + geocode is PRESERVED for re-enable:
        // // Pre-fill and geocode their address so "set my compass" is one
        // // tap away when the contact card already knows where they live
        // if let postal = contact.postalAddresses.first?.value {
        //     let formatted = CNPostalAddressFormatter.string(from: postal, style: .mailingAddress)
        //         .replacingOccurrences(of: "\n", with: ", ")
        //         .trimmingCharacters(in: .whitespaces)
        //     if !formatted.isEmpty {
        //         selectedAddressText = formatted   // don't re-trigger the suggestion search
        //         addressText         = formatted
        //         geocodeTypedAddress()
        //     }
        // }
    }

    private var pageDots: some View {
        HStack(spacing: 7) {
            ForEach(0..<2, id: \.self) { i in   // [build10 fixbatch] → 2 screens (marketing cut)
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

    // MARK: - Screen 1 · Hero  [build10 — CUT, merged into the sign-in background]

    // [build10 first-pass] "Begin" splash CUT — its compass moved to the sign-in
    // screen's background (one fewer tap; the emotional compass survives). Only
    // `heroBearing` survives — it is REUSED by the sign-in background compass.
    // [shot3a] The dead `#if false` heroScreen view + heroBreath/heroTagline/heroButton
    // state were hard-deleted (dead pairing/first-pass scaffold, zero live refs).
    @State private var heroBearing: Double = 150

    // MARK: - Screen 1 · Sign in with Apple (now first; carries the compass bg)

    @State private var signInBusy   = false
    @State private var signedIn     = SupabaseService.localUserID != nil
    @State private var signInError: String?
    @State private var currentNonce = ""

    private var signInScreen: some View {
        ZStack {
            // [build10] the merged "Begin" compass — dimmed/blurred BACKGROUND, offset
            // up so the white Apple button + serif title stay legible.
            miniCompass(skin: .vintage, bearing: heroBearing, locked: false, size: 280)
                .opacity(0.35)
                .blur(radius: 1.5)
                .offset(y: -150)
                .allowsHitTesting(false)

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
                    withAnimation(.easeInOut(duration: 0.4)) { page = 1 }   // [build10] → aboutYou (re-indexed)
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
            }   // [build10] close VStack
            .animation(.easeOut(duration: 0.4), value: signedIn)
        }   // [build10] close ZStack (merged compass bg)
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
            // [build10] Apple offers `fullName` only on the FIRST authorization (the
            // `.fullName` scope is requested above). PRE-FILL the name field with it
            // (one-tap confirm/edit on the next step) — only when the field is empty, so
            // a user edit is never clobbered. NEVER relied on (nil on reinstall/edit);
            // the #6 fix still GUARANTEES display_name regardless.
            if name.trimmingCharacters(in: .whitespaces).isEmpty,
               let full = credential.fullName {
                let assembled = [full.givenName, full.familyName]
                    .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                if !assembled.isEmpty { name = assembled }
            }
            signInBusy = true
            signInError = nil
            Task {
                defer { signInBusy = false }
                do {
                    try await SupabaseService.shared.signInWithApple(idToken: idToken,
                                                                     nonce: currentNonce)
                    try await SupabaseService.shared.ensureUser(appleUserID: credential.user)
                    // [pairing-retire step2] pairing-code mint call REMOVED (return value
                    // was discarded; the code is unredeemable + never surfaced). Stops
                    // writing new `connections` rows. The func def stays (removed later, in
                    // order). The LINK path (senderID/link_connections) is unaffected.
                    withAnimation(.easeOut(duration: 0.4)) { signedIn = true }
                    HapticEngine.connectionFelt()
                    // Brief success moment, then onward
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                        if page == 0 {   // [build10] sign-in is now tag 0
                            withAnimation(.easeInOut(duration: 0.4)) { page = 1 }   // → aboutYou
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

    // MARK: - Screen 3 · The four instruments  [build10 fixbatch — CUT from the flow]
    // The informational "three ways to connect" MARKETING screen (instrument carousel +
    // Connector/Expresser/Special-Moments copy) — no input, purely informational. Removed
    // from the TabView; kept DORMANT (#if false, reversible) for later relocation to
    // Settings/About. carouselIndex + cycleInstruments + experienceLine ride with it.
    #if false
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

            Text("three ways to connect")
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundColor(DesignTokens.Color.textPrimary)
                .padding(.top, 26)

            // [three experiences] reframe — Connector · Expresser · Special Moments,
            // each with its one-line descriptor.
            VStack(spacing: 10) {
                experienceLine("Connector", "loving · compass-led · always close")
                experienceLine("Expresser", "fun · instrument-led · your style")
                experienceLine("Special Moments", "occasion-grade · card-quality · premium")
            }
            .padding(.top, 14)

            Spacer()

            finishButton   // [build10 shot3a] instruments is now the LAST step → finish to the app
        }
        .onAppear { cycleInstruments() }
    }

    /// 2-second pause on each instrument, looping while the screen shows.
    private func cycleInstruments() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            guard page == 2 else { return }   // [build10] instruments re-indexed 4 → 2
            withAnimation(.easeInOut(duration: 0.35)) {
                carouselIndex = (carouselIndex + 1) % Instrument.allCases.count
            }
            cycleInstruments()
        }
    }
    #endif

    // [build10 shot3a] Screen 2 (previous) "the compass" — orphaned (defined-but-
    // unmounted) showcase concept + its sole-use alignConcept() helper + conceptRight/
    // conceptLocked state — HARD-DELETED (grep-confirmed zero live refs).

    // [build10 shot3a] Screen 3 (previous) "send a thought / the flick" — orphaned
    // (defined-but-unmounted) demo + its sole-use loopFlick() helper + flickPressed/
    // flickProgress state — HARD-DELETED (grep-confirmed zero live refs).

    // MARK: - Screen 4 · Pro teaser  [build10 shot3a — CUT from the launch flow]
    // Paywall removed from onboarding (free/open at launch; the paywall fires
    // contextually at premium-instrument use). The view is kept DORMANT (#if false,
    // reversible) for that relocation — its InstrumentPreview content is reused later.
    // proScreenSkins (orphan skins variant, never mounted) was HARD-DELETED.
    #if false
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
    #endif

    // MARK: - Screen 5 · Giving back  [build10 shot3a — CUT from the launch flow]
    // Charity removed from onboarding (post-launch concern). The view + givingBreath
    // state are kept DORMANT (#if false, reversible) for a later relocation
    // (Settings/Giving). finishButton (used here previously) now lives on the
    // instruments screen — the new last step — and stays compiled/live.
    #if false
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

            finishButton
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                givingBreath = true
            }
        }
    }
    #endif

    // MARK: - Screen 3 · About you (YOUR profile)

    // [build10 shot3a] codeReady/codeBusy state HARD-DELETED — used only by the
    // (now-deleted) yourCodeScreen pairing-code screen.

    private var aboutYouScreen: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("set your home · let us give direction to your messages ✦")
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

                    // [build10] emoji picker CUT (off-registry default; redesign call).
                    // `emoji` stays at its "❤️" default; UserProfile.emoji is KEPT
                    // (PersonDetailView reads it, falling back to person.emoji).
                    // Your emoji — tap to change (the full picker)
                    // fieldLabel("your emoji")
                    // EmojiPickerRow(selected: $emoji)

                    // [location-stripped-2026-06] own-profile location removed — about-you is
                    // NAME ONLY now. The Home-Location field + "Use current location" + helper
                    // are PRESERVED below for re-enable (the plumbing lives under #if false):
                    // // Where you are — MKLocalSearch autocomplete
                    // fieldLabel("Home Location (optional but recommended)")
                    // addressAutocompleteField
                    //
                    // // [build10] USE CURRENT LOCATION — the 3rd Home-Location option
                    // // (Skip / Type / Use current). One-time when-in-use grab → reverse-
                    // // geocode → writes into the SAME geocodedLocation/geocodeState path the
                    // // typed address uses, so commitProfile sends lat/lng identically.
                    // Button { useCurrentLocation() } label: {
                    //     HStack(spacing: 6) {
                    //         Image(systemName: "location.fill").font(.system(size: 11))
                    //         Text(locating ? "finding your location…" : "Use current location")
                    //     }
                    //     .font(.system(size: 13))
                    //     .foregroundColor(Self.lavender)
                    // }
                    // .disabled(locating)
                    // .padding(.top, 4)
                    //
                    // Text("your location lets people you connect with point\ntoward you — share only what you're comfortable with")
                    //     .font(.system(size: 13, design: .serif).italic())
                    //     .foregroundColor(DesignTokens.Color.textMuted)
                    //     .fixedSize(horizontal: false, vertical: true)
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

    /// One of the three experiences on the instruments page — name + a one-line
    /// descriptor (Connector · Expresser · Special Moments).
    private func experienceLine(_ name: String, _ descriptor: String) -> some View {
        VStack(spacing: 1) {
            Text(name)
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundColor(DesignTokens.Color.textPrimary)
            Text(descriptor)
                .font(.system(size: 12, design: .serif).italic())
                .foregroundColor(Self.lavender.opacity(0.85))
        }
    }

    /// The shared address field with live MKLocalSearch suggestions.
    // [location-stripped-2026-06] PRESERVED for re-enable — the own-profile address field is
    // no longer rendered (about-you is name-only). Dormant under #if false.
    #if false
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
    #endif  // [location-stripped-2026-06] addressAutocompleteField (dormant)

    /// [#6 fix] Commit the profile — LOCAL save + the SERVER `display_name` write,
    /// UNCONDITIONALLY (a name guarantees `users.display_name`, address or not). Idempotent
    /// via `lastCommittedName` (re-runs only when the name changed) so the button path +
    /// commit-on-leave + finishToApp can all call it without redundant writes. The #6 root
    /// was the server write being gated on a geocoded address (`if let geocoded`) — gone.
    private func commitProfile() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != lastCommittedName else { return }
        lastCommittedName = trimmed

        // [location-stripped-2026-06] own-profile location removed — name only. The geocode
        // read + lat/lng send are PRESERVED for re-enable:
        // var geocoded: GeocodedLocation? = nil
        // if case .success(let location) = geocodeState { geocoded = location }
        people.saveProfile(name: trimmed, emoji: emoji)   // LOCAL (no geocoded — paths are nil-safe)

        // SERVER mirror — display_name + emoji (lat/lng dropped with the strip).
        Task {
            await SupabaseService.shared.updateUserProfile(name: trimmed, emoji: emoji)
            // [location-stripped-2026-06] was: latitude: geocoded?.coordinate.latitude,
            //                                  longitude: geocoded?.coordinate.longitude
        }
    }

    /// Save YOUR profile, request the natural permissions, then FINISH.
    private func saveAboutYou() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        commitProfile()   // [#6 fix C] writes display_name unconditionally

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
        // [build10 fixbatch] instruments (marketing) cut → aboutYou is the LAST step.
        // finishToApp() re-commits (idempotent) → the #6 display_name guarantee holds.
        finishToApp()
    }

    // [build10 shot3a] Screen "Your connection code" (pairing-era) + its mint/share
    // helpers (shareCodeMessage / mintCodeIfNeeded, the latter holding the dangling
    // createProfileInvite call) — HARD-DELETED. Was dead `#if false`; the link model
    // replaced the connection-code screen. (The live pairing-code-gen subsystem —
    // myPairingCode on sign-in — is a SEPARATE concern, untouched here.)

    // [build10 shot3a] Screen "Let's go" (dead "you're all set" + letsGoGlow state) —
    // HARD-DELETED. Was dead `#if false`; the flow now finishes at the instruments
    // (showcase) step via finishButton → finishToApp().

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

    /// [build10] The LAST showcase screen (giving) finishes straight to the app —
    /// the cut "you're all set" screen's completion lands here.
    private var finishButton: some View {
        Button {
            finishToApp()
        } label: {
            Text("enter Pointward →")
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

    // [build10 minor cleanup] startCompletion() + showCompletion (@State) HARD-DELETED —
    // orphaned after Shot 3a removed alignConcept/loopFlick: startCompletion had zero
    // callers and showCompletion was write-only (set only here, read nowhere). The live
    // finish path is finishButton → finishToApp() (below). geocodedLocation is KEPT
    // (still live in the address-geocode path).

    private func finishToApp() {
        commitProfile()   // [#6 fix B] guarantee any typed name is committed before finishing
        hasCompletedOnboarding = true
    }

    // MARK: - Address autocomplete (same implementation as AddPersonView)

    // [location-stripped-2026-06] own-profile geocode plumbing PRESERVED for re-enable
    // (handleAddressInput · selectSuggestion · geocodeTypedAddress · useCurrentLocation).
    // Dormant under #if false now that about-you is name-only.
    #if false
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

    /// [build10] "Use current location" — one-time when-in-use grab → reverse-geocode →
    /// write into the SAME geocodedLocation/geocodeState path as a typed/picked address,
    /// so commitProfile sends lat/lng identically. Deny/fail degrades to Skip (no
    /// coordinate written → seeded bearing), with a gentle note in the existing UI.
    private func useCurrentLocation() {
        guard !locating else { return }
        locating = true
        autocomplete.clear()
        geocodeState = .geocoding("your location")   // shows "finding you…"
        Task {
            defer { locating = false }
            do {
                let coordinate = try await oneShotLocation.requestOnce()
                let result = try await geocodingService.reverseGeocode(coordinate: coordinate)
                geocodedLocation    = result
                geocodeState        = .success(result)          // commitProfile reads this
                addressText         = result.fullAddress         // reflect it in the field
                selectedAddressText = result.fullAddress         // don't re-trigger a search
            } catch OneShotLocationProvider.LocationError.denied {
                geocodeState = .failure("Location access is off — type your address or skip.")
            } catch {
                geocodeState = .failure("Couldn't get your location — type your address or skip.")
            }
        }
    }
    #endif  // [location-stripped-2026-06] geocode plumbing (dormant)
}

// [build10 shot3a] CompletionMoment ("your compass is set ✦") — HARD-DELETED.
// Orphaned private struct: grep-confirmed zero references (definition only); it was
// tied to the cut letsGoScreen/post-finish moment and never instantiated.
