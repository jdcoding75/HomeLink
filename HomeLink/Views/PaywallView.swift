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
        ("🧭", "3 compass skins — minimal, vintage brass, heart"),
        ("😤", "pro emojis — playful, chaotic, honestly human"),
        ("📏", "funny distances — football fields, chocolate bars, leopard geckos"),
        ("🎤", "custom emoji + sound — record your voice, pick any emoji"),
        ("⏱", "hold to send — point and hold to send a thought physically"),
        ("👥", "up to 5 people"),
        ("🦎", "the gecko · obviously"),
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

                        Text("Unlock Pointward Pro")
                            .font(DesignTokens.Font.compassName)
                            .foregroundColor(DesignTokens.Color.textPrimary)
                            .padding(.bottom, 6)

                        Text("the full experience · $1.99")
                            .font(DesignTokens.Font.compassDistance)
                            .foregroundColor(DesignTokens.Color.textMuted)
                            .padding(.bottom, 3)

                        Text("one time · yours forever")
                            .font(.system(size: 11, design: .serif).italic())
                            .foregroundColor(DesignTokens.Color.textDim)
                            .padding(.bottom, 28)
                        // (previous: "one small unlock. everything, forever.")

                        // ── Live sender-style previews — looping, no tap ──
                        senderStyleShowcase
                            .padding(.bottom, 18)

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

                        // Giving back — half of this purchase does good
                        if let charity = CharityConfig.current {
                            HStack(spacing: 10) {
                                Text(charity.emoji)
                                    .font(.system(size: 22))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("50% supports \(charity.name)")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(DesignTokens.Color.textPrimary)
                                    Text("always · not a promotion, just how we work")
                                        .font(.system(size: 10, design: .serif).italic())
                                        .foregroundColor(DesignTokens.Color.textMuted)
                                }
                                Spacer()
                            }
                            .padding(12)
                            .background(DesignTokens.Color.backgroundCard.opacity(0.7))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color(hex: "#5dcaa5").opacity(0.3), lineWidth: 1)
                            )
                            .padding(.bottom, 14)
                        }

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
                                Text(isPurchasing ? "unlocking…" : "unlock pro · $1.99")
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

                        Text("one time purchase · no subscription")
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

    // MARK: - Live sender-style showcase

    /// The Pro send styles, playing on a loop — seeing beats reading.
    /// Reuses SenderStylePreview (ProSetupView), which animates itself.
    private var senderStyleShowcase: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Text("HOW YOUR THOUGHTS TRAVEL")
                    .font(.system(size: 10, weight: .medium))
                    .kerning(1.8)
                    .foregroundColor(DesignTokens.Color.textMuted)
                Spacer()
                Text("pro")
                    .font(.system(size: 9, design: .serif).italic())
                    .foregroundColor(DesignTokens.Color.accentMid)
            }
            .padding(.horizontal, 2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(SenderStyle.allCases.filter(\.requiresPro)) { style in
                        VStack(spacing: 6) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 13)
                                    .fill(DesignTokens.Color.backgroundLift)
                                SenderStylePreview(style: style)
                                    .clipShape(RoundedRectangle(cornerRadius: 13))
                            }
                            .frame(width: 108, height: 62)
                            .overlay(
                                RoundedRectangle(cornerRadius: 13)
                                    .stroke(DesignTokens.Color.borderMid, lineWidth: 1)
                            )

                            Text("\(style.emoji) \(style.displayName)")
                                .font(.system(size: 11))
                                .foregroundColor(DesignTokens.Color.textPrimary)
                            Text(style.blurb)
                                .font(.system(size: 9, design: .serif).italic())
                                .foregroundColor(DesignTokens.Color.textDim)
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
    }
}
