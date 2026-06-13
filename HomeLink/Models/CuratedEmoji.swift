// CuratedEmoji.swift
// Pointward › Models
//
// THE CURATED SET — a fixed, hand-picked set of feelings (replaces the old
// custom-emoji slot picker). Each carries a long-press label, a warm default
// message, and (where shipped) a sound. Three tiers: base 6 (free), pro 5
// (locked for free), and occasion 3 (coming soon).

import Foundation

enum CuratedEmoji {

    enum Access { case free, pro, comingSoon }

    struct Item: Identifiable, Hashable {
        let emoji: String
        let label: String
        let defaultMessage: String
        let access: Access
        /// Reveal glow colour (hex). Mirrors RevealAnimationRegistry.
        var glowColor: String = "#c4a8d4"
        /// [5/7] 3–4 alternative messages, offered when editing the note.
        var suggestions: [String] = []
        var id: String { emoji }
    }

    /// [2/7] Base 6 — the ONLY emojis with sounds wired, so the only ones that
    /// are selectable. Always visible, always sendable. (🫂 → 🤗 [1/7].)
    static let base: [Item] = [
        Item(emoji: "🤗", label: "hug",         defaultMessage: "sending you a big hug ✦", access: .free,
             suggestions: ["wish I could hug you ✦", "a warm squeeze ✦", "here for you ✦"]),
        Item(emoji: "😘", label: "kiss",        defaultMessage: "thinking of you ✦",        access: .free,
             glowColor: "#FF69B4",
             suggestions: ["miss you ✦", "xoxo ✦", "you're on my mind ✦"]),
        // [removed] 🙌 Celebration — replaced by 👏 clap (see `pro`).
        // Item(emoji: "🙌", label: "celebration", defaultMessage: "yes! so proud of you ✦", access: .free,
        //      suggestions: ["you did it! ✦", "amazing news ✦", "celebrating you ✦"]),
        // [6/6] 👊 (punch) replaced in the free base set by 🤜🤛 (fist bump).
        Item(emoji: "🤜🤛", label: "fist bump", defaultMessage: "you got this ✦",           access: .free,
             glowColor: "#FF8C42",
             suggestions: ["go get 'em ✦", "proud of you ✦", "stay strong ✦"]),
        Item(emoji: "🖐️", label: "high five",   defaultMessage: "nice work ✦",              access: .free,
             suggestions: ["well done ✦", "crushed it ✦", "high five! ✦"]),
        Item(emoji: "🫶", label: "support",     defaultMessage: "sending you love ✦",       access: .free,
             suggestions: ["love you ✦", "always here for you ✦", "thinking of you ✦"]),
    ]

    /// [2/7] Pro extras. Coming-soon entries have no sound/animation yet (not
    /// locked, not selectable) and graduate as they ship; 🙏 has graduated.
    static let pro: [Item] = [
        // [removed] 💪 Muscle — dropped, no clear identity.
        // Item(emoji: "💪", label: "you got this", defaultMessage: "I believe in you ✦", access: .comingSoon),

        // [promoted] 🙏 Gratitude — graduated from coming-soon to a real .pro
        // send; uses the shared BLOOM reveal (RevealAnimationRegistry fallback).
        Item(emoji: "🙏", label: "gratitude",       defaultMessage: "so grateful for you ✦",          access: .pro),

        // [added] 👏 Clapping hands — replaces 🙌 celebration. Coming soon for now
        // (its clap reveal animation isn't built yet). tagline: "great job ✦".
        Item(emoji: "👏", label: "clapping hands",  defaultMessage: "so proud of you ✦",              access: .comingSoon,
             glowColor: "#FFD700", suggestions: ["great job ✦", "well done ✦", "bravo ✦"]),

        // [removed] 🤝 Thinking of you — dropped.
        // Item(emoji: "🤝", label: "thinking of you", defaultMessage: "just thinking of you ✦", access: .comingSoon),
        // [removed] ✨ Special — no clear identity, dropped.
        // Item(emoji: "✨", label: "special", defaultMessage: "you make everything brighter ✦", access: .comingSoon),
    ]

    /// [4–6/6] The newly-built animated reveals (placeholder polish). These have
    /// sounds + reveal animations wired, so they are real .pro entries (not
    /// "coming soon"). Glow colours mirror RevealAnimationRegistry.
    static let proAnimated: [Item] = [
        Item(emoji: "💭", label: "thinking",   defaultMessage: "just thinking of you ✦",       access: .pro, glowColor: "#c4a8d4"),
        // [removed] 💌 Love note — reserved for Special Moments (Valentine's Day card).
        // Item(emoji: "💌", label: "love note",  defaultMessage: "sending you love ✦", access: .pro, glowColor: "#FF6B9D"),
        Item(emoji: "💥", label: "boom",       defaultMessage: "that's huge! ✦",               access: .pro, glowColor: "#FF4530"),
        Item(emoji: "🎁", label: "a gift",     defaultMessage: "a little something for you ✦", access: .pro, glowColor: "#FF5CA8"),
        // [removed] 🎆 Firework — conflicts with the Firework instrument; the emoji
        // renders as a box. (Lives on as a Special Moment / instrument.)
        // Item(emoji: "🎆", label: "fireworks",  defaultMessage: "celebrating you ✦", access: .pro, glowColor: "#FFD700"),
        Item(emoji: "🎓", label: "graduation", defaultMessage: "so proud of you ✦",            access: .pro, glowColor: "#FFD166"),
        // [removed] 🎂 Birthday cake — conflicts with the Birthday instrument; the
        // emoji renders as a box. (Lives on as a Special Moment / instrument.)
        // Item(emoji: "🎂", label: "birthday",   defaultMessage: "happy birthday ✦", access: .pro, glowColor: "#FFB347"),
    ]

    /// Occasion — now empty; these moved to Special Moments (see bottom).
    static let occasion: [Item] = [
        // [removed] 🎄 Happy holidays — reserved for Special Moments.
        // Item(emoji: "🎄", label: "happy holidays", defaultMessage: "happy holidays ✦", access: .comingSoon),
        // [removed] 💐 For mum — reserved for Special Moments.
        // Item(emoji: "💐", label: "for mum", defaultMessage: "love you so much ✦", access: .comingSoon),
    ]

    static let all: [Item] = base + proAnimated + pro + occasion

    static func item(_ emoji: String) -> Item? { all.first { $0.emoji == emoji } }
    static func label(_ emoji: String) -> String? { item(emoji)?.label }
    static func defaultMessage(_ emoji: String) -> String? { item(emoji)?.defaultMessage }
    static func suggestions(_ emoji: String) -> [String] { item(emoji)?.suggestions ?? [] }

    /// Wav filenames per emoji, for the ones with shipped sounds (HomeLink/Sounds).
    /// Emojis without a shipped sound simply no-op. (🫂 → 🤗 [1/7] — same file.)
    static let soundMap: [String: String] = [
        "🤗": "emoji_hug",
        "😘": "emoji_kiss",
        "🙌": "emoji_celebration",   // not yet shipped → graceful no-op
        "👊": "emoji_punch",          // renamed from emoji_fistbump
        "🤜🤛": "emoji_fistbump_real",
        "🖐️": "emoji_highfive",
        "🫶": "emoji_hearthands",
        "👏": "emoji_clap",
        "💭": "emoji_thoughtbubble",
        "💌": "emoji_envelope",
        "💥": "emoji_explosion",
        "🎁": "emoji_gift",
        "🎆": "emoji_fireworks",
        "🎓": "emoji_graduation",
        "🎂": "emoji_birthday",
    ]

    // ── Special Moments ──────────────────────────────────────────────────────
    // Special Moments — occasion-grade cinematic sends. These are not emoji
    // picks. The animation IS the card. Premium, shareable, no instrument picker.
    //
    // Scaffold only: NOT part of `all` (they never appear in the emoji picker).
    // Birthday and Firework already exist as instruments; the rest are upcoming.
    static let specialMoments: [Item] = [
        Item(emoji: "🎂", label: "birthday",       defaultMessage: "happy birthday ✦",     access: .comingSoon),
        Item(emoji: "🎆", label: "firework",       defaultMessage: "celebrating you ✦",    access: .comingSoon),
        Item(emoji: "💌", label: "valentine's day", defaultMessage: "be mine ✦",           access: .comingSoon),
        Item(emoji: "🎄", label: "happy holidays", defaultMessage: "happy holidays ✦",     access: .comingSoon),
        Item(emoji: "💐", label: "for mum",        defaultMessage: "love you so much ✦",   access: .comingSoon),
        Item(emoji: "🎇", label: "july 4th",       defaultMessage: "happy 4th ✦",          access: .comingSoon),
    ]
}
