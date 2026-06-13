// SettingsView.swift
// Pointward › Views
//
// A clean, minimal settings surface:
//   send preferences · notifications · about Pointward · account · developer.
// The Pro screen was retired as a tab; instrument/skin selection lives on the
// compass long-press picker, and Pro status + upgrade now live here in account.

import SwiftUI
import AuthenticationServices
import CryptoKit
import os

struct SettingsView: View {

    private static let log = Logger(subsystem: "com.jdcoding75.pointward", category: "settings-account")

    @EnvironmentObject var subscription: SubscriptionManager
    #if DEBUG
    @EnvironmentObject var devPings: PingManager
    #endif

    // Sign-in state — drives the account section (button when signed out,
    // static identity when signed in). Seeded from the persisted session.
    @State private var signedInUserID: UUID? = SupabaseService.localUserID
    @State private var currentNonce  = ""
    @State private var isSigningIn   = false
    @State private var signInError: String? = nil

    // Display preference — surprise unit each launch (-1) or a locked favourite.
    @AppStorage("funnyUnitLocked")       private var funnyUnitLocked      = -1
    @AppStorage("notifyPointing")        private var notifyPointing       = true
    @AppStorage("arrivalPreviewEnabled") private var arrivalPreviewEnabled = true   // [5/6]

    @State private var showGivingBack = false
    @State private var showAbout      = false
    @State private var showPaywall    = false
    #if DEBUG
    @State private var showTestSheet        = false
    @State private var showAnimationLab     = false
    @State private var showAnimationFeedback = false
    #endif

    /// Toggle ON = clear warm teal; OFF stays the system's dark grey track.
    private static let toggleOn = Color(hex: "#5dcaa5")
    private static let green    = Color(hex: "#5dcaa5")

    private var isPro: Bool { subscription.tier != .free }

    var body: some View {
        ZStack {
            DesignTokens.Color.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    sectionHeader("send preferences")
                    sendPreferencesSection

                    sectionHeader("notifications")
                    notificationsSection

                    sectionHeader("about Pointward")
                    aboutSection

                    sectionHeader("account")
                    accountSection

                    #if DEBUG
                    sectionHeader("developer")
                    developerSection
                    #endif

                    // removed — see SESSION_LOG.md for history
                    // (proSection · inviteSection · unlockSection · feelSection ·
                    //  expressionSection · experienceSection · skinSection ·
                    //  hold-to-send block · `if false` pairing-code rows)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
            }
        }
        .sheet(isPresented: $showGivingBack) { GivingBackView() }
        .sheet(isPresented: $showAbout) { AboutView() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        #if DEBUG
        .sheet(isPresented: $showTestSheet) {
            TestMessageSheet().environmentObject(devPings)
        }
        .fullScreenCover(isPresented: $showAnimationLab) {
            AnimationTestLabView()
        }
        .sheet(isPresented: $showAnimationFeedback) {
            AnimationFeedbackView()
        }
        #endif
    }

    // MARK: - Send preferences

    /// Funny Distance — a display preference moved out of the old Pro screen.
    /// Surprise-me each launch, or lock a favourite unit.
    private var sendPreferencesSection: some View {
        settingsGroup {
            settingsRow {
                Image(systemName: "ruler")
                    .settingsIcon()
                VStack(alignment: .leading, spacing: 2) {
                    Text("funny distance")
                        .settingsLabel()
                    Text(funnyUnitLocked < 0 ? "a surprise unit each launch"
                                             : "locked to your favourite")
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Color.textDim)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { funnyUnitLocked >= 0 },
                    set: { locked in funnyUnitLocked = locked ? 0 : -1 }
                ))
                .tint(Self.toggleOn)
                .labelsHidden()
            }

            if funnyUnitLocked >= 0 {
                Divider().background(DesignTokens.Color.border).padding(.leading, 44)
                settingsRow {
                    Image(systemName: "sportscourt")
                        .settingsIcon()
                    Text("favourite unit")
                        .settingsLabel()
                    Spacer()
                    Picker("", selection: $funnyUnitLocked) {
                        ForEach(0..<DistanceFun.funnyCount, id: \.self) { i in
                            Text(DistanceFun.funnyLabels[i]).tag(i)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(DesignTokens.Color.accentSoft)
                }
            }
        }
    }

    // MARK: - Notifications  (will evolve with Phase 2)

    private var notificationsSection: some View {
        settingsGroup {
            settingsRow {
                Image(systemName: "sparkle")
                    .settingsIcon()
                VStack(alignment: .leading, spacing: 2) {
                    Text("thoughts")
                        .settingsLabel()
                    Text("a gentle word when someone points toward you")
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Color.textDim)
                }
                Spacer()
                Toggle("", isOn: $notifyPointing)
                    .tint(Self.toggleOn)
                    .labelsHidden()
                    .onChange(of: notifyPointing) { _, enabled in
                        // Mirror server-side so closed-app pushes respect it too
                        Task { await SupabaseService.shared.setNotifyPointing(enabled) }
                    }
            }

            Divider().background(DesignTokens.Color.border).padding(.leading, 44)

            // [5/6] A brief glimpse of what your person catches, right after you
            // send — on by default for your first sends, then your choice.
            settingsRow {
                Image(systemName: "eye")
                    .settingsIcon()
                VStack(alignment: .leading, spacing: 2) {
                    Text("show arrival preview")
                        .settingsLabel()
                    Text("a 2-second glimpse of their catch after you send")
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Color.textDim)
                }
                Spacer()
                Toggle("", isOn: $arrivalPreviewEnabled)
                    .tint(Self.toggleOn)
                    .labelsHidden()
            }
        }
    }

    // MARK: - About Pointward

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    private var aboutSection: some View {
        settingsGroup {
            // Giving back — half of every Pro purchase does good. Lives here now.
            settingsRow {
                Text("❤️")
                    .font(.system(size: 16))
                    .frame(width: 26, height: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text("giving back")
                        .settingsLabel()
                    Text(CharityConfig.current.map { "50% of Pro supports \($0.name)" }
                         ?? "supporting those who need it most")
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Color.textDim)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Color.textDim)
            }
            .contentShape(Rectangle())
            .onTapGesture { showGivingBack = true }

            Divider().background(DesignTokens.Color.border).padding(.leading, 44)

            settingsRow {
                Image(systemName: "heart.text.square")
                    .settingsIcon()
                Text("our story")
                    .settingsLabel()
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Color.textDim)
            }
            .contentShape(Rectangle())
            .onTapGesture { showAbout = true }

            Divider().background(DesignTokens.Color.border).padding(.leading, 44)

            Link(destination: URL(string: "https://pointward.app/privacy")!) {
                settingsRow {
                    Image(systemName: "lock.shield")
                        .settingsIcon()
                    Text("privacy policy")
                        .settingsLabel()
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Color.textDim)
                }
            }

            Divider().background(DesignTokens.Color.border).padding(.leading, 44)

            settingsRow {
                Image(systemName: "app.badge")
                    .settingsIcon()
                Text("version")
                    .settingsLabel()
                Spacer()
                Text(appVersion)
                    .font(DesignTokens.Font.caption)
                    .foregroundColor(DesignTokens.Color.textMuted)
            }

            Divider().background(DesignTokens.Color.border).padding(.leading, 44)

            // The one-line mission.
            settingsRow {
                Spacer()
                Text("feelings, delivered ✦")
                    .font(.system(size: 13, design: .serif).italic())
                    .foregroundColor(DesignTokens.Color.accentSoft)
                Spacer()
            }
        }
    }

    // MARK: - Account  (folded in — AccountView retired)

    private var accountSection: some View {
        settingsGroup {
            // Identity — Sign in with Apple when signed out, static line when in.
            if signedInUserID == nil {
                VStack(alignment: .leading, spacing: 8) {
                    SignInWithAppleButton(.signIn) { request in
                        currentNonce = Self.randomNonce()
                        request.requestedScopes = [.fullName]
                        request.nonce = Self.sha256(currentNonce)
                    } onCompletion: { result in
                        handleAppleResult(result)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 46)
                    .cornerRadius(DesignTokens.Radius.button)
                    .disabled(isSigningIn)

                    Text("sign in to pair and send real thoughts")
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Color.textDim)

                    if let signInError {
                        Text(signInError)
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if isSigningIn {
                        ProgressView().tint(DesignTokens.Color.accentSoft)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, 13)
            } else {
                // Signed-in identity — static, no action.
                settingsRow {
                    Image(systemName: "applelogo")
                        .settingsIcon()
                    Text("Signed in with Apple ✦")
                        .settingsLabel()
                    Spacer()
                }
            }

            Divider().background(DesignTokens.Color.border).padding(.leading, 44)

            // Pro status — "Pro ✦" or "Free · upgrade" (tap free to upgrade).
            settingsRow {
                Image(systemName: "sparkles")
                    .settingsIcon()
                VStack(alignment: .leading, spacing: 2) {
                    Text(isPro ? "Pro ✦" : "Free · upgrade")
                        .settingsLabel()
                        .foregroundColor(isPro ? Self.green : DesignTokens.Color.textPrimary)
                    Text(isPro ? "thank you — yours forever ✦"
                               : "unlock everything · one-time $2.99")
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Color.textDim)
                }
                Spacer()
                if !isPro {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Color.textDim)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { if !isPro { showPaywall = true } }

            Divider().background(DesignTokens.Color.border).padding(.leading, 44)

            // Restore purchase — re-grant Pro on a new device / reinstall.
            settingsRow {
                Image(systemName: "arrow.clockwise")
                    .settingsIcon()
                Text("restore purchase")
                    .settingsLabel()
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                Task { await subscription.restorePurchases() }
            }

            // Sign out — at the bottom, only when there's a session to leave.
            if signedInUserID != nil {
                Divider().background(DesignTokens.Color.border).padding(.leading, 44)

                settingsRow {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .settingsIcon()
                        .foregroundColor(.red)
                    Text("sign out")
                        .settingsLabel()
                        .foregroundColor(.red)
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture { signOut() }
            }
        }
    }

    // MARK: - Sign in / out (ported from the retired AccountView; standard
    // Sign in with Apple + Supabase pattern)

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            Self.log.error("signin: Apple authorization failed: \(error.localizedDescription, privacy: .public)")
            signInError = "Sign in didn't complete — try again."
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                Self.log.error("signin: missing identity token in Apple credential")
                signInError = "Sign in didn't complete — try again."
                return
            }
            isSigningIn = true
            signInError = nil
            Task {
                defer { isSigningIn = false }
                do {
                    try await SupabaseService.shared.signInWithApple(idToken: idToken,
                                                                     nonce: currentNonce)
                    let me = try await SupabaseService.shared.ensureUser(appleUserID: credential.user)
                    _ = try await SupabaseService.shared.myPairingCode()
                    _ = try await SupabaseService.shared.refreshConnection()
                    signedInUserID = me
                    Self.log.info("signin: complete ✓")
                } catch {
                    Self.log.error("signin: post-auth setup failed: \(error.localizedDescription, privacy: .public)")
                    signInError = error.localizedDescription
                }
            }
        }
    }

    private func signOut() {
        Task {
            await SupabaseService.shared.stopListening()   // realtime dies with the session
            try? await SupabaseService.shared.signOut()
            SupabaseService.localUserID       = nil
            SupabaseService.connectedFriendID = nil
            SupabaseService.localPairingCode  = nil
            signedInUserID = nil
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

    #if DEBUG
    // MARK: - Developer (DEBUG only — never ships)
    //
    // Minimal: the animation lab, a self-send, and build info. Simulate
    // far/nearby, auto-catch-all, and pairing/connection-testing tools were
    // removed — see SESSION_LOG.md for history.

    private var developerSection: some View {
        settingsGroup {
            // Send yourself a test thought — full receipt, no 2nd phone.
            Button { showTestSheet = true } label: {
                settingsRow {
                    Image(systemName: "paperplane.fill")
                        .settingsIcon()
                        .foregroundColor(Color(hex: "#c4a8d4"))
                    Text("Send myself a test thought").settingsLabel()
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12))
                        .foregroundColor(DesignTokens.Color.textDim)
                }
            }
            .buttonStyle(.plain)

            Divider().background(DesignTokens.Color.border).padding(.leading, 44)

            // 🧪 Animation Test Lab — every send + land animation, in isolation.
            Button { showAnimationLab = true } label: {
                settingsRow {
                    Image(systemName: "theatermasks").settingsIcon()
                        .foregroundColor(Color(hex: "#c4a8d4"))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("🧪 Animation Test Lab").settingsLabel()
                        Text("every send + land animation, in isolation")
                            .font(.system(size: 11)).foregroundColor(DesignTokens.Color.textMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12))
                        .foregroundColor(DesignTokens.Color.textDim)
                }
            }
            .buttonStyle(.plain)

            Divider().background(DesignTokens.Color.border).padding(.leading, 44)

            // 📋 Animation feedback — approved / needs-work summary from the lab.
            Button { showAnimationFeedback = true } label: {
                settingsRow {
                    Image(systemName: "list.clipboard").settingsIcon()
                        .foregroundColor(Color(hex: "#c4a8d4"))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("📋 View animation feedback").settingsLabel()
                        Text("approved / needs-work summary from the lab")
                            .font(.system(size: 11)).foregroundColor(DesignTokens.Color.textMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12))
                        .foregroundColor(DesignTokens.Color.textDim)
                }
            }
            .buttonStyle(.plain)

            Divider().background(DesignTokens.Color.border).padding(.leading, 44)

            // Build info.
            settingsRow {
                Image(systemName: "hammer").settingsIcon()
                VStack(alignment: .leading, spacing: 2) {
                    Text("build info").settingsLabel()
                    Text("v\(appVersion) (\(buildNumber)) · debug")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(DesignTokens.Color.textMuted)
                }
                Spacer()
            }

            // removed — see SESSION_LOG.md for history
            // (Clear all my data · Clear partner connection · Test All Animations ·
            //  Auto-catch all · Test Random · Clear test thoughts · Test Custom
            //  Emoji · Reset to onboarding · Clear onboarding flag · Mock heading ·
            //  Simulate far away · Simulate nearby)
        }
    }
    #endif

    // MARK: - Layout helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(DesignTokens.Font.overline)
            .foregroundColor(DesignTokens.Color.textMuted)
            .padding(.top, DesignTokens.Spacing.lg)
            .padding(.bottom, DesignTokens.Spacing.sm)
    }

    private func settingsGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(DesignTokens.Color.backgroundCard)
        .cornerRadius(DesignTokens.Radius.card)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.card)
                .stroke(DesignTokens.Color.border, lineWidth: 1)
        )
    }

    private func settingsRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            content()
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, 13)
    }
}

// MARK: - View modifiers for settings rows

private extension Image {
    func settingsIcon() -> some View {
        self
            .font(.system(size: 16))
            .foregroundColor(DesignTokens.Color.accentSoft)
            .frame(width: 26, height: 26)
    }
}

private extension Text {
    func settingsLabel() -> some View {
        self
            .font(DesignTokens.Font.label)
            .foregroundColor(DesignTokens.Color.textPrimary)
    }
}

#if DEBUG
// MARK: - Developer custom-emoji picker (kept for reference — its Settings entry
// was removed in the minimal-settings pass; see SESSION_LOG.md for history)
//
// Lists the user's saved slots (their personal six); tapping one sends a test
// thought with that emoji so custom emojis can be verified end to end.
struct DevCustomEmojiPicker: View {

    let onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var customStore = CustomThoughtStore.shared
    @State private var tokens = PersonalSet.load()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 3)

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.Color.background.ignoresSafeArea()
                VStack(spacing: 18) {
                    Text("tap a slot to send a test with it")
                        .font(.system(size: 13, design: .serif).italic())
                        .foregroundColor(DesignTokens.Color.textMuted)
                        .padding(.top, 12)
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(tokens, id: \.self) { token in
                            Button { onPick(token) } label: {
                                ZStack {
                                    if token == "gecko" {
                                        LeopardGeckoView(size: 30)
                                    } else if token.hasPrefix("yours:"),
                                              let id = UUID(uuidString: String(token.dropFirst(6))),
                                              let thought = customStore.thought(id: id) {
                                        Text(thought.emoji).font(.system(size: 30))
                                    } else {
                                        Text(token).font(.system(size: 30))
                                    }
                                }
                                .frame(width: 70, height: 70)
                                .background(DesignTokens.Color.backgroundCard)
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(DesignTokens.Color.border, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                    Spacer()
                }
            }
            .navigationTitle("test custom emoji")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                        .foregroundColor(DesignTokens.Color.textMuted)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
#endif
