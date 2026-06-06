// AccountView.swift
// Pointward › Views
//
// Phase 2 account screen: Sign in with Apple → your pairing code →
// enter a friend's code to connect. Reached from Settings › account.

import SwiftUI
import AuthenticationServices
import CryptoKit

struct AccountView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var people: PeopleManager

    @State private var userID: UUID?      = SupabaseService.localUserID
    @State private var pairingCode        = SupabaseService.localPairingCode ?? ""
    @State private var friendID: UUID?    = SupabaseService.connectedFriendID
    @State private var codeInput          = ""
    @State private var isBusy             = false
    @State private var errorMessage: String?
    @State private var currentNonce       = ""
    @State private var showCelebration   = false

    var body: some View {
        ZStack {
            DesignTokens.Color.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Spacer()
                    Button("done") { dismiss() }
                        .font(DesignTokens.Font.label)
                        .foregroundColor(DesignTokens.Color.accentSoft)
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.vertical, DesignTokens.Spacing.md)

                ScrollView {
                    VStack(spacing: 0) {
                        Text("account")
                            .font(DesignTokens.Font.compassName)
                            .foregroundColor(DesignTokens.Color.textPrimary)
                            .padding(.bottom, 4)
                        Text("pair with someone to send real thoughts")
                            .font(DesignTokens.Font.caption)
                            .foregroundColor(DesignTokens.Color.textMuted)
                            .padding(.bottom, 28)

                        if userID == nil {
                            signInSection
                        } else {
                            pairingSection
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(DesignTokens.Font.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.top, 16)
                        }

                        if isBusy {
                            ProgressView()
                                .tint(DesignTokens.Color.accentSoft)
                                .padding(.top, 16)
                        }
                    }
                    .padding(.horizontal, 28)
                }
            }
        }
        .onAppear { refresh() }
        .fullScreenCover(isPresented: $showCelebration) {
            PairingCelebrationView(person: people.selectedPerson) {
                showCelebration = false
                dismiss()
            }
        }
    }

    // MARK: - Sign in

    private var signInSection: some View {
        VStack(spacing: 14) {
            SignInWithAppleButton(.signIn) { request in
                currentNonce = Self.randomNonce()
                request.requestedScopes = [.fullName]
                request.nonce = Self.sha256(currentNonce)
            } onCompletion: { result in
                handleAppleResult(result)
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 48)
            .cornerRadius(DesignTokens.Radius.button)

            Text("no email shared with us — Apple keeps it private")
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Color.textDim)
        }
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure:
            errorMessage = "Sign in didn't complete — try again."
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                errorMessage = "Sign in didn't complete — try again."
                return
            }
            isBusy = true
            errorMessage = nil
            Task {
                defer { isBusy = false }
                do {
                    try await SupabaseService.shared.signInWithApple(idToken: idToken,
                                                                     nonce: currentNonce)
                    let me = try await SupabaseService.shared.ensureUser(
                        appleUserID: credential.user)
                    userID = me
                    pairingCode = try await SupabaseService.shared.myPairingCode()
                    friendID = try await SupabaseService.shared.refreshConnection()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Pairing

    private var pairingSection: some View {
        VStack(spacing: 22) {
            // Your code
            VStack(spacing: 8) {
                Text("YOUR CODE")
                    .font(.system(size: 11, weight: .medium))
                    .kerning(2)
                    .foregroundColor(DesignTokens.Color.textMuted)
                Text(pairingCode.isEmpty ? "· · · · · ·" : pairingCode)
                    .font(.system(size: 30, weight: .semibold, design: .monospaced))
                    .foregroundColor(DesignTokens.Color.accentSoft)
                Text("share it with the person you point toward")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Color.textDim)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(DesignTokens.Color.backgroundCard)
            .cornerRadius(DesignTokens.Radius.card)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.card)
                    .stroke(DesignTokens.Color.border, lineWidth: 1)
            )

            // Connection state / redeem
            if friendID != nil {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                    Text("connected ✓ — thoughts now travel for real")
                }
                .font(DesignTokens.Font.label)
                .foregroundColor(Color(hex: "#5dcaa5"))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("enter a friend's code")
                        .font(DesignTokens.Font.overline)
                        .foregroundColor(DesignTokens.Color.textMuted)
                    HStack(spacing: 10) {
                        TextField("POINT-XXXX", text: $codeInput)
                            .font(.system(size: 17, design: .monospaced))
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .formInput()
                        Button {
                            redeem()
                        } label: {
                            Text("connect")
                                .font(DesignTokens.Font.label)
                                .foregroundColor(DesignTokens.Color.textPrimary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 13)
                                .background(DesignTokens.Color.accentStrong)
                                .cornerRadius(DesignTokens.Radius.button)
                        }
                        .disabled(codeInput.trimmingCharacters(in: .whitespaces).isEmpty || isBusy)
                    }
                }
            }

            // Sign out
            Button("sign out") {
                signOut()
            }
            .font(DesignTokens.Font.caption)
            .foregroundColor(DesignTokens.Color.textMuted)
            .padding(.top, 8)
        }
    }

    private func redeem() {
        isBusy = true
        errorMessage = nil
        Task {
            defer { isBusy = false }
            do {
                friendID = try await SupabaseService.shared.redeemCode(codeInput)
                codeInput = ""
                showCelebration = true   // the moment two compasses link
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func refresh() {
        guard userID != nil else { return }
        Task {
            pairingCode = (try? await SupabaseService.shared.myPairingCode()) ?? pairingCode
            if let partner = try? await SupabaseService.shared.refreshConnection() {
                // Owner's side discovering the new pairing also celebrates
                let isNew = friendID == nil
                friendID = partner
                if isNew { showCelebration = true }
            }
        }
    }

    private func signOut() {
        Task {
            try? await SupabaseService.shared.signOut()
            SupabaseService.localUserID       = nil
            SupabaseService.connectedFriendID = nil
            SupabaseService.localPairingCode  = nil
            userID      = nil
            friendID    = nil
            pairingCode = ""
        }
    }

    // MARK: - Nonce helpers (standard Sign in with Apple + Supabase pattern)

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFabcdef")
        return String((0..<length).map { _ in charset.randomElement()! })
    }

    private static func sha256(_ input: String) -> String {
        let hash = SHA256.hash(data: Data(input.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Pairing celebration

/// The moment two compasses link — a full-screen ritual, not a popup.
/// Two compass faces drift in from opposite edges, meet at the center,
/// and the connection settles in around them.
struct PairingCelebrationView: View {

    let person: Person?
    let onDone: () -> Void

    @AppStorage("quietMode") private var quietMode = false

    // Staging
    @State private var glowBloom    = false
    @State private var met          = false
    @State private var showTitle    = false
    @State private var showSubtitle = false
    @State private var showPerson   = false
    @State private var showTagline  = false
    @State private var showButton   = false

    private let lavender   = Color(hex: "#c4a8d4")
    private let purpleGlow = Color(hex: "#9b7fc0")

    var body: some View {
        ZStack {
            // Deep purple ground with a blooming lavender glow
            DesignTokens.Color.background.ignoresSafeArea()
            RadialGradient(
                colors: [purpleGlow.opacity(glowBloom ? 0.30 : 0.0), .clear],
                center: .center, startRadius: 20, endRadius: 420
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Two compass faces meeting in the middle
                GeometryReader { geo in
                    ZStack {
                        compassFace
                            .offset(x: met ? -34 : -geo.size.width / 2 - 80)
                        compassFace
                            .offset(x: met ?  34 :  geo.size.width / 2 + 80)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: 120)
                .padding(.bottom, 36)

                Text("connected")
                    .font(.system(size: 32, weight: .semibold, design: .serif))
                    .foregroundColor(DesignTokens.Color.textPrimary)
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: showTitle ? 0 : 8)
                    .padding(.bottom, 6)

                Text("your compasses are now linked")
                    .font(DesignTokens.Font.compassDistance)
                    .foregroundColor(DesignTokens.Color.textMuted)
                    .opacity(showSubtitle ? 1 : 0)
                    .padding(.bottom, 30)

                // Who you point toward
                if let person {
                    VStack(spacing: 6) {
                        HStack(spacing: 10) {
                            Text(person.emoji).font(.system(size: 26))
                            Text(person.name)
                                .font(DesignTokens.Font.compassName)
                                .foregroundColor(DesignTokens.Color.textPrimary)
                        }
                        .opacity(showPerson ? 1 : 0)

                        Text(person.resolvedTagline)
                            .font(.system(size: 13).italic())
                            .foregroundColor(DesignTokens.Color.accentMid)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .opacity(showTagline ? 1 : 0)
                    }
                }

                Spacer()

                if showButton {
                    Button(action: onDone) {
                        Text("open your compass")
                            .font(DesignTokens.Font.label)
                            .foregroundColor(DesignTokens.Color.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(DesignTokens.Spacing.md)
                            .background(DesignTokens.Color.accentStrong)
                            .cornerRadius(DesignTokens.Radius.button)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 30)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .onAppear { runCelebration() }
    }

    /// One small compass face — ring, soft glow, 🧭 at heart.
    private var compassFace: some View {
        ZStack {
            Circle()
                .fill(purpleGlow.opacity(glowBloom ? 0.30 : 0.10))
                .frame(width: 76, height: 76)
                .blur(radius: 14)
            Circle()
                .stroke(lavender.opacity(0.6), lineWidth: 1)
                .frame(width: 84, height: 84)
            Circle()
                .stroke(lavender.opacity(0.2), lineWidth: 1)
                .frame(width: 98, height: 98)
            Text("🧭")
                .font(.system(size: 36))
        }
    }

    private func runCelebration() {
        // Glow blooms as the screen opens
        withAnimation(.easeInOut(duration: 1.2)) { glowBloom = true }
        // The two compasses drift in and meet
        withAnimation(.spring(response: 1.0, dampingFraction: 0.75).delay(0.3)) {
            met = true
        }
        // Soft warm double pulse the moment they meet
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            HapticEngine.pingReceived()
        }
        withAnimation(.easeOut(duration: 0.6).delay(1.0))  { showTitle    = true }
        withAnimation(.easeOut(duration: 0.6).delay(1.3))  { showSubtitle = true }
        withAnimation(.easeOut(duration: 0.6).delay(1.6))  { showPerson   = true }
        withAnimation(.easeIn(duration: 0.7).delay(1.9))   { showTagline  = true }
        // The button waits until the moment has landed
        withAnimation(.easeOut(duration: 0.5).delay(2.0))  { showButton   = true }
    }
}

#Preview {
    AccountView()
        .environmentObject(PeopleManager(subscriptionManager: SubscriptionManager()))
        .preferredColorScheme(.dark)
}

#Preview("Celebration") {
    PairingCelebrationView(
        person: Person(
            name: "Mum", emoji: "🏠",
            latitude: 51.5, longitude: -0.12,
            displayAddress: "London", tagline: "Never far."
        ),
        onDone: {}
    )
    .preferredColorScheme(.dark)
}
