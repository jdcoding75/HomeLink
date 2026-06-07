// PingView.swift
// Pointward › Views
//
// Phase 1: "send a thought" — a symbolic, backend-free gesture.
// Two lanes of feeling: "with love" floats out softly like a lantern;
// "with feeling" launches like a missile with fire and scorch marks.
// Either way it flies in the real compass direction of the person.
// Free for everyone — no Pro gating.

import SwiftUI
import Combine

struct PingView: View {

    @EnvironmentObject var compass: CompassManager
    @EnvironmentObject var people:  PeopleManager
    @EnvironmentObject var pings:   PingManager

    // @AppStorage("quietMode") private var quietMode = false   // retired
    private let quietMode = false

    // MARK: - State

    private enum ThoughtPhase { case idle, flying, sent }

    @State private var phase: ThoughtPhase = .idle
    @State private var selectedEmoji: String? = nil
    @State private var fly = false          // drives every flight animation
    @State private var redFlash = false     // one subtle screen flash for "with feeling"
    @State private var flashGreen = false   // 💨 flashes green instead of red
    @State private var scorch = false       // scorch marks linger, then fade
    @State private var popRing = false      // final pop as a fury thought exits
    @State private var wobble: CGFloat = 0  // 💨 screen wobble on launch

    // "Create your own" thoughts — up to five, tokens "yours:<uuid>"
    @ObservedObject private var customStore = CustomThoughtStore.shared
    @StateObject private var recorder    = AudioRecorder()
    @State private var showCreateSheet = false
    @State private var editingThought: CustomThought? = nil   // long-press → edit
    @State private var deleteCandidate: CustomThought? = nil  // long-press → delete (confirmed)
    @State private var slotPulse = false    // soft pulsing border on the create cell
    @State private var alignBypass = false  // DEBUG: skip the 15° aim gate (Simulator)
    @State private var lockPulse   = false  // brilliant send-button pulse within 5°
    @State private var foodWobble  = false  // playful rocking during food flights

    // Focused set — each emoji has its own synthesized voice in SoundEngine.
    // "gecko" renders the custom-drawn LeopardGeckoView — a personal touch
    // for the leopard-gecko lover in the family
    // ── CORE — six emotions, always visible, no labels ───────────────────
    // ❤️ love · 💋 tenderness · 🤗 embrace · ✨ a spark · 🌸 fleeting · 🌙 night
    private let coreEmojis = ["❤️","💋","🤗","✨","🌸","🌙"]

    // ── PRO — the playground, visible only in Pro Mode ─────
    private let feelingEmojis = ["😤","🤬","👊","💢","⚡️","🌋","🔥","😡","💨"]
    private let foodEmojis    = ["🍕","🍫","🍺","🍷","🍰","☕","🧁","🍜","🍣","🥂"]
    private let sillyEmojis   = ["😂","🤪","🥳","💥","🎉","gecko"]
    // (previous sets, superseded:)
    // private let loveEmojis    = ["💜","💋","🫂","🌸","gecko","✨"]
    // private let feelingEmojis = ["😢","😤","🤬","⚡️","🔥","💨"]

    @AppStorage(ProFeatures.storageKey) private var proOn = false
    @EnvironmentObject var subscription: SubscriptionManager
    @State private var showPaywall = false

    // ── Curated six + bottom drawer ──────────────────────────────────────
    @State private var personalSix: [String] = PersonalSet.load()
    @State private var drawerExpanded = false
    @State private var showCuration = false
    @AppStorage("curationHintShown") private var curationHintShown = false
    @State private var showCurationHint = false

    // ── Hold to send — optional premium: the holding still IS the send ───
    @AppStorage("holdToSendEnabled") private var holdToSendEnabled = false
    @State private var holdProgress: Double = 0
    private let holdDuration: Double = 3.0
    private let holdTick = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    private var holdToSendActive: Bool {
        holdToSendEnabled && subscription.tier != .free
    }

    private static let lavender   = Color(hex: "#c4a8d4")
    private static let lavenderHi = Color(hex: "#e0ccee")
    private static let purpleGlow = Color(hex: "#9b7fc0")
    private static let dim        = Color(hex: "#7c6b8e")
    private static let ember      = Color(hex: "#ff6b4a")
    private static let fire       = Color(hex: "#ff3b30")
    private static let amber      = Color(hex: "#ffb347")
    private static let geckoGold  = Color(hex: "#F5A623")
    private static let geckoSun   = Color(hex: "#FFD966")

    /// Renders an emoji string, the hand-drawn gecko, or a custom thought's emoji.
    @ViewBuilder
    private func thoughtSymbol(_ token: String, size: CGFloat) -> some View {
        if token == "gecko" {
            LeopardGeckoView(size: size * 1.2)   // match emoji glyph footprint
        } else if let thought = customThought(for: token) {
            Text(thought.emoji).font(.system(size: size))
        } else {
            Text(token).font(.system(size: size))
        }
    }

    private var selectedIsFeeling: Bool {
        guard let e = selectedEmoji else { return false }
        // Custom thoughts ride the "with feeling" launch animation
        return feelingEmojis.contains(e) || e.hasPrefix("yours:")
    }

    private var selectedIsFood: Bool {
        guard let e = selectedEmoji else { return false }
        return foodEmojis.contains(e)
    }

    private var selectedIsSilly: Bool {
        guard let e = selectedEmoji else { return false }
        return sillyEmojis.contains(e)
    }

    // ── 15° alignment gate ───────────────────────────────────────────────
    /// How far off-target the needle is (0 = pointing straight at them).
    private var alignmentDiff: Double {
        let bearing = compass.state.bearingDegrees
        return min(bearing, 360 - bearing)
    }
    private var isAligned: Bool     { alignBypass || alignmentDiff <= 15 }
    private var isLockAligned: Bool { alignBypass || alignmentDiff <= 5 }

    /// The CustomThought behind a "yours:<uuid>" token, if it is one.
    private func customThought(for token: String) -> CustomThought? {
        guard token.hasPrefix("yours:"),
              let id = UUID(uuidString: String(token.dropFirst(6))) else { return nil }
        return customStore.thought(id: id)
    }

    /// The plain emoji that represents a token when sent over the wire.
    private func remoteEmoji(for token: String) -> String {
        if token == "gecko" { return "🦎" }
        if let thought = customThought(for: token) { return thought.emoji }
        return token
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Quiet night atmosphere — deep purple, faint stars
                DesignTokens.Color.background.ignoresSafeArea()
                RadialGradient(
                    colors: [Self.purpleGlow.opacity(0.10), .clear],
                    center: UnitPoint(x: 0.5, y: 0.40),
                    startRadius: 30, endRadius: 420
                )
                .ignoresSafeArea()
                starField
                    .ignoresSafeArea()

                // One subtle screen flash when something is fired with feeling
                // (red for fury, green for the 💨)
                (flashGreen ? Color.green : Color.red)
                    .opacity(redFlash ? 0.10 : 0)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                // ── The compass IS the screen — flights cross the whole display
                // (1.0 → 0.9: another 10% trim per design pass)
                miniCompass
                    .frame(width: 200, height: 200)
                    .scaleEffect(min(geo.size.width, geo.size.height) * 0.9 / 200)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.42)
                    .allowsHitTesting(false)

                // ── Floating chrome over the face ────────────────────────────
                VStack(spacing: 0) {
                    header
                        .padding(.top, 8)

                    // Felt receipt — "[name] felt your thought ✓"
                    if let notice = pings.feltNotice {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 10))
                            Text(notice)
                                .font(.system(size: 12, design: .serif).italic())
                        }
                        .foregroundColor(Color(hex: "#5dcaa5"))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(DesignTokens.Color.background.opacity(0.8))
                                .overlay(Capsule().stroke(Color(hex: "#5dcaa5").opacity(0.35), lineWidth: 1))
                        )
                        .padding(.top, 10)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    Spacer()

                    if phase == .sent {
                        sentConfirmation
                            .padding(.bottom, 14)
                            .transition(.opacity.animation(.easeIn(duration: 0.5).delay(0.4)))
                    }

                    // Hold to send (paid, opt-in): no button — the ring fills
                    // while you physically hold the phone toward them.
                    // Default: the aligned tap-send button.
                    if let emoji = selectedEmoji, phase == .idle, !drawerExpanded {
                        if holdToSendActive {
                            holdToSendIndicator(emoji: emoji)
                                .padding(.bottom, 10)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        } else {
                            sendButton(emoji: emoji)
                                .padding(.horizontal, 24)
                                .padding(.bottom, 10)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }

                    drawer
                        .padding(.horizontal, 14)
                        .padding(.bottom, 8)
                }
            }
            .offset(x: wobble)   // 💨 launch shake — bouncy spring back to center
            .contentShape(Rectangle())
            .onTapGesture {
                // Tap the compass area: collapse the drawer / dismiss confirmation
                if drawerExpanded {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        drawerExpanded = false
                    }
                } else if phase == .sent {
                    resetThought()
                }
            }
            // The hold-to-send clock: fills over 3 s while aligned within 15°,
            // resets the moment the phone drifts off target.
            .onReceive(holdTick) { _ in
                guard holdToSendActive, selectedEmoji != nil, phase == .idle else {
                    if holdProgress > 0 { holdProgress = 0 }
                    return
                }
                if isAligned {
                    holdProgress += 0.05 / holdDuration
                    if holdProgress >= 1.0 {
                        holdProgress = 0
                        HapticEngine.thoughtLaunched()   // the completion pulse
                        sendThought()
                    }
                } else if holdProgress > 0 {
                    withAnimation(.easeOut(duration: 0.3)) { holdProgress = 0 }
                }
            }
            .sheet(isPresented: $showCuration) {
                EmojiPickerView(customStore: customStore, recorder: recorder) { tokens in
                    personalSix = tokens
                    if let sel = selectedEmoji, !tokens.contains(sel) { selectedEmoji = nil }
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
                        if selectedEmoji == "yours:\(thought.id.uuidString)" { selectedEmoji = nil }
                        customStore.remove(id: thought.id)
                    }
                    deleteCandidate = nil
                }
                Button("cancel", role: .cancel) { deleteCandidate = nil }
            } message: {
                Text("its sound goes with it")
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: selectedEmoji)
        .animation(.easeOut(duration: 0.35), value: phase)
        .animation(.easeInOut(duration: 0.4), value: pings.feltNotice)
    }

    // MARK: - Bottom drawer (the curated six)

    /// Collapsed: a pill handle + your six in one quiet row, compass fully
    /// visible above. Expanded: a bottom sheet (≤40% of screen) with the
    /// 3×2 grid, "✦ edit", and the locked preview for free users.
    private var drawer: some View {
        VStack(spacing: 10) {
            // The handle
            Capsule()
                .fill(DesignTokens.Color.borderMid)
                .frame(width: 38, height: 5)
                .padding(.top, 8)
                .contentShape(Rectangle().inset(by: -12))
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        drawerExpanded.toggle()
                    }
                }

            if !drawerExpanded {
                // Collapsed: the six in a single row — nothing else
                HStack(spacing: 8) {
                    ForEach(personalSix, id: \.self) { token in
                        emojiCell(token)
                    }
                }
            } else {
                // Expanded: exactly six, clean 3×2 — no edit buttons,
                // no sections, no headers. Curation lives in Pro setup.
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3),
                            spacing: 14
                        ) {
                            ForEach(personalSix, id: \.self) { token in
                                emojiCell(token, large: true)
                            }
                        }

                        if subscription.tier == .free {
                            lockedPreview
                        }
                    }
                    .padding(.top, 2)
                }
            }
            // ("your six" header, "✦ edit" button, and the curation hint
            //  moved to ProSetupView in the Pro-setup pass)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
        .frame(maxHeight: drawerExpanded ? UIScreen.main.bounds.height * 0.40 : nil)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(DesignTokens.Color.background.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(DesignTokens.Color.border, lineWidth: 1)
                )
        )
        .opacity(phase == .flying ? 0.25 : 1)
        .onAppear {
            // Pick up set changes made in Pro setup
            personalSix = PersonalSet.load()
            // (curation hint retired — editing moved to ProSetupView)
        }
        .onChange(of: selectedEmoji) { _, new in
            // Picking a thought collapses the sheet — back to the compass
            if new != nil && drawerExpanded {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    drawerExpanded = false
                }
            }
        }
    }

    // MARK: - Hold to send

    /// The selected thought with a circular progress ring that fills while
    /// the phone physically points at them (15° window, 3 seconds).
    private func holdToSendIndicator(emoji: String) -> some View {
        VStack(spacing: 7) {
            ZStack {
                Circle()
                    .stroke(DesignTokens.Color.borderMid, lineWidth: 3)
                    .frame(width: 56, height: 56)
                Circle()
                    .trim(from: 0, to: holdProgress)
                    .stroke(Self.lavenderHi,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                thoughtSymbol(emoji, size: 24)
                    .shadow(color: Self.purpleGlow.opacity(isAligned ? 0.8 : 0.3),
                            radius: isAligned ? 10 : 4)
            }
            Text(isAligned
                 ? (holdProgress > 0 ? "keep holding…" : "hold toward \(people.selectedPerson?.name ?? "them") to send")
                 : "point toward \(people.selectedPerson?.name ?? "them") first")
                .font(.system(size: 11, design: .serif).italic())
                .foregroundColor(isAligned ? Self.lavenderHi : DesignTokens.Color.textMuted)

            #if DEBUG
            // Simulator has no compass — bypass the aim gate
            Button(alignBypass ? "⚙︎ aim bypass: on" : "⚙︎ aim bypass: off (sim)") {
                alignBypass.toggle()
            }
            .font(.system(size: 9))
            .foregroundColor(DesignTokens.Color.textDim)
            #endif
        }
        .animation(.easeOut(duration: 0.2), value: isAligned)
    }

    // MARK: - Floating emoji panel (superseded by the drawer; kept)

    private var emojiPanel: some View {
        VStack(spacing: 8) {
            if proOn {
                // Pro Mode adds four sections — more than fits on
                // screen, so the panel scrolls. (Without this the sections
                // rendered off-screen and appeared to be "missing".)
                ScrollView(showsIndicators: false) {
                    emojiSections
                }
                .frame(maxHeight: 340)
            } else {
                emojiSections   // core 6 fits without scrolling
            }

            if let emoji = selectedEmoji, phase == .idle {
                sendButton(emoji: emoji)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: proOn)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(DesignTokens.Color.background.opacity(0.74))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(DesignTokens.Color.border, lineWidth: 1)
                )
        )
        .opacity(phase == .flying ? 0.25 : 1)
    }

    private func resetThought() {
        withAnimation(.easeOut(duration: 0.3)) {
            phase         = .idle
            selectedEmoji = nil
            fly           = false
            scorch        = false
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            Text("point toward them")
                .font(DesignTokens.Font.compassName)
                .foregroundColor(DesignTokens.Color.textPrimary)

            if let person = people.selectedPerson {
                Text("toward \(person.name) · \(compass.state.formattedDistance) away")
                    .font(.system(size: 13).italic())
                    .foregroundColor(DesignTokens.Color.accentMid)
            }
        }
    }

    // MARK: - Star field

    private var starField: some View {
        Canvas { ctx, size in
            var seed: UInt32 = 77
            for _ in 0..<42 {
                seed = seed &* 1103515245 &+ 12345
                let x = Double(seed & 0x7fff) / Double(0x7fff) * size.width
                seed = seed &* 1103515245 &+ 12345
                let y = Double(seed & 0x7fff) / Double(0x7fff) * size.height
                let r: CGFloat = 0.4 + CGFloat((seed >> 16) & 3) * 0.25
                let op = 0.12 + Double((seed >> 20) & 3) * 0.08
                let star = Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
                ctx.fill(star, with: .color(Self.lavender.opacity(op)))
            }
        }
    }

    // MARK: - Mini compass

    /// Direction the needle points, as a unit offset (bearing 0° = up).
    private var flightDirection: CGSize {
        let rad = compass.state.bearingDegrees * .pi / 180
        return CGSize(width: CGFloat(sin(rad)), height: -CGFloat(cos(rad)))
    }

    private var miniCompass: some View {
        ZStack {
            // Soft glow under the face — warms purple for love, embers for feeling
            Circle()
                .fill((phase == .flying && selectedIsFeeling ? Self.ember : Self.purpleGlow)
                    .opacity(phase == .flying ? 0.25 : 0.12))
                .frame(width: 185, height: 185)
                .blur(radius: 26)
                .animation(.easeInOut(duration: 0.5), value: phase)

            // Face rings + ticks
            Circle()
                .stroke(Self.dim.opacity(0.55), lineWidth: 1)
                .frame(width: 195, height: 195)
            Circle()
                .stroke(Self.dim.opacity(0.22), lineWidth: 0.5)
                .frame(width: 187, height: 187)
            Canvas { ctx, size in
                let cx = size.width / 2, cy = size.height / 2
                for deg in stride(from: 0, to: 360, by: 15) {
                    let rad   = Double(deg) * .pi / 180
                    let major = deg % 90 == 0
                    let len: CGFloat = major ? 8 : 4
                    var path = Path()
                    path.move(to: CGPoint(x: cx + CGFloat(sin(rad)) * 93,
                                          y: cy - CGFloat(cos(rad)) * 93))
                    path.addLine(to: CGPoint(x: cx + CGFloat(sin(rad)) * (93 - len),
                                             y: cy - CGFloat(cos(rad)) * (93 - len)))
                    ctx.stroke(path,
                               with: .color(major ? Self.lavender.opacity(0.7)
                                                  : Self.dim.opacity(0.5)),
                               lineWidth: major ? 1.0 : 0.5)
                }

                // The 15° send window — same visual language as the lock moment.
                // Fixed at the top: the needle must settle inside it to send.
                var arc = Path()
                arc.addArc(center: CGPoint(x: cx, y: cy), radius: 88,
                           startAngle: .degrees(-90 - 15), endAngle: .degrees(-90 + 15),
                           clockwise: false)
                ctx.stroke(arc,
                           with: .color(Self.lavender.opacity(isAligned ? 0.9 : 0.30)),
                           style: StrokeStyle(lineWidth: isAligned ? 3 : 2, lineCap: .round))
                if isAligned {
                    // Warm glow halo when the needle is in the window
                    var halo = Path()
                    halo.addArc(center: CGPoint(x: cx, y: cy), radius: 88,
                                startAngle: .degrees(-90 - 17), endAngle: .degrees(-90 + 17),
                                clockwise: false)
                    ctx.stroke(halo,
                               with: .color(Self.purpleGlow.opacity(isLockAligned ? 0.55 : 0.30)),
                               style: StrokeStyle(lineWidth: 9, lineCap: .round))
                }
            }
            .frame(width: 195, height: 195)

            // Needle at the live bearing — the thought travels where this points
            ZStack {
                Triangle()
                    .fill(Self.lavender)
                    .frame(width: 9, height: 56)
                    .offset(y: -30)
                Triangle()
                    .fill(Color(hex: "#5a4870"))
                    .frame(width: 7, height: 36)
                    .rotationEffect(.degrees(180))
                    .offset(y: 20)
            }
            .rotationEffect(.degrees(compass.state.bearingDegrees))
            .opacity(phase == .sent ? 0.35 : 1)

            // Pivot
            Circle()
                .fill(Self.dim)
                .frame(width: 8, height: 8)

            // ── The flight ───────────────────────────────────────────────────
            if phase == .flying, let emoji = selectedEmoji {
                if selectedIsFood || selectedIsSilly {
                    foodFlight(emoji: emoji)   // playful wobble for silly too
                } else if selectedIsFeeling {
                    furyFlight(emoji: emoji)
                } else {
                    loveFlight(emoji: emoji)   // core six: the gentle release
                }
            }

            // ── Afterglow: their emoji rests at center ───────────────────────
            if phase == .sent, let person = people.selectedPerson {
                ZStack {
                    Circle()
                        .fill(Self.purpleGlow.opacity(0.30))
                        .frame(width: 64, height: 64)
                        .blur(radius: 14)
                    Text(person.emoji)
                        .font(.system(size: 30))
                }
                .transition(.opacity.animation(.easeIn(duration: 0.6).delay(0.5)))
            }
        }
    }

    // MARK: - Love flight — a lantern released into the night

    @ViewBuilder
    private func loveFlight(emoji: String) -> some View {
        let isGecko = emoji == "gecko"
        let dir     = flightDirection
        let edge    = CGSize(width: dir.width * 150, height: dir.height * 150)
        // The gecko trails its own warm orange/yellow; everything else stays pink/purple
        let cloudA  = isGecko ? Self.geckoGold : Self.purpleGlow
        let cloudB  = isGecko ? Self.geckoSun  : Color(hex: "#e0a8c8")

        // Soft warm particle cloud drifting behind
        ForEach(0..<8, id: \.self) { i in
            let frac   = 0.2 + Double(i) / 10
            let side   = (i % 2 == 0 ? 1.0 : -1.0)
            let jitter = side * Double(5 + (i * 9) % 14)
            let target = CGSize(
                width:  dir.width  * 150 * frac - dir.height * jitter,
                height: dir.height * 150 * frac + dir.width  * jitter
            )
            Circle()
                .fill((i % 2 == 0 ? cloudA : cloudB).opacity(0.5))
                .frame(width: CGFloat(5 + (i * 3) % 7), height: CGFloat(5 + (i * 3) % 7))
                .blur(radius: 3)
                .scaleEffect(fly ? 1.4 : 0.3)
                .opacity(fly ? 0 : 0.8)
                .offset(fly ? target : .zero)
                .animation(.easeOut(duration: 2.0).delay(0.25 + frac * 0.8), value: fly)
        }

        // Trail — hearts and sparkles, or orange/yellow sparkles for the gecko
        ForEach(0..<6, id: \.self) { i in
            Group {
                if isGecko {
                    Text("✦")
                        .font(.system(size: CGFloat(10 + (i * 2) % 6)))
                        .foregroundColor(i % 2 == 0 ? Self.geckoGold : Self.geckoSun)
                } else {
                    Text(i % 2 == 0 ? "💗" : "✨")
                        .font(.system(size: CGFloat(10 + (i * 2) % 6)))
                }
            }
            .scaleEffect(fly ? 0.4 : 0.9)
            .opacity(fly ? 0 : 0.85 - Double(i) * 0.1)
            .offset(fly ? edge : .zero)
            .animation(.easeOut(duration: 2.4).delay(0.3 + Double(i) * 0.18), value: fly)
        }

        // The thought — a slow intentional drift across the whole screen
        thoughtSymbol(emoji, size: 30)
            .scaleEffect(fly ? 1.6 : 0.6)
            .opacity(fly ? 0 : 1)
            .offset(fly ? edge : .zero)
            .animation(.easeOut(duration: 2.6).delay(0.1), value: fly)
            .shadow(color: (isGecko ? Self.geckoGold : Self.purpleGlow).opacity(0.7), radius: 10)
    }

    // MARK: - Food flight — floats and wobbles, leaving crumbs

    @ViewBuilder
    private func foodFlight(emoji: String) -> some View {
        let dir  = flightDirection
        let edge = CGSize(width: dir.width * 150, height: dir.height * 150)

        // Trail of little food particles tumbling behind
        ForEach(0..<6, id: \.self) { i in
            Text(emoji)
                .font(.system(size: CGFloat(9 + (i * 2) % 5)))
                .rotationEffect(.degrees(Double((i * 47) % 70) - 35))
                .opacity(fly ? 0 : 0.7 - Double(i) * 0.1)
                .offset(fly ? edge : .zero)
                .animation(.easeInOut(duration: 2.8).delay(0.25 + Double(i) * 0.16), value: fly)
        }

        // The dish itself — slower, playful, rocking side to side as it goes
        Text(emoji)
            .font(.system(size: 30))
            .rotationEffect(.degrees(foodWobble ? 12 : -12))
            .scaleEffect(fly ? 1.5 : 0.7)
            .opacity(fly ? 0 : 1)
            .offset(fly ? edge : .zero)
            .animation(.easeInOut(duration: 3.0).delay(0.1), value: fly)
            .shadow(color: Self.amber.opacity(0.7), radius: 10)
    }

    // MARK: - Fury flight — fired, not floated

    @ViewBuilder
    private func furyFlight(emoji: String) -> some View {
        let isFart = emoji == "💨"
        let dir  = flightDirection
        let edge = CGSize(width: dir.width * 165, height: dir.height * 165)
        // 💨 trails green instead of fire
        let trailA: Color = isFart ? Color(hex: "#6fd44a") : Self.fire
        let trailB: Color = isFart ? Color(hex: "#4a9c33") : Self.ember
        let trailC: Color = isFart ? Color(hex: "#a8e063") : Self.amber

        // Scorch marks along the path — appear fast, linger, fade slow
        ForEach(0..<6, id: \.self) { i in
            let frac = 0.15 + Double(i) / 8
            let pos  = CGSize(width: dir.width * 150 * frac,
                              height: dir.height * 150 * frac)
            Circle()
                .fill(Color(hex: "#3a201a").opacity(0.9))
                .frame(width: CGFloat(4 + (i * 5) % 6), height: CGFloat(4 + (i * 5) % 6))
                .offset(pos)
                .opacity(scorch ? 0 : 0.85)
                .animation(.easeOut(duration: 1.6).delay(0.15 + frac * 0.4), value: scorch)
        }

        // Red/orange explosion trail — fades over a second
        ForEach(0..<12, id: \.self) { i in
            let frac   = 0.1 + Double(i) / 13
            let side   = (i % 2 == 0 ? 1.0 : -1.0)
            let jitter = side * Double(4 + (i * 11) % 20)
            let target = CGSize(
                width:  dir.width  * 160 * frac - dir.height * jitter,
                height: dir.height * 160 * frac + dir.width  * jitter
            )
            let col: Color = i % 3 == 0 ? trailA : (i % 3 == 1 ? trailB : trailC)
            Text("✦")
                .font(.system(size: CGFloat(6 + (i * 3) % 8)))
                .foregroundColor(col)
                .scaleEffect(fly ? 0.3 : 1.1)
                .opacity(fly ? 0 : 0.95)
                .offset(fly ? target : .zero)
                .animation(.easeOut(duration: 1.0).delay(0.08 + frac * 0.35), value: fly)
        }

        // Final pop — a brief expanding ring where the thought exits
        if popRing {
            Circle()
                .stroke((isFart ? trailC : Self.amber).opacity(0.9), lineWidth: 2)
                .frame(width: 30, height: 30)
                .offset(edge)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.25).combined(with: .opacity),
                    removal:   .opacity
                ))
        }

        // The thought — still fired, but with enough air time to feel it
        thoughtSymbol(emoji, size: 30)
            .scaleEffect(fly ? 1.9 : 0.6)
            .opacity(fly ? 0 : 1)
            .offset(fly ? edge : .zero)
            .animation(.easeIn(duration: 1.0).delay(0.05), value: fly)
            .shadow(color: (isFart ? trailA : Self.fire).opacity(0.8), radius: 12)
    }

    // MARK: - Emoji sections

    private var emojiSections: some View {
        VStack(alignment: .leading, spacing: 10) {
            // ── CORE: six clean emotions, 3×2, no labels, no headers ──────
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3),
                spacing: 14
            ) {
                ForEach(coreEmojis, id: \.self) { emoji in
                    emojiCell(emoji, large: true)
                }
            }

            // ── FREE: a locked glimpse of the playground ──────────────────
            if subscription.tier == .free {
                lockedPreview
            }

            // ── PRO: the playground, only when the mode is on ──────
            if proOn && subscription.tier != .free {
                Divider()
                    .background(DesignTokens.Color.border)
                    .padding(.vertical, 8)

                sectionLabel("with feeling", color: Self.ember)
                emojiGrid(feelingEmojis)

                Divider()
                    .background(DesignTokens.Color.border)
                    .padding(.vertical, 8)

                sectionLabel("with food & drink", color: Self.amber)
                emojiGrid(foodEmojis)

                Divider()
                    .background(DesignTokens.Color.border)
                    .padding(.vertical, 8)

                sectionLabel("silly", color: Self.geckoGold)
                emojiGrid(sillyEmojis)

                Divider()
                    .background(DesignTokens.Color.border)
                    .padding(.vertical, 8)

                sectionLabel("yours", color: Self.lavenderHi)
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6),
                    spacing: 8
                ) {
                    ForEach(customStore.thoughts) { thought in
                        yoursCell(thought)
                    }
                    if !customStore.isFull {
                        createCell
                    }
                }
                .onAppear {
                    guard !quietMode else { return }
                    withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                        slotPulse = true
                    }
                }
            }
        }
    }

    /// FREE tier: a dimmed, blurred taste of the pro playground with
    /// a lock — one tap anywhere opens the paywall.
    private var lockedPreview: some View {
        Button {
            HapticEngine.paywallReached()
            showPaywall = true
        } label: {
            ZStack {
                // The forbidden fruit, dimmed and softened
                HStack(spacing: 10) {
                    ForEach(["😤","🤬","🍕","🍺","😂","🥳","⚡️","🎉"], id: \.self) { e in
                        Text(e).font(.system(size: 24))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .opacity(0.4)
                .blur(radius: 2.5)

                VStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 15))
                        .foregroundColor(Self.lavender)
                    Text("unlock pro for more")
                        .font(.system(size: 12, design: .serif).italic())
                        .foregroundColor(Self.lavender)
                }
            }
            .background(DesignTokens.Color.backgroundCard.opacity(0.5))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(DesignTokens.Color.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    /// A saved custom thought — selectable like any emoji; long-press to delete.
    private func yoursCell(_ thought: CustomThought) -> some View {
        let token      = "yours:\(thought.id.uuidString)"
        let isSelected = selectedEmoji == token
        return Button {
            guard phase != .flying else { return }
            if phase == .sent {
                phase  = .idle
                fly    = false
                scorch = false
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                selectedEmoji = isSelected ? nil : token
            }
        } label: {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(Self.lavenderHi.opacity(0.35))
                        .blur(radius: 13)
                        .padding(6)
                }
                Text(thought.emoji).font(.system(size: 25))
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(isSelected
                        ? DesignTokens.Color.accentStrong
                        : DesignTokens.Color.backgroundCard.opacity(0.8))
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(isSelected ? Self.lavenderHi.opacity(0.8)
                                       : DesignTokens.Color.borderMid,
                            lineWidth: 1)
            )
            .scaleEffect(isSelected ? 1.08 : 1.0)
        }
        .contextMenu {
            Button {
                editingThought = thought
                showCreateSheet = true
            } label: {
                Label("edit", systemImage: "pencil")
            }
            Button(role: .destructive) {
                deleteCandidate = thought   // confirm before removing
            } label: {
                Label("delete", systemImage: "trash")
            }
        }
    }

    /// "+ create your own" — opens the creation sheet (emoji + sound + name).
    private var createCell: some View {
        Button {
            guard phase != .flying else { return }
            showCreateSheet = true
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Self.lavenderHi)
                Text("create")
                    .font(.system(size: 7))
                    .foregroundColor(DesignTokens.Color.textMuted)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(DesignTokens.Color.backgroundCard.opacity(0.8))
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Self.lavenderHi.opacity(slotPulse ? 0.75 : 0.3),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
        }
    }

    private func sectionLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(DesignTokens.Font.overline)
            .foregroundColor(color.opacity(0.85))
    }

    private func emojiGrid(_ emojis: [String]) -> some View {
        // 6-up keeps the floating panel compact so the compass stays the hero
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6),
            spacing: 8
        ) {
            ForEach(emojis, id: \.self) { emoji in
                emojiCell(emoji)
            }
        }
    }

    private func emojiCell(_ emoji: String, large: Bool = false) -> some View {
        let isSelected = selectedEmoji == emoji
        let isFeeling  = feelingEmojis.contains(emoji)
        let isGecko    = emoji == "gecko"
        let glow       = isGecko ? Self.geckoGold : (isFeeling ? Self.ember : Self.purpleGlow)
        return Button {
            guard phase != .flying else { return }
            // Tapping an emoji right after a send dismisses the confirmation
            // and starts the next thought — no extra step
            if phase == .sent {
                phase  = .idle
                fly    = false
                scorch = false
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                selectedEmoji = isSelected ? nil : emoji
            }
        } label: {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(glow.opacity(isGecko ? 0.45 : large ? 0.30 : 0.35))
                        .blur(radius: large ? 16 : 13)
                        .padding(6)
                }
                thoughtSymbol(emoji, size: large ? 34 : 25)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(isSelected
                        ? (isGecko ? Self.geckoGold.opacity(0.16)
                           : isFeeling ? Self.fire.opacity(0.18)
                           : DesignTokens.Color.accentStrong)
                        : large ? Color.clear
                        : DesignTokens.Color.backgroundCard.opacity(0.8))
            .cornerRadius(large ? 19 : 15)
            .overlay(
                RoundedRectangle(cornerRadius: large ? 19 : 15)
                    .stroke(isSelected
                            ? (isGecko ? Self.geckoGold.opacity(0.7)
                               : isFeeling ? Self.ember.opacity(0.7)
                               : DesignTokens.Color.accentMid)
                            : large ? DesignTokens.Color.border.opacity(0.5)
                            : DesignTokens.Color.border,
                            lineWidth: 1)
            )
            // Selected: soft lavender glow + subtle scale (core stays gentle)
            .scaleEffect(isSelected ? (large ? 1.05 : 1.08) : 1.0)
        }
    }

    // MARK: - Send

    private func sendButton(emoji: String) -> some View {
        VStack(spacing: 6) {
            Button {
                sendThought()
            } label: {
                HStack(spacing: 8) {
                    if isAligned {
                        Text(selectedIsFeeling ? "launch" : selectedIsFood ? "serve" : "release")
                        thoughtSymbol(emoji, size: 17)
                    } else {
                        Image(systemName: "location.north.line")
                            .font(.system(size: 13))
                        Text("turn toward \(people.selectedPerson?.name ?? "them") to send")
                    }
                }
                .font(DesignTokens.Font.label)
                .foregroundColor(isAligned ? DesignTokens.Color.textPrimary
                                           : DesignTokens.Color.textMuted)
                .frame(maxWidth: .infinity)
                .padding(DesignTokens.Spacing.md)
                .background(!isAligned
                            ? DesignTokens.Color.backgroundCard
                            : selectedIsFeeling ? Self.fire.opacity(0.25)
                            : DesignTokens.Color.accentStrong)
                .cornerRadius(DesignTokens.Radius.button)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.button)
                        .stroke(!isAligned ? DesignTokens.Color.border
                                : selectedIsFeeling ? Self.ember.opacity(0.7)
                                : DesignTokens.Color.accentMid,
                                lineWidth: 1)
                )
                // Aligned: soft glow. Locked (≤5°): brilliant pulse — the most
                // satisfying moment to send from.
                .shadow(color: Self.purpleGlow.opacity(
                            !isAligned ? 0
                            : isLockAligned ? (lockPulse ? 0.85 : 0.45)
                            : 0.30),
                        radius: isLockAligned ? 14 : 8)
                .scaleEffect(isLockAligned && lockPulse ? 1.03 : 1.0)
            }
            .disabled(!isAligned)
            .onChange(of: isLockAligned) { _, locked in
                if locked && !quietMode {
                    withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                        lockPulse = true
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.3)) { lockPulse = false }
                }
            }

            #if DEBUG
            // Simulator has no compass — allow bypassing the aim gate
            Button(alignBypass ? "⚙︎ aim bypass: on" : "⚙︎ aim bypass: off (sim)") {
                alignBypass.toggle()
            }
            .font(.system(size: 10))
            .foregroundColor(DesignTokens.Color.textDim)
            #endif
        }
    }

    private func sendThought() {
        guard phase == .idle, let token = selectedEmoji else { return }
        let isFeeling = selectedIsFeeling

        fly     = false
        scorch  = false
        popRing = false
        withAnimation(.easeOut(duration: 0.2)) { phase = .flying }

        // If a real friend is paired via Supabase, the thought travels for real —
        // fire-and-forget so the local animation never waits on the network.
        if let friend = SupabaseService.connectedFriendID {
            let emoji = remoteEmoji(for: token)
            Task { try? await SupabaseService.shared.sendPing(to: friend, emoji: emoji) }
        }

        if selectedIsFood || selectedIsSilly {
            // Served: slow playful float with a wobble, ~3s of deliciousness
            foodWobble = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                HapticEngine.pingSent()
                SoundEngine.shared.play(for: token)
                fly = true
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    foodWobble = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.3) {
                foodWobble = false
                withAnimation { phase = .sent }
                scheduleConfirmationDismiss()
            }
        } else if isFeeling {
            // Fired: sharp launch, screen flash, ~1s flight, pop at the edge
            flashGreen = (token == "💨")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                HapticEngine.thoughtFired()
                if let thought = customThought(for: token) {
                    customStore.play(thought)         // their own sound
                } else {
                    SoundEngine.shared.play(for: token)   // synthesized
                }
                fly = true
                if !quietMode {
                    withAnimation(.easeIn(duration: 0.08)) { redFlash = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        withAnimation(.easeOut(duration: 0.4)) { redFlash = false }
                    }
                    // 💨 also rattles the screen — set hard, spring back loose
                    if token == "💨" {
                        wobble = 9
                        withAnimation(.spring(response: 0.12, dampingFraction: 0.14)) {
                            wobble = 0
                        }
                    }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) {
                HapticEngine.thoughtLaunched()                // second hit as it exits
                scorch = true                                 // scorch marks begin to fade
                withAnimation(.easeOut(duration: 0.25)) { popRing = true }   // the final pop
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeOut(duration: 0.3)) { popRing = false }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.85) {
                withAnimation { phase = .sent }
                scheduleConfirmationDismiss()
            }
        } else {
            // Released: gentle double pulse, slow ~2.6s drift, soft fade
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                HapticEngine.pingReceived()                   // gentle double pulse
                SoundEngine.shared.play(for: token)   // synthesized — rises with the float
                fly = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.9) {
                HapticEngine.thoughtReleased()                // whisper as it fades
                withAnimation { phase = .sent }
                scheduleConfirmationDismiss()
            }
        }
    }

    /// The confirmation is brief — it dissolves on its own if not interacted
    /// with. When it carries the invite link (no one paired yet), it lingers
    /// long enough to be tapped.
    private func scheduleConfirmationDismiss() {
        let delay: Double = SupabaseService.connectedFriendID == nil ? 6.5 : 2.8
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if phase == .sent { resetThought() }
        }
    }

    // MARK: - Sent confirmation

    // Brief and button-free — auto-dismisses, or tap anywhere / tap an emoji
    private var sentConfirmation: some View {
        VStack(spacing: 5) {
            Text("thought sent toward \(people.selectedPerson?.name ?? "them")")
                .font(DesignTokens.Font.label)
                .foregroundColor(DesignTokens.Color.accentSoft)

            Text(people.selectedPerson?.resolvedTagline ?? TaglineSystem.defaultTagline)
                .font(.system(size: 13).italic())
                .foregroundColor(DesignTokens.Color.textMuted)
                .multilineTextAlignment(.center)

            // No one paired to actually receive it? Offer the invite.
            if SupabaseService.connectedFriendID == nil {
                VStack(spacing: 7) {
                    Text("want them to feel it too?")
                        .font(.system(size: 12, design: .serif).italic())
                        .foregroundColor(DesignTokens.Color.textMuted)

                    ShareLink(item: AppLinks.thoughtInvite(code: SupabaseService.localPairingCode)) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 11))
                            Text("invite \(people.selectedPerson?.name ?? "them") to Pointward")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(Self.lavenderHi)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .overlay(Capsule().stroke(Self.lavenderHi.opacity(0.4), lineWidth: 1))
                    }
                }
                .padding(.top, 6)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(DesignTokens.Color.background.opacity(0.74))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(DesignTokens.Color.border, lineWidth: 1))
        )
    }
}

// MARK: - Create your own

/// The unified creation sheet: pick an emoji (native keyboard), choose its
/// sound (record your own or a preset voice), optionally name it, save.
struct CreateThoughtSheet: View {

    @ObservedObject var recorder: AudioRecorder
    @ObservedObject var store: CustomThoughtStore
    var editing: CustomThought? = nil   // pre-fills when editing an existing one
    @Environment(\.dismiss) private var dismiss

    private enum SoundChoice { case record, preset }

    @State private var chosenEmoji   = ""
    @State private var thoughtName   = ""               // optional, step 3
    @State private var soundChoice: SoundChoice = .record
    @State private var presetToken: String? = nil
    @State private var keepExistingRecording = false   // editing a recorded thought
    @State private var recordPulse   = false
    @State private var errorMessage: String?
    @FocusState private var emojiFocused: Bool

    private let lavender   = Color(hex: "#c4a8d4")
    private let lavenderHi = Color(hex: "#e0ccee")

    // Every synthesized voice is available as a preset
    private let presets = ["💜","💋","🫂","🌸","✨","😢","😤","🤬","⚡️","🔥","💨"]

    private var canSave: Bool {
        guard !chosenEmoji.isEmpty else { return false }
        switch soundChoice {
        case .record: return recorder.hasRecording || keepExistingRecording
        case .preset: return presetToken != nil
        }
    }

    var body: some View {
        ZStack {
            DesignTokens.Color.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Text(editing == nil ? "create your own" : "edit your thought")
                        .font(.system(size: 22, weight: .semibold, design: .serif))
                        .foregroundColor(DesignTokens.Color.textPrimary)
                        .padding(.top, 24)
                        .padding(.bottom, 22)

                    // a) The emoji — native keyboard; first tap auto-selects,
                    // keyboard dismisses itself, no return key needed
                    sectionLabel("its emoji")
                    TextField("tap to pick an emoji", text: $chosenEmoji)
                        .focused($emojiFocused)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 40))
                        .frame(height: 72)
                        .frame(maxWidth: .infinity)
                        .background(DesignTokens.Color.backgroundCard)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(chosenEmoji.isEmpty
                                        ? DesignTokens.Color.borderMid
                                        : DesignTokens.Color.accentMid, lineWidth: 1)
                        )
                        .onChange(of: chosenEmoji) { _, new in
                            guard let last = new.last else { return }
                            chosenEmoji  = String(last)   // auto-select the tapped emoji
                            emojiFocused = false          // dismiss keyboard immediately
                        }
                        .padding(.bottom, 18)

                    // b) The sound
                    sectionLabel("its sound")
                    Picker("", selection: $soundChoice) {
                        Text("record your own").tag(SoundChoice.record)
                        Text("preset").tag(SoundChoice.preset)
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, 14)

                    Group {
                        if soundChoice == .record {
                            recordSection
                        } else {
                            presetSection
                        }
                    }
                    .padding(.bottom, 18)

                    // Step 3 — optional name (leave empty to skip)
                    sectionLabel("name this one")
                    TextField("dad's laugh · our song", text: $thoughtName)
                        .formInput()
                        .padding(.bottom, 22)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(DesignTokens.Font.caption)
                            .foregroundColor(.red)
                            .padding(.bottom, 10)
                    }

                    // Save / cancel
                    HStack(spacing: 12) {
                        Button {
                            recorder.discardTake()
                            dismiss()
                        } label: {
                            Text("cancel")
                                .font(DesignTokens.Font.label)
                                .foregroundColor(DesignTokens.Color.textMuted)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignTokens.Radius.button)
                                        .stroke(DesignTokens.Color.borderMid, lineWidth: 1)
                                )
                        }

                        Button {
                            save()
                        } label: {
                            Text("save")
                                .font(.system(size: 15, weight: canSave ? .semibold : .regular))
                                .foregroundColor(DesignTokens.Color.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(DesignTokens.Color.accentStrong)
                                .cornerRadius(DesignTokens.Radius.button)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignTokens.Radius.button)
                                        .stroke(canSave ? DesignTokens.Color.accentSoft
                                                        : Color.clear, lineWidth: 1.2)
                                )
                                // The glow: save lights up the moment it's ready
                                .shadow(color: DesignTokens.Color.accentMid.opacity(canSave ? 0.6 : 0),
                                        radius: 10)
                                .scaleEffect(canSave ? 1.03 : 1.0)
                        }
                        .disabled(!canSave)
                        .opacity(canSave ? 1 : 0.4)
                        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: canSave)
                    }
                    .padding(.bottom, 30)
                }
                .padding(.horizontal, 26)
            }
        }
        .animation(.easeOut(duration: 0.25), value: soundChoice)
        .animation(.easeOut(duration: 0.25), value: recorder.hasRecording)
        .onAppear {
            // Editing: pre-fill from the existing thought
            if let editing {
                chosenEmoji = editing.emoji
                thoughtName = editing.name ?? ""
                switch editing.sound {
                case .preset(let token):
                    soundChoice = .preset
                    presetToken = token
                case .recording:
                    soundChoice = .record
                    keepExistingRecording = true   // keep it unless they retake
                }
            }
        }
        .onDisappear { recorder.discardTake() }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(DesignTokens.Font.overline)
            .foregroundColor(DesignTokens.Color.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
    }

    // MARK: Record

    private var recordSection: some View {
        VStack(spacing: 12) {
            Button {
                if recorder.isRecording {
                    recorder.stopRecording()
                } else {
                    recorder.beginRecording()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(recorder.isRecording
                              ? Color.red.opacity(recordPulse ? 0.85 : 0.55)
                              : DesignTokens.Color.accentStrong)
                        .frame(width: 72, height: 72)
                    Circle()
                        .stroke(recorder.isRecording ? Color.red : DesignTokens.Color.accentMid,
                                lineWidth: 1.5)
                        .frame(width: 82, height: 82)
                        .scaleEffect(recorder.isRecording && recordPulse ? 1.08 : 1.0)
                    Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 24))
                        .foregroundColor(DesignTokens.Color.textPrimary)
                }
            }
            .onChange(of: recorder.isRecording) { _, recording in
                if recording {
                    withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                        recordPulse = true
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.2)) { recordPulse = false }
                }
            }

            // Live waveform
            HStack(spacing: 3) {
                ForEach(Array(recorder.levels.enumerated()), id: \.offset) { _, level in
                    Capsule()
                        .fill(lavender.opacity(0.85))
                        .frame(width: 3, height: 4 + level * 34)
                }
            }
            .frame(height: 40)
            .animation(.easeOut(duration: 0.06), value: recorder.levels)

            Text(recorder.isRecording
                 ? String(format: "0:0%.0f / 0:03", min(3, recorder.elapsed.rounded(.down)))
                 : (recorder.hasRecording ? "recorded ✓"
                    : keepExistingRecording ? "keeping your current recording — record to replace"
                                            : "up to 3 seconds"))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(DesignTokens.Color.textMuted)

            if recorder.hasRecording {
                HStack(spacing: 14) {
                    Button {
                        recorder.playPreview()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                            Text("preview")
                        }
                        .font(DesignTokens.Font.caption)
                        .foregroundColor(lavenderHi)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .overlay(Capsule().stroke(DesignTokens.Color.borderMid, lineWidth: 1))
                    }
                    Button("retake") {
                        recorder.discardTake()
                    }
                    .font(DesignTokens.Font.caption)
                    .foregroundColor(DesignTokens.Color.textMuted)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Presets

    private var presetSection: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6),
            spacing: 8
        ) {
            ForEach(presets, id: \.self) { token in
                Button {
                    presetToken = token
                    SoundEngine.shared.play(for: token)   // audition on tap
                } label: {
                    Text(token)
                        .font(.system(size: 24))
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .background(presetToken == token
                                    ? DesignTokens.Color.accentStrong
                                    : DesignTokens.Color.backgroundCard)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(presetToken == token
                                        ? DesignTokens.Color.accentMid
                                        : DesignTokens.Color.border, lineWidth: 1)
                        )
                }
            }
        }
    }

    // MARK: Save

    private func save() {
        guard canSave else { return }
        if editing == nil && store.isFull { return }
        errorMessage = nil

        // Keep the id stable when editing (recordings live at custom-<id>.m4a)
        var thought = editing ?? CustomThought(emoji: chosenEmoji, name: nil, sound: .recording)
        thought.emoji = chosenEmoji
        let trimmedName = thoughtName.trimmingCharacters(in: .whitespaces)
        thought.name = trimmedName.isEmpty ? nil : trimmedName

        switch soundChoice {
        case .preset:
            guard let token = presetToken else { return }
            thought.sound = .preset(token)
        case .record:
            thought.sound = .recording
            if recorder.hasRecording {
                guard recorder.saveTake(to: CustomThoughtStore.soundURL(for: thought.id)) else {
                    errorMessage = "Couldn't save the recording — try recording again."
                    return
                }
            } else if !keepExistingRecording {
                return   // nothing to save
            }
        }

        if editing == nil {
            store.add(thought)
        } else {
            store.update(thought)
        }

        HapticEngine.saved()
        recorder.discardTake()
        dismiss()
    }
}

// MARK: - LeopardGeckoView

/// A hand-drawn leopard gecko "emoji" — golden #F5A623 base, dark leopard
/// spots, big glossy eyes, fat tapering tail. Cute, recognisable, and a
/// personal touch for the gecko lover in the family.
struct LeopardGeckoView: View {
    var size: CGFloat = 30

    private static let base   = Color(hex: "#F5A623")
    private static let belly  = Color(hex: "#FFC85C")
    private static let spot   = Color(hex: "#3d2410")
    private static let eyeInk = Color(hex: "#241509")

    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width, h = sz.height
            func pt(_ x: Double, _ y: Double) -> CGPoint {
                CGPoint(x: x * w, y: y * h)
            }
            func ellipse(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double) -> Path {
                Path(ellipseIn: CGRect(x: (cx - rx) * w, y: (cy - ry) * h,
                                       width: rx * 2 * w, height: ry * 2 * h))
            }

            // Tail — fat at the base, tapering with a gentle curl to the right
            var tail = Path()
            tail.move(to: pt(0.42, 0.60))
            tail.addCurve(to: pt(0.74, 0.90),
                          control1: pt(0.66, 0.64), control2: pt(0.84, 0.72))
            tail.addCurve(to: pt(0.46, 0.70),
                          control1: pt(0.62, 0.99), control2: pt(0.40, 0.86))
            tail.closeSubpath()
            ctx.fill(tail, with: .color(Self.base))

            // Stubby legs with round toes
            let legs: [(Double, Double, Double, Double)] = [
                (0.38, 0.36, 0.20, 0.28),   // front left
                (0.62, 0.36, 0.80, 0.28),   // front right
                (0.38, 0.56, 0.20, 0.64),   // back left
                (0.62, 0.56, 0.80, 0.64),   // back right
            ]
            for (x1, y1, x2, y2) in legs {
                var leg = Path()
                leg.move(to: pt(x1, y1))
                leg.addLine(to: pt(x2, y2))
                ctx.stroke(leg, with: .color(Self.base),
                           style: StrokeStyle(lineWidth: w * 0.075, lineCap: .round))
                ctx.fill(ellipse(x2, y2, 0.045, 0.04), with: .color(Self.base))
            }

            // Body
            ctx.fill(ellipse(0.50, 0.46, 0.150, 0.230), with: .color(Self.base))
            // Lighter belly stripe
            ctx.fill(ellipse(0.50, 0.50, 0.075, 0.150), with: .color(Self.belly.opacity(0.55)))

            // Head — broad and rounded, the leopard-gecko wedge
            ctx.fill(ellipse(0.50, 0.20, 0.180, 0.150), with: .color(Self.base))

            // Big glossy eyes
            ctx.fill(ellipse(0.405, 0.165, 0.052, 0.062), with: .color(Self.eyeInk))
            ctx.fill(ellipse(0.595, 0.165, 0.052, 0.062), with: .color(Self.eyeInk))
            ctx.fill(ellipse(0.422, 0.145, 0.016, 0.018), with: .color(.white.opacity(0.92)))
            ctx.fill(ellipse(0.612, 0.145, 0.016, 0.018), with: .color(.white.opacity(0.92)))

            // Little smile
            var smile = Path()
            smile.addArc(center: pt(0.50, 0.225), radius: w * 0.052,
                         startAngle: .degrees(25), endAngle: .degrees(155),
                         clockwise: false)
            ctx.stroke(smile, with: .color(Self.spot),
                       style: StrokeStyle(lineWidth: max(0.8, w * 0.022), lineCap: .round))
            // Nostrils
            ctx.fill(ellipse(0.46, 0.115, 0.008, 0.008), with: .color(Self.spot.opacity(0.7)))
            ctx.fill(ellipse(0.54, 0.115, 0.008, 0.008), with: .color(Self.spot.opacity(0.7)))

            // Leopard spots — scattered over head, body and tail
            let spots: [(Double, Double, Double)] = [
                (0.40, 0.27, 0.018), (0.59, 0.28, 0.020),
                (0.44, 0.36, 0.024), (0.57, 0.41, 0.028),
                (0.45, 0.50, 0.026), (0.58, 0.55, 0.020),
                (0.43, 0.62, 0.018), (0.52, 0.31, 0.016),
                (0.55, 0.66, 0.018), (0.62, 0.76, 0.018),
                (0.68, 0.84, 0.014), (0.51, 0.58, 0.014),
            ]
            for (sx, sy, sr) in spots {
                ctx.fill(ellipse(sx, sy, sr, sr * 0.88), with: .color(Self.spot.opacity(0.85)))
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview("Leopard gecko") {
    LeopardGeckoView(size: 120)
        .padding()
        .background(Color(hex: "#0d0d14"))
}
