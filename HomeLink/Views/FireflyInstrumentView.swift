// FireflyInstrumentView.swift
// Pointward › Views
//
// ⛔️ SUPERSEDED — the firefly's hold-to-send was the compass mechanic in
// different clothes, so the slot became WIND 🌬️ (WindInstrumentView).
// View kept for reference; nothing routes here anymore.
//
// INSTRUMENT 3 — FIREFLY (Pro). A dark atmospheric circle, no rose —
// just a warm living light drifting toward the person. Load a thought,
// hold the phone toward them, and over two seconds the light brightens
// until it releases itself. Gentle encouragement, never penalty.

// ───────────────────────────────────────────────────────────────────────────
// [cleanup 2026-06-13] ORPHAN — entire file disabled, not deleted (per CLAUDE.md
// never-delete rule). FireflyInstrumentView has ZERO live callers (its only
// remaining mention is a commented-out line in CompassView); it was SUPERSEDED
// by WindCompassFace / WindInstrumentView (the firefly slot became WIND 🌬️).
// Wrapped in `#if false` so the code is preserved verbatim but excluded from
// compilation.
// ───────────────────────────────────────────────────────────────────────────
#if false

import SwiftUI
import Combine

struct FireflyInstrumentView: View {

    let loadedToken: String?
    let loadedSymbol: AnyView?
    let bearingDegrees: Double
    let personName: String
    let onSend: () -> Void

    @State private var pulse = false
    @State private var drift: CGSize = .zero
    @State private var trail: [CGSize] = []
    @State private var holdProgress: Double = 0     // 0…1 over 2 s
    @State private var lastPulseHaptic = Date.distantPast

    private let tick = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    private let driftTick = Timer.publish(every: 0.9, on: .main, in: .common).autoconnect()

    private static let green = Color(hex: "#90EE90")

    private var rad: Double { bearingDegrees * .pi / 180 }
    private var alignDiff: Double { BearingCalculator.alignmentError(relativeBearing: bearingDegrees) }
    private var aligned: Bool { BearingCalculator.isSendAligned(bearingDegrees) }

    var body: some View {
        ZStack {
            // ── The dark atmosphere — no rose, just night ──
            Circle()
                .fill(
                    RadialGradient(colors: [Color(hex: "#161226"), Color(hex: "#0d0d14")],
                                   center: .center, startRadius: 30, endRadius: 185)
                )
                .overlay(Circle().stroke(Color.white.opacity(0.06), lineWidth: 1))
                .frame(width: 360, height: 360)

            // ── Faint trail — 3 dots remembering where the light was ──
            ForEach(Array(trail.enumerated()), id: \.offset) { index, position in
                Circle()
                    .fill(Self.green.opacity(0.10 - Double(index) * 0.03))
                    .frame(width: 5, height: 5)
                    .blur(radius: 1.5)
                    .offset(position)
            }

            // ── The firefly — drifting toward them, breathing ──
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(colors: [Self.green.opacity(0.9),
                                                Self.green.opacity(0.30), .clear],
                                       center: .center, startRadius: 3,
                                       endRadius: 16 + holdProgress * 16)
                    )
                    .frame(width: 34 + holdProgress * 22,
                           height: 34 + holdProgress * 22)
                    .blur(radius: 2)
                if let loadedSymbol {
                    loadedSymbol
                        .scaleEffect(0.7 + holdProgress * 0.25)
                        .opacity(0.55 + holdProgress * 0.45)
                }
            }
            .scaleEffect((pulse ? 1.1 : 0.9) * (1.0 + holdProgress * 0.3))
            .shadow(color: Self.green.opacity(0.4 + holdProgress * 0.5),
                    radius: 12 + holdProgress * 16)
            .offset(drift)

            // ── Instruction ──
            VStack {
                Spacer()
                if loadedToken != nil {
                    Text(aligned
                         ? (holdProgress > 0.05 ? "keep holding…" : "hold steady")
                         : "hold toward \(personName) to send")
                        .font(.system(size: 12, design: .serif).italic())
                        .foregroundColor(aligned ? Self.green.opacity(0.9)
                                                 : Color(hex: "#c4a8d4").opacity(0.8))
                }
            }
            .padding(.bottom, 4)
        }
        .frame(width: 370, height: 370)
        .onAppear {
            withAnimation(AnimationSystem.easeInOutSine(4.0)
                            .repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        // The hold: brighten over 2 s while aligned, dim gently when not
        .onReceive(tick) { _ in
            guard loadedToken != nil else {
                if holdProgress > 0 { holdProgress = 0 }
                return
            }
            if aligned {
                holdProgress = min(1, holdProgress + 0.05 / 2.0)
                // Warm pulse every 500 ms while building
                if Date.now.timeIntervalSince(lastPulseHaptic) >= 0.5 {
                    lastPulseHaptic = .now
                    HapticEngine.sendSoft()
                }
                if holdProgress >= 1 {
                    holdProgress = 0
                    HapticEngine.send()   // the release
                    onSend()
                }
            } else if holdProgress > 0 {
                withAnimation(.easeOut(duration: 0.5)) { holdProgress = 0 }
            }
        }
        // Organic drift — a few px of wander, leaning toward the person
        .onReceive(driftTick) { _ in
            trail.insert(drift, at: 0)
            if trail.count > 3 { trail.removeLast() }
            let lean = CGSize(width: CGFloat(sin(rad)) * 26,
                              height: -CGFloat(cos(rad)) * 26)
            withAnimation(AnimationSystem.easeInOutSine(0.9)) {
                drift = CGSize(width: lean.width + .random(in: -5...5),
                               height: lean.height + .random(in: -5...5))
            }
        }
    }
}

#endif  // [cleanup 2026-06-13] end ORPHAN FireflyInstrumentView
