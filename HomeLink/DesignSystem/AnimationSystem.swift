// AnimationSystem.swift
// Pointward › DesignSystem
//
// GLOBAL ANIMATION PRINCIPLES — every motion in the app follows these rules.
//
//   EASING (never linear, anywhere):
//     send motion   → easeOutCubic    fast start, soft landing
//     catch motion  → easeInOutCubic  smooth approach and release
//     glow pulses   → easeInOutSine   organic breathing
//     lock-on snap  → easeOutBack     slight overshoot for satisfaction
//     replay        → easeInOutQuad   balanced and gentle
//
//   TIMING:
//     micro-interactions 80–150 ms · sends 250–450 ms · catches 350–600 ms
//     replays 300–500 ms · glow pulses 600–900 ms · lock-on 120–200 ms
//
//   VISUALS:
//     glow soft + diffused only, 12–24 px radius, 20–40 % opacity, emoji-hued
//     trails 6–12 px wide, fade 200–350 ms, no hard edges
//     particles max 8–12, soft circles never stars, fade quickly
//     shadows 8–16 px blur, 10–20 % opacity
//
//   EMOJI MOTION:
//     always a curved path · 5–8 % squash/stretch on impact ·
//     max 5–10° rotation · the emoji stays readable at all times

import SwiftUI
import UIKit

enum AnimationSystem {

    // ════════════════════════════════════════════════════════════════════
    // MARK: - Easing curves (the only five allowed)
    // ════════════════════════════════════════════════════════════════════

    /// Send motion — fast start, soft landing.
    static func easeOutCubic(_ duration: Double) -> Animation {
        .timingCurve(0.33, 1.0, 0.68, 1.0, duration: duration)
    }

    /// Catch motion — smooth approach and release.
    static func easeInOutCubic(_ duration: Double) -> Animation {
        .timingCurve(0.65, 0.0, 0.35, 1.0, duration: duration)
    }

    /// Glow pulses — organic breathing.
    static func easeInOutSine(_ duration: Double) -> Animation {
        .timingCurve(0.37, 0.0, 0.63, 1.0, duration: duration)
    }

    /// Lock-on snap — slight overshoot for satisfaction.
    static func easeOutBack(_ duration: Double) -> Animation {
        .timingCurve(0.34, 1.56, 0.64, 1.0, duration: duration)
    }

    /// Replay — balanced and gentle.
    static func easeInOutQuad(_ duration: Double) -> Animation {
        .timingCurve(0.45, 0.0, 0.55, 1.0, duration: duration)
    }

    // ════════════════════════════════════════════════════════════════════
    // MARK: - Timing ranges (seconds)
    // ════════════════════════════════════════════════════════════════════

    enum Timing {
        /// Micro-interactions: 80–150 ms
        static let micro: Double          = 0.12
        /// Send animations: 250–450 ms
        static let send: Double           = 0.35
        static let sendFast: Double       = 0.30   // shooting star
        static let sendSlow: Double       = 0.45
        /// Catch animations: 350–600 ms
        static let catchTravel: Double    = 0.40
        static let catchReveal: Double    = 0.30
        static let catchMax: Double       = 0.60
        /// Replay animations: 300–500 ms
        static let replay: Double         = 0.40
        /// Glow pulses: 600–900 ms
        static let glowPulse: Double      = 0.75
        static let glowPulseSlow: Double  = 0.90
        /// Lock-on effect: 120–200 ms
        static let lockOn: Double         = 0.15
        /// Trail fade: 200–350 ms
        static let trailFade: Double      = 0.25
    }

    // ════════════════════════════════════════════════════════════════════
    // MARK: - Visual rules
    // ════════════════════════════════════════════════════════════════════

    enum Glow {
        /// Soft diffused glow only — radius 12–24 px.
        static let radiusMin: CGFloat  = 12
        static let radius: CGFloat     = 16
        static let radiusMax: CGFloat  = 24
        /// Opacity 20–40 %.
        static let opacityMin: Double  = 0.20
        static let opacity: Double     = 0.20
        static let opacityMax: Double  = 0.40
    }

    enum Trail {
        /// Width 6–12 px, no hard edges, soft and subtle.
        static let widthMin: CGFloat = 6
        static let width: CGFloat    = 8
        static let widthMax: CGFloat = 12
        static let opacity: Double   = 0.30
        /// Fade over 200–350 ms.
        static let fade: Double      = 0.25
        static let fadeMax: Double   = 0.35
    }

    enum Particles {
        /// Maximum 8–12 particles. Soft circles, not stars.
        /// Never childish or sparkly.
        static let maxCount  = 12
        static let softCount = 8
    }

    enum Shadows {
        /// Blur 8–16 px, opacity 10–20 % — very soft.
        static let blurMin: CGFloat  = 8
        static let blur: CGFloat     = 12
        static let blurMax: CGFloat  = 16
        static let opacity: Double   = 0.15
        static let opacityMax: Double = 0.20
    }

    enum EmojiMotion {
        /// Slight squash/stretch — 5–8 % on impact/launch.
        static let squash: CGFloat       = 1.05
        static let squashMax: CGFloat    = 1.08
        static let squashReturn: Double  = 0.15
        /// Rotate 5–10° only — the emoji stays readable.
        static let maxRotation: Double   = 8
        static let rotationCap: Double   = 10
    }

    // ════════════════════════════════════════════════════════════════════
    // MARK: - Legacy tokens (existing views still reference these)
    // ════════════════════════════════════════════════════════════════════

    // MARK: Needle
    static let needleSettle = Animation.spring(
        response: 0.8, dampingFraction: 0.55, blendDuration: 0.2
    )
    static let needleSettleQuiet = Animation.spring(
        response: 1.4, dampingFraction: 0.75, blendDuration: 0.3
    )
    static let needleAmbient = easeInOutSine(5)
        .repeatForever(autoreverses: true)

    // MARK: Breathing ring
    static let ringBreath = easeInOutSine(4)
        .repeatForever(autoreverses: true)
    static let ringBreathQuiet = easeInOutSine(8)
        .repeatForever(autoreverses: true)

    // MARK: Ping events
    static let pingPulse = Animation.spring(response: 0.6, dampingFraction: 0.4)
    static let pingBurst = Animation.spring(response: 0.5, dampingFraction: 0.5)
    static let pingGlow  = easeInOutSine(0.4)

    // MARK: Compass lock moment
    static let lockPop = easeOutBack(Timing.lockOn)

    // MARK: Navigation and UI
    static let softAppear       = easeOutCubic(0.35)
    static let buttonPress      = Animation.spring(response: 0.25, dampingFraction: 0.7)
    static let sheetAppear      = Animation.spring(response: 0.5, dampingFraction: 0.8)
    static let taglineTransition = easeOutCubic(0.4)
}

// ════════════════════════════════════════════════════════════════════════
// MARK: - EmojiHue
// ════════════════════════════════════════════════════════════════════════

/// Derives a soft glow colour from an emoji by rendering it tiny and
/// averaging its opaque pixels. Cached — the render happens once per emoji.
/// Glows, trails, and orbs throughout the animation system use this so the
/// light always belongs to the thought being sent.
enum EmojiHue {

    private static var cache: [String: Color] = [:]
    private static let fallback = Color(hex: "#c4a8d4")   // lavender

    static func color(for emoji: String) -> Color {
        if let cached = cache[emoji] { return cached }
        let resolved = averageColor(of: emoji) ?? fallback
        cache[emoji] = resolved
        return resolved
    }

    /// The same hue at glow opacity — convenience for shadows and halos.
    static func glow(for emoji: String, opacity: Double = AnimationSystem.Glow.opacity) -> Color {
        color(for: emoji).opacity(opacity)
    }

    private static func averageColor(of emoji: String) -> Color? {
        let side = 16
        let size = CGSize(width: side, height: side)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            (emoji as NSString).draw(
                in: CGRect(origin: .zero, size: size),
                withAttributes: [.font: UIFont.systemFont(ofSize: 14)]
            )
        }
        guard let cgImage = image.cgImage else { return nil }

        let width  = cgImage.width
        let height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var r = 0.0, g = 0.0, b = 0.0, count = 0.0
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Double(pixels[i + 3])
            guard alpha > 40 else { continue }   // skip transparent fringe
            r += Double(pixels[i])     / alpha * 255
            g += Double(pixels[i + 1]) / alpha * 255
            b += Double(pixels[i + 2]) / alpha * 255
            count += 1
        }
        guard count > 0 else { return nil }

        // Lift toward full saturation softly so dark emojis still glow
        var color = UIColor(red: min(1, r / count / 255),
                            green: min(1, g / count / 255),
                            blue: min(1, b / count / 255), alpha: 1)
        var h: CGFloat = 0, s: CGFloat = 0, v: CGFloat = 0, a: CGFloat = 0
        color.getHue(&h, saturation: &s, brightness: &v, alpha: &a)
        color = UIColor(hue: h, saturation: max(s, 0.35),
                        brightness: max(v, 0.65), alpha: 1)
        return Color(color)
    }
}
