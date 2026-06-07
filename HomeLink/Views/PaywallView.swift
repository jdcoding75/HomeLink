// PaywallView.swift
// Pointward › Views
//
// One-time $1.99 unlock — NOT a subscription. No recurring charges,
// no subscription language anywhere. Buy once, yours forever.

import SwiftUI

struct PaywallView: View {

    @EnvironmentObject var subscription: SubscriptionManager
    @Environment(\.dismiss) var dismiss

    @State private var isPurchasing = false

    private let features: [(emoji: String, text: String)] = [
        ("😤", "expressive emojis — playful, chaotic, honestly human"),
        ("📏", "funny distances — football fields, chocolate bars, leopard geckos"),
        ("🎤", "custom emoji + sound — record your voice, pick any emoji"),
        ("🦎", "the gecko · obviously"),
        ("🎨", "all compass skins"),
        ("👥", "up to 5 people"),
    ]
    // (previous list:)
    // ("👥", "unlimited people"), ("🎨", "all compass skins"),
    // ("📱", "home screen widget")

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

                        Text("Unlock Pointward")
                            .font(DesignTokens.Font.compassName)
                            .foregroundColor(DesignTokens.Color.textPrimary)
                            .padding(.bottom, 6)

                        Text("one small unlock. everything, forever.")
                            .font(DesignTokens.Font.compassDistance)
                            .foregroundColor(DesignTokens.Color.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 28)

                        // Feature list — clean and simple
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
                        .padding(.bottom, 14)

                        // One-time purchase badge
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal")
                                .font(.system(size: 11))
                            Text("one-time purchase · no subscription")
                                .font(DesignTokens.Font.caption)
                        }
                        .foregroundColor(Color(hex: "#5dcaa5"))
                        .padding(.bottom, 20)

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
                                Text(isPurchasing ? "unlocking…" : "Unlock Pointward — $1.99")
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

                        Button("restore purchase") {
                            Task { await subscription.restorePurchases() }
                        }
                        .font(DesignTokens.Font.caption)
                        .foregroundColor(DesignTokens.Color.textMuted)
                        .padding(.bottom, 8)

                        Text("one-time payment charged to your Apple ID. yours forever — nothing recurring.")
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
