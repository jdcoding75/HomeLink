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
             suggestions: ["miss you ✦", "xoxo ✦", "you're on my mind ✦"]),
        Item(emoji: "🙌", label: "celebration", defaultMessage: "yes! so proud of you ✦",   access: .free,
             suggestions: ["you did it! ✦", "amazing news ✦", "celebrating you ✦"]),
        Item(emoji: "👊", label: "fist bump",   defaultMessage: "you got this ✦",           access: .free,
             suggestions: ["go get 'em ✦", "proud of you ✦", "stay strong ✦"]),
        Item(emoji: "🖐️", label: "high five",   defaultMessage: "nice work ✦",              access: .free,
             suggestions: ["well done ✦", "crushed it ✦", "high five! ✦"]),
        Item(emoji: "🫶", label: "support",     defaultMessage: "sending you love ✦",       access: .free,
             suggestions: ["love you ✦", "always here for you ✦", "thinking of you ✦"]),
    ]

    /// [2/7] These have NO sounds yet — shown as COMING SOON (not locked), not
    /// selectable, alongside the occasion set. They graduate as sounds ship.
    static let pro: [Item] = [
        Item(emoji: "💪", label: "you got this",    defaultMessage: "I believe in you ✦",             access: .comingSoon),
        Item(emoji: "🙏", label: "gratitude",       defaultMessage: "so grateful for you ✦",          access: .comingSoon),
        Item(emoji: "👏", label: "well done",       defaultMessage: "so well done ✦",                 access: .comingSoon),
        Item(emoji: "🤝", label: "thinking of you", defaultMessage: "just thinking of you ✦",         access: .comingSoon),
        Item(emoji: "✨", label: "special",         defaultMessage: "you make everything brighter ✦", access: .comingSoon),
    ]

    /// Occasion 3 — shown with a "coming soon" badge (not selectable).
    static let occasion: [Item] = [
        Item(emoji: "🎂", label: "birthday",       defaultMessage: "happy birthday ✦",   access: .comingSoon),
        Item(emoji: "🎄", label: "happy holidays", defaultMessage: "happy holidays ✦",   access: .comingSoon),
        Item(emoji: "💐", label: "for mum",        defaultMessage: "love you so much ✦", access: .comingSoon),
    ]

    static let all: [Item] = base + pro + occasion

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
        "👊": "emoji_fistbump",
        "🖐️": "emoji_highfive",
        "🫶": "emoji_hearthands",
        "👏": "emoji_clap",
    ]
}
