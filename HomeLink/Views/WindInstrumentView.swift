// WindInstrumentView.swift
// Pointward › Views
//
// INSTRUMENT 3 — WIND 🌬️ (Pro, replaced the firefly). A soft atmospheric
// dark circle full of delicate particles drifting gently toward the person
// — breath, or dandelion seeds. Load a thought and the particles gather
// around it; a slow steady exhale into the microphone releases everything
// toward them.
//
// Graceful degradation: if mic permission is denied (or the engine can't
// start), hold the phone within 15° for 2 seconds instead.

import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

struct WindInstrumentView: View {

    let loadedToken: String?
    let loadedSymbol: AnyView?
    let bearingDegrees: Double
    let personName: String
    var personEmoji: String = "💜"
    let onSend: () -> Void

    @StateObject private var breath = BreathDetector()

    /// A drifting seed of light.
    private struct Particle: Identifiable {
        let id = UUID()
        var offset: CGSize
        var size: CGFloat
        var white: Bool     // warm lavender/white mix
        var opacity: Double
    }

    @State private var particles: [Particle] = []
    @State private var gatherPulse = false
    @State private var holdProgress: Double = 0      // fallback hold-to-send
    @State private var lastPulseHaptic = Date.distantPast
    @State private var showAimHint = false           // exhaled while off-target

    private let driftTick = Timer.publish(every: 0.8, on: .main, in: .common).autoconnect()
    private let holdTick  = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    private static let lavender = Color(hex: "#c4a8d4")
    private static let warmWhite = Color(hex: "#f2ecf8")

    private var rad: Double { bearingDegrees * .pi / 180 }
    private var aligned: Bool { BearingCalculator.isSendAligned(bearingDegrees) }
    /// Breath when we can hear it; the steady hold when we can't.
    private var usingBreath: Bool { breath.isListening && !breath.micDenied }
    /// How gathered/bright everything is — breath progress or hold progress.
    private var charge: Double { usingBreath ? breath.exhaleProgress : holdProgress }
    /// The instantaneous, smoothed mic loudness — drives the listening arc
    /// and the live "particles move with your breath" response.
    private var liveLevel: Double { usingBreath ? breath.level : 0 }

    var body: some View {
        ZStack {
            // ── The atmosphere — a soft dark night ──
            Circle()
                .fill(
                    RadialGradient(colors: [Color(hex: "#151123"),
                                            Color(hex: "#0d0d14")],
                                   center: .center, startRadius: 30, endRadius: 185)
                )
                .overlay(Circle().stroke(Color.white.opacity(0.06), lineWidth: 1))
                .frame(width: 360, height: 360)

            // ── Where they are — marker · arc (instructions are ours) ──
            DirectionIndicator(bearingDegrees: bearingDegrees,
                               personName: personName,
                               personEmoji: personEmoji,
                               ringRadius: 168,
                               showHint: loadedToken == nil)

            // ── The breath-level arc — the instrument listening ──
            // A soft arc cradling the instrument bottom that brightens in
            // real time with the mic: dim lavender in silence, full glow on
            // a strong steady exhale. Only while a thought is loaded and we
            // can actually hear (mic granted).
            if loadedToken != nil && usingBreath {
                breathArc
            }

            // ── The particles — breath made visible ──
            // Each particle brightens with how gathered we are (charge) and
            // shimmers a little harder the louder the live breath (liveLevel).
            ForEach(particles) { particle in
                Circle()
                    .fill((particle.white ? Self.warmWhite : Self.lavender)
                            .opacity(particle.opacity * (1 + charge * 0.8 + liveLevel * 0.5)))
                    .frame(width: particle.size * (1 + CGFloat(liveLevel) * 0.4),
                           height: particle.size * (1 + CGFloat(liveLevel) * 0.4))
                    .blur(radius: 1.5)
                    .offset(gatheredOffset(particle))
                    .animation(AnimationSystem.easeInOutSine(0.8), value: particle.offset)
                    .animation(AnimationSystem.easeInOutSine(0.4), value: charge)
                    .animation(AnimationSystem.easeInOutSine(0.25), value: liveLevel)
            }

            // ── The loaded thought — center, particles gathering around ──
            if let loadedSymbol {
                loadedSymbol
                    .scaleEffect(1.0 + charge * 0.25)
                    .shadow(color: Self.lavender.opacity(0.45 + charge * 0.5),
                            radius: 10 + charge * 14)
                    .scaleEffect(gatherPulse ? 1.05 : 0.97)
            }

            // ── Instructions ──
            VStack {
                Spacer()
                if showAimHint {
                    Text("point toward \(personName) first")
                        .font(.system(size: 12, design: .serif).italic())
                        .foregroundColor(Color(hex: "#e08a3c"))
                        .transition(.opacity)
                } else if loadedToken != nil {
                    Text(instruction)
                        .font(.system(size: 12, design: .serif).italic())
                        .foregroundColor(Self.lavender.opacity(aligned ? 0.95 : 0.7))
                        .transition(.opacity)
                }

                // Permission denied — wind still sends by holding, but offer
                // the door to enable the microphone for breath sending.
                if breath.micDenied {
                    Button(action: openSettings) {
                        VStack(spacing: 2) {
                            Text("allow microphone for breath sending")
                                .font(.system(size: 11, design: .serif).italic())
                                .foregroundColor(Self.lavender.opacity(0.7))
                            Text("tap to enable in Settings")
                                .font(.system(size: 10))
                                .foregroundColor(Self.lavender.opacity(0.5))
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                    .transition(.opacity)
                }
            }
            .padding(.bottom, 4)
            .animation(.easeOut(duration: 0.25), value: showAimHint)
            .animation(.easeOut(duration: 0.3), value: breath.micDenied)
        }
        .frame(width: 370, height: 370)
        .onAppear {
            seedParticles()
            withAnimation(AnimationSystem.easeInOutSine(2.2)
                            .repeatForever(autoreverses: true)) {
                gatherPulse = true
            }
        }
        // The mic listens only while a thought is loaded
        .onChange(of: loadedToken) { _, token in
            if token != nil {
                breath.onExhale = { exhaleDetected() }
                breath.start()
            } else {
                breath.stop()
                holdProgress = 0
            }
        }
        .onDisappear { breath.stop() }
        // Gentle drift — every particle wanders, leaning toward them
        .onReceive(driftTick) { _ in driftParticles() }
        // Fallback hold-to-send (mic denied): within 15° for 2 s
        .onReceive(holdTick) { _ in fallbackHoldTick() }
    }

    private var instruction: String {
        if usingBreath {
            if charge > 0.1 { return "keep breathing…" }
            return aligned ? "breathe toward \(personName)"
                           : "point toward \(personName), then breathe"
        } else {
            if charge > 0.05 { return "keep holding…" }
            return "hold toward \(personName)"
        }
    }

    // ── The listening arc ────────────────────────────────────────────────

    /// A soft arc around the instrument's bottom that shows the live mic
    /// level: very dim lavender in silence, brightening with breath, full
    /// glow on a strong steady exhale. It makes the instrument feel like
    /// it's listening for you.
    private var breathArc: some View {
        // Bottom third of the ring (≈ 120° centred on the bottom).
        Circle()
            .trim(from: 0.34, to: 0.66)
            .stroke(
                Self.lavender.opacity(0.18 + liveLevel * 0.7),
                style: StrokeStyle(lineWidth: 3 + CGFloat(liveLevel) * 4, lineCap: .round)
            )
            .frame(width: 320, height: 320)
            .blur(radius: 1.5)
            .shadow(color: Self.warmWhite.opacity(liveLevel * 0.8),
                    radius: 6 + liveLevel * 16)
            .animation(AnimationSystem.easeInOutSine(0.25), value: liveLevel)
            .allowsHitTesting(false)
    }

    /// Open the iOS Settings page for Pointward so the user can grant the
    /// microphone. Wind keeps working via hold-to-send regardless.
    private func openSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }

    // ── Particles ─────────────────────────────────────────────────────────

    private func seedParticles() {
        particles = (0..<16).map { _ in
            Particle(offset: CGSize(width: .random(in: -150...150),
                                    height: .random(in: -150...150)),
                     size: .random(in: 2.5...5),
                     white: Bool.random(),
                     opacity: .random(in: 0.15...0.4))
        }
    }

    /// While charging, particles pull in toward the loaded thought.
    private func gatheredOffset(_ particle: Particle) -> CGSize {
        let pull = CGFloat(charge) * (loadedToken != nil ? 0.7 : 0)
        return CGSize(width: particle.offset.width * (1 - pull),
                      height: particle.offset.height * (1 - pull))
    }

    /// Each particle drifts gently toward the person's bearing, wandering
    /// like seeds on a slow current — respawning behind when it leaves.
    private func driftParticles() {
        let lean = CGSize(width: CGFloat(sin(rad)) * 16,
                          height: -CGFloat(cos(rad)) * 16)
        for index in particles.indices {
            var next = CGSize(
                width: particles[index].offset.width + lean.width + .random(in: -7...7),
                height: particles[index].offset.height + lean.height + .random(in: -7...7)
            )
            // Left the circle → drift back in from the opposite side
            let distance = sqrt(next.width * next.width + next.height * next.height)
            if distance > 168 {
                next = CGSize(width: -next.width * 0.85 + .random(in: -20...20),
                              height: -next.height * 0.85 + .random(in: -20...20))
            }
            withAnimation(AnimationSystem.easeInOutSine(0.8)) {
                particles[index].offset = next
            }
        }
    }

    // ── Release paths ─────────────────────────────────────────────────────

    /// Breath path: a detected exhale releases — if aimed.
    private func exhaleDetected() {
        guard loadedToken != nil else { return }
        guard aligned else {
            showAimHint = true
            HapticEngine.sendSoft()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation { showAimHint = false }
            }
            return
        }
        HapticEngine.send()
        onSend()
    }

    /// Fallback path (mic denied): hold steady within 15° for 2 seconds.
    private func fallbackHoldTick() {
        guard loadedToken != nil, breath.micDenied else {
            if !usingBreath && holdProgress > 0 { holdProgress = 0 }
            return
        }
        if aligned {
            holdProgress = min(1, holdProgress + 0.05 / 2.0)
            if Date.now.timeIntervalSince(lastPulseHaptic) >= 0.5 {
                lastPulseHaptic = .now
                HapticEngine.sendSoft()
            }
            if holdProgress >= 1 {
                holdProgress = 0
                HapticEngine.send()
                onSend()
            }
        } else if holdProgress > 0 {
            withAnimation(.easeOut(duration: 0.5)) { holdProgress = 0 }
        }
    }
}
