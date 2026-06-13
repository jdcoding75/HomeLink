// EmojiPickerView.swift
// Pointward › Views
//
// THE SLOT PICKER — your personal six as six visible slots (two rows of
// three). Empty slots invite a tap ("+ tap to add") and open the full emoji
// library; filled slots glow in the thought's hue. Long-press to wiggle and
// reveal a ✕ to clear, or drag a slot onto another to reorder. A status line
// keeps the count honest.
//
// Free: only the core six are addable (the rest show a quiet lock in the
// library). Pro (paid): the entire library, including your recordings.

import SwiftUI

struct EmojiPickerView: View {

    @ObservedObject var customStore: CustomThoughtStore
    @ObservedObject var recorder: AudioRecorder
    var onDone: ([String]) -> Void

    @EnvironmentObject var subscription: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    /// Six optional slots — nil is an empty, addable slot.
    @State private var slots: [String?] = EmojiPickerView.loadSlots()
    @State private var targetSlot: Int? = nil       // which slot the library fills
    @State private var showLibrary = false
    @State private var showCreateSheet = false
    @State private var editMode = false             // long-press → wiggle + ✕
    @State private var fillAnimSlot: Int? = nil     // the slot currently popping in
    @State private var dropTargetSlot: Int? = nil   // [3/3] slot a drag is hovering over
    @State private var wiggle = false

    private var isPaid: Bool { subscription.tier != .free }
    private var filledCount: Int { slots.compactMap { $0 }.count }

    private static let lavender = Color(hex: "#c4a8d4")
    private static let emptyBorder = Color(hex: "#3a2e50")
    private static let emptyFill   = Color(hex: "#1a1228")
    private static let emptyPlus   = Color(hex: "#4a3860")
    private static let filledFill  = Color(hex: "#1e1828")

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)

    static func loadSlots() -> [String?] {
        var s: [String?] = PersonalSet.load().map { Optional($0) }
        while s.count < PersonalSet.slotCount { s.append(nil) }
        return Array(s.prefix(PersonalSet.slotCount))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.Color.background.ignoresSafeArea()

                VStack(spacing: 22) {
                    Text("these appear on your send screen")
                        .font(.system(size: 14, design: .serif).italic())
                        .foregroundColor(DesignTokens.Color.textMuted)
                        .padding(.top, 10)

                    // ── The six slots, two rows of three ──
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(0..<PersonalSet.slotCount, id: \.self) { i in
                            slotCard(i)
                        }
                    }
                    .padding(.horizontal, 28)

                    // ── Status line ──
                    statusLine

                    Spacer()

                    // ── Save ──
                    Button {
                        let tokens = slots.compactMap { $0 }
                        PersonalSet.save(tokens)
                        onDone(tokens)
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
                    .disabled(filledCount == 0)
                    .opacity(filledCount == 0 ? 0.4 : 1)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("your six")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if editMode {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("done") { withAnimation { editMode = false; wiggle = false } }
                            .foregroundColor(Self.lavender)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showLibrary) {
            EmojiLibrarySheet(customStore: customStore,
                              recorder: recorder,
                              isPaid: isPaid,
                              existing: Set(slots.compactMap { $0 })) { token in
                fillSlot(with: token)
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateThoughtSheet(recorder: recorder, store: customStore)
                .presentationDetents([.large])
        }
    }

    // ── A single slot ─────────────────────────────────────────────────────

    @ViewBuilder
    private func slotCard(_ i: Int) -> some View {
        let token = slots[i]
        ZStack {
            if let token {
                filledSlot(token, index: i)
            } else {
                emptySlot(index: i)
            }
        }
        .frame(width: 64, height: 64)
        .rotationEffect(.degrees(editMode && token != nil && wiggle ? 2.2 : (editMode && token != nil ? -2.2 : 0)))
        .animation(editMode ? .easeInOut(duration: 0.14).repeatForever(autoreverses: true) : .default,
                   value: wiggle)
        // [3/3] Drag a filled slot onto another → swap. Library emoji can also
        // be dropped here. Hovering highlights the target; dropping bounces in.
        .scaleEffect(dropTargetSlot == i ? 1.05 : 1.0)
        .overlay {
            if dropTargetSlot == i {
                ZStack {
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Self.lavender, lineWidth: 2.5)
                        .shadow(color: Self.lavender.opacity(0.9), radius: 8)
                    VStack {
                        Spacer()
                        Text("release to set")
                            .font(.system(size: 7, design: .serif).italic())
                            .foregroundColor(Self.lavender)
                    }
                    .padding(2)
                }
                .allowsHitTesting(false)
            }
        }
        .animation(.easeOut(duration: 0.15), value: dropTargetSlot)
        .ifLet(token) { view, tok in
            view.draggable(tok)
        }
        .dropDestination(for: String.self) { items, _ in
            dropTargetSlot = nil
            guard let dropped = items.first else { return false }
            swapToken(dropped, into: i)
            return true
        } isTargeted: { hovering in
            if hovering { dropTargetSlot = i }
            else if dropTargetSlot == i { dropTargetSlot = nil }
        }
        .contextMenu { EmptyView() }   // suppress default; we use long-press below
        .onLongPressGesture(minimumDuration: 0.45) {
            if token != nil {
                HapticEngine.personSelected()
                withAnimation { editMode = true; wiggle = true }
            }
        }
    }

    private func emptySlot(index i: Int) -> some View {
        Button {
            targetSlot = i
            showLibrary = true
            HapticEngine.personSelected()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(Self.emptyPlus)
                Text("tap to add")
                    .font(.system(size: 8))
                    .foregroundColor(Self.emptyPlus)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Self.emptyFill)
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Self.emptyBorder,
                            style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
            )
        }
        .buttonStyle(.plain)
    }

    private func filledSlot(_ token: String, index i: Int) -> some View {
        let hue = EmojiHue.color(for: displayEmoji(token))
        let popping = fillAnimSlot == i
        return Button {
            // Tap a filled slot → replace it via the library.
            if editMode { return }
            targetSlot = i
            showLibrary = true
        } label: {
            ZStack {
                symbol(token, size: 32)
                    .scaleEffect(popping ? 1.1 : 1.0)

                if token.hasPrefix("yours:") {
                    VStack { Spacer()
                        HStack { Spacer(); Text("🎤").font(.system(size: 9)) }
                    }.padding(3)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Self.filledFill)
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Self.lavender, lineWidth: 2)
            )
            .shadow(color: hue.opacity(0.45), radius: 8)
        }
        .buttonStyle(.plain)
        .scaleEffect(popping ? 1.0 : (fillAnimSlot == nil ? 1.0 : 1.0))
        .overlay(alignment: .topTrailing) {
            if editMode {
                Button {
                    clearSlot(i)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .background(Circle().fill(Color.black.opacity(0.6)))
                        .shadow(radius: 2)
                }
                .offset(x: 6, y: -6)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // ── Status line ───────────────────────────────────────────────────────

    private var statusLine: some View {
        // [4/6] Three clear states — always helpful, never confusing.
        Group {
            if filledCount == 0 {
                Text("tap any slot to add a feeling")
                    .foregroundColor(DesignTokens.Color.textMuted)
            } else if filledCount == PersonalSet.slotCount {
                Text("all slots filled · tap any to remove")
                    .foregroundColor(Self.lavender)
            } else {
                Text("\(filledCount) of \(PersonalSet.slotCount) · tap empty slots to add")
                    .foregroundColor(DesignTokens.Color.textMuted)
            }
        }
        .font(.system(size: 12, design: .serif).italic())
        .animation(.easeOut(duration: 0.2), value: filledCount)
    }

    // ── Mutations ─────────────────────────────────────────────────────────

    private func fillSlot(with token: String) {
        // Don't double-add the same token.
        if slots.contains(token) { return }
        let target = targetSlot ?? slots.firstIndex(where: { $0 == nil })
        guard let idx = target else { return }
        slots[idx] = token
        HapticEngine.personSelected()
        // Satisfying fill pop: border lights, emoji scales 0.3 → 1.1 → 1.0
        fillAnimSlot = idx
        withAnimation(AnimationSystem.easeOutBack(0.4)) { }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            if fillAnimSlot == idx { fillAnimSlot = nil }
        }
        targetSlot = nil
    }

    private func clearSlot(_ i: Int) {
        HapticEngine.personSelected()
        withAnimation(.easeOut(duration: 0.25)) {
            slots[i] = nil
        }
        if filledCount == 0 { withAnimation { editMode = false; wiggle = false } }
    }

    /// Reorder: swap the dragged token into slot `dest` (both animate to their
    /// new positions); the destination bounces to confirm the drop. [3/3]
    private func swapToken(_ token: String, into dest: Int) {
        guard let src = slots.firstIndex(where: { $0 == token }), src != dest else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            slots.swapAt(src, dest)
        }
        HapticEngine.sendSoft()
        bounceSlot(dest)
    }

    /// The satisfying scale 0.8 → 1.1 → 1.0 pop, shared by set + drop. [3/3]
    private func bounceSlot(_ idx: Int) {
        fillAnimSlot = idx
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            if fillAnimSlot == idx { fillAnimSlot = nil }
        }
    }

    // ── Token rendering ───────────────────────────────────────────────────

    private func displayEmoji(_ token: String) -> String {
        if token == "gecko" { return "🦎" }
        if token.hasPrefix("yours:"),
           let id = UUID(uuidString: String(token.dropFirst(6))),
           let thought = customStore.thought(id: id) {
            return thought.emoji
        }
        return token
    }

    @ViewBuilder
    private func symbol(_ token: String, size: CGFloat) -> some View {
        if token == "gecko" {
            LeopardGeckoView(size: size * 1.1)
        } else if token.hasPrefix("yours:"),
                  let id = UUID(uuidString: String(token.dropFirst(6))),
                  let thought = customStore.thought(id: id) {
            Text(thought.emoji).font(.system(size: size))
        } else {
            Text(token).font(.system(size: size))
        }
    }
}

// ════════════════════════════════════════════════════════════════════════
// MARK: - EmojiLibrarySheet
// ════════════════════════════════════════════════════════════════════════

/// The full emoji library — Core · Feeling · Food · Silly · Yours. Tapping
/// an emoji fills the target slot and dismisses. Locked sections (free tier)
/// route to the paywall.
struct EmojiLibrarySheet: View {

    @ObservedObject var customStore: CustomThoughtStore
    @ObservedObject var recorder: AudioRecorder
    let isPaid: Bool
    let existing: Set<String>
    let onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showCreateSheet = false
    @State private var showPaywall = false

    // [registry 2026-06-13] The library now reads from CuratedEmoji.all, grouped
    // by access tier — was four hardcoded arrays (core/feeling/food/silly) that
    // had drifted from the curated registry (they held retired tokens like 👊,
    // and emoji never wired for send). Source of truth: CuratedEmoji. Never
    // hardcode an emoji list on this surface again.
    private let core   = CuratedEmoji.all.filter { $0.access == .free }.map { $0.emoji }
    private let proSet = CuratedEmoji.all.filter { $0.access == .pro  }.map { $0.emoji }
    private let soon   = CuratedEmoji.all.filter { $0.access == .comingSoon }.map { $0.emoji }

    private static let lavender = Color(hex: "#c4a8d4")
    private let grid = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.Color.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        section("core", tokens: core, locked: false)
                        section("pro", tokens: proSet, locked: !isPaid)
                        if !soon.isEmpty {
                            section("coming soon", tokens: soon, locked: true)
                        }
                        yoursSection
                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("choose an emoji")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                        .foregroundColor(DesignTokens.Color.textMuted)
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
            LazyVGrid(columns: grid, spacing: 10) {
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
            LazyVGrid(columns: grid, spacing: 10) {
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

    private func cell(_ token: String, locked: Bool, displayEmoji: String? = nil) -> some View {
        let alreadyIn = existing.contains(token)
        return Button {
            if locked {
                HapticEngine.paywallReached()
                showPaywall = true
                return
            }
            if alreadyIn { return }
            onPick(token)
            dismiss()
        } label: {
            ZStack {
                Group {
                    if token == "gecko" {
                        LeopardGeckoView(size: 26)
                    } else {
                        Text(displayEmoji ?? token).font(.system(size: 24))
                    }
                }
                .opacity(locked || alreadyIn ? 0.3 : 1)

                if token.hasPrefix("yours:") {
                    VStack { Spacer()
                        HStack { Spacer(); Text("🎤").font(.system(size: 9)) }
                    }.padding(3)
                }
                if alreadyIn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Self.lavender)
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(DesignTokens.Color.backgroundCard.opacity(0.8))
            .cornerRadius(13)
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .stroke(DesignTokens.Color.border, lineWidth: 1)
            )
        }
        .disabled(alreadyIn && !locked)
    }
}

// ── A tiny conditional-modifier helper ───────────────────────────────────

private extension View {
    /// Applies `transform` only when `value` is non-nil, passing it through.
    @ViewBuilder
    func ifLet<V, Content: View>(_ value: V?,
                                 @ViewBuilder _ transform: (Self, V) -> Content) -> some View {
        if let value { transform(self, value) } else { self }
    }
}
