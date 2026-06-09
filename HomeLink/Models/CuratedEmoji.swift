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
        var id: String { emoji }
    }

    /// Base 6 — always visible and selectable, free and pro.
    static let base: [Item] = [
        Item(emoji: "🫂", label: "hug",         defaultMessage: "sending you a big hug ✦", access: .free),
        Item(emoji: "😘", label: "kiss",        defaultMessage: "thinking of you ✦",        access: .free),
        Item(emoji: "🙌", label: "celebration", defaultMessage: "yes! so proud of you ✦",   access: .free),
        Item(emoji: "👊", label: "fist bump",   defaultMessage: "you got this ✦",           access: .free),
        Item(emoji: "🖐️", label: "high five",   defaultMessage: "nice work ✦",              access: .free),
        Item(emoji: "🫶", label: "support",     defaultMessage: "sending you love ✦",       access: .free),
    ]

    /// Pro 5 — visible but locked for free users (tap → upgrade).
    static let pro: [Item] = [
        Item(emoji: "💪", label: "you got this",    defaultMessage: "I believe in you ✦",             access: .pro),
        Item(emoji: "🙏", label: "gratitude",       defaultMessage: "so grateful for you ✦",          access: .pro),
        Item(emoji: "👏", label: "well done",       defaultMessage: "so well done ✦",                 access: .pro),
        Item(emoji: "🤝", label: "thinking of you", defaultMessage: "just thinking of you ✦",         access: .pro),
        Item(emoji: "✨", label: "special",         defaultMessage: "you make everything brighter ✦", access: .pro),
    ]

    /// Occasion 3 — pro only, shown with a "coming soon" badge (not selectable).
    static let occasion: [Item] = [
        Item(emoji: "🎂", label: "birthday",       defaultMessage: "happy birthday ✦",   access: .comingSoon),
        Item(emoji: "🎄", label: "happy holidays", defaultMessage: "happy holidays ✦",   access: .comingSoon),
        Item(emoji: "💐", label: "for mum",        defaultMessage: "love you so much ✦", access: .comingSoon),
    ]

    static let all: [Item] = base + pro + occasion

    static func item(_ emoji: String) -> Item? { all.first { $0.emoji == emoji } }
    static func label(_ emoji: String) -> String? { item(emoji)?.label }
    static func defaultMessage(_ emoji: String) -> String? { item(emoji)?.defaultMessage }

    /// Wav filenames per emoji, for the ones with shipped sounds (HomeLink/Sounds).
    /// Emojis without a shipped sound simply no-op.
    static let soundMap: [String: String] = [
        "🫂": "emoji_hug",
        "😘": "emoji_kiss",
        "🙌": "emoji_celebration",   // not yet shipped → graceful no-op
        "👊": "emoji_fistbump",
        "🖐️": "emoji_highfive",
        "🫶": "emoji_hearthands",
        "👏": "emoji_clap",
    ]
}
