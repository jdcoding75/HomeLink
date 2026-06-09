// AnimationDescriptor.swift
// Pointward › AnimationEngine
//
// A complete declarative description of
// one animation. Fill this in and the
// animation engine knows everything it
// needs. No custom logic required.
//
// ADDING A NEW ANIMATION:
// 1. Add case to Instrument enum
// 2. Create static let in
//    AnimationDescriptors.swift
// 3. Add to instrument picker
// Done. No animation code needed.

import SwiftUI

struct AnimationDescriptor {

    // MARK: - Identity
    var instrument: Instrument
    var emotionalIntent: EmotionalIntent

    // MARK: - Timing (seconds)
    var anticipationDuration: Double
    var journeyDuration: Double
    var arrivalDuration: Double
    var revealDuration: Double
    var lingerDuration: Double = 6.0

    // MARK: - Visual
    var particleCount: Int
    var particleColor: ParticleColorStyle
    var glowRadius: CGFloat
    var glowOpacity: Double
    var trailLength: Int
    var primaryColor: Color
    var worldBackground: WorldBackground
    var easingCurve: AnimationEasingProfile
    var launchScale: CGFloat
    var peakScale: CGFloat
    var arrivalBounce: Bool

    // MARK: - Sound
    var sendSound: SoundCategory
    var arrivalSound: SoundCategory
    var revealSound: SoundCategory = .emojiMatched

    // MARK: - Haptics
    var sendHaptic: HapticPattern
    var arrivalHaptic: HapticPattern
    var revealHaptic: HapticPattern = .heartbeat

    // MARK: - Computed
    var totalSendDuration: Double {
        anticipationDuration + journeyDuration
    }

    var totalReceiveDuration: Double {
        arrivalDuration + revealDuration +
        lingerDuration
    }

    // MARK: - Holiday support
    func applying(
        _ variant: HolidayVariant
    ) -> AnimationDescriptor {
        variant.apply(to: self)
    }
}
