// SettingsView.swift
// Pointward › Views
//
// Phase 1: intentionally minimal — skin picker, quiet mode, haptics, about.

import SwiftUI

struct SettingsView: View {

    @EnvironmentObject var subscription: SubscriptionManager
    @EnvironmentObject var skinStore:    SkinStore

    @AppStorage("quietMode")      private var quietMode      = false
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    // Distance units — defaults to the locale's measurement system, user can override
    @AppStorage("useMiles") private var useMiles = Locale.current.measurementSystem == .us
    @AppStorage("lockScreenWidgetEnabled") private var lockScreenWidget = false
    @AppStorage("notifyPointing") private var notifyPointing = true
    @AppStorage("funnyUnitLocked")      private var funnyUnitLocked      = -1
    @AppStorage("thoughtTaglineLocked") private var thoughtTaglineLocked = -1

    @State private var showSkinPicker = false
    @State private var showAbout      = false
    @State private var showUnlock     = false
    @State private var showAccount    = false

    var body: some View {
        ZStack {
            DesignTokens.Color.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if subscription.tier == .free {
                        sectionHeader("unlock")
                        unlockSection
                    }

                    sectionHeader("invite")
                    inviteSection

                    sectionHeader("account")
                    accountSection

                    sectionHeader("compass skin")
                    skinSection

                    sectionHeader("experience")
                    experienceSection

                    sectionHeader("about")
                    aboutSection

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

    private var accountSection: some View {
        settingsGroup {
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

    // MARK: - Experience

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

            Divider().background(DesignTokens.Color.border).padding(.leading, 44)

            // Tell someone you love about it
            ShareLink(item: AppLinks.shareMessage) {
                settingsRow {
                    Image(systemName: "square.and.arrow.up")
                        .settingsIcon()
                    Text("share Pointward")
                        .settingsLabel()
                    Spacer()
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
