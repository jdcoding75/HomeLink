// PermissionsView.swift
// Pointward › Views
//
// Settings › permissions. Shows the OS permissions the app uses — microphone,
// location (CRITICAL), notifications — with a live granted/not indicator, each
// tappable to open Pointward's iOS Settings page (iOS won't re-prompt once denied,
// so deep-link is the recovery route for ALL three; first-time native prompts live
// at point-of-use / onboarding, not in this management surface). CONTACTS is
// intentionally EXCLUDED — the contact picker is out-of-process and needs no grant.
//
// Status is read FRESH at display time: location via a throwaway
// CLLocationManager().authorizationStatus (NOT a CompassManager property), mic via
// AVAudioApplication.recordPermission, notifications via getNotificationSettings.

import SwiftUI
import CoreLocation
import AVFAudio
import UserNotifications

struct PermissionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var notifGranted: Bool? = nil   // nil = loading (async)
    @State private var refreshTick = 0              // re-read the sync statuses on return from Settings

    private static let green   = Color(hex: "#5dcaa5")
    private static let offGrey = Color(hex: "#6b5f7a")

    // MIC — sync.
    private var micGranted: Bool {
        if #available(iOS 17.0, *) { return AVAudioApplication.shared.recordPermission == .granted }
        return AVAudioSession.sharedInstance().recordPermission == .granted
    }
    // LOCATION — sync, FRESH instance (deliberately NOT CompassManager; the compass tab owns that).
    private var locationGranted: Bool {
        switch CLLocationManager().authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: return true
        default: return false
        }
    }

    private func openAppSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        #endif
    }
    private func loadNotif() {
        UNUserNotificationCenter.current().getNotificationSettings { s in
            let ok = [.authorized, .provisional, .ephemeral].contains(s.authorizationStatus)
            DispatchQueue.main.async { notifGranted = ok }
        }
    }

    var body: some View {
        ZStack {
            DesignTokens.Color.background.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Text("permissions")
                        .font(DesignTokens.Font.label)
                        .foregroundColor(DesignTokens.Color.textPrimary)
                    Spacer()
                    Button("done") { dismiss() }
                        .font(DesignTokens.Font.label)
                        .foregroundColor(DesignTokens.Color.accentSoft)
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.vertical, DesignTokens.Spacing.md)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Pointward only uses what it needs. Tap any to manage it in Settings.")
                            .font(.system(size: 13, design: .serif).italic())
                            .foregroundColor(DesignTokens.Color.textMuted)
                            .padding(.bottom, 2)

                        row(icon: "mic.fill", name: "microphone",
                            detail: "breath sending (wind · birthday)",
                            granted: micGranted, critical: false)
                        row(icon: "location.fill", name: "location",
                            detail: "points the compass to your people",
                            granted: locationGranted, critical: true)
                        row(icon: "bell.fill", name: "notifications",
                            detail: "a gentle word when a thought arrives",
                            granted: notifGranted ?? false, loading: notifGranted == nil, critical: false)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.top, DesignTokens.Spacing.md)
                    .id(refreshTick)   // force the sync (mic/location) reads to recompute on return
                }
                Spacer()
            }
        }
        .onAppear(perform: loadNotif)
        .onChange(of: scenePhase) { _, phase in
            // Re-read after the Settings round-trip so the indicators reflect any change.
            if phase == .active { refreshTick += 1; loadNotif() }
        }
    }

    @ViewBuilder
    private func row(icon: String, name: String, detail: String,
                     granted: Bool, loading: Bool = false, critical: Bool) -> some View {
        Button { openAppSettings() } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(DesignTokens.Color.accentSoft)
                    .frame(width: 26, height: 26)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(name)
                            .font(DesignTokens.Font.label)
                            .foregroundColor(DesignTokens.Color.textPrimary)
                        if critical {
                            Text("critical")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(Color(hex: "#0d0d14"))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(DesignTokens.Color.accentSoft))
                        }
                    }
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Color.textDim)
                }
                Spacer()
                if loading {
                    ProgressView().tint(DesignTokens.Color.accentSoft).scaleEffect(0.8)
                } else {
                    HStack(spacing: 6) {
                        Circle().fill(granted ? Self.green : Self.offGrey).frame(width: 9, height: 9)
                        Text(granted ? "on" : "off")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(granted ? Self.green : Self.offGrey)
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Color.textDim)
            }
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.Color.backgroundCard)
            .cornerRadius(DesignTokens.Radius.card)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.card)
                    .stroke(DesignTokens.Color.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PermissionsView().preferredColorScheme(.dark)
}
