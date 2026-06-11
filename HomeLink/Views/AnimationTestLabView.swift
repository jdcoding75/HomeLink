// AnimationTestLabView.swift
// Pointward › Views
//
// THE ANIMATION TEST LAB — DEBUG ONLY. Stage-driven and fed entirely by
// AnimationManifest (the single source of truth). For every catalogued
// animation (instrument · version · emoji mechanism) the lab offers:
//
//   • FULL WORKFLOW — Compass → Send → [interstitial] → Receipt → Reveal, played
//     as one continuous run. The interstitial ("sent… → arriving") is a
//     transition, NOT a selectable stage.
//   • Each STAGE alone — Compass / Send / Receipt / Reveal (only the stages the
//     manifest says that animation provides).
//
// Labels come straight from the manifest: "<Instrument> <Version> — <Stage>"
// and "<Instrument> <Version> — Full Workflow". Nothing is hand-maintained here.

#if DEBUG
import SwiftUI

struct AnimationTestLabView: View {

    @Environment(\.dismiss) private var dismiss

    enum Mode: Equatable {
        case workflow
        case stage(AnimationStage)
    }
    struct Run: Identifiable {
        let id = UUID()
        let def: AnimationDefinition
        let mode: Mode
        let emoji: String
    }
    @State private var run: Run?

    private static let lavender = Color(hex: "#c4a8d4")
    private static let gold     = Color(hex: "#e0a85a")
    private static let stageOrder: [AnimationStage] = [.compass, .send, .receipt, .reveal]

    private var randomEmoji: String { DevTools.testEmojis.randomElement() ?? "💜" }
    private func emoji(for def: AnimationDefinition) -> String { def.fixedEmoji ?? randomEmoji }

    private let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.Color.background.ignoresSafeArea()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        ForEach(AnimationManifest.all) { def in
                            section(for: def)
                        }
                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 20).padding(.top, 10)
                }
            }
            .navigationTitle("Animation Test Lab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("done") { dismiss() }.foregroundColor(Self.lavender)
                }
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(item: $run) { playerOverlay($0) }
    }

    // ── A section per manifest definition ──────────────────────────────────

    private func section(for def: AnimationDefinition) -> some View {
        let stages = Self.stageOrder.filter { def.provides($0) }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(def.icon).font(.system(size: 22))
                Text(def.displayName)
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundColor(DesignTokens.Color.textPrimary)
            }
            workflowButton(def)
            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(stages) { stage in stageChip(def, stage) }
            }
        }
    }

    private func workflowButton(_ def: AnimationDefinition) -> some View {
        Button { start(def, .workflow) } label: {
            HStack {
                Text("Full Workflow")
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .foregroundColor(.black)
                Spacer()
                Text("Compass → Send → Receipt → Reveal")
                    .font(.system(size: 10, design: .serif).italic())
                    .foregroundColor(.black.opacity(0.6))
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(Self.gold.opacity(0.9))
            .cornerRadius(DesignTokens.Radius.card)
        }
        .buttonStyle(.plain)
    }

    private func stageChip(_ def: AnimationDefinition, _ stage: AnimationStage) -> some View {
        Button { start(def, .stage(stage)) } label: {
            Text(stage.rawValue)
                .font(.system(size: 13, weight: .medium, design: .serif))
                .foregroundColor(DesignTokens.Color.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(DesignTokens.Color.backgroundCard)
                .cornerRadius(DesignTokens.Radius.card)
                .overlay(RoundedRectangle(cornerRadius: DesignTokens.Radius.card)
                    .stroke(Self.lavender.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func start(_ def: AnimationDefinition, _ mode: Mode) {
        run = Run(def: def, mode: mode, emoji: emoji(for: def))
    }

    // ── The full-screen player ──────────────────────────────────────────────

    @ViewBuilder
    private func playerOverlay(_ r: Run) -> some View {
        ZStack {
            DesignTokens.Color.background.ignoresSafeArea()
            CatchWorldBackground(style: r.def.style).ignoresSafeArea()

            switch r.mode {
            case .workflow:
                AnimationWorkflowRunner(def: r.def, emoji: r.emoji, onDone: { run = nil })
            case .stage(let stage):
                AnimationStageView(def: r.def, stage: stage, emoji: r.emoji, onDone: { run = nil })
            }

            chrome(for: r)
        }
        .preferredColorScheme(.dark)
    }

    private func chrome(for r: Run) -> some View {
        ZStack(alignment: .top) {
            // Close button — top-left, always tappable (interactive faces own
            // the rest of the screen, so there is no tap-to-dismiss backdrop).
            HStack {
                Button { run = nil } label: {
                    Text("✕ close")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Self.lavender)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Capsule().fill(DesignTokens.Color.background.opacity(0.8)))
                }
                .buttonStyle(.plain)
                Spacer()
                Text(labelText(for: r))
                    .font(.system(size: 11, design: .serif).italic())
                    .foregroundColor(Self.lavender.opacity(0.85))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(DesignTokens.Color.background.opacity(0.7)))
                    .allowsHitTesting(false)
            }
            .padding(.top, 50).padding(.horizontal, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func labelText(for r: Run) -> String {
        switch r.mode {
        case .workflow:     return "\(r.emoji) \(r.def.displayName) — Full Workflow"
        case .stage(let s): return "\(r.emoji) \(r.def.label(for: s))"
        }
    }
}

// MARK: - One stage, rendered

/// Renders a single stage (Compass / Send / Receipt / Reveal) for a manifest
/// definition. Used both for a standalone stage run and as the building block of
/// the full-workflow runner. `onDone` fires when the stage completes.
private struct AnimationStageView: View {
    let def: AnimationDefinition
    let stage: AnimationStage
    let emoji: String
    let onDone: () -> Void

    var body: some View {
        switch stage {
        case .compass: compassStage
        case .send:    sendStage
        case .receipt: receiptStage
        case .reveal:  revealStage
        }
    }

    private var sym: AnyView { AnyView(Text(emoji).font(.system(size: 22))) }

    /// A receipt that ENDS in EmojiRevealView (so the workflow must NOT add a
    /// separate Reveal stage after it). False only for the landing-beat path.
    static func receiptAutoReveals(_ def: AnimationDefinition) -> Bool {
        if def.kind == .emoji { return true }
        if def.version == "V2" { return true }
        switch def.style {
        case .firefly, .rocket, .plane: return true   // dedicated V1 receipts
        default:                         return false  // bow/flick/wand V1, compass
        }
    }

    private var instrumentKind: Instrument {
        switch def.style {
        case .bowArrow:    return .bow
        case .fingerFlick: return .flick
        case .plane:       return .plane
        case .rocket:      return .rocket
        case .wand:        return .wand
        case .firefly:     return .wind
        default:           return .compass
        }
    }

    // ── COMPASS ──────────────────────────────────────────────────────────────

    @ViewBuilder private var compassStage: some View {
        if def.name == "Firework" {
            FireworkCompassFace(personName: "them", onSend: onDone)
        } else if def.name == "Birthday Cake" {
            if def.version == "V2" {
                BirthdayCakeCompassFaceV2(personName: "them", onSend: onDone)
            } else {
                BirthdayCakeCompassFace(personName: "them", onSend: onDone)
            }
        } else {
            instrumentCompass
        }
    }

    @ViewBuilder private var instrumentCompass: some View {
        let t = "test-token"
        switch def.style {
        case .bowArrow:
            BowInstrumentView(loadedToken: t, loadedSymbol: sym, bearingDegrees: 0,
                              personName: "them", onSend: onDone)
        case .fingerFlick:
            FlickInstrumentView(loadedToken: t, loadedSymbol: sym, bearingDegrees: 0,
                                personName: "them", onSend: { _ in onDone() })
        case .plane:
            PlaneInstrumentView(loadedToken: t, loadedSymbol: sym, bearingDegrees: 0,
                                personName: "them", onLaunch: onDone)
        case .wand:
            WandInstrumentView(loadedToken: t, loadedSymbol: sym, bearingDegrees: 0,
                               personName: "them", onSend: onDone)
        case .rocket:
            RocketInstrumentView(loadedToken: t, loadedSymbol: sym, bearingDegrees: 0,
                                 personName: "them", onLaunch: onDone)
        case .firefly:
            WindInstrumentView(loadedToken: t, loadedSymbol: sym, bearingDegrees: 0,
                               personName: "them", onSend: onDone)
        default:
            // Compass / glow — the aim mechanic is in-app only (no standalone face).
            VStack(spacing: 10) {
                Text("🧭").font(.system(size: 64))
                Text("the compass aim mechanic runs in the app")
                    .font(.system(size: 13, design: .serif).italic())
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }

    // ── SEND ─────────────────────────────────────────────────────────────────

    @ViewBuilder private var sendStage: some View {
        if def.name == "Firework" {
            FireworkSendAnimation(emoji: "🎆", onComplete: onDone)
        } else if def.name == "Birthday Cake" {
            BirthdayCakeSendAnimationV2(emoji: "🎂", onComplete: onDone)
        } else {
            instrumentSend
        }
    }

    @ViewBuilder private var instrumentSend: some View {
        let t = InstrumentTransition(exitBearing: 0, exitPoint: .zero,
                                     instrument: instrumentKind, emoji: emoji,
                                     message: nil, tagline: nil)
        if def.style == .rocket {
            SenderAnimationView(style: .rocket, emoji: emoji, bearingDegrees: 0,
                                symbol: Text(emoji).font(.system(size: 45))) { onDone() }
        } else if def.version == "V2" {
            switch def.style {
            case .bowArrow:    BowSendAnimationV2(transition: t, personName: "them", onComplete: onDone)
            case .fingerFlick: FlickSendAnimationV2(transition: t, personName: "them", onComplete: onDone)
            case .plane:       PlaneSendAnimationV2(transition: t, personName: "them", onComplete: onDone)
            default:           EmptyView()
            }
        } else if def.style == .plane {
            PlaneSendAnimation(transition: t, personName: "them", onComplete: onDone)
        } else {
            SenderAnimationView(style: def.style, emoji: emoji, bearingDegrees: 0,
                                symbol: Text(emoji).font(.system(size: 45))) { onDone() }
        }
    }

    // ── RECEIPT ──────────────────────────────────────────────────────────────

    @ViewBuilder private var receiptStage: some View {
        if def.name == "Firework" {
            FireworkReceipt(emoji: "🎆", fromName: "them", onRevealed: {}, onFinished: onDone)
        } else if def.name == "Birthday Cake" {
            if def.version == "V2" {
                BirthdayCakeReceiptV2(emoji: "🎂", fromName: "them", onRevealed: {}, onFinished: onDone)
            } else {
                BirthdayCakeReceipt(emoji: "🎂", fromName: "them", onRevealed: {}, onFinished: onDone)
            }
        } else {
            instrumentReceipt
        }
    }

    @ViewBuilder private var instrumentReceipt: some View {
        if def.version == "V2" {
            switch def.style {
            case .bowArrow:    BowReceiptAnimationV2(senderBearing: 120, emoji: emoji, fromName: "",
                                                     onRevealed: {}, onFinished: onDone)
            case .fingerFlick: FlickReceiptAnimationV2(senderBearing: 120, emoji: emoji, fromName: "",
                                                       onRevealed: {}, onFinished: onDone)
            case .plane:       PlaneReceiptAnimationV2(senderBearing: 120, emoji: emoji, fromName: "",
                                                       onRevealed: {}, onFinished: onDone)
            default:           EmptyView()
            }
        } else if def.style == .plane {
            PlaneReceiptAnimation(senderBearing: 120, emoji: emoji, fromName: "",
                                  onRevealed: {}, onFinished: onDone)
        } else if def.style == .firefly {
            WindReceiptAnimation(senderBearing: 120, emoji: emoji, fromName: "",
                                 onRevealed: {}, onFinished: onDone)
        } else if def.style == .rocket {
            RocketReceiptAnimation(senderBearing: 120, emoji: emoji, fromName: "",
                                   onRevealed: {}, onFinished: onDone)
        } else {
            // bow V1 / flick V1 / wand V1 / compass — the landing beat (no reveal).
            InstrumentLandingView(style: def.style, emoji: emoji) { onDone() }
        }
    }

    // ── REVEAL ───────────────────────────────────────────────────────────────

    private var revealStage: some View {
        EmojiRevealView(emoji: emoji, message: nil, tagline: nil,
                        context: .received(fromName: "them"),
                        ambient: RevealAmbient.forStyle(def.style),
                        onDismiss: onDone)
    }
}

// MARK: - Full workflow runner

/// Plays a definition's stages start-to-finish — Compass → Send →
/// [interstitial] → Receipt → Reveal — advancing as each stage completes. The
/// interstitial is a brief transition, not a stage. A per-stage safety dwell
/// auto-advances if a stage's completion callback never fires (and lets the
/// interactive compass face advance on its own after a beat).
private struct AnimationWorkflowRunner: View {
    let def: AnimationDefinition
    let emoji: String
    let onDone: () -> Void

    @State private var index = 0
    @State private var interstitial = false

    /// Canonical-order stages this workflow plays. If the receipt carries its
    /// own reveal, the trailing Reveal is dropped (no double reveal).
    private var stages: [AnimationStage] {
        var s: [AnimationStage] = [.compass, .send, .receipt, .reveal].filter { def.provides($0) }
        if s.contains(.receipt) && AnimationStageView.receiptAutoReveals(def) {
            s.removeAll { $0 == .reveal }
        }
        return s
    }

    var body: some View {
        ZStack {
            if index < stages.count {
                AnimationStageView(def: def, stage: stages[index], emoji: emoji, onDone: advance)
                    .id(index)
            }
            if interstitial {
                VStack(spacing: 8) {
                    Text("sent…")
                        .font(.system(size: 24, design: .serif).italic())
                        .foregroundColor(.white.opacity(0.85))
                    Text("arriving ✦")
                        .font(.system(size: 16, design: .serif).italic())
                        .foregroundColor(Color(hex: "#c4a8d4"))
                }
                .transition(.opacity)
            }
        }
        .onAppear { scheduleDwell(for: index) }
    }

    private func advance() {
        guard index < stages.count else { onDone(); return }
        let current = stages[index]
        let next = index + 1
        // Interstitial transition only between SEND and RECEIPT.
        if current == .send && next < stages.count && stages[next] == .receipt {
            withAnimation(.easeInOut(duration: 0.3)) { interstitial = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeInOut(duration: 0.3)) { interstitial = false }
                step(to: next)
            }
        } else {
            step(to: next)
        }
    }

    private func step(to next: Int) {
        if next >= stages.count {
            onDone()
        } else {
            index = next
            scheduleDwell(for: next)
        }
    }

    /// Safety / pacing dwell: auto-advances a stage if its callback is missed,
    /// and gives the interactive compass face a beat before moving on.
    private func scheduleDwell(for i: Int) {
        guard i < stages.count else { return }
        let timeout: Double
        switch stages[i] {
        case .compass: timeout = 3.5
        case .send:    timeout = 8.0
        case .receipt: timeout = 9.0
        case .reveal:  timeout = 8.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            if index == i && !interstitial { advance() }
        }
    }
}

// MARK: - Animation feedback store

/// A developer's verdict on a single animation.
enum AnimationVerdict: String {
    case approved
    case needsWork

    var symbol: String { self == .approved ? "✅" : "✏️" }
    var label:  String { self == .approved ? "approved" : "needs work" }
}

/// DEBUG-only persistence for animation ratings made in the Animation Test Lab.
/// Keyed by "<senderStyle>-<send|land>[-<version>]" in UserDefaults.
enum AnimationFeedbackStore {

    private static let defaultsKey = "animationFeedbackVerdicts"

    static func key(style: SenderStyle, isSend: Bool, version: String? = nil) -> String {
        let base = "\(style.rawValue)-\(isSend ? "send" : "land")"
        return version.map { "\(base)-\($0)" } ?? base
    }

    static func all() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: String] ?? [:]
    }

    static func verdict(for key: String) -> AnimationVerdict? {
        all()[key].flatMap(AnimationVerdict.init)
    }

    static func set(_ verdict: AnimationVerdict, for key: String) {
        var dict = all()
        dict[key] = verdict.rawValue
        UserDefaults.standard.set(dict, forKey: defaultsKey)
    }

    static func clearAll() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}

// MARK: - Animation feedback summary

/// A read-only summary of every animation's verdict, grouped by send and land.
/// Reads its instrument list from AnimationManifest so it can't drift.
struct AnimationFeedbackView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var verdicts = AnimationFeedbackStore.all()

    private let entries: [AnimationDefinition] = AnimationManifest.instruments

    private static let lavender = Color(hex: "#c4a8d4")

    private var approvedCount: Int {
        verdicts.values.filter { $0 == AnimationVerdict.approved.rawValue }.count
    }
    private var needsWorkCount: Int {
        verdicts.values.filter { $0 == AnimationVerdict.needsWork.rawValue }.count
    }
    private var totalSlots: Int { entries.count * 2 }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.Color.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        summaryHeader
                        section("send animations", isSend: true)
                        section("receive animations", isSend: false)
                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 20).padding(.top, 12)
                }
            }
            .navigationTitle("Animation Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("done") { dismiss() }.foregroundColor(Self.lavender)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("reset") {
                        AnimationFeedbackStore.clearAll()
                        verdicts = [:]
                    }
                    .foregroundColor(DesignTokens.Color.textMuted)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(approvedCount) approved · \(needsWorkCount) need work · "
                 + "\(max(0, totalSlots - approvedCount - needsWorkCount)) unrated")
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundColor(DesignTokens.Color.textPrimary)
            Text("rate animations in the Animation Test Lab")
                .font(.system(size: 12, design: .serif).italic())
                .foregroundColor(DesignTokens.Color.textMuted)
        }
    }

    private func section(_ title: String, isSend: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(DesignTokens.Font.overline)
                .foregroundColor(DesignTokens.Color.textMuted)
            VStack(spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { idx, entry in
                    let key = AnimationFeedbackStore.key(style: entry.style, isSend: isSend, version: entry.version)
                    let verdict = verdicts[key].flatMap(AnimationVerdict.init)
                    if idx > 0 {
                        Divider().background(DesignTokens.Color.border).padding(.leading, 44)
                    }
                    HStack(spacing: 12) {
                        Text(entry.icon).font(.system(size: 20)).frame(width: 28)
                        Text(entry.displayName)
                            .font(DesignTokens.Font.label)
                            .foregroundColor(DesignTokens.Color.textPrimary)
                        Spacer()
                        verdictTag(verdict)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, 12)
                }
            }
            .background(DesignTokens.Color.backgroundCard)
            .cornerRadius(DesignTokens.Radius.card)
            .overlay(RoundedRectangle(cornerRadius: DesignTokens.Radius.card)
                .stroke(DesignTokens.Color.border, lineWidth: 1))
        }
    }

    @ViewBuilder
    private func verdictTag(_ verdict: AnimationVerdict?) -> some View {
        if let verdict {
            let tint = verdict == .approved ? Color(hex: "#5dcaa5") : Color(hex: "#e0a85a")
            Text("\(verdict.symbol) \(verdict.label)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(tint)
        } else {
            Text("— not rated")
                .font(.system(size: 12))
                .foregroundColor(DesignTokens.Color.textDim)
        }
    }
}
#endif
