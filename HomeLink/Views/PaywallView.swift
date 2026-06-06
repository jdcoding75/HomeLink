// PaywallView.swift
// HomeLink › Views

import SwiftUI

struct PaywallView: View {

    @EnvironmentObject var subscription: SubscriptionManager
    @Environment(\.dismiss) var dismiss

    @State private var isPurchasing = false

    private let features: [(emoji: String, text: String)] = [
        ("👥", "add unlimited people"),
        ("💜", "send and receive pings"),
        ("✦",  "premium emoji glow themes"),
        ("🎨", "all compass skins"),
        ("📍", "dynamic live location (coming soon)"),
        ("☕", "brand location packs"),
        ("📱", "lock screen and live activity widgets"),
    ]

    var body: some View {
        ZStack {
            DesignTokens.Color.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Handle
                RoundedRectangle(cornerRadius: 2)
                    .fill(DesignTokens.Color.borderMid)
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                ScrollView {
                    VStack(spacing: 0) {
                        // Icon
                        ZStack {
                            Circle()
                                .stroke(DesignTokens.Color.accentMid.opacity(0.3), lineWidth: 1)
                                .frame(width: 72, height: 72)
                            Text("✦")
                                .font(.system(size: 30))
                                .foregroundColor(DesignTokens.Color.accentSoft)
                        }
                        .padding(.bottom, 16)

                        Text("HomeLink Pro")
                            .font(DesignTokens.Font.compassName)
                            .foregroundColor(DesignTokens.Color.textPrimary)
                            .padding(.bottom, 6)

                        Text("everyone you love. every compass. one upgrade.")
                            .font(DesignTokens.Font.compassDistance)
                            .foregroundColor(DesignTokens.Color.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 28)

                        // Feature list
                        VStack(spacing: 0) {
                            ForEach(features, id: \.text) { feature in
                                HStack(spacing: 14) {
                                    Text(feature.emoji)
                                        .font(.system(size: 18))
                                        .frame(width: 28)
                                    Text(feature.text)
                                        .font(DesignTokens.Font.label)
                                        .foregroundColor(DesignTokens.Color.textSecondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 11)

                                if feature.text != features.last?.text {
                                    Divider()
                                        .background(DesignTokens.Color.border)
                                        .padding(.leading, 58)
                                }
                            }
                        }
                        .background(DesignTokens.Color.backgroundCard)
                        .cornerRadius(DesignTokens.Radius.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.card)
                                .stroke(DesignTokens.Color.border, lineWidth: 1)
                        )
                        .padding(.bottom, 24)

                        // CTA
                        Button {
                            isPurchasing = true
                            Task {
                                await subscription.upgrade()
                                isPurchasing = false
                                dismiss()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if isPurchasing {
                                    ProgressView()
                                        .tint(DesignTokens.Color.textPrimary)
                                        .scaleEffect(0.8)
                                }
                                Text(isPurchasing ? "purchasing…" : "upgrade · $2.99 / month")
                            }
                            .font(DesignTokens.Font.label)
                            .foregroundColor(DesignTokens.Color.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(DesignTokens.Spacing.md)
                            .background(DesignTokens.Color.accentStrong)
                            .cornerRadius(DesignTokens.Radius.button)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignTokens.Radius.button)
                                    .stroke(DesignTokens.Color.accentMid, lineWidth: 1)
                            )
                        }
                        .disabled(isPurchasing)
                        .padding(.bottom, 10)

                        Button("restore purchases") {
                            Task { await subscription.restorePurchases() }
                        }
                        .font(DesignTokens.Font.caption)
                        .foregroundColor(DesignTokens.Color.textMuted)
                        .padding(.bottom, 8)

                        Text("payment charged to your Apple ID. cancel anytime in Settings.")
                            .font(.system(size: 10))
                            .foregroundColor(DesignTokens.Color.textDim)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 20)
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
    }
}
