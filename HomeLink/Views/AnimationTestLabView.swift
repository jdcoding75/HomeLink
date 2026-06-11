// AnimationTestLabView.swift
// Pointward › Views
//
// [1/3] THE ANIMATION TEST LAB — DEBUG ONLY. A dedicated space to fire every
// animation in isolation, with no thought queue, no pairing, no compass: just
// the pure send and land animations on demand.
//
//   SEND ANIMATIONS     compass · bow (V1/V2) · flick (V1/V2) · rocket · wind ·
//                       wand · plane (V1/V2)
//   RECEIVE ANIMATIONS  compass · bow (V1/V2) · flick (V1/V2) · rocket · wind ·
//                       wand · plane (V1/V2)
//
// V1 is the live/active animation (the shared dispatcher path: SenderAnimationView
// for sends, InstrumentLandingView for lands). V2 is today's extracted full-screen
// ACT struct (…SendAnimationV2 / …ReceiptAnimationV2), shown here ONLY for
// comparison — it is NOT wired into the live app until explicitly promoted.
//
// Tapping a tile plays that animation full-screen over a clean backdrop; it
// auto-dismisses when the animation completes, or tap anywhere to dismiss.
// Each run uses a random test emoji so the hue-driven glows vary.

#if DEBUG
import SwiftUI

struct AnimationTestLabView: View {

    @Environment(\.dismiss) private var dismiss

    /// One catalogued animation: an instrument personality, optionally versioned.
    struct LabEntry: Identifiable {
        let icon: String
        let name: String
        let style: SenderStyle
        let version: String?     // nil = single · "V1" = active inline · "V2" = extracted ACT
        var id: String { "\(name)-\(version ?? "single")" }
        /// "Bow V2" · "Wand V1" · "Compass"
        var displayName: String { version.map { "\(name) \($0)" } ?? name }
    }

    /// One animation playing full screen — send or land, an entry, an emoji.
    private struct Playing: Identifiable {
        let id = UUID()
        let isSend: Bool
        let entry: LabEntry
        let emoji: String
        var style: SenderStyle { entry.style }
        var isV2: Bool { entry.version == "V2" }
        var isBirthday: Bool { entry.name == "Birthday Cake" }
    }
    @State private var playing: Playing?

    // The 🧭🏹👆🚀🌬️🪄✈️ lineup. Bow/Flick/Plane carry both V1 (active inline) and
    // V2 (today's extracted full-screen redesign) so the two can be compared.
    private let entries: [LabEntry] = [
        LabEntry(icon: "🧭", name: "Compass", style: .glow,        version: nil),
        // [bow] V1 RETIRED — bow is V2-only live now; the V1 entry is removed
        // from the lab (files kept, unreferenced). See Phase 2 version decision.
        // LabEntry(icon: "🏹", name: "Bow",     style: .bowArrow,    version: "V1"),
        LabEntry(icon: "🏹", name: "Bow",     style: .bowArrow,    version: "V2"),
        LabEntry(icon: "👆", name: "Flick",   style: .fingerFlick, version: "V1"),
        LabEntry(icon: "👆", name: "Flick",   style: .fingerFlick, version: "V2"),
        // [rocket] BOTH landings kept: V1 = legs (InstrumentLandingView), V2 =
        // parachute (RocketReceiptAnimation, the live receipt). Send is shared.
        LabEntry(icon: "🚀", name: "Rocket",  style: .rocket,      version: "V1"),
        LabEntry(icon: "🚀", name: "Rocket",  style: .rocket,      version: "V2"),
        LabEntry(icon: "🌬️", name: "Wind",    style: .firefly,     version: nil),
        LabEntry(icon: "🪄", name: "Wand",    style: .wand,        version: "V1"),
        LabEntry(icon: "✈️", name: "Plane",   style: .plane,       version: "V1"),
        LabEntry(icon: "✈️", name: "Plane",   style: .plane,       version: "V2"),
        LabEntry(icon: "🎂", name: "Birthday Cake", style: .glow,  version: nil),
        LabEntry(icon: "🎆", name: "Firework Send",    style: .glow, version: nil),
        LabEntry(icon: "🎆", name: "Firework Receipt", style: .glow, version: nil),
        LabEntry(icon: "🎆", name: "Firework Compass", style: .glow, version: nil),
        LabEntry(icon: "🎂", name: "Birthday Send",    style: .glow, version: nil),
        LabEntry(icon: "🎂", name: "Birthday Receipt", style: .glow, version: nil),
        LabEntry(icon: "🎂", name: "Birthday Compass", style: .glow, version: nil),
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
                            ForEach(entries) { entry in
                                tile(entry, isSend: true)
                            }
                        }

                        sectionHeader("receive animations")
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(entries) { entry in
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

    private func tile(_ entry: LabEntry, isSend: Bool) -> some View {
        Button {
            let emoji = entry.name.hasPrefix("Birthday") ? "🎂"
                      : (entry.name.hasPrefix("Firework") ? "🎆" : randomEmoji)
            playing = Playing(isSend: isSend, entry: entry, emoji: emoji)
        } label: {
            VStack(spacing: 8) {
                Text(entry.icon)
                    .font(.system(size: 34))
                Text("\(entry.displayName) \(isSend ? "Send" : "Land")")
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
                    .stroke(tileStroke(entry: entry, isSend: isSend), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    /// V2 tiles get a gold edge so they read as the experimental version.
    private func tileStroke(entry: LabEntry, isSend: Bool) -> Color {
        if entry.version == "V2" { return Color(hex: "#e0a85a").opacity(0.55) }
        return isSend ? Self.lavender.opacity(0.4) : Color(hex: "#5dcaa5").opacity(0.4)
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
                sendPlayer(p)
            } else {
                landPlayer(p)
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

    // ── 🎆 Firework — three named previews (send · receipt · compass) ───────

    @ViewBuilder
    private func fireworkPlayer(_ p: Playing) -> some View {
        switch p.entry.name {
        case "Firework Compass":
            FireworkCompassFace(personName: "them",
                                onSend: { autoDismiss(p, after: 0.3) })
        case "Firework Receipt":
            FireworkReceipt(emoji: "🎆", fromName: "them",
                            onRevealed: {}, onFinished: { autoDismiss(p, after: 0.1) })
        default: // "Firework Send"
            FireworkSendAnimation(emoji: "🎆",
                                  onComplete: { autoDismiss(p, after: 0.3) })
        }
    }

    /// 🎂 Birthday Cake V2 — three named previews (send · receipt · compass).
    private var birthdayV2Names: Set<String> { ["Birthday Send", "Birthday Receipt", "Birthday Compass"] }

    @ViewBuilder
    private func birthdayV2Player(_ p: Playing) -> some View {
        switch p.entry.name {
        case "Birthday Compass":
            BirthdayCakeCompassFaceV2(personName: "them",
                                      onSend: { autoDismiss(p, after: 0.3) })
        case "Birthday Receipt":
            BirthdayCakeReceiptV2(emoji: "🎂", fromName: "them",
                                  onRevealed: {}, onFinished: { autoDismiss(p, after: 0.1) })
        default: // "Birthday Send"
            BirthdayCakeSendAnimationV2(emoji: "🎂",
                                        onComplete: { autoDismiss(p, after: 0.3) })
        }
    }

    // ── Send: V1 = shared SenderAnimationView · V2 = extracted ACT struct ──

    @ViewBuilder
    private func sendPlayer(_ p: Playing) -> some View {
        if p.entry.name.hasPrefix("Firework") {
            fireworkPlayer(p)
        } else if birthdayV2Names.contains(p.entry.name) {
            birthdayV2Player(p)
        } else if p.isBirthday {
            // 🎂 — the special tap-the-candles compass-face send mechanic.
            BirthdayCakeCompassFace(personName: "them",
                                    onSend: { autoDismiss(p, after: 0.3) })
        } else if p.style == .rocket {
            // Rocket send is shared (one launch) — both V1 (legs) and V2
            // (parachute) tiles fire the same SenderAnimationView blast off.
            SenderAnimationView(style: .rocket, emoji: p.emoji, bearingDegrees: 0,
                                symbol: Text(p.emoji).font(.system(size: 45))) {
                autoDismiss(p, after: 0.3)
            }
        } else if p.isV2 {
            let t = InstrumentTransition(exitBearing: 0, exitPoint: .zero,
                                         instrument: instrumentKind(p.style),
                                         emoji: p.emoji, message: nil, tagline: nil)
            switch p.style {
            case .bowArrow:    BowSendAnimationV2(transition: t, personName: "them",
                                                  onComplete: { autoDismiss(p, after: 0.1) })
            case .fingerFlick: FlickSendAnimationV2(transition: t, personName: "them",
                                                    onComplete: { autoDismiss(p, after: 0.1) })
            case .plane:       PlaneSendAnimationV2(transition: t, personName: "them",
                                                    onComplete: { autoDismiss(p, after: 0.1) })
            default:           EmptyView()
            }
        } else if p.style == .plane {
            // Plane V1 send = the dedicated full-screen PlaneSendAnimation (NE flight).
            let t = InstrumentTransition(exitBearing: 0, exitPoint: .zero,
                                         instrument: .plane,
                                         emoji: p.emoji, message: nil, tagline: nil)
            PlaneSendAnimation(transition: t, personName: "them",
                               onComplete: { autoDismiss(p, after: 0.1) })
        } else {
            // Straight up (bearing 0) so the flight is centred and visible.
            SenderAnimationView(
                style: p.style,
                emoji: p.emoji,
                bearingDegrees: 0,
                symbol: Text(p.emoji).font(.system(size: 45))
            ) {
                autoDismiss(p, after: 0.3)
            }
        }
    }

    // ── Land: V1 = shared InstrumentLandingView · V2 = extracted ACT struct ─

    @ViewBuilder
    private func landPlayer(_ p: Playing) -> some View {
        if p.entry.name.hasPrefix("Firework") {
            fireworkPlayer(p)
        } else if birthdayV2Names.contains(p.entry.name) {
            birthdayV2Player(p)
        } else if p.isBirthday {
            // 🎂 — the special cake receipt (smoke wisps, no bucket).
            BirthdayCakeReceipt(emoji: "🎂", fromName: "them",
                                onRevealed: {}, onFinished: { autoDismiss(p, after: 0.1) })
        } else if p.isV2 {
            switch p.style {
            case .bowArrow:    BowReceiptAnimationV2(senderBearing: 120, emoji: p.emoji,
                                                     message: nil, tagline: nil, fromName: "",
                                                     onRevealed: {}, onFinished: { autoDismiss(p, after: 0.1) })
            case .fingerFlick: FlickReceiptAnimationV2(senderBearing: 120, emoji: p.emoji,
                                                       message: nil, tagline: nil, fromName: "",
                                                       onRevealed: {}, onFinished: { autoDismiss(p, after: 0.1) })
            case .plane:       PlaneReceiptAnimationV2(senderBearing: 120, emoji: p.emoji,
                                                       message: nil, tagline: nil, fromName: "",
                                                       onRevealed: {}, onFinished: { autoDismiss(p, after: 0.1) })
            case .rocket:      RocketReceiptAnimation(senderBearing: 120, emoji: p.emoji,
                                                      message: nil, tagline: nil, fromName: "",
                                                      onRevealed: {}, onFinished: { autoDismiss(p, after: 0.1) })
            default:           EmptyView()
            }
        } else if p.style == .plane {
            // Plane V1 receipt = the dedicated "coming-at-you" PlaneReceiptAnimation.
            PlaneReceiptAnimation(senderBearing: 120, emoji: p.emoji,
                                  message: nil, tagline: nil, fromName: "",
                                  onRevealed: {}, onFinished: { autoDismiss(p, after: 0.1) })
        } else {
            InstrumentLandingView(style: p.style, emoji: p.emoji) {
                // Let the emerged emoji breathe, then dismiss.
                autoDismiss(p, after: 1.4)
            }
        }
    }

    private func autoDismiss(_ p: Playing, after: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + after) {
            if playing?.id == p.id { playing = nil }
        }
    }

    /// SenderStyle → Instrument kind, for the V2 ACT structs' transition context.
    private func instrumentKind(_ style: SenderStyle) -> Instrument {
        switch style {
        case .bowArrow:     return .bow
        case .fingerFlick:  return .flick
        case .plane:        return .plane
        case .rocket:       return .rocket
        case .wand:         return .wand
        case .firefly:      return .wind
        default:            return .compass
        }
    }

    /// ✅ approved / ✏️ needs work — records the verdict for this exact
    /// animation (style + send/land + version), then dismisses.
    private func verdictButtons(for p: Playing) -> some View {
        let key = AnimationFeedbackStore.key(style: p.style, isSend: p.isSend, version: p.entry.version)
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
        "\(p.entry.displayName) \(p.isSend ? "send" : "land")"
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
/// Lab. Keyed by "<senderStyle>-<send|land>[-<version>]" and stored in
/// UserDefaults so the "📋 View animation feedback" summary survives relaunches.
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

// MARK: - [2/6] Animation feedback summary

/// A read-only summary of every animation's verdict — approved / needs work /
/// not yet rated — grouped by send and land. Reached from Developer Tools.
struct AnimationFeedbackView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var verdicts = AnimationFeedbackStore.all()

    private let entries: [AnimationTestLabView.LabEntry] = [
        .init(icon: "🧭", name: "Compass", style: .glow,        version: nil),
        // [bow] V1 retired (see main lab list).
        // .init(icon: "🏹", name: "Bow",     style: .bowArrow,    version: "V1"),
        .init(icon: "🏹", name: "Bow",     style: .bowArrow,    version: "V2"),
        .init(icon: "👆", name: "Flick",   style: .fingerFlick, version: "V1"),
        .init(icon: "👆", name: "Flick",   style: .fingerFlick, version: "V2"),
        .init(icon: "🚀", name: "Rocket",  style: .rocket,      version: "V1"),
        .init(icon: "🚀", name: "Rocket",  style: .rocket,      version: "V2"),
        .init(icon: "🌬️", name: "Wind",    style: .firefly,     version: nil),
        .init(icon: "🪄", name: "Wand",    style: .wand,        version: "V1"),
        .init(icon: "✈️", name: "Plane",   style: .plane,       version: "V1"),
        .init(icon: "✈️", name: "Plane",   style: .plane,       version: "V2"),
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
