// SettingsView.swift
// HomeLink › Views

import SwiftUI

struct SettingsView: View {

    @EnvironmentObject var subscription: SubscriptionManager
    @EnvironmentObject var skinStore:    SkinStore

    @AppStorage("quietMode")              private var quietMode         = false
    @AppStorage("hapticsEnabled")         private var hapticsEnabled    = true
    @AppStorage("emojiGlowEnabled")       private var emojiGlowEnabled  = true
    @AppStorage("notificationsEnabled")   private var notificationsEnabled = true
    @AppStorage("farThresholdKm")         private var farThresholdKm    = 500.0
    @AppStorage("northReference")         private var northReference    = "magnetic"

    @State private var showPaywall     = false
    @State private var showSkinPicker  = false

    var body: some View {
        ZStack {
            DesignTokens.Color.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    sectionHeader("subscription")
                    subscriptionSection

                    sectionHeader("experience")
                    experienceSection

                    sectionHeader("compass skin")
                    skinSection

                    sectionHeader("location")
                    locationSection

                    sectionHeader("notifications")
                    notificationsSection

                    sectionHeader("about")
                    aboutSection

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(isPresented: $showSkinPicker) {
            SkinPickerView()
                .environmentObject(skinStore)
                .environmentObject(subscription)
        }
    }

    // MARK: - Subscription

    private var subscriptionSection: some View {
        settingsGroup {
            settingsRow {
                Image(systemName: "sparkles")
                    .settingsIcon()
                Text("HomeLink Pro")
                    .settingsLabel()
                Spacer()
                Text(subscription.tier == .pro ? "✦ pro" : "free plan")
                    .font(DesignTokens.Font.caption)
                    .foregroundColor(subscription.tier == .pro
                                     ? DesignTokens.Color.accentSoft
                                     : DesignTokens.Color.textMuted)
            }
            .contentShape(Rectangle())
            .onTapGesture { showPaywall = true }
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
                Image(systemName: "sparkle")
                    .settingsIcon()
                Text("emoji glow")
                    .settingsLabel()
                Spacer()
                Toggle("", isOn: $emojiGlowEnabled)
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

    // MARK: - Location

    private var locationSection: some View {
        settingsGroup {
            settingsRow {
                Image(systemName: "location.fill")
                    .settingsIcon()
                Text("location access")
                    .settingsLabel()
                Spacer()
                Text("while using app")
                    .font(DesignTokens.Font.caption)
                    .foregroundColor(Color(hex: "#5dcaa5"))
            }

            Divider().background(DesignTokens.Color.border).padding(.leading, 44)

            settingsRow {
                Image(systemName: "arrow.up.circle")
                    .settingsIcon()
                Text("north reference")
                    .settingsLabel()
                Spacer()
                Text(northReference)
                    .font(DesignTokens.Font.caption)
                    .foregroundColor(DesignTokens.Color.textMuted)
            }

            Divider().background(DesignTokens.Color.border).padding(.leading, 44)

            settingsRow {
                Image(systemName: "house")
                    .settingsIcon()
                Text("far from home at")
                    .settingsLabel()
                Spacer()
                Text("\(Int(farThresholdKm)) km")
                    .font(DesignTokens.Font.caption)
                    .foregroundColor(DesignTokens.Color.textMuted)
            }
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        settingsGroup {
            settingsRow {
                Image(systemName: "bell")
                    .settingsIcon()
                Text("ping notifications")
                    .settingsLabel()
                Spacer()
                Toggle("", isOn: $notificationsEnabled)
                    .tint(DesignTokens.Color.accentMid)
                    .labelsHidden()
            }

            Divider().background(DesignTokens.Color.border).padding(.leading, 44)

            settingsRow {
                Image(systemName: "moon.zzz")
                    .settingsIcon()
                Text("quiet hours")
                    .settingsLabel()
                Spacer()
                Text("11 pm – 7 am")
                    .font(DesignTokens.Font.caption)
                    .foregroundColor(DesignTokens.Color.textMuted)
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        settingsGroup {
            settingsRow {
                Image(systemName: "app.badge")
                    .settingsIcon()
                Text("version")
                    .settingsLabel()
                Spacer()
                Text("1.0.0")
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
