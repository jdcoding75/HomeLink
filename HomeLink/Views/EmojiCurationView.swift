// EmojiCurationView.swift
// Pointward › Views
//
// "✦ edit" — choose your personal six from the full library.
// Free: only the core six are selectable (the rest show a quiet lock).
// Pro (paid): the entire library, including your recordings.

import SwiftUI

struct EmojiCurationView: View {

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

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("choose the six thoughts you carry")
                            .font(.system(size: 15, design: .serif).italic())
                            .foregroundColor(DesignTokens.Color.textMuted)
                            .padding(.top, 6)

                        section("core", tokens: core, locked: false)
                        section("with feeling", tokens: feeling, locked: !isPaid)
                        section("with food & drink", tokens: food, locked: !isPaid)
                        section("silly", tokens: silly, locked: !isPaid)
                        yoursSection

                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 22)
                }
            }
            .navigationTitle("\(selected.count) of \(PersonalSet.slotCount) selected")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("done") {
                        PersonalSet.save(selected)
                        onDone(selected)
                        dismiss()
                    }
                    .foregroundColor(selected.count == PersonalSet.slotCount
                                     ? DesignTokens.Color.accentSoft
                                     : DesignTokens.Color.textDim)
                    .disabled(selected.count != PersonalSet.slotCount)
                }
            }
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
