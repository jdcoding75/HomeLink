// RevealAnimationRegistry.swift
// Pointward › Instruments › _Shared › EmojiReveal
//
// THE REGISTRY — replaces the per-emoji if/else in EmojiRevealView. Each emoji
// maps to a RevealAnimation describing its kind (which timed motion drives the
// reveal), its glow colour, and whether it travels full-screen.
//
// Adding a new emoji reveal = add ONE entry here + (optionally) a start<Kind>()
// in EmojiRevealView + a sound in EmojiRevealSound. Nothing else changes.

import SwiftUI

/// Which timed motion an emoji's reveal plays. EmojiRevealView switches on this.
enum RevealKind {
    case bloom        // default — bloom + breathe (🙌 🖐️ 🫶 and any unknown)
    case hug          // 🤗 — arm-squeeze ×3
    case punch        // 👊 — slam in from the left, 3 pumps (sound on the 3rd)
    case kiss         // 😘 — pucker → pop, hearts float up
    case fistBump     // 🤜🤛 — two fists meet at centre with a flash
    case thought      // 💭 — bubble rises from the bottom, wobbles, pops
    case envelope     // 💌 — flutters, a heart floats out
    case explosion    // 💥 — shake → burst + shockwave ring + debris
    case gift         // 🎁 — shake → pop → confetti
    case fireworks    // 🎆 — rises → 3 bursts
    case graduation   // 🎓 — cap spins up from the bottom → confetti → bounce
    case birthday     // 🎂 — bloom → candle flicker → confetti
    case clap         // 👏 — hands clap together rhythmically ×4, impact pulse each, then breathe
}

struct RevealAnimation {
    let kind: RevealKind
    let glow: Color
    /// true = travels the full screen (positions from geo.size); false = centred.
    let fullScreen: Bool
}

enum RevealAnimationRegistry {

    static let map: [String: RevealAnimation] = [
        // Migrated first, pixel-identical:
        "🤗":   RevealAnimation(kind: .hug,        glow: Color(hex: "#90EE90"), fullScreen: false),
        // [registry 2026-06-13] REMOVED retired 👊 — replaced in the base set by
        // 🤜🤛 (fistBump). A legacy 👊 ping now falls back to .bloom. (The .punch
        // RevealKind + its EmojiRevealView beat are kept, just unmapped.)
        // "👊":   RevealAnimation(kind: .punch,      glow: Color(hex: "#FF6B35"), fullScreen: false),
        // [registry 2026-06-13] 🙏 gratitude — graduated to .pro; shared BLOOM reveal.
        "🙏":   RevealAnimation(kind: .bloom,      glow: Color(hex: "#FFD479"), fullScreen: false),
        // New placeholders:
        "😘":   RevealAnimation(kind: .kiss,       glow: Color(hex: "#FF6FAF"), fullScreen: false),
        "🤜🤛": RevealAnimation(kind: .fistBump,   glow: Color(hex: "#FF8C42"), fullScreen: true),
        "💭":   RevealAnimation(kind: .thought,    glow: Color(hex: "#c4a8d4"), fullScreen: true),
        "💌":   RevealAnimation(kind: .envelope,   glow: Color(hex: "#FF6B9D"), fullScreen: false),
        "💥":   RevealAnimation(kind: .explosion,  glow: Color(hex: "#FF4530"), fullScreen: true),
        "🎁":   RevealAnimation(kind: .gift,       glow: Color(hex: "#FF5CA8"), fullScreen: false),
        "🎆":   RevealAnimation(kind: .fireworks,  glow: Color(hex: "#FFD700"), fullScreen: true),
        "🎓":   RevealAnimation(kind: .graduation, glow: Color(hex: "#FFD166"), fullScreen: true),
        "🎂":   RevealAnimation(kind: .birthday,   glow: Color(hex: "#FFB347"), fullScreen: false),
        "👏":   RevealAnimation(kind: .clap,       glow: Color(hex: "#FFC857"), fullScreen: false),
        // Base set that simply blooms (kept their existing glow colours):
        // [registry 2026-06-13] REMOVED retired 🙌 — replaced by 👏 (clap). A
        // legacy 🙌 ping falls back to .bloom anyway, so nothing changes for it.
        // "🙌":   RevealAnimation(kind: .bloom,      glow: Color(hex: "#FFD700"), fullScreen: false),
        "🖐️":   RevealAnimation(kind: .bloom,      glow: Color(hex: "#c4a8d4"), fullScreen: false),
        "🫶":   RevealAnimation(kind: .bloom,      glow: Color(hex: "#FF69B4"), fullScreen: false),
    ]

    static let fallback = RevealAnimation(kind: .bloom, glow: Color(hex: "#c4a8d4"), fullScreen: false)

    static func animation(for emoji: String) -> RevealAnimation {
        map[emoji] ?? fallback
    }
}
