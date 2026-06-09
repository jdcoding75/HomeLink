// HugRevealModifier.swift
// Pointward › Instruments › _Shared › EmojiReveal
//
// THE HUG SQUEEZE — the 🤗 emoji's signature reveal animation, factored out so
// any view can wear it (and future per-emoji animations can follow the same
// pattern). Three arm-squeezes synced to the heartbeat pulses in
// emoji_hug_v2.wav: open wide (stretch wide, squash short), close in (pull
// narrow, stretch tall), settle back to rest.
//
// Plus a small presentation helper — `.emojiReveal(...)` — so the full-screen
// EmojiRevealView can be attached as an overlay from anywhere.

import SwiftUI

// MARK: - Hug squeeze phases

/// One squeeze of a hug — the open/close/settle states the 🤗 emoji moves
/// through. Drives the asymmetric scale that reads as arms opening then
/// wrapping in.
enum HugSqueezePhase {
    case rest      // neutral
    case open      // arms wide — stretch wide, squash short
    case close     // arms in — pull narrow, stretch tall

    var scaleX: CGFloat {
        switch self {
        case .rest:  return 1.0
        case .open:  return 1.45
        case .close: return 0.82
        }
    }

    var scaleY: CGFloat {
        switch self {
        case .rest:  return 1.0
        case .open:  return 0.75
        case .close: return 1.15
        }
    }
}

/// Applies the hug squeeze scale to any content. The host drives `phase`
/// through open → close → rest on the reveal's heartbeat timing.
struct HugSqueeze: ViewModifier {
    var phase: HugSqueezePhase

    func body(content: Content) -> some View {
        content
            .scaleEffect(x: phase.scaleX, y: phase.scaleY)
            .animation(.easeInOut(duration: phase == .open ? 0.25 : 0.3),
                       value: phase)
    }
}

extension View {
    /// Wear the 🤗 hug squeeze at the given phase.
    func hugSqueeze(_ phase: HugSqueezePhase) -> some View {
        modifier(HugSqueeze(phase: phase))
    }
}

// MARK: - The squeeze timeline

enum HugReveal {
    /// The three squeeze start times, synced to the heartbeat pulses in
    /// emoji_hug_v2.wav (0.35s · 0.85s · 1.35s, offset for the bloom-in).
    static let squeezeDelays: [Double] = [0.9, 1.5, 2.1]
    static let openHold:   Double = 0.25   // open → close
    static let settleHold: Double = 0.55   // close → rest (from the squeeze start)

    /// Fire the three-squeeze sequence, calling `set(phase)` at each beat.
    /// Used by hosts that drive the squeeze through a HugSqueezePhase rather
    /// than the boolean flags inside EmojiRevealView.
    static func runSqueezes(_ set: @escaping (HugSqueezePhase) -> Void) {
        for delay in squeezeDelays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation { set(.open) }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + openHold) {
                withAnimation { set(.close) }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + settleHold) {
                withAnimation { set(.rest) }
            }
        }
    }
}

// MARK: - Presentation helper

/// The thought a reveal is showing.
struct EmojiRevealData: Identifiable, Equatable {
    let id = UUID()
    let emoji: String
    let message: String?
    let tagline: String?
    let fromName: String
    /// The instrument world behind the reveal (defaults to the plain compass
    /// background). The presenter builds the `.received` context from fromName.
    var ambient: RevealAmbient = .compass
}

private struct EmojiRevealPresenter: ViewModifier {
    @Binding var reveal: EmojiRevealData?

    func body(content: Content) -> some View {
        content.overlay {
            if let data = reveal {
                EmojiRevealView(
                    emoji: data.emoji,
                    message: data.message,
                    tagline: data.tagline,
                    context: .received(fromName: data.fromName),
                    ambient: data.ambient,
                    onDismiss: { reveal = nil }
                )
                .transition(.opacity)
                .zIndex(50)
            }
        }
    }
}

extension View {
    /// Present the full-screen emoji reveal as an overlay; clearing the binding
    /// (or tapping the reveal) dismisses it.
    func emojiReveal(_ reveal: Binding<EmojiRevealData?>) -> some View {
        modifier(EmojiRevealPresenter(reveal: reveal))
    }
}
