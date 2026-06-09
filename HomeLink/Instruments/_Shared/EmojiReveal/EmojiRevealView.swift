// EmojiRevealView.swift
// Pointward › Instruments › _Shared › EmojiReveal
//
// THE SINGLE REVEAL SCREEN
// Used for BOTH sent confirmation
// AND received reveal.
// Context determines copy.
// Ambient determines background feel.
// Emoji determines animation + sound.
//
// THERE IS NO OTHER REVEAL SCREEN.
// Do not create a separate sent screen.
// Do not create a separate received screen.
// This is the only one. Ever.

import SwiftUI

struct EmojiRevealView: View {
  let emoji: String
  let message: String?
  let tagline: String?
  let context: RevealContext
  let ambient: RevealAmbient
  let onDismiss: () -> Void

  @State private var bloomed = false
  @State private var messageVisible = false
  @State private var taglineVisible = false
  @State private var contextVisible = false
  @State private var dismissVisible = false
  @State private var glowScale: CGFloat = 1.0
  @State private var hugOpen = false
  @State private var hugClose = false

  var body: some View {
    ZStack {
      // Instrument background
      ambient.background

      // Instrument ambient layer
      // (clouds, stars, sparkles etc)
      ambient.ambientLayer

      // Soft glow behind emoji
      Circle()
        .fill(
          RadialGradient(
            colors: [
              glowColor.opacity(0.15),
              Color.clear
            ],
            center: .center,
            startRadius: 0,
            endRadius: 140
          )
        )
        .frame(width: 280, height: 280)
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
            .easeInOut(duration:
              hugOpen ? 0.25 : 0.3),
            value: hugOpen
          )
          .animation(
            .easeInOut(duration: 0.3),
            value: hugClose
          )

        // Message — what was sent
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

        // Context line — sent to / from
        Text(context.headlineText)
          .font(.system(size: 17,
                       design: .serif)
               .italic())
          .foregroundColor(
            Color(hex: "#c4a8d4").opacity(0.75))
          .padding(.top, 10)
          .opacity(contextVisible ? 1 : 0)
          .animation(.easeOut(duration: 0.5),
                     value: contextVisible)

        // Sent subtext if applicable
        if !context.subText.isEmpty {
          Text(context.subText)
            .font(.system(size: 13,
                         design: .serif)
                 .italic())
            .foregroundColor(
              DesignTokens.Color.textMuted)
            .padding(.top, 6)
            .opacity(contextVisible ? 1 : 0)
            .animation(.easeOut(duration: 0.5),
                       value: contextVisible)
        }

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
    // Sound at bloom
    EmojiRevealSound.play(emoji)

    // Bloom
    DispatchQueue.main.asyncAfter(
      deadline: .now() + 0.1) {
      withAnimation { bloomed = true }
      withAnimation(
        .easeInOut(duration: 3)
        .repeatForever(autoreverses: true)) {
        glowScale = 1.06
      }
    }

    // Haptic
    DispatchQueue.main.asyncAfter(
      deadline: .now() + 0.3) {
      HapticPattern.heartbeat.fire()
    }

    // Hug squeeze x3 for 🤗
    if emoji == "🤗" {
      [0.9, 1.5, 2.1].forEach { delay in
        DispatchQueue.main.asyncAfter(
          deadline: .now() + delay) {
          withAnimation {
            hugOpen = true
            hugClose = false
          }
        }
        DispatchQueue.main.asyncAfter(
          deadline: .now() + delay + 0.25) {
          withAnimation {
            hugOpen = false
            hugClose = true
          }
        }
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
      withAnimation { contextVisible = true }
    }
    DispatchQueue.main.asyncAfter(
      deadline: .now() + 1.8) {
      withAnimation { dismissVisible = true }
    }

    // Auto dismiss after 6s
    DispatchQueue.main.asyncAfter(
      deadline: .now() + 6.0) {
      onDismiss()
    }
  }
}
