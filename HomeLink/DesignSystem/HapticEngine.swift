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

    // ════════════════════════════════════════════════════════════════════
    // MARK: - CATCH — the receipt redesign (arrival · lock · reveal)
    // ════════════════════════════════════════════════════════════════════

    /// ARRIVAL — a strong, warm double tap the instant a thought lands.
    /// Impossible to miss: two heavy taps 120 ms apart.
    static func catchArrival() {
        guard hapticsEnabled else { return }
        let gen = UIImpactFeedbackGenerator(style: .heavy)
        gen.impactOccurred(intensity: scaled(0.9))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            gen.impactOccurred(intensity: scaled(0.8))
        }
    }

    /// LOCK SNAP — the most satisfying click in the app, fired exactly at 5°.
    /// A rigid snap immediately followed by a soft echo.
    static func catchLock() {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: scaled(1.0))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: scaled(0.4))
        }
    }

    /// HOLD ENERGY — a soft pulse while the locked orb charges (call on a
    /// tightening interval; throttled here).
    private static var lastCatchHold = Date.distantPast
    static func catchHold(_ progress: Double) {
        guard hapticsEnabled else { return }
        let interval = 0.16 - progress * 0.08
        guard Date.now.timeIntervalSince(lastCatchHold) >= interval else { return }
        lastCatchHold = .now
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: scaled(0.3 + progress * 0.4))
    }

    /// REVEAL PEAK — the strongest moment in the app: a success notification
    /// layered over a heavy tap as the emoji blooms.
    static func catchReveal() {
        guard hapticsEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: scaled(1.0))
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // MARK: - [4/8] Emotional reveal — a heartbeat, then a quiet presence
    // ════════════════════════════════════════════════════════════════════
    //
    // Replaces the single reveal tap: silence → soft → warm → gentle double →
    // warm, then a barely-there pulse every 3 s until dismissed. Pro's 1.3×
    // (via scaled) makes every beat warmer and deeper.

    private static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle,
                            _ intensity: CGFloat, after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard hapticsEnabled else { return }
            UIImpactFeedbackGenerator(style: style).impactOccurred(intensity: scaled(intensity))
        }
    }

    static func revealHeartbeat() {
        guard hapticsEnabled else { return }
        // 0 ms silence — anticipation.
        tap(.soft,   0.3, after: 0.20)   // very soft pulse
        tap(.medium, 0.7, after: 0.50)   // stronger warm pulse
        tap(.soft,   0.4, after: 0.80)   // gentle double …
        tap(.soft,   0.4, after: 0.92)   // … pulse
        tap(.medium, 0.6, after: 1.20)   // single warm pulse
        startRevealPresence()
    }

    /// A barely-perceptible pulse every 3 s while the reveal lingers.
    private static var presenceTimer: Timer?
    private static func startRevealPresence() {
        stopRevealPresence()
        presenceTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            guard hapticsEnabled else { return }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: scaled(0.2))
        }
    }
    /// Stops the lingering presence pulse — call when the reveal is dismissed.
    static func stopRevealPresence() {
        presenceTimer?.invalidate()
        presenceTimer = nil
    }

    // ════════════════════════════════════════════════════════════════════
    // MARK: - [5/8] Emoji-matched reveal haptics — each gesture feels itself
    // ════════════════════════════════════════════════════════════════════
    //
    // The single entry point for the reveal moment: a matched emoji fires its
    // own signature; everything else gets the emotional heartbeat. Both leave
    // the gentle presence pulse running until dismissed.
    static func revealHaptic(for emoji: String) {
        guard hapticsEnabled else { return }
        switch emoji {
        case "🤗":            // Hug — slow warm enveloping (soft · medium · soft) [1/7]
            tap(.soft,   0.4, after: 0.0)
            tap(.medium, 0.7, after: 0.4)
            tap(.soft,   0.4, after: 0.8)
        case "😘":            // Kiss — single sharp, then a flutter
            tap(.rigid, 0.8, after: 0.0)
            tap(.soft,  0.3, after: 0.3)
        case "🙌":            // Celebration — rapid joyful triple → medium
            tap(.light,  0.5, after: 0.0)
            tap(.light,  0.5, after: 0.12)
            tap(.light,  0.5, after: 0.24)
            tap(.medium, 0.7, after: 0.4)
        case "👊":            // Punch — single decisive heavy
            tap(.heavy, 0.9, after: 0.0)
        case "🤜🤛":           // Fist bump — two fists meet: medium ×2
            tap(.medium, 0.8, after: 0.0)
            tap(.medium, 0.8, after: 0.16)
        case "😘":            // Kiss — a light pop at the pucker
            tap(.light, 0.6, after: 0.7)
        case "💭", "💌":       // Thought / love note — soft pulses
            tap(.soft, 0.5, after: 0.2)
            tap(.soft, 0.4, after: 0.5)
        case "💥":            // Explosion — heavy + sharp
            tap(.heavy, 1.0, after: 0.45)
            tap(.rigid, 0.7, after: 0.55)
        case "🎁", "🎂":       // Gift / birthday — medium + success flourish
            tap(.medium, 0.7, after: 0.3)
            for k in 1...3 { tap(.light, 0.4, after: 0.6 + Double(k) * 0.06) }
        case "🎆", "🎓":       // Fireworks / graduation — celebratory taps
            for k in 0...4 { tap(.light, 0.5, after: 0.6 + Double(k) * 0.12) }
        case "🖐️", "🖐", "✋":  // High five — sharp slap, then a vibrate
            tap(.rigid, 0.9, after: 0.0)
            for k in 1...4 { tap(.soft, 0.3, after: Double(k) * 0.05) }
        case "🫶":            // Heart hands — double soft heartbeat
            tap(.soft, 0.35, after: 0.0)
            tap(.soft, 0.35, after: 0.6)
        default:
            revealHeartbeat()   // the emotional default
            return
        }
        startRevealPresence()
    }

    // ════════════════════════════════════════════════════════════════════
    // MARK: - [5/5] HAPTIC PERSONALITY — each instrument distinct, eyes shut
    // ════════════════════════════════════════════════════════════════════
    //
    // BOW    tension building → sharp snap release
    // FLICK  single sharp light flick
    // WAND   rhythmic shake pulses → explosion
    // WIND   barely there — a whisper
    // PLANE  click-click-click winding → spring release
    // COMPASS calm and steady
    // (ROCKET lives above; all Pro haptics already ride the 1.3× `scaled`.)

    // ── BOW: the draw tightens, the release snaps ──

    /// Draw tension — pulses strengthen with how far the string is pulled (0…1).
    private static var lastBowDraw = Date.distantPast
    static func bowDraw(_ progress: CGFloat) {
        guard hapticsEnabled else { return }
        let interval = 0.18 - Double(progress) * 0.1     // quickens as it tightens
        guard Date.now.timeIntervalSince(lastBowDraw) >= interval else { return }
        lastBowDraw = .now
        UIImpactFeedbackGenerator(style: .soft)
            .impactOccurred(intensity: scaled(0.3 + progress * 0.4))
    }

    /// Release — one sharp medium tap as the arrow leaves the string.
    static func bowRelease() {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: scaled(0.85))
    }

    // ── FLICK: a single sharp light flick ──

    static func flickLoad() {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: scaled(0.4))
    }

    static func flickRelease() {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: scaled(0.75))
    }

    // ── WAND: rhythmic shake pulses, then an explosion ──

    /// One light tap per shake as the crystal charges.
    static func wandShake() {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: scaled(0.5))
    }

    /// Full charge — a rapid triple tap, the magic crackling.
    static func wandFull() {
        guard hapticsEnabled else { return }
        let gen = UIImpactFeedbackGenerator(style: .rigid)
        for k in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(k) * 0.06) {
                gen.impactOccurred(intensity: scaled(0.7))
            }
        }
    }

    /// Release — one heavy tap as the spell bursts free.
    static func wandRelease() {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: scaled(0.95))
    }

    // ── WIND: barely there, just a whisper ──

    /// Breath detected — barely perceptible.
    static func windBreath() {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: scaled(0.18))
    }

    /// Send — a very soft double tap as the seeds let go.
    static func windSend() {
        guard hapticsEnabled else { return }
        let gen = UIImpactFeedbackGenerator(style: .soft)
        gen.impactOccurred(intensity: scaled(0.3))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            gen.impactOccurred(intensity: scaled(0.22))
        }
    }

    // ── PLANE: click-click-click winding → spring release ──

    /// One crisp light click per propeller wind.
    static func planeWind() {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: scaled(0.45))
    }

    /// Fully wound — a rapid triple click.
    static func planeFull() {
        guard hapticsEnabled else { return }
        let gen = UIImpactFeedbackGenerator(style: .rigid)
        for k in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(k) * 0.05) {
                gen.impactOccurred(intensity: scaled(0.5))
            }
        }
    }

    /// Launch — a medium snap as the spring lets go.
    static func planeLaunch() {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: scaled(0.8))
    }

    // ── COMPASS: calm and steady ──

    /// Lock — a single satisfying medium tap.
    static func compassLock() {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: scaled(0.7))
    }

    /// Send — a gentle double tap as the thought leaves true north.
    static func compassSend() {
        guard hapticsEnabled else { return }
        let gen = UIImpactFeedbackGenerator(style: .soft)
        gen.impactOccurred(intensity: scaled(0.55))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
            gen.impactOccurred(intensity: scaled(0.4))
        }
    }
}
