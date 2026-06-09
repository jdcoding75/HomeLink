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
            DesignTokens.Color.background.ignoresSafeArea()

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
                Text("tap to dismiss")
                    .font(.system(size: 11, design: .serif).italic())
                    .foregroundColor(DesignTokens.Color.textDim)
                    .padding(.bottom, 30)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { playing = nil }
        .preferredColorScheme(.dark)
    }

    private func animationLabel(_ p: Playing) -> String {
        let name = entries.first { $0.style == p.style }?.name ?? p.style.displayName
        return "\(name) \(p.isSend ? "send" : "land")"
    }
}
#endif
