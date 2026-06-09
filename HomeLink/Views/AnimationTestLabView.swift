// AnimationTestLabView.swift
// Pointward › Views
//
// [1/3] THE ANIMATION TEST LAB — DEBUG ONLY. A dedicated space to fire every
// animation in isolation, with no thought queue, no pairing, no compass: just
// the pure send and land animations on demand.
//
//   SEND ANIMATIONS     compass · bow · flick · rocket · wind · wand · plane
//   RECEIVE ANIMATIONS  compass · bow · flick · rocket · wind · wand · plane
//
// Tapping a tile plays that animation full-screen over a clean backdrop; it
// auto-dismisses when the animation completes, or tap anywhere to dismiss.
// Each run uses a random test emoji so the hue-driven glows vary.

#if DEBUG
import SwiftUI

struct AnimationTestLabView: View {

    @Environment(\.dismiss) private var dismiss

    /// One animation playing full screen — send or land, a style, an emoji.
    private struct Playing: Identifiable {
        let id = UUID()
        let isSend: Bool
        let style: SenderStyle
        let emoji: String
    }
    @State private var playing: Playing?

    // The 🧭🏹👆🚀🌬️🪄✈️ lineup, in the user-facing order. Both sends and
    // lands route through SenderStyle (the animation personality).
    private let entries: [(icon: String, name: String, style: SenderStyle)] = [
        ("🧭", "Compass", .glow),
        ("🏹", "Bow",     .bowArrow),
        ("👆", "Flick",   .fingerFlick),
        ("🚀", "Rocket",  .rocket),
        ("🌬️", "Wind",    .firefly),
        ("🪄", "Wand",    .wand),
        ("✈️", "Plane",   .plane),
    ]

    private let columns = [GridItem(.flexible(), spacing: 12),
                           GridItem(.flexible(), spacing: 12)]

    private static let lavender = Color(hex: "#c4a8d4")

    private var randomEmoji: String {
        DevTools.testEmojis.randomElement() ?? "💜"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.Color.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        sectionHeader("send animations")
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(entries, id: \.style) { entry in
                                tile(entry, isSend: true)
                            }
                        }

                        sectionHeader("receive animations")
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(entries, id: \.style) { entry in
                                tile(entry, isSend: false)
                            }
                        }

                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
            }
            .navigationTitle("Animation Test Lab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("done") { dismiss() }
                        .foregroundColor(Self.lavender)
                }
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(item: $playing) { p in
            playerOverlay(p)
        }
    }

    // ── A single animation tile ───────────────────────────────────────────

    private func tile(_ entry: (icon: String, name: String, style: SenderStyle),
                      isSend: Bool) -> some View {
        Button {
            playing = Playing(isSend: isSend, style: entry.style, emoji: randomEmoji)
        } label: {
            VStack(spacing: 8) {
                Text(entry.icon)
                    .font(.system(size: 34))
                Text("\(entry.name) \(isSend ? "Send" : "Land")")
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .foregroundColor(DesignTokens.Color.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(DesignTokens.Color.backgroundCard)
            .cornerRadius(DesignTokens.Radius.card)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.card)
                    .stroke(isSend ? Self.lavender.opacity(0.4)
                                   : Color(hex: "#5dcaa5").opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(DesignTokens.Font.overline)
            .foregroundColor(DesignTokens.Color.textMuted)
    }

    // ── The full-screen player ────────────────────────────────────────────

    @ViewBuilder
    private func playerOverlay(_ p: Playing) -> some View {
        ZStack {
            // [2/8] The same themed world the real app shows, so the test lab
            // looks identical — deep space for rocket, sky for wind/plane, cork
            // for flick, archery range for bow, magic for wand, purple glow for
            // compass. Shown for BOTH send and receive.
            DesignTokens.Color.background.ignoresSafeArea()
            CatchWorldBackground(style: p.style).ignoresSafeArea()

            if p.isSend {
                // Straight up (bearing 0) so the flight is centred and visible.
                SenderAnimationView(
                    style: p.style,
                    emoji: p.emoji,
                    bearingDegrees: 0,
                    symbol: Text(p.emoji).font(.system(size: 45))
                ) {
                    // Auto-dismiss a beat after the send completes.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if playing?.id == p.id { playing = nil }
                    }
                }
            } else {
                InstrumentLandingView(style: p.style, emoji: p.emoji) {
                    // Let the emerged emoji breathe, then dismiss.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                        if playing?.id == p.id { playing = nil }
                    }
                }
            }

            // Tap-anywhere-to-dismiss + a quiet hint. Topmost so it always
            // catches the tap regardless of what the animation does.
            VStack {
                HStack {
                    Spacer()
                    Text("\(p.emoji) \(animationLabel(p))")
                        .font(.system(size: 11, design: .serif).italic())
                        .foregroundColor(Self.lavender.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(DesignTokens.Color.background.opacity(0.7)))
                        .padding(.top, 50)
                        .padding(.trailing, 18)
                }
                Spacer()
                // [2/6] RATE THIS ANIMATION — the verdict feeds the "View
                // animation feedback" summary in Developer Tools. Tapping
                // either button records it and dismisses; the buttons capture
                // their own taps so they never trigger tap-to-dismiss.
                verdictButtons(for: p)
                Text("tap elsewhere to dismiss")
                    .font(.system(size: 11, design: .serif).italic())
                    .foregroundColor(DesignTokens.Color.textDim)
                    .padding(.bottom, 30)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { playing = nil }
        .preferredColorScheme(.dark)
    }

    /// ✅ approved / ✏️ needs work — records the verdict for this exact
    /// animation (style + send/land), then dismisses.
    private func verdictButtons(for p: Playing) -> some View {
        let key = AnimationFeedbackStore.key(style: p.style, isSend: p.isSend)
        let current = AnimationFeedbackStore.verdict(for: key)
        return HStack(spacing: 12) {
            verdictButton("✅ approved", tint: Color(hex: "#5dcaa5"),
                          isOn: current == .approved) {
                AnimationFeedbackStore.set(.approved, for: key)
                HapticEngine.saved()
                playing = nil
            }
            verdictButton("✏️ needs work", tint: Color(hex: "#e0a85a"),
                          isOn: current == .needsWork) {
                AnimationFeedbackStore.set(.needsWork, for: key)
                HapticEngine.saved()
                playing = nil
            }
        }
        .padding(.bottom, 10)
    }

    private func verdictButton(_ title: String, tint: Color, isOn: Bool,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isOn ? .black : tint)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(isOn ? tint : tint.opacity(0.14))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(tint, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func animationLabel(_ p: Playing) -> String {
        let name = entries.first { $0.style == p.style }?.name ?? p.style.displayName
        return "\(name) \(p.isSend ? "send" : "land")"
    }
}

// MARK: - [2/6] Animation feedback store

/// A developer's verdict on a single animation.
enum AnimationVerdict: String {
    case approved
    case needsWork

    var symbol: String { self == .approved ? "✅" : "✏️" }
    var label:  String { self == .approved ? "approved" : "needs work" }
}

/// DEBUG-only persistence for animation ratings made in the Animation Test
/// Lab. Keyed by "<senderStyle>-<send|land>" and stored in UserDefaults so the
/// "📋 View animation feedback" summary survives relaunches.
enum AnimationFeedbackStore {

    private static let defaultsKey = "animationFeedbackVerdicts"

    static func key(style: SenderStyle, isSend: Bool) -> String {
        "\(style.rawValue)-\(isSend ? "send" : "land")"
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

// MARK: - [2/6] Animation feedback summary

/// A read-only summary of every animation's verdict — approved / needs work /
/// not yet rated — grouped by send and land. Reached from Developer Tools.
struct AnimationFeedbackView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var verdicts = AnimationFeedbackStore.all()

    private let entries: [(icon: String, name: String, style: SenderStyle)] = [
        ("🧭", "Compass", .glow),
        ("🏹", "Bow",     .bowArrow),
        ("👆", "Flick",   .fingerFlick),
        ("🚀", "Rocket",  .rocket),
        ("🌬️", "Wind",    .firefly),
        ("🪄", "Wand",    .wand),
        ("✈️", "Plane",   .plane),
    ]

    private static let lavender = Color(hex: "#c4a8d4")

    private var approvedCount: Int {
        verdicts.values.filter { $0 == AnimationVerdict.approved.rawValue }.count
    }
    private var needsWorkCount: Int {
        verdicts.values.filter { $0 == AnimationVerdict.needsWork.rawValue }.count
    }
    private var totalSlots: Int { entries.count * 2 }   // send + land each

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
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
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
                 + "\(totalSlots - approvedCount - needsWorkCount) unrated")
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
                ForEach(Array(entries.enumerated()), id: \.element.style) { idx, entry in
                    let key = AnimationFeedbackStore.key(style: entry.style, isSend: isSend)
                    let verdict = verdicts[key].flatMap(AnimationVerdict.init)
                    if idx > 0 {
                        Divider().background(DesignTokens.Color.border).padding(.leading, 44)
                    }
                    HStack(spacing: 12) {
                        Text(entry.icon).font(.system(size: 20)).frame(width: 28)
                        Text(entry.name)
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
