// GivingBackView.swift
// Pointward › Views
//
// Giving back — 50% of every Pro purchase goes to the featured charity.
// Always. Not a promotion. Just how we work.

import SwiftUI

struct GivingBackView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var totalCents: Int? = nil

    private static let lavender = Color(hex: "#c4a8d4")

    private var dollarText: String {
        let cents = totalCents ?? 0
        return String(format: "$%.2f", Double(cents) / 100)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.Color.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        // ── Header ─────────────────────────────────────────
                        Text("GIVING BACK")
                            .font(.system(size: 11, weight: .medium))
                            .kerning(2.5)
                            .foregroundColor(DesignTokens.Color.textMuted)
                            .padding(.top, 18)

                        // ── Currently supporting ───────────────────────────
                        if let charity = CharityConfig.current {
                            VStack(spacing: 8) {
                                Text(charity.emoji)
                                    .font(.system(size: 48))
                                    .padding(.top, 18)

                                Text(charity.name)
                                    .font(.system(size: 24, weight: .semibold, design: .serif))
                                    .foregroundColor(DesignTokens.Color.textPrimary)

                                Text(charity.description)
                                    .font(.system(size: 13, design: .serif).italic())
                                    .foregroundColor(DesignTokens.Color.textMuted)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)

                                HStack(spacing: 24) {
                                    if let url = URL(string: charity.websiteURL) {
                                        Link("learn more →", destination: url)
                                    }
                                    if let url = URL(string: charity.donationURL) {
                                        Link("donate directly →", destination: url)
                                    }
                                }
                                .font(.system(size: 13))
                                .foregroundColor(Self.lavender)
                                .padding(.top, 8)
                                .padding(.bottom, 18)
                            }
                            .frame(maxWidth: .infinity)
                            .background(DesignTokens.Color.backgroundCard)
                            .cornerRadius(DesignTokens.Radius.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignTokens.Radius.card)
                                    .stroke(DesignTokens.Color.border, lineWidth: 1)
                            )
                        } else {
                            Text("coming soon · stay tuned")
                                .font(.system(size: 14, design: .serif).italic())
                                .foregroundColor(DesignTokens.Color.textMuted)
                                .padding(.vertical, 30)
                        }

                        divider

                        // ── Total donated ──────────────────────────────────
                        VStack(spacing: 6) {
                            Text("DONATED SO FAR")
                                .font(.system(size: 10, weight: .medium))
                                .kerning(2.2)
                                .foregroundColor(DesignTokens.Color.textMuted)

                            Text(dollarText)
                                .font(.system(size: 40, weight: .light))
                                .foregroundColor(DesignTokens.Color.textPrimary)
                                .monospacedDigit()
                                .contentTransition(.numericText())

                            Text("and growing with every purchase")
                                .font(.system(size: 12, design: .serif).italic())
                                .foregroundColor(Self.lavender.opacity(0.85))
                        }

                        divider

                        // ── How it works ───────────────────────────────────
                        Text("50% of every Pro purchase goes to our featured charity. Always.\nNot a promotion. Just how we work.")
                            .font(.system(size: 13, design: .serif).italic())
                            .foregroundColor(Self.lavender.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 30)

                        divider

                        // ── Nominate ───────────────────────────────────────
                        VStack(spacing: 6) {
                            Text("know an organization we should support?")
                                .font(.system(size: 13))
                                .foregroundColor(DesignTokens.Color.textMuted)
                            if let mail = URL(string: "mailto:johndittami@gmail.com") {
                                Link("get in touch →", destination: mail)
                                    .font(.system(size: 13))
                                    .foregroundColor(Self.lavender)
                            }
                        }
                        .padding(.bottom, 30)
                    }
                    .padding(.horizontal, 22)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("done") { dismiss() }
                        .foregroundColor(DesignTokens.Color.accentSoft)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            // Falls back to $0 gracefully when offline
            totalCents = await SupabaseService.shared.fetchGivingTotalCents()
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(height: 1)
    }
}
