// EmotionalIntent.swift
// Pointward › AnimationEngine
//
// Every animation declares its emotional
// intent. This single declaration drives
// ALL other decisions automatically.
// No more one-off animation logic.

import SwiftUI
import UIKit

enum EmotionalIntent {

    /// Slow, warm, intimate.
    /// Like a long hug or a whispered secret.
    /// Timing: unhurried. Easing: gentle sine.
    /// Particles: few, soft, drifting.
    /// Haptics: slow building, warm.
    /// Colors: deep warm purples, soft amber.
    case tender

    /// Light, bouncy, fun.
    /// Like a high five or a paper airplane.
    /// Timing: snappy. Easing: bouncy back.
    /// Particles: scattered, energetic.
    /// Haptics: light crisp taps.
    /// Colors: bright, warm yellows and whites.
    case playful

    /// Fast, dramatic, overwhelming.
    /// Like a rocket launch or a thunderclap.
    /// Timing: explosive build then instant.
    /// Easing: aggressive ease-out cubic.
    /// Particles: many, fast, trailing.
    /// Haptics: deep rumble building to peak.
    /// Colors: dark with single bright source.
    case powerful

    /// Organic, shimmering, otherworldly.
    /// Like fairy dust or northern lights.
    /// Timing: flowing, never mechanical.
    /// Easing: organic sine with variation.
    /// Particles: many, glowing, clustering.
    /// Haptics: soft shimmer sequence.
    /// Colors: deep purple, lavender glow.
    case magical

    /// Quick, precise, decisive.
    /// Like a snap or a finger click.
    /// Timing: instant. No build up.
    /// Easing: linear to sudden stop.
    /// Particles: sharp, directional.
    /// Haptics: single sharp snap.
    /// Colors: clean, high contrast.
    case urgent

    // MARK: - Derived properties

    var defaultParticleCount: Int {
        switch self {
        case .tender:  return 12
        case .playful: return 20
        case .powerful: return 40
        case .magical: return 72
        case .urgent:  return 8
        }
    }

    var defaultGlowRadius: CGFloat {
        switch self {
        case .tender:  return 16
        case .playful: return 12
        case .powerful: return 32
        case .magical: return 28
        case .urgent:  return 8
        }
    }

    var defaultGlowOpacity: Double {
        switch self {
        case .tender:  return 0.25
        case .playful: return 0.30
        case .powerful: return 0.50
        case .magical: return 0.55
        case .urgent:  return 0.20
        }
    }

    var defaultAnticipationDuration: Double {
        switch self {
        case .tender:  return 0.8
        case .playful: return 0.2
        case .powerful: return 2.5
        case .magical: return 0.4
        case .urgent:  return 0.0
        }
    }

    var defaultJourneyDuration: Double {
        switch self {
        case .tender:  return 4.0
        case .playful: return 0.8
        case .powerful: return 1.5
        case .magical: return 1.2
        case .urgent:  return 0.4
        }
    }

    var defaultEasing: AnimationEasingProfile {
        switch self {
        case .tender:  return .gentle
        case .playful: return .bouncy
        case .powerful: return .explosive
        case .magical: return .organic
        case .urgent:  return .instant
        }
    }
}

enum AnimationEasingProfile {
    case gentle     // easeInOutSine — tender, unhurried
    case bouncy     // easeOutBack — playful, spring
    case explosive  // easeOutCubic — powerful, fast start
    case organic    // easeInOutQuad with variation — magical
    case instant    // linear — urgent, no ramp

    var swiftUIAnimation: Animation {
        switch self {
        case .gentle:
            return .easeInOut(duration: 0.6)
        case .bouncy:
            return .spring(response: 0.4,
                          dampingFraction: 0.6)
        case .explosive:
            return .timingCurve(0.2, 0.8,
                               0.3, 1.0,
                               duration: 0.5)
        case .organic:
            return .spring(response: 0.8,
                          dampingFraction: 0.55)
        case .instant:
            return .linear(duration: 0.15)
        }
    }
}

enum ParticleColorStyle {
    case emojiHue       // derived from emoji color
    case goldAmber      // #D4A017 — bow, achievement
    case lavender       // #c4a8d4 — compass, magical
    case warmWhite      // #F5F0FF — wind, tender
    case fireOrange     // #FF6B35 — rocket, powerful
    case electricBlue   // #4FC3F7 — urgent, precise
    case roseGold       // #FF69B4 — occasion, love
    case custom(Color)

    var color: Color {
        switch self {
        case .emojiHue:     return Color(hex: "#c4a8d4")
        case .goldAmber:    return Color(hex: "#D4A017")
        case .lavender:     return Color(hex: "#c4a8d4")
        case .warmWhite:    return Color(hex: "#F5F0FF")
        case .fireOrange:   return Color(hex: "#FF6B35")
        case .electricBlue: return Color(hex: "#4FC3F7")
        case .roseGold:     return Color(hex: "#FF69B4")
        case .custom(let c): return c
        }
    }
}

enum WorldBackground {
    case deepSpace      // rocket — black + stars
    case daySkyClouds   // wind, plane — blue + clouds
    case nightSky       // wand — deep purple + stars
    case corkBoard      // flick — warm cork texture
    case archeryRange   // bow — dark range + target
    case magicalDark    // wand — deep purple sparkles
    case deepPurple     // compass — brand background
    case custom(Color, Color) // gradient from/to
}

enum SoundCategory {
    // Instrument sounds (play during send)
    case rocketRoar         // deep subwoofer rumble
    case bowRelease         // wood creak + string snap
    case windBreath         // intimate breath sound
    case wandShimmer        // magical crystal shimmer
    case planeEngine        // toy propeller whir
    case flickSnap          // paper snap and flutter
    case compassPulse       // warm soft glow tone

    // Arrival sounds (play at bucket catch)
    case heavyThud          // rocket touchdown
    case arrowImpact        // sharp metal thud
    case leafLanding        // soft organic settle
    case sparkleArrive      // magical burst
    case planeTouchdown     // wheels on ground
    case noteSlap           // post-it on cork
    case orbArrive          // soft energy pulse

    // Reveal sounds (play at emoji reveal)
    // These are the emoji_*.wav files
    case emojiMatched       // plays emoji sound file

    case none
}

enum HapticPattern {
    case none
    case singleSoft         // UIImpactFeedback .soft
    case singleMedium       // UIImpactFeedback .medium
    case singleHeavy        // UIImpactFeedback .heavy
    case singleRigid        // UIImpactFeedback .rigid
    case doubleSoft         // two soft pulses 150ms apart
    case buildingSequence   // soft→medium→heavy over 1s
    case heartbeat          // soft·medium 300ms apart
    case sharpSnap          // .rigid single
    case sustainedRumble    // heavy repeating 8x 100ms
    case celebration        // success notification

    func fire() {
        switch self {
        case .none: break
        case .singleSoft:
            UIImpactFeedbackGenerator(style: .soft)
                .impactOccurred(intensity: 0.6)
        case .singleMedium:
            UIImpactFeedbackGenerator(style: .medium)
                .impactOccurred(intensity: 0.7)
        case .singleHeavy:
            UIImpactFeedbackGenerator(style: .heavy)
                .impactOccurred(intensity: 0.9)
        case .singleRigid:
            UIImpactFeedbackGenerator(style: .rigid)
                .impactOccurred(intensity: 0.8)
        case .doubleSoft:
            let g = UIImpactFeedbackGenerator(
                style: .soft)
            g.impactOccurred(intensity: 0.7)
            DispatchQueue.main.asyncAfter(
                deadline: .now() + 0.15) {
                g.impactOccurred(intensity: 0.5)
            }
        case .buildingSequence:
            let g = UIImpactFeedbackGenerator(
                style: .soft)
            g.impactOccurred(intensity: 0.3)
            DispatchQueue.main.asyncAfter(
                deadline: .now() + 0.3) {
                UIImpactFeedbackGenerator(style: .medium)
                    .impactOccurred(intensity: 0.6)
            }
            DispatchQueue.main.asyncAfter(
                deadline: .now() + 0.7) {
                UIImpactFeedbackGenerator(style: .heavy)
                    .impactOccurred(intensity: 1.0)
            }
        case .heartbeat:
            UIImpactFeedbackGenerator(style: .soft)
                .impactOccurred(intensity: 0.5)
            DispatchQueue.main.asyncAfter(
                deadline: .now() + 0.3) {
                UIImpactFeedbackGenerator(style: .medium)
                    .impactOccurred(intensity: 0.8)
            }
        case .sharpSnap:
            UIImpactFeedbackGenerator(style: .rigid)
                .impactOccurred(intensity: 1.0)
        case .sustainedRumble:
            for i in 0..<8 {
                DispatchQueue.main.asyncAfter(
                    deadline: .now() +
                    Double(i) * 0.1) {
                    UIImpactFeedbackGenerator(
                        style: .heavy)
                        .impactOccurred(
                            intensity: 0.3 +
                            Double(i) * 0.09)
                }
            }
        case .celebration:
            UINotificationFeedbackGenerator()
                .notificationOccurred(.success)
        }
    }
}
