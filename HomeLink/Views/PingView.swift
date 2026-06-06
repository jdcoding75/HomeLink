// PingView.swift
// HomeLink › Views

import SwiftUI

struct PingView: View {

    @EnvironmentObject var pings:        PingManager
    @EnvironmentObject var people:       PeopleManager
    @EnvironmentObject var subscription: SubscriptionManager

    @State private var selectedEmoji: String? = nil
    @State private var isSending = false
    @State private var showSentConfirm = false
    @State private var showPaywall = false

    private let emojiOptions = ["💜","🌙","🌿","✨","🕊️","🌸","☀️","🫂",
                                "🔥","🌈","⭐️","🍀","🎵","🌺","🦋","🤍"]

    var body: some View {
        ZStack {
            DesignTokens.Color.background.ignoresSafeArea()

            if subscription.tier == .free {
                paywallGate
            } else {
                pingContent
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    // MARK: - Paywall gate

    private var paywallGate: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(DesignTokens.Color.accentMid.opacity(0.25), lineWidth: 1)
                    .frame(width: 80, height: 80)
                Text("💜")
                    .font(.system(size: 34))
            }

            Text("send a thought")
                .font(DesignTokens.Font.compassName)
                .foregroundColor(DesignTokens.Color.textPrimary)

            Text("pings let you send a wordless moment to the people you love. one tap, no words needed.")
                .font(DesignTokens.Font.compassDistance)
                .foregroundColor(DesignTokens.Color.textMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 32)

            Button {
                showPaywall = true
            } label: {
                Text("upgrade to Pro to send pings")
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
            .padding(.horizontal, 28)

            Spacer()
        }
    }

    // MARK: - Ping content

    private var pingContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 6) {
                    Text("send a thought")
                        .font(DesignTokens.Font.compassName)
                        .foregroundColor(DesignTokens.Color.textPrimary)

                    if let person = people.selectedPerson {
                        Text("to \(person.name)")
                            .font(.system(size: 13).italic())
                            .foregroundColor(DesignTokens.Color.accentMid)
                    }

                    Text("one tap · no words needed")
                        .font(DesignTokens.Font.caption)
                        .foregroundColor(DesignTokens.Color.textMuted)
                        .padding(.top, 2)
                }
                .padding(.top, 24)
                .padding(.bottom, 28)

                // Emoji grid
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                    spacing: 10
                ) {
                    ForEach(emojiOptions, id: \.self) { emoji in
                        emojiCell(emoji)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

                // Send button
                if let emoji = selectedEmoji {
                    sendButton(emoji: emoji)
                        .padding(.horizontal, 24)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                // Sent confirmation
                if showSentConfirm {
                    sentConfirmation
                        .padding(.top, 12)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }

                Spacer(minLength: 40)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: selectedEmoji)
        .animation(.easeOut(duration: 0.3), value: showSentConfirm)
    }

    private func emojiCell(_ emoji: String) -> some View {
        let isSelected = selectedEmoji == emoji
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                selectedEmoji  = isSelected ? nil : emoji
                showSentConfirm = false
            }
        } label: {
            Text(emoji)
                .font(.system(size: 30))
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(isSelected
                            ? DesignTokens.Color.accentStrong
                            : DesignTokens.Color.backgroundCard)
                .cornerRadius(15)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(isSelected
                                ? DesignTokens.Color.accentMid
                                : DesignTokens.Color.border,
                                lineWidth: 1)
                )
                .scaleEffect(isSelected ? 1.06 : 1.0)
        }
    }

    private func sendButton(emoji: String) -> some View {
        Button {
            guard let person = people.selectedPerson else { return }
            isSending = true
            Task {
                await pings.sendPing(to: person, emoji: emoji)
                isSending       = false
                selectedEmoji   = nil
                showSentConfirm = true
                withAnimation {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        showSentConfirm = false
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                if isSending {
                    ProgressView()
                        .tint(DesignTokens.Color.textPrimary)
                        .scaleEffect(0.8)
                } else {
                    Text("send \(emoji)")
                }
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
        .disabled(isSending)
    }

    private var sentConfirmation: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Color(hex: "#5dcaa5"))
            Text("sent to \(people.selectedPerson?.name ?? "them") ✦")
                .font(DesignTokens.Font.label)
                .foregroundColor(DesignTokens.Color.accentSoft)
        }
    }
}
