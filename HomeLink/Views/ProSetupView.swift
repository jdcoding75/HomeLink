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
    @AppStorage(SenderStyle.storageKey) private var senderStyleRaw = SenderStyle.glow.rawValue

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
                        yourStyleSection
                        // (instrument + skin selections unified above)
                        // instrumentSection
                        // if instrumentStore.selected == .compass { skinSection }
                        // senderStyleSection   // superseded by the instrument selection
                        emojiSetSection
                        customSoundsSection
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
                Text("unlock Pointward Pro · $2.99")
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundColor(DesignTokens.Color.textPrimary)
                Button {
                    HapticEngine.paywallReached()
                    showPaywall = true
                } label: {
                    Text("unlock pro · $2.99")
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

    // MARK: - Your style (instrument + skin, unified)

    @EnvironmentObject var instrumentStore: InstrumentStore

    /// ONE selection for everything — three free compass variants on top,
    /// the Pro instruments below. Same options as the long-press picker.
    private var yourStyleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("your style")
            Text("choose how you send a feeling")
                .font(.system(size: 12, design: .serif).italic())
                .foregroundColor(DesignTokens.Color.textMuted)
                .padding(.bottom, 2)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible(), spacing: 10)],
                      spacing: 10) {
                ForEach(InstrumentOption.allCases) { option in
                    styleCard(option)
                }
            }
        }
    }

    private func styleCard(_ option: InstrumentOption) -> some View {
        let locked   = option.requiresPro && !isPro
        let isActive = InstrumentOption.selected == option

        return Button {
            if option.comingSoon {
                HapticEngine.personSelected()   // a wink — not selectable yet
            } else if locked {
                HapticEngine.paywallReached()
                showPaywall = true
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    InstrumentOption.apply(option, instrumentStore: instrumentStore,
                                           skinStore: skinStore)
                }
                HapticEngine.skinSelected()
            }
        } label: {
            VStack(spacing: 7) {
                HStack {
                    Spacer()
                    if option.comingSoon {
                        Text("coming soon")
                            .font(.system(size: 8, design: .serif).italic())
                            .foregroundColor(DesignTokens.Color.accentMid)
                    } else if locked {
                        HStack(spacing: 3) {
                            Image(systemName: "lock.fill").font(.system(size: 8))
                            Text("pro").font(.system(size: 9, design: .serif).italic())
                        }
                        .foregroundColor(Self.lavender.opacity(0.85))
                    } else {
                        Text(option.requiresPro ? "pro" : "free")
                            .font(.system(size: 9, design: .serif).italic())
                            .foregroundColor(option.requiresPro
                                             ? Self.lavender.opacity(0.85) : Self.green)
                    }
                }
                .frame(height: 12)

                Text(option.icon)
                    .font(.system(size: 38))
                    .opacity(locked || option.comingSoon ? 0.5 : 1)

                Text(option.displayName)
                    .font(.system(size: 13, weight: isActive ? .semibold : .regular,
                                  design: .serif))
                    .foregroundColor(DesignTokens.Color.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(option.tagline)
                    .font(.system(size: 9, design: .serif).italic())
                    .foregroundColor(DesignTokens.Color.textDim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                // Compass variants show their face; instruments their mechanic
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(DesignTokens.Color.backgroundLift)
                    if let skin = option.skin {
                        ZStack {
                            SkinFaceView(skin: skin, bearing: -22.5, locked: false,
                                         quietMode: false, pingRingActive: false)
                            NeedleView(bearing: -22.5, skin: skin, locked: false)
                        }
                        .frame(width: 240, height: 240)
                        .scaleEffect(44.0 / 240.0)
                        .frame(width: 44, height: 44)
                    } else {
                        InstrumentPreview(instrument: option.instrument)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .opacity(locked || option.comingSoon ? 0.4 : 1)
                    }
                }
                .frame(height: 50)
            }
            .padding(11)
            .frame(maxWidth: .infinity)
            .background(DesignTokens.Color.backgroundCard)
            .cornerRadius(DesignTokens.Radius.card)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.card)
                    .stroke(isActive ? Self.lavender : DesignTokens.Color.border,
                            lineWidth: isActive ? 2 : 1)
            )
            .shadow(color: isActive ? Self.lavender.opacity(0.5) : .clear, radius: 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var instrumentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("your instrument")
            Text("choose how you send a feeling")
                .font(.system(size: 12, design: .serif).italic())
                .foregroundColor(DesignTokens.Color.textMuted)
                .padding(.bottom, 2)

            // Four large cards — icon, serif name, tagline, and the
            // mechanic itself looping in miniature
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible(), spacing: 10)],
                      spacing: 10) {
                ForEach(Instrument.allCases) { instrument in
                    instrumentCard(instrument)
                }
            }
        }
    }

    private func instrumentCard(_ instrument: Instrument) -> some View {
        let locked   = instrument.requiresPro && !isPro
        let isActive = instrumentStore.selected == instrument && !locked

        return Button {
            if locked {
                HapticEngine.paywallReached()
                showPaywall = true
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    instrumentStore.selected = instrument
                }
                HapticEngine.skinSelected()
            }
        } label: {
            VStack(spacing: 8) {
                // Free/Pro badge — top right
                HStack {
                    Spacer()
                    if locked {
                        HStack(spacing: 3) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 8))
                            Text("pro")
                                .font(.system(size: 9, design: .serif).italic())
                        }
                        .foregroundColor(Self.lavender.opacity(0.85))
                    } else {
                        Text(instrument.requiresPro ? "pro" : "free")
                            .font(.system(size: 9, design: .serif).italic())
                            .foregroundColor(instrument.requiresPro
                                             ? Self.lavender.opacity(0.85)
                                             : Self.green)
                    }
                }
                .frame(height: 12)

                Text(instrument.icon)
                    .font(.system(size: 48))
                    .opacity(locked ? 0.55 : 1)

                Text(instrument.displayName)
                    .font(.system(size: 15, weight: isActive ? .semibold : .regular,
                                  design: .serif))
                    .foregroundColor(DesignTokens.Color.textPrimary)

                Text(instrument.tagline)
                    .font(.system(size: 10, design: .serif).italic())
                    .foregroundColor(DesignTokens.Color.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                // The mechanic, looping in miniature
                ZStack {
                    RoundedRectangle(cornerRadius: 11)
                        .fill(DesignTokens.Color.backgroundLift)
                    InstrumentPreview(instrument: instrument)
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                        .opacity(locked ? 0.4 : 1)
                }
                .frame(height: 56)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(DesignTokens.Color.backgroundCard)
            .cornerRadius(DesignTokens.Radius.card)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.card)
                    .stroke(isActive ? Self.lavender : DesignTokens.Color.border,
                            lineWidth: isActive ? 2 : 1)
            )
            // Selected: the full lavender border glow
            .shadow(color: isActive ? Self.lavender.opacity(0.5) : .clear, radius: 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - How you send (sender styles — superseded by instruments, kept)

    private var senderStyleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("how you send")
            card {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(SenderStyle.allCases) { style in
                        senderStyleCard(style)
                    }
                }
                .padding(14)
            }
        }
    }

    private func senderStyleCard(_ style: SenderStyle) -> some View {
        let locked   = style.requiresPro && !isPro
        let isActive = senderStyleRaw == style.rawValue && !locked

        return Button {
            if locked {
                HapticEngine.paywallReached()
                showPaywall = true
            } else {
                senderStyleRaw = style.rawValue
                HapticEngine.skinSelected()
            }
        } label: {
            VStack(spacing: 7) {
                // Mini animation preview — looping
                ZStack {
                    RoundedRectangle(cornerRadius: 13)
                        .fill(DesignTokens.Color.backgroundLift)
                    SenderStylePreview(style: style)
                        .opacity(locked ? 0.35 : 1)
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13))
                            .foregroundColor(Self.lavender.opacity(0.85))
                    }
                    if isActive {
                        VStack { HStack { Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Self.lavender)
                                .padding(4)
                        }; Spacer() }
                    }
                }
                .frame(height: 58)
                .overlay(
                    RoundedRectangle(cornerRadius: 13)
                        .stroke(isActive ? Self.lavender : DesignTokens.Color.borderMid,
                                lineWidth: isActive ? 2 : 1)
                )
                // Selected style: lavender border glow
                .shadow(color: isActive ? Self.lavender.opacity(0.5) : .clear, radius: 8)

                Text("\(style.emoji) \(style.displayName)")
                    .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? DesignTokens.Color.textPrimary
                                              : DesignTokens.Color.textMuted)
                Text(style.blurb)
                    .font(.system(size: 9, design: .serif).italic())
                    .foregroundColor(DesignTokens.Color.textDim)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
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
                    Text("hold your phone toward them for 2 seconds to send instead of tapping")
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

// MARK: - SenderStylePreview

/// A tiny looping echo of the real send — a hue-true dot drifting along a
/// curve, restarting gently. Lives inside the "how you send" cards.
struct SenderStylePreview: View {

    let style: SenderStyle

    @State private var progress: CGFloat = 0
    @State private var visible = true

    private var duration: Double {
        switch style {
        case .glow:         return 0.9
        case .shootingStar: return 0.7
        case .firefly:      return 1.7
        case .fingerFlick:  return 0.8
        case .bowArrow:     return 1.0
        }
    }

    private var travel: Animation {
        switch style {
        case .glow:         return AnimationSystem.easeOutCubic(duration)
        case .shootingStar: return AnimationSystem.easeOutCubic(duration)
        case .firefly:      return AnimationSystem.easeInOutSine(duration)
        case .fingerFlick:  return AnimationSystem.easeOutCubic(duration)
        case .bowArrow:     return AnimationSystem.easeOutCubic(duration)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let start   = CGSize(width: -w * 0.30, height: h * 0.16)
            let end     = CGSize(width:  w * 0.30, height: -h * 0.16)
            let control = CGSize(width: 0, height: -h * 0.34)

            dot
                .opacity(visible ? 1 : 0)
                .modifier(CurvedFlightEffect(progress: progress, start: start,
                                             control: control, end: end))
                .animation(travel, value: progress)
                .animation(.easeOut(duration: 0.25), value: visible)
                .position(x: w / 2, y: h / 2)
        }
        .allowsHitTesting(false)
        .onAppear { loop() }
    }

    @ViewBuilder
    private var dot: some View {
        switch style {
        case .glow:
            Circle()
                .fill(Color(hex: "#c4a8d4"))
                .frame(width: 7, height: 7)
                .blur(radius: 0.5)
                .shadow(color: Color(hex: "#c4a8d4").opacity(0.7), radius: 5)
        case .shootingStar:
            Capsule()
                .fill(LinearGradient(colors: [.white, Color(hex: "#FFD700").opacity(0.7), .clear],
                                     startPoint: .trailing, endPoint: .leading))
                .frame(width: 16, height: 4)
                .rotationEffect(.degrees(-24))
                .shadow(color: Color(hex: "#FFD700").opacity(0.5), radius: 4)
        case .firefly:
            Circle()
                .fill(Color(hex: "#90EE90"))
                .frame(width: 6, height: 6)
                .blur(radius: 1)
                .shadow(color: Color(hex: "#90EE90").opacity(0.7), radius: 6)
        case .fingerFlick:
            // A flicked spark — white core, gold halo
            Circle()
                .fill(.white.opacity(0.95))
                .frame(width: 7, height: 7)
                .shadow(color: Color(hex: "#FFD700").opacity(0.8), radius: 5)
        case .bowArrow:
            // A tiny arrow in flight
            HStack(spacing: 0) {
                Capsule()
                    .fill(Color(hex: "#E8B64C").opacity(0.9))
                    .frame(width: 12, height: 2.5)
                Triangle()
                    .fill(Color(hex: "#FFD700"))
                    .frame(width: 6, height: 7)
                    .rotationEffect(.degrees(90))
            }
            .rotationEffect(.degrees(-24))
            .shadow(color: Color(hex: "#FFD700").opacity(0.6), radius: 4)
        }
    }

    private func loop() {
        visible  = true
        progress = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            visible = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                var snap = Transaction()
                snap.disablesAnimations = true
                withTransaction(snap) { progress = 0 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { loop() }
            }
        }
    }
}
