// ProSetupView.swift
// Pointward › Views
//
// "✦ Pro Features" — the one place everything Pro lives: status, your
// emoji set, custom sounds, compass skins, funny distance, hold to send.
// Free users see everything, locked — each 🔒 leads to the paywall.

import SwiftUI

struct ProSetupView: View {

    @EnvironmentObject var subscription: SubscriptionManager
    @EnvironmentObject var skinStore: SkinStore
    @Environment(\.dismiss) private var dismiss

    @AppStorage(ProFeatures.storageKey) private var proOn = false
    @AppStorage("holdToSendEnabled")    private var holdToSend = false
    @AppStorage("funnyUnitLocked")      private var funnyUnitLocked = -1

    @ObservedObject private var customStore = CustomThoughtStore.shared
    @StateObject private var recorder = AudioRecorder()

    @State private var personalSix: [String] = PersonalSet.load()
    @State private var showPaywall = false
    @State private var showEmojiPicker = false
    @State private var showCreateSheet = false
    @State private var editingThought: CustomThought? = nil
    @State private var deleteCandidate: CustomThought? = nil

    private var isPro: Bool { subscription.tier != .free }

    private static let lavender = Color(hex: "#c4a8d4")
    private static let green    = Color(hex: "#5dcaa5")

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.Color.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        statusSection
                        emojiSetSection
                        customSoundsSection
                        skinSection
                        funnyDistanceSection
                        holdToSendSection
                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
            }
            .navigationTitle("Pointward Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("done") { dismiss() }
                        .foregroundColor(DesignTokens.Color.accentSoft)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(isPresented: $showEmojiPicker) {
            EmojiPickerView(customStore: customStore, recorder: recorder) { tokens in
                personalSix = tokens
            }
        }
        .sheet(isPresented: $showCreateSheet, onDismiss: { editingThought = nil }) {
            CreateThoughtSheet(recorder: recorder, store: customStore,
                               editing: editingThought)
                .presentationDetents([.large])
        }
        .confirmationDialog(
            "delete \(deleteCandidate?.emoji ?? "")?",
            isPresented: Binding(
                get: { deleteCandidate != nil },
                set: { if !$0 { deleteCandidate = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("delete", role: .destructive) {
                if let thought = deleteCandidate {
                    customStore.remove(id: thought.id)
                    // Drop it from the six too, if it was chosen
                    let token = "yours:\(thought.id.uuidString)"
                    if personalSix.contains(token) {
                        personalSix = PersonalSet.load().filter { $0 != token }
                        PersonalSet.save(personalSix)
                        personalSix = PersonalSet.load()
                    }
                }
                deleteCandidate = nil
            }
            Button("cancel", role: .cancel) { deleteCandidate = nil }
        } message: {
            Text("its sound goes with it")
        }
    }

    // MARK: - Status

    @ViewBuilder
    private var statusSection: some View {
        if isPro {
            card {
                HStack {
                    Text("✦ Pro active")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Self.green)
                    Spacer()
                    // Small escape hatch back to the pure core experience
                    Toggle("", isOn: $proOn)
                        .tint(Self.green)
                        .labelsHidden()
                }
                .padding(14)
            }
        } else {
            VStack(spacing: 12) {
                Text("unlock Pointward Pro · $1.99")
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundColor(DesignTokens.Color.textPrimary)
                Button {
                    HapticEngine.paywallReached()
                    showPaywall = true
                } label: {
                    Text("unlock pro · $1.99")
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
                        .shadow(color: Color(hex: "#9b7fc0").opacity(0.4), radius: 10)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Your emoji set

    private var emojiSetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("your emoji set")
            lockable {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        ForEach(personalSix, id: \.self) { token in
                            slotCard {
                                if token == "gecko" {
                                    LeopardGeckoView(size: 22)
                                } else if token.hasPrefix("yours:"),
                                          let id = UUID(uuidString: String(token.dropFirst(6))),
                                          let thought = customStore.thought(id: id) {
                                    Text(thought.emoji).font(.system(size: 22))
                                } else {
                                    Text(token).font(.system(size: 22))
                                }
                            }
                        }
                    }
                    Button {
                        showEmojiPicker = true
                    } label: {
                        Text("edit your set →")
                            .font(.system(size: 13))
                            .foregroundColor(Self.lavender)
                    }
                }
                .padding(14)
            }
        }
        .onAppear { personalSix = PersonalSet.load() }
    }

    // MARK: - Your custom sounds

    private var customSoundsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("your custom sounds")
            lockable {
                HStack(spacing: 8) {
                    ForEach(customStore.thoughts) { thought in
                        slotCard {
                            VStack(spacing: 2) {
                                Text(thought.emoji).font(.system(size: 20))
                                if let name = thought.name {
                                    Text(name)
                                        .font(.system(size: 7))
                                        .foregroundColor(DesignTokens.Color.textMuted)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .onTapGesture { customStore.play(thought) }
                        .contextMenu {
                            Button {
                                editingThought = thought
                                showCreateSheet = true
                            } label: { Label("edit", systemImage: "pencil") }
                            Button(role: .destructive) {
                                deleteCandidate = thought
                            } label: { Label("delete", systemImage: "trash") }
                        }
                    }
                    if !customStore.isFull {
                        Button {
                            showCreateSheet = true
                        } label: {
                            slotCard {
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Self.lavender)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
            }
        }
    }

    // MARK: - Compass skin

    private var skinSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("compass skin")
            card {
                HStack(spacing: 10) {
                    skinCard(.minimal, locked: false)
                    skinCard(.vintage, locked: !isPro)
                    skinCard(.heart,   locked: !isPro)
                }
                .padding(14)
            }
        }
    }

    private func skinCard(_ skin: CompassSkin, locked: Bool) -> some View {
        let isActive = skinStore.activeSkin == skin
        return Button {
            if locked {
                HapticEngine.paywallReached()
                showPaywall = true
            } else {
                skinStore.activeSkin = skin
                HapticEngine.skinSelected()
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(isActive ? Self.lavender : DesignTokens.Color.borderMid,
                                lineWidth: isActive ? 2 : 1)
                        .frame(width: 52, height: 52)
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Self.lavender.opacity(0.8))
                    } else {
                        Image(systemName: "location.north.fill")
                            .font(.system(size: 17))
                            .foregroundColor(isActive ? Self.lavender : DesignTokens.Color.textDim)
                    }
                    if isActive {
                        VStack { HStack { Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(Self.lavender)
                        }; Spacer() }
                        .frame(width: 58, height: 58)
                    }
                }
                .shadow(color: isActive ? Self.lavender.opacity(0.5) : .clear, radius: 8)
                Text(skin.displayName)
                    .font(.system(size: 10))
                    .foregroundColor(isActive ? DesignTokens.Color.textPrimary
                                              : DesignTokens.Color.textMuted)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Funny distance

    private var funnyDistanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("funny distance")
            lockable {
                VStack(spacing: 10) {
                    HStack {
                        Text(funnyUnitLocked < 0 ? "surprise me each launch" : "locked to favourite")
                            .font(.system(size: 13))
                            .foregroundColor(DesignTokens.Color.textPrimary)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { funnyUnitLocked >= 0 },
                            set: { locked in funnyUnitLocked = locked ? 0 : -1 }
                        ))
                        .tint(Self.green)
                        .labelsHidden()
                    }
                    if funnyUnitLocked >= 0 {
                        Picker("", selection: $funnyUnitLocked) {
                            ForEach(0..<DistanceFun.funnyCount, id: \.self) { i in
                                Text(DistanceFun.funnyLabels[i]).tag(i)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Self.lavender)
                    }
                }
                .padding(14)
            }
        }
    }

    // MARK: - Hold to send

    private var holdToSendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("hold to send")
            lockable {
                HStack {
                    Text("hold your phone toward them for 3 seconds to send instead of tapping")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Toggle("", isOn: $holdToSend)
                        .tint(Self.green)
                        .labelsHidden()
                }
                .padding(14)
            }
        }
    }

    // MARK: - Building blocks

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(DesignTokens.Font.overline)
            .foregroundColor(DesignTokens.Color.textMuted)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .frame(maxWidth: .infinity)
            .background(DesignTokens.Color.backgroundCard)
            .cornerRadius(DesignTokens.Radius.card)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.card)
                    .stroke(DesignTokens.Color.border, lineWidth: 1)
            )
    }

    private func slotCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(width: 46, height: 46)
            .background(DesignTokens.Color.backgroundLift)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(DesignTokens.Color.borderMid, lineWidth: 1)
            )
    }

    /// Free users see the section dimmed under a 🔒 — one tap → paywall.
    @ViewBuilder
    private func lockable<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if isPro {
            card { content() }
        } else {
            Button {
                HapticEngine.paywallReached()
                showPaywall = true
            } label: {
                card { content() }
                    .opacity(0.45)
                    .overlay(
                        VStack(spacing: 3) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 15))
                            Text("pro")
                                .font(.system(size: 9, design: .serif).italic())
                        }
                        .foregroundColor(Self.lavender)
                    )
            }
            .buttonStyle(.plain)
        }
    }
}
