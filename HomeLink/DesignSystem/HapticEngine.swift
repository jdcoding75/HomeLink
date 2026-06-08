// HapticEngine.swift
// Pointward › DesignSystem

import UIKit

enum HapticEngine {

    // Quiet Mode retired — full emotional intensity, always.
    // private static var isQuiet: Bool {
    //     UserDefaults.standard.bool(forKey: "quietMode")
    // }
    private static let isQuiet = false
    private static var hapticsEnabled: Bool {
        UserDefaults.standard.bool(forKey: "hapticsEnabled")
    }

    // ════════════════════════════════════════════════════════════════════
    // MARK: - Intensity scaling — Pro feels everything 1.3× stronger
    // ════════════════════════════════════════════════════════════════════

    private static var intensityMultiplier: CGFloat {
        let saved = UserDefaults.standard.string(forKey: "subscriptionTier") ?? ""
        let tier  = SubscriptionTier(rawValue: saved) ?? .free
        return tier == .free ? 1.0 : 1.3
    }

    /// Pro users: all haptics at 1.3× intensity (capped at the hardware max).
    private static func scaled(_ intensity: CGFloat) -> CGFloat {
        min(1.0, intensity * intensityMultiplier)
    }

    // ════════════════════════════════════════════════════════════════════
    // MARK: - The four canonical moments (animation system overhaul)
    // ════════════════════════════════════════════════════════════════════

    /// SEND — a strong light tap, fired at the moment of launch.
    /// (Part one of the two-part send haptic; sendImpact is part two.)
    static func send() {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: scaled(0.7))
    }

    /// SEND IMPACT — the medium tap as the thought reaches the screen edge.
    /// Launch tap → flight → this. Two-part, physical.
    static func sendImpact() {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: scaled(0.7))
    }

    /// FIREFLY SEND — very soft, slightly delayed (the drift begins first).
    static func sendSoft() {
        guard hapticsEnabled else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: scaled(0.3))
        }
    }

    /// CATCH ALIGNMENT — pulses speed up and strengthen as the user turns
    /// toward the sender. Call freely (e.g. every heading tick); the band
    /// interval throttling lives here.
    ///   outside 30°  silent
    ///   within 30°   very soft, every 2 s, 0.2
    ///   within 15°   soft, every 1 s, 0.4
    ///   within 5°    medium pulse rate, every 0.5 s, 0.6
    private static var lastAlignmentPulse = Date.distantPast
    static func catchAlignment(angleError: Double) {
        guard hapticsEnabled else { return }
        let interval: TimeInterval
        let intensity: CGFloat
        switch angleError {
        case ..<5:   interval = 0.5; intensity = 0.6
        case ..<15:  interval = 1.0; intensity = 0.4
        case ..<30:  interval = 2.0; intensity = 0.2
        default:     return
        }
        guard Date.now.timeIntervalSince(lastAlignmentPulse) >= interval else { return }
        lastAlignmentPulse = .now
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: scaled(intensity))
    }

    /// LOCK-ON — one clean medium tap, exactly at the alignment moment.
    static func lockOn() {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: scaled(0.8))
    }

    /// REVEAL — success notification as the emoji blooms.
    static func reveal() {
        guard hapticsEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// SENDER CAUGHT CONFIRMATION — a very soft single tap. No text,
    /// no receipt — just a warm symbolic moment.
    static func caughtConfirmation() {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: scaled(0.25))
    }

    static func connectionFelt() {
        guard hapticsEnabled else { return }
        let intensity: CGFloat = isQuiet ? 0.35 : 0.65
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: intensity)
    }

    static func pingSent() {
        guard hapticsEnabled else { return }
        if isQuiet {
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.4)
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    static func pingReceived() {
        guard hapticsEnabled else { return }
        let gen = UIImpactFeedbackGenerator(style: .soft)
        let i1: CGFloat = isQuiet ? 0.45 : 0.85
        let i2: CGFloat = isQuiet ? 0.25 : 0.5
        gen.impactOccurred(intensity: i1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            gen.impactOccurred(intensity: i2)
        }
    }

    /// Core-mode arrival — a single soft pulse, like a directional pull.
    /// Intimate, not an alert: no double tap, no notification feel.
    static func thoughtArrived() {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .soft)
            .impactOccurred(intensity: isQuiet ? 0.35 : 0.6)
    }

    /// Send-a-thought sequence: light tap as the emoji starts to move…
    static func thoughtReleased() {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: isQuiet ? 0.3 : 0.45)
    }

    /// …stronger pulse as it launches outward. (The fade-away uses pingReceived's
    /// soft double tap.)
    static func thoughtLaunched() {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: isQuiet ? 0.5 : 0.85)
    }

    /// "With feeling" launch — strong and sharp, like something fired.
    static func thoughtFired() {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: isQuiet ? 0.6 : 1.0)
    }

    /// Gentle, warm tap when choosing who to point toward — softer than connectionFelt.
    static func personSelected() {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: isQuiet ? 0.3 : 0.5)
    }

    static func paywallReached() {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: isQuiet ? 0.25 : 0.45)
    }

    static func skinSelected() {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: isQuiet ? 0.3 : 0.55)
    }

    static func saved() {
        guard hapticsEnabled else { return }
        if isQuiet {
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.4)
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    static func destructive() {
        guard hapticsEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    // ════════════════════════════════════════════════════════════════════
    // MARK: - Rocket 🚀 — fueling clicks and the armed-for-launch beat
    // ════════════════════════════════════════════════════════════════════

    /// ROCKET FUEL — one tap per shake/tap as the tank fills.
    /// Light for the first three segments, medium at four, heavy at full.
    static func rocketFuel(segment: Int) {
        guard hapticsEnabled else { return }
        let style: UIImpactFeedbackGenerator.FeedbackStyle
        let intensity: CGFloat
        switch segment {
        case ..<4:  style = .light;  intensity = 0.5
        case 4:     style = .medium; intensity = 0.7
        default:    style = .heavy;  intensity = 0.9
        }
        UIImpactFeedbackGenerator(style: style).impactOccurred(intensity: scaled(intensity))
    }

    /// ROCKET READY — full tank, aligned: a sharp confirming tap before liftoff.
    static func rocketReady() {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: scaled(0.9))
    }

    /// COUNTDOWN — one clean medium tap per number (3 · 2 · 1).
    static func rocketCountdown() {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: scaled(0.7))
    }

    /// LAUNCH — a sustained rumble: three heavy taps, 50 ms apart.
    static func rocketLaunch() {
        guard hapticsEnabled else { return }
        let gen = UIImpactFeedbackGenerator(style: .heavy)
        for k in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(k) * 0.05) {
                gen.impactOccurred(intensity: scaled(1.0))
            }
        }
    }

    /// LANDING — a single soft thud as the rocket touches the catch pad.
    static func rocketLanding() {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: scaled(0.6))
    }
}
