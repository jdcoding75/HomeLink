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

    // ── FREE THOUGHTS ─────────────────────────────────────────────────────
    /// The emojis with sounds wired — selectable, always visible, free for all.
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

    // ── PRO THOUGHTS ──────────────────────────────────────────────────────
    // Pro/Free tier configuration: TBD — do not change without product sign-off.
    // Review scheduled for pre-launch end-game session.
    /// Pro extras. Coming-soon entries have no sound/animation yet (not locked,
    /// not selectable) and graduate as they ship; 🙏 has graduated.
    static let pro: [Item] = [
        // [removed] 💪 Muscle — dropped, no clear identity.
        // Item(emoji: "💪", label: "you got this", defaultMessage: "I believe in you ✦", access: .comingSoon),

        // [promoted] 🙏 Gratitude — graduated from coming-soon to a real .pro
        // send; uses the shared BLOOM reveal (RevealAnimationRegistry fallback).
        Item(emoji: "🙏", label: "gratitude",       defaultMessage: "so grateful for you ✦",          access: .pro,
             suggestions: ["thank you so so much ✦", "you mean so much ✦", "couldn't do it without you ✦"]),

        // [added] 👏 Clapping hands — replaces 🙌 celebration. [promoted 2026-06-13]
        // its clap reveal animation is built, so it's now a real selectable .pro send.
        Item(emoji: "👏", label: "clapping hands",  defaultMessage: "you nailed it ✦",                access: .pro,
             glowColor: "#FFD700",
             suggestions: ["you absolutely nailed it ✦", "that took courage ✦", "standing ovation ✦"]),

        // [removed] 🤝 Thinking of you — dropped.
        // Item(emoji: "🤝", label: "thinking of you", defaultMessage: "just thinking of you ✦", access: .comingSoon),
        // [removed] ✨ Special — no clear identity, dropped.
        // Item(emoji: "✨", label: "special", defaultMessage: "you make everything brighter ✦", access: .comingSoon),
    ]

    /// [4–6/6] The newly-built animated reveals (placeholder polish). These have
    /// sounds + reveal animations wired, so they are real .pro entries (not
    /// "coming soon"). Glow colours mirror RevealAnimationRegistry.
    static let proAnimated: [Item] = [
        Item(emoji: "💭", label: "thinking",   defaultMessage: "thinking of you ✦",            access: .pro, glowColor: "#c4a8d4",
             suggestions: ["you crossed my mind ✦", "quietly thinking of you ✦", "you're on my mind ✦"]),
        // [removed] 💌 Love note — reserved for Special Moments (Valentine's Day card).
        // Item(emoji: "💌", label: "love note",  defaultMessage: "sending you love ✦", access: .pro, glowColor: "#FF6B9D"),
        Item(emoji: "💥", label: "boom",       defaultMessage: "amazing ✦",                    access: .pro, glowColor: "#FF4530",
             suggestions: ["this is massive ✦", "did you hear that?! ✦", "big news ✦"]),
        Item(emoji: "🎁", label: "a gift",     defaultMessage: "a little something for you ✦", access: .pro, glowColor: "#FF5CA8"),
        // [removed] 🎆 Firework — conflicts with the Firework instrument; the emoji
        // renders as a box. (Lives on as a Special Moment / instrument.)
        // Item(emoji: "🎆", label: "fireworks",  defaultMessage: "celebrating you ✦", access: .pro, glowColor: "#FFD700"),
        Item(emoji: "🎓", label: "graduation", defaultMessage: "so proud of you ✦",            access: .pro, glowColor: "#FFD166"),
        // [removed] 🎂 Birthday cake — conflicts with the Birthday instrument; the
        // emoji renders as a box. (Lives on as a Special Moment / instrument.)
        // Item(emoji: "🎂", label: "birthday",   defaultMessage: "happy birthday ✦", access: .pro, glowColor: "#FFB347"),
    ]

    // ── COMING SOON / RESERVED ────────────────────────────────────────────
    // These are commented out intentionally. Do not restore without product sign-off.
    // Reason for each is noted inline.
    /// Occasion — now empty; these moved to Special Moments (see bottom).
    static let occasion: [Item] = [
        // [removed] 🎄 Happy holidays — reserved for Special Moments.
        // Item(emoji: "🎄", label: "happy holidays", defaultMessage: "happy holidays ✦", access: .comingSoon),
        // [removed] 💐 For mum — reserved for Special Moments.
        // Item(emoji: "💐", label: "for mum", defaultMessage: "love you so much ✦", access: .comingSoon),
    ]

    static let all: [Item] = base + proAnimated + pro + occasion

    /// The registry's designated DEFAULT emoji — the first base (free) feeling.
    /// The in-set fallback wherever an emoji is required but missing (e.g. opening
    /// a link-delivered message that carries no emoji). DERIVED from the set, so
    /// it can never drift out of the library.
    static let defaultEmoji: String = base.first?.emoji ?? "🤗"

    static func item(_ emoji: String) -> Item? { all.first { $0.emoji == emoji } }
    static func label(_ emoji: String) -> String? { item(emoji)?.label }
    static func defaultMessage(_ emoji: String) -> String? { item(emoji)?.defaultMessage }
    static func suggestions(_ emoji: String) -> [String] { item(emoji)?.suggestions ?? [] }

    /// Wav filenames per emoji, for the ones with shipped sounds (HomeLink/Sounds).
    /// Emojis without a shipped sound simply no-op. (🫂 → 🤗 [1/7] — same file.)
    static let soundMap: [String: String] = [
        "🤗": "emoji_hug_v2",        // [cleanup 2026-06-13] was "emoji_hug" (old dup
                                     // wav removed); emoji_hug_v2 is the canonical hug.
        "😘": "emoji_kiss",
        // [cleanup 2026-06-13] REMOVED unreachable entry — 🙌 is no longer in
        // CuratedEmoji.all (replaced by 👏) AND emoji_celebration.wav is not in
        // the bundle. Commented out (never-delete) rather than left dangling.
        // "🙌": "emoji_celebration",   // not yet shipped → graceful no-op
        // [registry 2026-06-13] REMOVED retired 👊 — replaced in the base set by
        // 🤜🤛 (fist bump); 👊 is no longer in CuratedEmoji.all.
        // "👊": "emoji_punch",          // renamed from emoji_fistbump
        "🤜🤛": "emoji_fistbump_real",
        "🖐️": "emoji_highfive",
        "🫶": "emoji_hearthands",
        "🙏": "emoji_gratitude",      // [registry 2026-06-13] 🙏 graduated to .pro
        "👏": "emoji_clap",
        "💭": "emoji_thoughtbubble",
        "💌": "emoji_envelope",
        "💥": "emoji_explosion",
        "🎁": "emoji_gift",
        // [registry 2026-06-13] REMOVED 🎆 / 🎂 — they conflict with the Firework
        // and Birthday INSTRUMENTS (which own their own sounds) and are no longer
        // emoji-reveal sends; they live on only as Special Moments.
        // "🎆": "emoji_fireworks",
        "🎓": "emoji_graduation",
        // "🎂": "emoji_birthday",
    ]

    // ── SPECIAL MOMENTS ───────────────────────────────────────────────────
    // These are not emoji picks. The animation IS the card.
    // Occasion-grade cinematic sends. Premium, shareable.
    // Architecture note: Special Moments may not need emoji attached — TBD.
    //
    // Scaffold only: NOT part of `all` (they never appear in the emoji picker).
    // Birthday and Firework already exist as instruments; the rest are upcoming.
    static let specialMoments: [Item] = [
        Item(emoji: "🎂", label: "birthday",        defaultMessage: "make a wish ✦",                 access: .comingSoon),
        Item(emoji: "🎆", label: "firework",        defaultMessage: "light it up ✦",                 access: .comingSoon),
        Item(emoji: "💌", label: "valentine's day", defaultMessage: "happy valentine's day ✦",       access: .comingSoon),
        Item(emoji: "🎄", label: "happy holidays",  defaultMessage: "thinking of you this season ✦", access: .comingSoon),
        Item(emoji: "💐", label: "for mum",         defaultMessage: "love you so much ✦",            access: .comingSoon),
        Item(emoji: "🎇", label: "july 4th",        defaultMessage: "light it up ✦",                 access: .comingSoon),
        Item(emoji: "🎓", label: "graduation",      defaultMessage: "look how far you've come ✦",    access: .comingSoon),
    ]
}
