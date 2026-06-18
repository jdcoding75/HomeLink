// ComposeBackView.swift
// Pointward › Views
//
// BUILD 10 — SHOT 2 · the link-arriver's "Send one back to [Name]" door.
//
// The minimal SHARED IDENTITY for a reply — sign-in + a name — NOT the full
// onboarding tour. A sender always has a name (the #6 guarantee lands here too).
//
//   • Signed OUT → Apple sign-in ("just sign in") → name (Apple-name pre-filled,
//     Shot-1 logic) → commit (local + server display_name) → onEntered().
//   • Signed IN  → IncomingMessageView skips this view entirely and enters
//     compose directly (see goToComposeBack()), so this view's name step is the
//     fresh-arriver path.
//
// onEntered() is wired by IncomingMessageView to: select the sender as the
// compass target, fire the fill-via-link aim, mark the guest flag, and dismiss
// into the app (the compass, pointing back at the sender).
//
// Placeholder copy — refine in situ. Additive; does not touch the arrival flow,
// the fresh-installer onboarding, or the #6 fix in OnboardingView (this is a
// parallel minimal commit for the link path).

import SwiftUI
import AuthenticationServices
import CryptoKit

struct ComposeBackView: View {

    /// The sender's resolved name — the person we're replying to.
    let senderName: String
    /// Called once the minimal identity is in place → enter the app composing.
    var onEntered: () -> Void = {}

    @EnvironmentObject var people: PeopleManager

    @State private var signedIn = SupabaseService.localUserID != nil
    @State private var name = ""
    @State private var emoji = "❤️"            // default (matches onboarding; off-registry picker cut)
    @State private var currentNonce = ""
    @State private var busy = false
    @State private var signInError: String? = nil
    @State private var lastCommittedName = ""

    private static let lavender = Color(hex: "#c4a8d4")

    var body: some View {
        ZStack {
            DesignTokens.Color.background.ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()

                Text("✦")
                    .font(.system(size: 30))
                    .foregroundColor(Self.lavender.opacity(0.8))

                if !signedIn {
                    signInStep
                } else {
                    nameStep
                }

                Spacer()
                Spacer()
            }
            .padding(.horizontal, 32)
            .animation(.easeOut(duration: 0.35), value: signedIn)
        }
    }

    // MARK: - Sign-in (signed-out arriver)

    private var signInStep: some View {
        VStack(spacing: 16) {
            Text("reply to \(senderName)")
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundColor(DesignTokens.Color.textPrimary)
                .multilineTextAlignment(.center)

            Text("just sign in to send one back")
                .font(.system(size: 13, design: .serif).italic())
                .foregroundColor(Self.lavender.opacity(0.85))
                .padding(.bottom, 14)

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
            .disabled(busy)
            .opacity(busy ? 0.6 : 1)

            if busy {
                ProgressView().tint(DesignTokens.Color.accentSoft).padding(.top, 12)
            }
            if let signInError {
                Text(signInError)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
            }
        }
    }

    // MARK: - Name (the #6 capture — a sender always has a name)

    private var nameStep: some View {
        VStack(spacing: 16) {
            Text("How should your name appear to \(senderName)?")
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundColor(DesignTokens.Color.textPrimary)
                .multilineTextAlignment(.center)

            TextField("your name", text: $name)
                .formInput()
                .padding(.top, 4)

            Button {
                commitAndEnter()
            } label: {
                Text("Send one back to \(senderName) →")
                    .font(DesignTokens.Font.label)
                    .foregroundColor(DesignTokens.Color.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(DesignTokens.Spacing.md)
                    .background(DesignTokens.Color.accentStrong)
                    .cornerRadius(DesignTokens.Radius.button)
            }
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
            .padding(.top, 8)
        }
    }

    // MARK: - Apple sign-in result (mirrors SettingsView/OnboardingView pattern)

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure:
            signInError = nil   // includes user-cancelled — stay quiet
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                signInError = "Sign in didn't complete — try again."
                return
            }
            // [Shot 1 logic] Apple offers fullName only on first auth — pre-fill the
            // name (only when empty; never clobber a user edit).
            if name.trimmingCharacters(in: .whitespaces).isEmpty,
               let full = credential.fullName {
                let assembled = [full.givenName, full.familyName]
                    .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                if !assembled.isEmpty { name = assembled }
            }
            busy = true
            signInError = nil
            Task {
                defer { busy = false }
                do {
                    try await SupabaseService.shared.signInWithApple(idToken: idToken,
                                                                     nonce: currentNonce)
                    try await SupabaseService.shared.ensureUser(appleUserID: credential.user)
                    // [pairing-retire step2] pairing-code mint call REMOVED (discarded result).
                    // ⚠️ THIRD call site — the audit listed only OnboardingView + SettingsView;
                    // this one (added in Shot 2, "same as onboarding") was also stopping the
                    // mint open for link-arriver sign-ins. Removed to fully stop the mint.
                    HapticEngine.connectionFelt()
                    withAnimation(.easeOut(duration: 0.35)) { signedIn = true }   // → name step
                } catch {
                    signInError = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Commit the minimal identity, then enter composing

    /// The #6 guarantee on the link path: write display_name LOCAL + SERVER, then
    /// hand off to IncomingMessageView to select the sender + aim + dismiss.
    private func commitAndEnter() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if trimmed != lastCommittedName {
            lastCommittedName = trimmed
            people.saveProfile(name: trimmed, emoji: emoji)                       // LOCAL
            Task { await SupabaseService.shared.updateUserProfile(name: trimmed, emoji: emoji) }  // SERVER (display_name always)
        }
        onEntered()
    }

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFabcdef")
        return String((0..<length).map { _ in charset.randomElement()! })
    }

    private static func sha256(_ input: String) -> String {
        let hash = SHA256.hash(data: Data(input.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
