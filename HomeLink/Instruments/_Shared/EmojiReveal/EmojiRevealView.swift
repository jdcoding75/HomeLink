// EmojiRevealView.swift
// Pointward › Instruments › _Shared › EmojiReveal
//
// THE EMOJI REVEAL MOMENT
// Same for ALL instruments.
// Instrument delivers the thought.
// This view IS the emotional peak.
//
// STRUCTURE:
// Full screen #0d0d14 background
// Emoji blooms to 156pt centered
// Custom animation if emoji has one
// Message fades in below
// Tagline below message
// "from [Name] ✦" below tagline
// Lingers minimum 6 seconds
// Tap anywhere to dismiss
//
// EMOJI ANIMATIONS:
// 🤗 — bloom + arm squeeze x3
// All others — bloom + gentle breathing
// New emojis added here over time
//
// SOUND:
// EmojiRevealSound.play(emoji)
// Called at bloom moment only
// NEVER during instrument animation

import SwiftUI

struct EmojiRevealView: View {
    let emoji: String
    let message: String?
    let tagline: String?
    let fromName: String
    let onDismiss: () -> Void

    @State private var bloomed = false
    @State private var messageVisible = false
    @State private var taglineVisible = false
    @State private var fromVisible = false
    @State private var dismissVisible = false
    @State private var glowScale: CGFloat = 1.0
    @State private var hugOpen = false
    @State private var hugClose = false

    var body: some View {
        ZStack {
            Color(hex: "#0d0d14").ignoresSafeArea()

            // Soft glow behind emoji
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            glowColor.opacity(0.12),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 130
                    )
                )
                .frame(width: 260, height: 260)
                .scaleEffect(glowScale)

            VStack(spacing: 0) {
                Spacer()

                // Emoji — 156pt
                Text(emoji)
                    .font(.system(size: 156))
                    .scaleEffect(
                        x: hugOpen ? 1.45 :
                           hugClose ? 0.82 : 1.0,
                        y: hugOpen ? 0.75 :
                           hugClose ? 1.15 : 1.0
                    )
                    .scaleEffect(bloomed ? 1.0 : 0.8)
                    .animation(
                        .spring(response: 1.0,
                               dampingFraction: 0.6),
                        value: bloomed
                    )
                    .animation(
                        .easeInOut(duration: hugOpen ? 0.25 : 0.3),
                        value: hugOpen
                    )
                    .animation(
                        .easeInOut(duration: 0.3),
                        value: hugClose
                    )

                // Message
                if let msg = message, !msg.isEmpty {
                    Text(msg)
                        .font(.system(size: 20,
                                     design: .serif)
                             .italic())
                        .foregroundColor(
                            DesignTokens.Color.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 20)
                        .opacity(messageVisible ? 1 : 0)
                        .animation(.easeOut(duration: 0.5),
                                   value: messageVisible)
                }

                // Tagline
                if let tag = tagline, !tag.isEmpty {
                    Text(tag)
                        .font(.system(size: 14,
                                     design: .serif)
                             .italic())
                        .foregroundColor(
                            DesignTokens.Color.textSecondary)
                        .padding(.top, 8)
                        .opacity(taglineVisible ? 1 : 0)
                        .animation(.easeOut(duration: 0.5),
                                   value: taglineVisible)
                }

                // From name
                Text("from \(fromName) ✦")
                    .font(.system(size: 17,
                                 design: .serif)
                         .italic())
                    .foregroundColor(
                        Color(hex: "#c4a8d4").opacity(0.7))
                    .padding(.top, 10)
                    .opacity(fromVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.5),
                               value: fromVisible)

                Spacer()
            }

            // Dismiss hint
            VStack {
                Spacer()
                Text("tap anywhere to keep ✦")
                    .font(.system(size: 11).italic())
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.bottom, 30)
                    .opacity(dismissVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.4),
                               value: dismissVisible)
            }
        }
        .onTapGesture { onDismiss() }
        .onAppear { startReveal() }
    }

    private var glowColor: Color {
        switch emoji {
        case "🤗": return Color(hex: "#90EE90")
        case "😘": return Color(hex: "#FF69B4")
        case "🙌": return Color(hex: "#FFD700")
        case "👊": return Color(hex: "#FF6B35")
        case "🖐️": return Color(hex: "#c4a8d4")
        case "🫶": return Color(hex: "#FF69B4")
        default:   return Color(hex: "#c4a8d4")
        }
    }

    private func startReveal() {
        // Play emoji sound at bloom
        EmojiRevealSound.play(emoji)

        // Bloom emoji
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.1) {
            withAnimation { bloomed = true }
            // Glow breathe
            withAnimation(
                .easeInOut(duration: 3)
                .repeatForever(autoreverses: true)) {
                glowScale = 1.06
            }
        }

        // Heartbeat haptic at bloom
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.3) {
            HapticPattern.heartbeat.fire()
        }

        // Hug squeeze x3 — synced to sound pulses
        // Pulse 1: 0.35s, Pulse 2: 0.85s, Pulse 3: 1.35s
        if emoji == "🤗" {
            let delays: [Double] = [0.9, 1.5, 2.1]
            delays.forEach { delay in
                // Open arms
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + delay) {
                    withAnimation { hugOpen = true; hugClose = false }
                }
                // Close arms
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + delay + 0.25) {
                    withAnimation { hugOpen = false; hugClose = true }
                }
                // Settle
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + delay + 0.55) {
                    withAnimation { hugClose = false }
                }
            }
        }

        // Text sequence
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.6) {
            withAnimation { messageVisible = true }
        }
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.9) {
            withAnimation { taglineVisible = true }
        }
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 1.2) {
            withAnimation { fromVisible = true }
        }
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 1.8) {
            withAnimation { dismissVisible = true }
        }
    }
}
