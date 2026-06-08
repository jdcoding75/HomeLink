// TestMessageSheet.swift
// Pointward › Views
//
// DEBUG ONLY — send yourself a test thought without a second phone or network.
// Tapping send creates a ReceivedPing locally and triggers the FULL receipt
// experience (catch mode, landing animation, bucket fill, replay).

#if DEBUG
import SwiftUI

struct TestMessageSheet: View {

    @EnvironmentObject var pings: PingManager
    @Environment(\.dismiss) private var dismiss

    @State private var style: SenderStyle = .rocket
    @State private var emoji = "💜"
    @State private var message = "test message"
    @State private var tagline = "near is a feeling ✦"
    @State private var fromName = "Test Sarah"

    /// The seven instruments, by their wire SenderStyle.
    private let instruments: [(icon: String, label: String, style: SenderStyle)] = [
        ("🧭", "compass", .glow),
        ("🏹", "bow",     .bowArrow),
        ("👆", "flick",   .fingerFlick),
        ("🚀", "rocket",  .rocket),
        ("🌬️", "wind",    .firefly),
        ("🪄", "wand",    .wand),
        ("✈️", "plane",   .plane),
    ]
    private let testEmojis = ["💜","❤️","🔥","✨","🌟","😂","🥹","🙏","☕️","🌙","🎉","👋"]

    private static let lavender = Color(hex: "#c4a8d4")

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.Color.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        quickSendRow
                        instrumentPicker
                        emojiPicker
                        fields
                        sendButton
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Test a thought")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("close") { dismiss() }.foregroundColor(Self.lavender)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // ── Quick send — one tap, default 💜, no config ──────────────────────
    private var quickSendRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("quick send · default 💜")
                .font(.system(size: 12, design: .serif).italic())
                .foregroundColor(DesignTokens.Color.textMuted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(instruments, id: \.label) { inst in
                        Button {
                            fire(style: inst.style, emoji: "💜", message: nil)
                        } label: {
                            VStack(spacing: 3) {
                                Text(inst.icon).font(.system(size: 22))
                                Text(inst.label).font(.system(size: 9))
                                    .foregroundColor(DesignTokens.Color.textMuted)
                            }
                            .frame(width: 58, height: 58)
                            .background(DesignTokens.Color.backgroundCard)
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .stroke(DesignTokens.Color.borderMid, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var instrumentPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("instrument").font(.system(size: 12)).foregroundColor(DesignTokens.Color.textMuted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(instruments, id: \.label) { inst in
                        Button { style = inst.style } label: {
                            Text("\(inst.icon) \(inst.label)")
                                .font(.system(size: 13))
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(style == inst.style ? Self.lavender.opacity(0.3) : DesignTokens.Color.backgroundCard)
                                .foregroundColor(style == inst.style ? Self.lavender : DesignTokens.Color.textPrimary)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12)
                                    .stroke(style == inst.style ? Self.lavender : DesignTokens.Color.borderMid, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var emojiPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("emoji").font(.system(size: 12)).foregroundColor(DesignTokens.Color.textMuted)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                ForEach(testEmojis, id: \.self) { e in
                    Button { emoji = e } label: {
                        Text(e).font(.system(size: 26))
                            .frame(width: 42, height: 42)
                            .background(emoji == e ? Self.lavender.opacity(0.3) : Color.clear)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 12) {
            labeledField("message", text: $message)
            labeledField("tagline", text: $tagline)
            labeledField("from", text: $fromName)
        }
    }

    private func labeledField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 11)).foregroundColor(DesignTokens.Color.textMuted)
            TextField(label, text: text)
                .textFieldStyle(.plain)
                .padding(10)
                .background(DesignTokens.Color.backgroundCard)
                .cornerRadius(10)
                .foregroundColor(DesignTokens.Color.textPrimary)
        }
    }

    private var sendButton: some View {
        Button {
            fire(style: style, emoji: emoji, message: message)
        } label: {
            Text("send \(emoji) to myself")
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Self.lavender.opacity(0.9))
                .foregroundColor(.black)
                .cornerRadius(14)
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    /// Dismiss first so the full receipt plays over the compass, then fire.
    private func fire(style: SenderStyle, emoji: String, message: String?) {
        let snapshotTagline = tagline, snapshotFrom = fromName
        dismiss()
        NotificationCenter.default.post(name: .pointwardOpenCompass, object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            DevTools.sendTestThought(pings: pings, style: style, emoji: emoji,
                                     message: message, tagline: snapshotTagline,
                                     fromName: snapshotFrom)
        }
    }
}
#endif
