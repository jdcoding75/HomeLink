// CompassReceiptAnimation.swift
// Pointward › Instruments › Compass
//
// ACT 3 of 3 — the full-screen COMPASS receipt (SIMPLE REVEAL) + emoji reveal.
//
// The compass's own calm arrival: a soft glowing thought (the orb carrying the
// emoji) drifts IN AT AN ANGLE from the sender's bearing, the receiver's OWN
// compass face turns its needle to meet it, and the orb SETTLES INTO the centre
// of the compass — sinking in with a gentle ring pulse — then hands off to the
// shared EmojiRevealView. This is a SIMPLE REVEAL: no bucket, no spin-to-catch,
// no phone-aiming. The thought comes in, settles into the compass, reveals.
//
//   ARRIVE  (2.00s)  orb edge → compass centre, grows 0.5 → 1.0; the needle
//                    swings to face the incoming bearing (easeInOut)
//   SETTLE  (1.00s)  the orb sinks into the face — scale → 0, soft flash, the
//                    ring pulses, the needle locks
//   → EmojiRevealView (the reveal)                                       ≈ 3.0s
//
// SHARED GRAPHIC (single source of truth): the SAME compass the app's face uses
// — SkinFaceView(.minimal) (the plain/clean skin) + NeedleView. No bespoke dial.
//
// Screen-coordinate rules (InstrumentBoundaries): GeometryReader root, background
// .ignoresSafeArea(), every position derived from geo.size.

import SwiftUI

struct CompassReceiptAnimation: View {

    // ── Receives (parity with the other receipts) ───────────────────────────
    let senderBearing: Double      // degrees the thought arrives FROM
    let emoji: String
    var message: String? = nil
    var tagline: String? = nil
    let fromName: String
    /// Fired the moment the orb settles and the reveal begins ("felt means
    /// felt"). Distinct from onFinished (the dismiss).
    var onRevealed: () -> Void = {}
    var onFinished: () -> Void = {}

    // ── Source-of-truth timing + sound (live beside the instrument) ─────────
    static let duration: Double = InstrumentBoundaries.Receipt.compass   // 1.5 (base)
    static let soundFile: String = CompassSounds.receiptFile
    static let soundDuration: Double = CompassSounds.receiptDuration
    static let revealLinger: Double = InstrumentBoundaries.Reveal.linger

    // Phase boundaries (seconds). Calm and clean.
    private static let arriveDur: Double = 2.0
    private static let settleDur: Double = 1.0
    private static let total:     Double = arriveDur + settleDur   // 3.0

    private static let lavender = Color(hex: "#c4a8d4")

    // ── Animation state ──────────────────────────────────────────────────────
    @State private var arrive: CGFloat = 0        // 0 edge → 1 compass centre
    @State private var sink: CGFloat = 0          // 0 present → 1 sunk into face
    @State private var needleBearing: Double = 0  // the face turns to meet it
    @State private var faceLocked = false
    @State private var ringPulse = false
    @State private var flash = false
    @State private var revealing = false

    private var hue: Color { EmojiHue.color(for: emoji) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if revealing {
                    // THE PEAK — the ONE shared reveal screen, on the compass
                    // ambient (soft glow pulse on deep purple). The emoji sound
                    // + reveal haptic fire INSIDE this view.
                    EmojiRevealView(emoji: emoji, message: message,
                                    tagline: tagline,
                                    context: .received(fromName: fromName),
                                    ambient: .compass,
                                    onDismiss: onFinished)
                        .transition(.opacity)
                } else {
                    ZStack {
                        background(geo: geo)
                        compassFace(geo: geo)
                        orb(geo: geo)
                        label(geo: geo)
                        // A soft white settle flash over everything.
                        Color.white.opacity(flash ? 0.18 : 0)
                            .ignoresSafeArea().allowsHitTesting(false)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .onAppear { run() }
    }

    // ── Geometry ─────────────────────────────────────────────────────────────

    /// The compass sits a touch above centre so the caption has room below.
    private func compassCenter(_ size: CGSize) -> CGPoint {
        CGPoint(x: size.width / 2, y: size.height * 0.46)
    }

    /// The orb enters off-screen FROM the sender's bearing (screen convention:
    /// 0° = up, x = sin, y = -cos).
    private func entryPoint(_ size: CGSize) -> CGPoint {
        let rad = senderBearing * .pi / 180
        let c = compassCenter(size)
        return CGPoint(x: c.x + CGFloat(sin(rad)) * size.width * 0.85,
                       y: c.y - CGFloat(cos(rad)) * size.height * 0.60)
    }

    private func orbPoint(_ size: CGSize) -> CGPoint {
        let from = entryPoint(size)
        let to = compassCenter(size)
        return CGPoint(x: from.x + (to.x - from.x) * arrive,
                       y: from.y + (to.y - from.y) * arrive)
    }

    // ── Background — calm deep-purple glow (compass world) ───────────────────

    private func background(geo: GeometryProxy) -> some View {
        ZStack {
            Color(hex: "#0d0d14").ignoresSafeArea()
            RadialGradient(
                colors: [Color(hex: "#7c6b8e").opacity(0.30),
                         Color(hex: "#3a2f4a").opacity(0.18),
                         Color(hex: "#0d0d14")],
                center: .center,
                startRadius: 30, endRadius: max(geo.size.width, geo.size.height) * 0.7)
                .ignoresSafeArea()
        }
        .allowsHitTesting(false)
    }

    // ── The shared compass face (plain/clean = minimal skin) ─────────────────

    private func compassFace(geo: GeometryProxy) -> some View {
        ZStack {
            // The SAME face graphic the app's compass uses (single source of
            // truth): the minimal skin dial + the shared needle.
            SkinFaceView(skin: .minimal, bearing: needleBearing, locked: faceLocked,
                         quietMode: false, pingRingActive: ringPulse)
            NeedleView(bearing: needleBearing, skin: .minimal, locked: faceLocked,
                       quietMode: false)
        }
        .frame(width: 240, height: 240)
        // A whisper of warmth as the thought settles in.
        .overlay(
            Circle()
                .fill(hue.opacity(Double(sink) * 0.18))
                .frame(width: 180, height: 180)
                .blur(radius: 36)
        )
        .position(compassCenter(geo.size))
    }

    // ── The incoming thought (orb carrying the emoji) ────────────────────────

    private func orb(geo: GeometryProxy) -> some View {
        let size = geo.size
        let p = orbPoint(size)
        // Grows as it arrives, then shrinks to nothing as it sinks into the face.
        let scale = (0.5 + 0.5 * arrive) * (1 - sink)
        let opacity = Double(1 - sink)
        return ZStack {
            // Soft trailing glow.
            Circle()
                .fill(hue.opacity(0.30 * opacity))
                .frame(width: 120, height: 120).blur(radius: 26)
            // The orb body.
            Circle()
                .fill(RadialGradient(colors: [hue.opacity(0.95), hue.opacity(0.35), .clear],
                                     center: .center, startRadius: 4, endRadius: 36))
                .frame(width: 72, height: 72)
            Text(emoji).font(.system(size: 40)).opacity(0.95)
        }
        .scaleEffect(scale)
        .opacity(opacity)
        .position(p)
        .allowsHitTesting(false)
    }

    // ── Caption ──────────────────────────────────────────────────────────────

    @ViewBuilder
    private func label(geo: GeometryProxy) -> some View {
        VStack {
            Spacer()
            Text(messageLine)
                .font(.system(size: 20, design: .serif).italic())
                .foregroundColor(Self.lavender)
                .shadow(color: .black.opacity(0.5), radius: 6)
                .padding(.bottom, geo.size.height * 0.10)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.5), value: messageLine)
        }
        .allowsHitTesting(false)
    }

    private var messageLine: String {
        let name = fromName.isEmpty ? "someone" : fromName
        if sink > 0.01      { return "almost here ✦" }
        if arrive < 0.9     { return "\(name) is thinking of you ✦" }
        return "arriving ✦"
    }

    // ── Sequencing ──────────────────────────────────────────────────────────

    private func run() {
        // The warm compass receipt chime (compass_receipt.wav, 1.5s) plays at
        // the START of the receipt screen — a soft, warm welcome as the thought
        // arrives. Safe no-op if the file is ever missing.
        InstrumentSoundPlayer.shared.playReceipt(.compass)
        HapticPattern.singleSoft.fire()

        // ARRIVE — the orb drifts in; the needle turns to meet the bearing.
        withAnimation(.easeInOut(duration: Self.arriveDur)) { arrive = 1 }
        needleBearing = senderBearing          // NeedleView animates the swing

        // SETTLE — the orb sinks into the face; ring pulses; needle locks.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.arriveDur) {
            faceLocked = true
            ringPulse = true
            HapticPattern.doubleSoft.fire()
            // [removed] The settle no longer re-triggers the receipt chime — the
            // warm welcome now plays once at the START via playReceipt(.compass)
            // above. Re-playing the same file here would double the tone.
            // InstrumentSoundPlayer.shared.playCue(file: CompassSounds.receiptFile,
            //                                      duration: 0.5)
            withAnimation(.easeOut(duration: 0.12)) { flash = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                withAnimation(.easeIn(duration: 0.25)) { flash = false }
            }
            withAnimation(.easeIn(duration: Self.settleDur * 0.8)) { sink = 1 }
        }

        // → the shared reveal. "Felt means felt" fires here.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.total) {
            onRevealed()
            withAnimation(.easeInOut(duration: 0.3)) { revealing = true }
        }
    }
}
