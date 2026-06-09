// HolidayVariant.swift
// Pointward › AnimationEngine
//
// ADDING A HOLIDAY PACK:
// 1. Create static let below
// 2. Set only what changes from base
// 3. Add to HolidayVariant.current()
// Done. No animation code needed.
//
// Every holiday pack reuses ALL existing
// animation mechanics. Only colors,
// particles, and sounds change.

import SwiftUI

struct HolidayVariant {
    var name: String
    var season: HolidaySeason
    var emoji: String

    // Override only what changes
    // nil = use base descriptor value
    var particleColorOverride: ParticleColorStyle?
    var primaryColorOverride: Color?
    var worldBackgroundOverride: WorldBackground?
    var sendSoundOverride: SoundCategory?
    var arrivalSoundOverride: SoundCategory?
    var particleCountMultiplier: Double?
    var extraParticleShape: ParticleShape?
    var taglineOverrides: [String]?

    func apply(
        to base: AnimationDescriptor
    ) -> AnimationDescriptor {
        var d = base
        if let c = particleColorOverride {
            d.particleColor = c
        }
        if let c = primaryColorOverride {
            d.primaryColor = c
        }
        if let b = worldBackgroundOverride {
            d.worldBackground = b
        }
        if let s = sendSoundOverride {
            d.sendSound = s
        }
        if let s = arrivalSoundOverride {
            d.arrivalSound = s
        }
        if let m = particleCountMultiplier {
            d.particleCount = Int(
                Double(d.particleCount) * m
            )
        }
        return d
    }

    /// Active holiday variant if any.
    static func current() -> HolidayVariant? {
        let month = Calendar.current.component(
            .month, from: Date()
        )
        switch month {
        case 2:  return .valentines
        case 5:  return .mothersDay
        case 12: return .christmas
        default: return nil
        }
    }
}

enum HolidaySeason {
    case valentines
    case mothersDay
    case graduation
    case fathersDay
    case halloween
    case christmas
    case birthday
    case anniversary
}

enum ParticleShape {
    case circle     // default
    case star
    case heart
    case snowflake
    case confetti
    case leaf
    case sparkle
}

// MARK: - Holiday Variants

extension HolidayVariant {

    // ─────────────────────────────────────
    // CHRISTMAS 🎄
    // Snow falls. Everything is softer.
    // Jingle bell sounds.
    // The warmth of home in winter.
    // ─────────────────────────────────────
    static let christmas = HolidayVariant(
        name: "Christmas ✦",
        season: .christmas,
        emoji: "🎄",
        particleColorOverride: .warmWhite,
        primaryColorOverride: Color(hex: "#CC0000"),
        worldBackgroundOverride: .nightSky,
        sendSoundOverride: .compassPulse,
        particleCountMultiplier: 1.8,
        extraParticleShape: .snowflake,
        taglineOverrides: [
            "home is wherever you are ✦",
            "distance can't stop warmth ✦",
            "thinking of you this season ✦",
            "near in every way that matters ✦"
        ]
    )

    // ─────────────────────────────────────
    // BIRTHDAY 🎂
    // Confetti everywhere. Maximum joy.
    // This is a celebration send.
    // Nothing subtle about birthdays.
    // ─────────────────────────────────────
    static let birthday = HolidayVariant(
        name: "Birthday ✦",
        season: .birthday,
        emoji: "🎂",
        particleColorOverride: .roseGold,
        primaryColorOverride: Color(hex: "#FF69B4"),
        sendSoundOverride: .wandShimmer,
        particleCountMultiplier: 2.5,
        extraParticleShape: .confetti,
        taglineOverrides: [
            "celebrating you from here ✦",
            "wishing I was there ✦",
            "you make the world better ✦",
            "another year of you ✦"
        ]
    )

    // ─────────────────────────────────────
    // VALENTINE'S DAY ❤️
    // Rose pink everything.
    // The most romantic send.
    // Hearts in the particles.
    // ─────────────────────────────────────
    static let valentines = HolidayVariant(
        name: "Valentine's Day ✦",
        season: .valentines,
        emoji: "❤️",
        particleColorOverride: .roseGold,
        primaryColorOverride: Color(hex: "#CC0044"),
        sendSoundOverride: .compassPulse,
        particleCountMultiplier: 1.5,
        extraParticleShape: .heart,
        taglineOverrides: [
            "distance can't stop love ✦",
            "you are my direction ✦",
            "wherever you are ✦",
            "love travels in all directions ✦"
        ]
    )

    // ─────────────────────────────────────
    // MOTHER'S DAY 💐
    // Soft pinks and roses.
    // Gentle and warm.
    // The most tender send.
    // ─────────────────────────────────────
    static let mothersDay = HolidayVariant(
        name: "Mother's Day ✦",
        season: .mothersDay,
        emoji: "💐",
        particleColorOverride: .roseGold,
        primaryColorOverride: Color(hex: "#FFB6C1"),
        sendSoundOverride: .compassPulse,
        extraParticleShape: .heart,
        taglineOverrides: [
            "home is wherever you are ✦",
            "always your kid ✦",
            "you taught me direction ✦",
            "love you more than miles ✦"
        ]
    )

    // ─────────────────────────────────────
    // GRADUATION 🎓
    // Gold and purple — achievement colors.
    // Maximum confetti.
    // This is a proud moment send.
    // ─────────────────────────────────────
    static let graduation = HolidayVariant(
        name: "Graduation ✦",
        season: .graduation,
        emoji: "🎓",
        particleColorOverride: .goldAmber,
        primaryColorOverride: Color(hex: "#4B0082"),
        sendSoundOverride: .wandShimmer,
        particleCountMultiplier: 2.0,
        extraParticleShape: .confetti,
        taglineOverrides: [
            "look how far you've come ✦",
            "the beginning of everything ✦",
            "so proud of you ✦",
            "your whole life is pointing forward ✦"
        ]
    )

    // ─────────────────────────────────────
    // FATHER'S DAY 👨
    // Deep blues and golds.
    // Strong and warm.
    // ─────────────────────────────────────
    static let fathersDay = HolidayVariant(
        name: "Father's Day ✦",
        season: .fathersDay,
        emoji: "👨",
        particleColorOverride: .goldAmber,
        primaryColorOverride: Color(hex: "#1B3A6B"),
        taglineOverrides: [
            "always your kid ✦",
            "you showed me the way ✦",
            "pointing toward you always ✦",
            "home is where you are ✦"
        ]
    )
}
