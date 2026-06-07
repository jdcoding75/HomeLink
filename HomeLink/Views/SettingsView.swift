// SettingsView.swift
// Pointward › Views
//
// Emotional core: feel · expression · compass · notifications · account · about.

import SwiftUI
import UIKit

struct SettingsView: View {

    @EnvironmentObject var subscription: SubscriptionManager
    @EnvironmentObject var skinStore:    SkinStore
    @EnvironmentObject var instrumentStore: InstrumentStore

    @AppStorage("quietMode")      private var quietMode      = false
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    // Distance units — defaults to the locale's measurement system, user can override
    @AppStorage("useMiles") private var useMiles = Locale.current.measurementSystem == .us
    @AppStorage("lockScreenWidgetEnabled") private var lockScreenWidget = false
    @AppStorage("notifyPointing") private var notifyPointing = true
    @AppStorage("funnyUnitLocked")      private var funnyUnitLocked      = -1
    @AppStorage("thoughtTaglineLocked") private var thoughtTaglineLocked = -1
    @AppStorage(ProFeatures.storageKey) private var proFeatures = false
    @AppStorage("holdToSendEnabled") private var holdToSend = false

    @State private var showCopied     = false
    @State private var showConnect    = false
    @State private var showSkinPicker = false
    @State private var showAbout      = false
    @State private var showUnlock     = false
    @State private var showAccount    = false

    var body: some View {
        ZStack {
            DesignTokens.Color.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Quiet Mode retired — full emotional intensity, always.
                    // sectionHeader("feel")
                    // feelSection

                    sectionHeader("pro")
                    proSection

                    // Final clean: expression toggles + skin row moved
                    // into ProSetupView. (kept below for reference)
                    // sectionHeader("expression")
                    // expressionSection
                    // sectionHeader("compass")
                    // skinSection

                    sectionHeader("notifications")
                    notificationsSection

                    sectionHeader("account")
                    accountSection

                    // ── Stripped in the emotional-core pass (kept, not lost) ──
                    // sectionHeader("about")
                    // aboutSection              // story · version · offline
                    // if subscription.tier == .free {
                    //     sectionHeader("unlock")
                    //     unlockSection          // paywall now reached via Expression
                    // }
                    // sectionHeader("invite")
                    // inviteSection             // inviting lives on person cards now
                    // sectionHeader("experience")
                    // experienceSection         // miles toggle, pickers, lock-screen row

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
            }
        }
        .sheet(isPresented: $showSkinPicker) {
            SkinPickerView()
                .environmentObject(skinStore)
                .environmentObject(subscription)
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
        .sheet(isPresented: $showUnlock) {
            PaywallView()
        }
        .sheet(isPresented: $showAccount) {
            AccountView()
        }
    }

    // MARK: - Pro

    @State private var showProSetup = false

    private var proSection: some View {
        settingsGroup {
            settingsRow {
                Image(systemName: "sparkles")
                    .settingsIcon()
                VStack(alignment: .leading, spacing: 2) {
                    Text("✦ Pro Features")
                        .settingsLabel()
                    // The current instrument at a glance —
                    // "🏹 bow & arrow · pro active" / "🧭 compass · free"
                    Text("\(instrumentStore.selected.icon) \(instrumentStore.selected.displayName) · "
                         + (subscription.tier == .free
                            ? "free"
                            : (proFeatures ? "pro active" : "pro · switched off")))
                        .font(.system(size: 11))
                        .foregroundColor(subscription.tier != .free && proFeatures
                                         ? Color(hex: "#5dcaa5")
                                         : DesignTokens.Color.textDim)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Color.textDim)
            }
            .contentShape(Rectangle())
            .onTapGesture { showProSetup = true }
        }
        .sheet(isPresented: $showProSetup) {
            ProSetupView()
                .environmentObject(subscription)
                .environmentObject(skinStore)
                .environmentObject(instrumentStore)
        }
    }

    // MARK: - Invite

    private var inviteSection: some View {
        settingsGroup {
            ShareLink(item: AppLinks.inviteMessage(pairingCode: SupabaseService.localPairingCode)) {
                settingsRow {
                    Image(systemName: "square.and.arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(DesignTokens.Color.accentSoft)
                        .frame(width: 26, height: 26)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("invite a friend")
                            .settingsLabel()
                        Text(SupabaseService.localPairingCode != nil
                             ? "sends the TestFlight link + your pairing code"
                             : "sends the TestFlight link")
                            .font(.system(size: 11))
                            .foregroundColor(DesignTokens.Color.textDim)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Color.textDim)
                }
            }
        }
    }

    // MARK: - Account

    @State private var showGivingBack = false

    private var accountSection: some View {
        settingsGroup {
            // Giving back — above sign in, where the heart belongs
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
            .sheet(isPresented: $showGivingBack) { GivingBackView() }

            Divider().background(DesignTokens.Color.border).padding(.leading, 44)

            settingsRow {
                Image(systemName: "person.crop.circle")
                    .settingsIcon()
                VStack(alignment: .leading, spacing: 2) {
                    Text(SupabaseService.localUserID == nil ? "sign in" : "account")
                        .settingsLabel()
                    Text(SupabaseService.connectedFriendID != nil
                         ? "connected — thoughts travel for real"
                         : "pair with someone to send real thoughts")
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Color.textDim)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Color.textDim)
            }
            .contentShape(Rectangle())
            .onTapGesture { showAccount = true }

            Divider().background(DesignTokens.Color.border).padding(.leading, 44)

            // All connection UI lives in ConnectView now
            settingsRow {
                Image(systemName: "link")
                    .settingsIcon()
                Text("your connection")
                    .settingsLabel()
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Color.textDim)
            }
            .contentShape(Rectangle())
            .onTapGesture { showConnect = true }
            .sheet(isPresented: $showConnect) { ConnectView() }

            // (pairing-code copy row replaced by ConnectView; kept)
            if false, let code = SupabaseService.localPairingCode {
                Divider().background(DesignTokens.Color.border).padding(.leading, 44)

                settingsRow {
                    Image(systemName: "number")
                        .settingsIcon()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("your pairing code")
                            .settingsLabel()
                        Text(showCopied ? "copied ✓" : code.replacingOccurrences(of: "-", with: " · "))
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(showCopied ? Color(hex: "#5dcaa5")
                                                        : DesignTokens.Color.accentSoft)
                    }
                    Spacer()
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 13))
                        .foregroundColor(DesignTokens.Color.textDim)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    UIPasteboard.general.string = code
                    HapticEngine.saved()
                    withAnimation { showCopied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { showCopied = false }
                    }
                }
            }

            Divider().background(DesignTokens.Color.border).padding(.leading, 44)

            ShareLink(item: AppLinks.shareMessage) {
                settingsRow {
                    Image(systemName: "square.and.arrow.up")
                        .settingsIcon()
                    Text("share Pointward")
                        .settingsLabel()
                    Spacer()
                }
            }
        }
    }

    // MARK: - Unlock (one-time purchase — shown only while on the free tier)

    private var unlockSection: some View {
        settingsGroup {
            settingsRow {
                Image(systemName: "sparkles")
                    .settingsIcon()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unlock Pointward — $1.99")
                        .settingsLabel()
                    Text("unlimited people · all skins · widget — one-time purchase")
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Color.textDim)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Color.textDim)
            }
            .contentShape(Rectangle())
            .onTapGesture { showUnlock = true }

            Divider().background(DesignTokens.Color.border).padding(.leading, 44)

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
        }
    }

    // MARK: - Feel (retired — quiet mode gone, full intensity always)

    private var feelSection: some View {
        settingsGroup {
            // settingsRow {
            //     Image(systemName: "moon.stars")
            //         .settingsIcon()
            //     VStack(alignment: .leading, spacing: 2) {
            //         Text("quiet mode")
            //             .settingsLabel()
            //         Text("slower animations · reduced haptics · dimmer glows")
            //             .font(.system(size: 11))
            //             .foregroundColor(DesignTokens.Color.textDim)
            //     }
            //     Spacer()
            //     Toggle("", isOn: $quietMode)
            //         .tint(Self.toggleOn)
            //         .labelsHidden()
            // }
            EmptyView()

            // (haptics row commented out in the settings-final pass — the
            // hapticsEnabled storage still gates HapticEngine everywhere)
            // Divider().background(DesignTokens.Color.border).padding(.leading, 44)
            // settingsRow {
            //     Image(systemName: "iphone.radiowaves.left.and.right")
            //         .settingsIcon()
            //     Text("haptics")
            //         .settingsLabel()
            //     Spacer()
            //     Toggle("", isOn: $hapticsEnabled)
            //         .tint(Self.toggleOn)
            //         .labelsHidden()
            // }
        }
    }

    /// Toggle ON = clear warm teal with a white knob; OFF stays the system's
    /// dark grey track — the two states read instantly at a glance.
    private static let toggleOn = Color(hex: "#5dcaa5")

    // MARK: - Expression (the paid playground)

    private var expressionSection: some View {
        settingsGroup {
            settingsRow {
                Image(systemName: "party.popper")
                    .settingsIcon()
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Pro Features")
                            .settingsLabel()
                        if subscription.tier == .free {
                            Text("unlock")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(DesignTokens.Color.accentSoft)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().stroke(DesignTokens.Color.accentMid, lineWidth: 1))
                        }
                    }
                    Text("custom emojis, funny distances, hold to send, and more")
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Color.textDim)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { proFeatures && subscription.tier != .free },
                    set: { wantsOn in
                        if subscription.tier == .free {
                            HapticEngine.paywallReached()
                            showUnlock = true     // Pro Mode is the paid tier
                        } else {
                            proFeatures = wantsOn
                        }
                    }
                ))
                .tint(Self.toggleOn)
                .labelsHidden()
            }

            Divider().background(DesignTokens.Color.border).padding(.leading, 44)

            // Hold to Send — the purely physical send (paid)
            settingsRow {
                Image(systemName: "timer")
                    .settingsIcon()
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Hold to Send")
                            .settingsLabel()
                        if subscription.tier == .free {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .foregroundColor(DesignTokens.Color.accentSoft)
                        }
                    }
                    Text("hold your phone toward them for 2 seconds to send a thought instead of tapping")
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Color.textDim)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { holdToSend && subscription.tier != .free },
                    set: { wantsOn in
                        if subscription.tier == .free {
                            HapticEngine.paywallReached()
                            showUnlock = true
                        } else {
                            holdToSend = wantsOn
                        }
                    }
                ))
                .tint(Self.toggleOn)
                .labelsHidden()
            }

            // Lock a favourite funny unit (or keep the per-launch surprise)
            if proFeatures && subscription.tier != .free {
                Divider().background(DesignTokens.Color.border).padding(.leading, 44)

                settingsRow {
                    Image(systemName: "sportscourt")
                        .settingsIcon()
                    Text("funny distance unit")
                        .settingsLabel()
                    Spacer()
                    Picker("", selection: $funnyUnitLocked) {
                        Text("surprise me").tag(-1)
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

    // MARK: - Notifications

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
        }
    }

    // MARK: - Experience (stripped from the body; kept for reference)

    private var experienceSection: some View {
        settingsGroup {
            settingsRow {
                Image(systemName: "moon.stars")
                    .settingsIcon()
                VStack(alignment: .leading, spacing: 2) {
                    Text("quiet mode")
                        .settingsLabel()
                    Text("slower animations · reduced haptics · dimmer glows")
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Color.textDim)
                }
                Spacer()
                Toggle("", isOn: $quietMode)
                    .tint(DesignTokens.Color.accentMid)
                    .labelsHidden()
            }

            Divider().background(DesignTokens.Color.border).padding(.leading, 44)

            settingsRow {
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .settingsIcon()
                Text("haptics")
                    .settingsLabel()
                Spacer()
                Toggle("", isOn: $hapticsEnabled)
                    .tint(DesignTokens.Color.accentMid)
                    .labelsHidden()
            }

            Divider().background(DesignTokens.Color.border).padding(.leading, 44)

            settingsRow {
                Image(systemName: "ruler")
                    .settingsIcon()
                VStack(alignment: .leading, spacing: 2) {
                    Text(useMiles ? "use miles" : "use kilometers")
                        .settingsLabel()
                    Text(useMiles ? "88 mi · 142 km" : "142 km · 88 mi")
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Color.textDim)
                }
                Spacer()
                Toggle("", isOn: $useMiles)
                    .tint(DesignTokens.Color.accentMid)
                    .labelsHidden()
            }

            Divider().background(DesignTokens.Color.border).padding(.leading, 44)

            settingsRow {
                Image(systemName: "sportscourt")
                    .settingsIcon()
                Text("funny distance unit")
                    .settingsLabel()
                Spacer()
                Picker("", selection: $funnyUnitLocked) {
                    Text("surprise me").tag(-1)
                    ForEach(0..<DistanceFun.funnyCount, id: \.self) { i in
                        Text(DistanceFun.funnyLabels[i]).tag(i)
                    }
                }
                .pickerStyle(.menu)
                .tint(DesignTokens.Color.accentSoft)
            }

            Divider().background(DesignTokens.Color.border).padding(.leading, 44)

            settingsRow {
                Image(systemName: "sparkle")
                    .settingsIcon()
                Text("thought speed tagline")
                    .settingsLabel()
                Spacer()
                Picker("", selection: $thoughtTaglineLocked) {
                    Text("surprise me").tag(-1)
                    ForEach(0..<DistanceFun.thoughtTaglines.count, id: \.self) { i in
                        Text(DistanceFun.thoughtTaglines[i]).tag(i)
                    }
                }
                .pickerStyle(.menu)
                .tint(DesignTokens.Color.accentSoft)
            }

            Divider().background(DesignTokens.Color.border).padding(.leading, 44)

            settingsRow {
                Image(systemName: "location.north.line")
                    .settingsIcon()
                VStack(alignment: .leading, spacing: 2) {
                    Text("notify me when someone points toward me")
                        .settingsLabel()
                    Text("a quiet compass toast when their needle finds you")
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Color.textDim)
                }
                Spacer()
                Toggle("", isOn: $notifyPointing)
                    .tint(DesignTokens.Color.accentMid)
                    .labelsHidden()
                    .onChange(of: notifyPointing) { _, enabled in
                        // Mirror server-side so closed-app pushes respect it too
                        Task { await SupabaseService.shared.setNotifyPointing(enabled) }
                    }
            }

            Divider().background(DesignTokens.Color.border).padding(.leading, 44)

            settingsRow {
                Image(systemName: "lock.iphone")
                    .settingsIcon()
                VStack(alignment: .leading, spacing: 2) {
                    Text("lock screen widget")
                        .settingsLabel()
                    if lockScreenWidget {
                        Text("long press your lock screen to add")
                            .font(.system(size: 11))
                            .foregroundColor(DesignTokens.Color.textDim)
                        Link("how to add a widget →",
                             destination: URL(string: "https://support.apple.com/en-us/HT207122")!)
                            .font(.system(size: 11))
                            .foregroundColor(DesignTokens.Color.accentSoft)
                    } else {
                        Text("the needle, right above the clock")
                            .font(.system(size: 11))
                            .foregroundColor(DesignTokens.Color.textDim)
                    }
                }
                Spacer()
                Toggle("", isOn: $lockScreenWidget)
                    .tint(DesignTokens.Color.accentMid)
                    .labelsHidden()
            }
        }
    }

    // MARK: - Skin

    private var skinSection: some View {
        settingsGroup {
            settingsRow {
                Text(skinStore.activeSkin.displayName
                     .prefix(1).uppercased() +
                     skinStore.activeSkin.displayName.dropFirst())
                    .font(.system(size: 18))
                    .frame(width: 26, height: 26)
                    .padding(.leading, -2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(skinStore.activeSkin.displayName)
                        .settingsLabel()
                    Text(skinStore.activeSkin.description)
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Color.textDim)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Color.textDim)
            }
            .contentShape(Rectangle())
            .onTapGesture { showSkinPicker = true }
        }
    }

    // MARK: - About

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private var aboutSection: some View {
        settingsGroup {
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

            // (share moved to the account section in the emotional-core pass)
            // ShareLink(item: AppLinks.shareMessage) {
            //     settingsRow {
            //         Image(systemName: "square.and.arrow.up").settingsIcon()
            //         Text("share Pointward").settingsLabel()
            //         Spacer()
            //     }
            // }

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

            settingsRow {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .settingsIcon()
                Text("connection mode")
                    .settingsLabel()
                Spacer()
                Text("offline")
                    .font(DesignTokens.Font.caption)
                    .foregroundColor(Color(hex: "#5dcaa5"))
            }
        }
    }

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
