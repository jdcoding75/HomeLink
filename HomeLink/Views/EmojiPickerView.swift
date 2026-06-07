// EmojiPickerView.swift
// Pointward › Views
//
// "✦ edit" — choose your personal six from the full library.
// Free: only the core six are selectable (the rest show a quiet lock).
// Pro (paid): the entire library, including your recordings.

import SwiftUI

struct EmojiPickerView: View {

    @ObservedObject var customStore: CustomThoughtStore
    @ObservedObject var recorder: AudioRecorder
    var onDone: ([String]) -> Void

    @EnvironmentObject var subscription: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    @State private var selected: [String] = PersonalSet.load()
    @State private var showCreateSheet = false
    @State private var showPaywall = false

    private let core    = PersonalSet.coreDefault
    private let feeling = ["😤","🤬","👊","💢","⚡️","🌋","🔥","😡","💨"]
    private let food    = ["🍕","🍫","🍺","🍷","🍰","☕","🧁","🍜","🍣","🥂"]
    private let silly   = ["😂","🤪","🥳","💥","🎉","gecko"]

    private var isPaid: Bool { subscription.tier != .free }
    private var atLimit: Bool { selected.count >= PersonalSet.slotCount }

    private static let lavender = Color(hex: "#c4a8d4")

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.Color.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            Text("these appear on your send screen")
                                .font(.system(size: 14, design: .serif).italic())
                                .foregroundColor(DesignTokens.Color.textMuted)
                                .padding(.top, 6)

                            section("core", tokens: core, locked: false)
                            section("with feeling", tokens: feeling, locked: !isPaid)
                            section("with food & drink", tokens: food, locked: !isPaid)
                            section("silly", tokens: silly, locked: !isPaid)
                            yoursSection

                            Spacer(minLength: 24)
                        }
                        .padding(.horizontal, 22)
                    }

                    // ── Live preview of the chosen six + save ─────────────
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            ForEach(0..<PersonalSet.slotCount, id: \.self) { i in
                                ZStack {
                                    RoundedRectangle(cornerRadius: 11)
                                        .fill(DesignTokens.Color.backgroundLift)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 11)
                                                .stroke(i < selected.count
                                                        ? Self.lavender.opacity(0.5)
                                                        : DesignTokens.Color.border,
                                                        lineWidth: 1)
                                        )
                                    if i < selected.count {
                                        previewSymbol(selected[i])
                                    }
                                }
                                .frame(width: 42, height: 42)
                            }
                        }
                        .animation(.easeOut(duration: 0.2), value: selected)

                        Button {
                            PersonalSet.save(selected)
                            onDone(selected)
                            dismiss()
                        } label: {
                            Text("save my set")
                                .font(DesignTokens.Font.label)
                                .foregroundColor(DesignTokens.Color.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(DesignTokens.Spacing.md)
                                .background(DesignTokens.Color.accentStrong)
                                .cornerRadius(DesignTokens.Radius.button)
                        }
                        .disabled(selected.count != PersonalSet.slotCount)
                        .opacity(selected.count == PersonalSet.slotCount ? 1 : 0.4)
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(DesignTokens.Color.background.opacity(0.97))
                }
            }
            .navigationTitle("choose your 6 · \(selected.count) of \(PersonalSet.slotCount) chosen")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showCreateSheet) {
            CreateThoughtSheet(recorder: recorder, store: customStore)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    // MARK: - Sections

    private func section(_ title: String, tokens: [String], locked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(title)
                    .font(DesignTokens.Font.overline)
                    .foregroundColor(DesignTokens.Color.textMuted)
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                        .foregroundColor(Self.lavender.opacity(0.7))
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5),
                      spacing: 10) {
                ForEach(tokens, id: \.self) { token in
                    cell(token, locked: locked)
                }
            }
        }
    }

    private var yoursSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("yours")
                    .font(DesignTokens.Font.overline)
                    .foregroundColor(DesignTokens.Color.textMuted)
                if !isPaid {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                        .foregroundColor(Self.lavender.opacity(0.7))
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5),
                      spacing: 10) {
                ForEach(customStore.thoughts) { thought in
                    cell("yours:\(thought.id.uuidString)", locked: !isPaid,
                         displayEmoji: thought.emoji)
                }
                if isPaid && !customStore.isFull {
                    Button { showCreateSheet = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Self.lavender)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                            .background(DesignTokens.Color.backgroundCard.opacity(0.8))
                            .cornerRadius(13)
                            .overlay(
                                RoundedRectangle(cornerRadius: 13)
                                    .stroke(Self.lavender.opacity(0.4),
                                            style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            )
                    }
                }
            }
        }
    }

    /// Renders a token for the preview row (emoji, gecko, or custom).
    @ViewBuilder
    private func previewSymbol(_ token: String) -> some View {
        if token == "gecko" {
            LeopardGeckoView(size: 20)
        } else if token.hasPrefix("yours:"),
                  let id = UUID(uuidString: String(token.dropFirst(6))),
                  let thought = customStore.thought(id: id) {
            Text(thought.emoji).font(.system(size: 20))
        } else {
            Text(token).font(.system(size: 20))
        }
    }

    // MARK: - Cell

    private func cell(_ token: String, locked: Bool, displayEmoji: String? = nil) -> some View {
        let isSelected = selected.contains(token)
        let dimmed = locked || (atLimit && !isSelected)
        return Button {
            if locked {
                HapticEngine.paywallReached()
                showPaywall = true
                return
            }
            if isSelected {
                selected.removeAll { $0 == token }
            } else if !atLimit {
                selected.append(token)
                HapticEngine.personSelected()
            }
        } label: {
            ZStack {
                Group {
                    if token == "gecko" {
                        LeopardGeckoView(size: 26)
                    } else {
                        Text(displayEmoji ?? token).font(.system(size: 24))
                    }
                }
                .opacity(dimmed && !isSelected ? 0.35 : 1)

                // Custom recordings carry a small 🎤 marker
                if token.hasPrefix("yours:") {
                    VStack { Spacer()
                        HStack { Spacer()
                            Text("🎤").font(.system(size: 9))
                        }
                    }
                    .padding(3)
                }

                // Selected → quiet ✓ in the corner
                if isSelected {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(Self.lavender)
                        }
                        Spacer()
                    }
                    .padding(4)
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(isSelected
                        ? DesignTokens.Color.accentStrong
                        : DesignTokens.Color.backgroundCard.opacity(0.8))
            .cornerRadius(13)
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .stroke(isSelected ? DesignTokens.Color.accentMid
                                       : DesignTokens.Color.border,
                            lineWidth: 1)
            )
        }
        .disabled(atLimit && !isSelected && !locked)
        .animation(.easeOut(duration: 0.2), value: isSelected)
    }
}
