// WindReceiptAnimation.swift
// Pointward › Instruments › Wind
//
// ACT 3 of 3 — the full-screen WIND receipt journey + emoji reveal.
//
// A leaf arrives FROM the sender's bearing onto the same daytime sky the
// compass face and the send used, wanders a lazy S-curve shedding seeds, then
// tips into the shared wooden bucket — AUTO-CATCH, no user interaction (the
// wind finds you). The bucket land hands off to the shared EmojiRevealView, the
// emotional peak, where the emoji's own sound + reveal haptic fire.
//
//   ENTER    (0.8s)  TOP → centre — a full fall, grows 0.5 → 1.0, easeOut
//   DRIFT    (4.0s)  lazy S-curve (W*0.36 / H*0.15), seeds stream, messages
//   APPROACH (1.5s)  toward the bucket, scale 1.0 → 0.65, easeInOut
//   LAND     (0.9s)  tips in: rotate −85°, scale 0.65 → 0.25, fade, seed burst
//   → EmojiRevealView (the reveal)                                      = 7.2s
//
// ENTRY RULE (differs from send): the leaf arrives FROM the sender's bearing
// (real GPS or symbolic) — it does NOT match the compass-face exit bearing.
// The receipt is its own emotional moment.

import SwiftUI

struct WindReceiptAnimation: View {

    // ── Receives ─────────────────────────────────────────────────────────
    let senderBearing: Double      // degrees the thought arrives FROM
    let emoji: String
    var message: String? = nil
    var tagline: String? = nil
    let fromName: String
    /// Fired the moment the leaf lands and the reveal begins ("felt means
    /// felt" — the read receipt). Distinct from onFinished (the dismiss).
    var onRevealed: () -> Void = {}
    /// The reveal was dismissed (tap) — the receipt is complete.
    var onFinished: () -> Void = {}

    // ── Source-of-truth timing + sound (live beside the instrument) ──────
    static let duration: Double = InstrumentBoundaries.Receipt.wind   // 7.2
    static let soundFile: String = WindSounds.receiptFile
    static let soundDuration: Double = WindSounds.receiptDuration
    static let revealLinger: Double = InstrumentBoundaries.Reveal.linger

    // Phase boundaries (seconds). 0.8 + 4.0 + 1.5 + 0.9 = 7.2.
    private static let enterDur:    Double = 0.8
    private static let driftDur:    Double = 4.0
    private static let approachDur: Double = 1.5
    private static let landDur:     Double = 0.9
    private static let enterEnd:    Double = enterDur                           // 0.8
    private static let driftEnd:    Double = enterDur + driftDur                // 4.8
    private static let approachEnd: Double = enterDur + driftDur + approachDur  // 6.3
    private static let total:       Double = approachEnd + landDur              // 7.2

    // Drift S-curve geometry (per spec).
    private static let driftWidthAmp:  CGFloat = 0.36   // × screen width
    private static let driftHeightAmp: CGFloat = 0.15   // × screen height

    // Bucket — the shared skin across ALL instruments.
    private static let bucketW: CGFloat = 150
    private static let bucketH: CGFloat = 128

    private static let leafW: CGFloat = 200
    private static let leafH: CGFloat = 124

    private static let leafGreen     = Color(hex: "#5a8a3a")
    private static let leafGreenLite = Color(hex: "#6fae4a")
    private static let cloudColor    = Color(hex: "#FFFAF0")
    private static let wood          = Color(hex: "#8B4513")
    private static let woodDark      = Color(hex: "#6E3A1E")
    private static let brass         = Color(hex: "#C9A86A")

    @State private var start: Date? = nil
    @State private var skyIn = false       // 300 ms crossfade from the send sky
    @State private var seedBurst = false   // 4 seeds burst out on bucket land
    @State private var revealing = false   // crossed into the reveal

    private var rad: Double { senderBearing * .pi / 180 }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if revealing {
                    // THE PEAK — the ONE shared reveal screen. context =
                    // .received (this is the recipient's side); ambient = .wind
                    // (daySky + drifting clouds, continuous with the receipt).
                    // The emoji sound + reveal haptic fire INSIDE this view.
                    EmojiRevealView(emoji: emoji, message: message,
                                    tagline: tagline,
                                    context: .received(fromName: fromName),
                                    ambient: .wind,
                                    onDismiss: onFinished)
                        .transition(.opacity)
                } else {
                    TimelineView(.animation) { timeline in
                        let elapsed = clampedElapsed(now: timeline.date)
                        ZStack {
                            // BACKGROUND — the same daytime sky, crossfaded in.
                            Color(hex: "#0d0d14").ignoresSafeArea()
                            InstrumentBackground.daySky
                                .ignoresSafeArea()
                                .opacity(skyIn ? 1 : 0)

                            clouds(geo: geo, elapsed: elapsed)
                            bucket(geo: geo)
                            seedTrail(geo: geo, elapsed: elapsed)
                            seedBurstView(geo: geo)
                            leaf(geo: geo, elapsed: elapsed)
                            messageView(geo: geo, elapsed: elapsed)
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
        .onAppear { begin() }
    }

    // ── Sequencing ────────────────────────────────────────────────────────

    private func begin() {
        start = Date()
        withAnimation(.easeInOut(duration: 0.3)) { skyIn = true }   // crossfade
        // The wind receipt sound starts at the very begin (7.2 s, matches).
        InstrumentSoundPlayer.shared.playReceipt(.firefly)

        // On arrival (the leaf reaches centre after ENTER).
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.enterEnd) {
            HapticPattern.singleSoft.fire()
        }
        // On bucket land — the leaf tips in.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.approachEnd) {
            HapticPattern.doubleSoft.fire()
            withAnimation(.easeOut(duration: 0.6)) { seedBurst = true }
        }
        // After landing → the emoji reveal. "Felt means felt" fires here.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.total) {
            onRevealed()
            withAnimation(.easeInOut(duration: 0.3)) { revealing = true }
        }
    }

    private func clampedElapsed(now: Date) -> Double {
        guard let start else { return 0 }
        return min(max(0, now.timeIntervalSince(start)), Self.total)
    }

    // ── The leaf ───────────────────────────────────────────────────────────

    @ViewBuilder
    private func leaf(geo: GeometryProxy, elapsed: Double) -> some View {
        let pos     = leafPos(geo: geo, elapsed: elapsed)
        let scale   = leafScale(elapsed: elapsed)
        let opacity = leafOpacity(elapsed: elapsed)
        let tilt    = leafTilt(geo: geo, elapsed: elapsed)
        ZStack {
            LeafShape()
                .fill(LinearGradient(colors: [Self.leafGreenLite, Self.leafGreen],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(LeafVeins().stroke(Color.white.opacity(0.18), lineWidth: 1))
                .shadow(color: Self.leafGreen.opacity(0.5), radius: 10, y: 4)
            Text(emoji).font(.system(size: 60))
        }
        .frame(width: Self.leafW, height: Self.leafH)
        .scaleEffect(scale)
        .rotationEffect(.degrees(tilt))
        .opacity(opacity)
        .position(pos)
    }

    /// The entry point — the leaf falls from the TOP of the screen.
    private func entryPoint(_ size: CGSize) -> CGPoint {
        // [tweak] Start at TOP-centre, above the screen edge, so the leaf does a
        // FULL fall straight down to centre (was: in from the sender's bearing
        // edge, which for many bearings started from a low/below-screen point).
        CGPoint(x: size.width / 2, y: -size.height * 0.15)
    }

    private func bucketPoint(_ size: CGSize) -> CGPoint {
        // Bucket at the bottom (RULE 6): height - bucketHeight - 6% margin.
        CGPoint(x: size.width / 2,
                y: size.height - Self.bucketH - size.height * 0.06)
    }

    private func leafPos(geo: GeometryProxy, elapsed: Double) -> CGPoint {
        let size   = geo.size
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        if elapsed <= Self.enterEnd {
            // ENTER — edge → centre, easeOut.
            return lerp(entryPoint(size), center, easeOut(elapsed / Self.enterDur))
        } else if elapsed <= Self.driftEnd {
            // DRIFT — lazy S-curve around centre.
            return driftPos(localT: elapsed - Self.enterEnd, size: size)
        } else if elapsed <= Self.approachEnd {
            // APPROACH — toward the bucket, easeInOut.
            let from = driftPos(localT: Self.driftDur, size: size)
            let p = easeInOut((elapsed - Self.driftEnd) / Self.approachDur)
            return lerp(from, bucketPoint(size), p)
        } else {
            // LAND — settle into the bucket mouth.
            return bucketPoint(size)
        }
    }

    private func driftPos(localT: Double, size: CGSize) -> CGPoint {
        // Swirl center = geo.size / 2 EXACTLY (RULE 4), same coefficients as the
        // send so the two acts feel like one continuous breeze.
        let sx = sin(localT * 0.72)
        let sy = sin(localT * 0.45 + 1.0)
        return CGPoint(x: size.width  / 2 + CGFloat(sx) * size.width  * Self.driftWidthAmp,
                       y: size.height / 2 + CGFloat(sy) * size.height * Self.driftHeightAmp)
    }

    private func leafScale(elapsed: Double) -> CGFloat {
        let breathe = 1 + CGFloat(sin(elapsed * 0.4)) * 0.03
        if elapsed <= Self.enterEnd {
            return (0.5 + 0.5 * CGFloat(easeOut(elapsed / Self.enterDur))) * breathe   // 0.5 → 1.0
        } else if elapsed <= Self.driftEnd {
            return breathe                                                              // ~1.0
        } else if elapsed <= Self.approachEnd {
            let p = easeInOut((elapsed - Self.driftEnd) / Self.approachDur)
            return (1.0 - 0.35 * CGFloat(p)) * breathe                                  // 1.0 → 0.65
        } else {
            let p = easeOut((elapsed - Self.approachEnd) / Self.landDur)
            return 0.65 - 0.40 * CGFloat(p)                                             // 0.65 → 0.25
        }
    }

    private func leafOpacity(elapsed: Double) -> Double {
        guard elapsed > Self.approachEnd else { return 1 }
        let p = easeOut((elapsed - Self.approachEnd) / Self.landDur)
        return 1 - p                                                                    // 1.0 → 0
    }

    /// Banks into the curve while travelling; tips to −85° as it lands.
    private func leafTilt(geo: GeometryProxy, elapsed: Double) -> Double {
        if elapsed > Self.approachEnd {
            let p = easeOut((elapsed - Self.approachEnd) / Self.landDur)
            return -85 * p                                                              // tip into the bucket
        }
        let ahead = leafPos(geo: geo, elapsed: min(Self.total, elapsed + 0.05))
        let here  = leafPos(geo: geo, elapsed: elapsed)
        return Double(max(-20, min(20, (ahead.x - here.x) * 0.5)))
    }

    // ── The bucket — shared wooden barrel + brass fittings ──────────────────

    private func bucket(geo: GeometryProxy) -> some View {
        let p = bucketPoint(geo.size)
        return ZStack {
            BucketHandleShape()
                .stroke(Self.brass, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: Self.bucketW * 0.9, height: 52)
                .offset(y: -Self.bucketH / 2 - 16)
            BucketShape()
                .fill(LinearGradient(colors: [Self.wood, Self.woodDark],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: Self.bucketW, height: Self.bucketH)
                .overlay(
                    VStack {
                        Capsule().fill(Self.brass).frame(height: 6)
                            .padding(.horizontal, -2).padding(.top, 12)
                        Spacer()
                        Capsule().fill(Self.brass).frame(height: 6)
                            .padding(.horizontal, 6).padding(.bottom, 14)
                    }
                    .frame(width: Self.bucketW, height: Self.bucketH)
                    .opacity(0.85)
                )
                .shadow(color: .black.opacity(0.4), radius: 10, y: 6)
        }
        .position(p)
    }

    // ── Seeds ────────────────────────────────────────────────────────────

    @ViewBuilder
    private func seedTrail(geo: GeometryProxy, elapsed: Double) -> some View {
        let count = InstrumentBoundaries.Particles.standard   // 20
        ForEach(0..<count, id: \.self) { k in
            let tb = elapsed - Double(k) * 0.05
            if tb > 0 && tb <= Self.approachEnd {
                let frac = Double(k) / Double(count)
                let p = leafPos(geo: geo, elapsed: tb)
                let jx = CGFloat(sin(tb * 9 + Double(k))) * 7
                let jy = CGFloat(cos(tb * 7 + Double(k))) * 7
                DandelionSeed(size: 9 - CGFloat(frac) * 4, opacity: (1 - frac) * 0.7)
                    .position(x: p.x + jx, y: p.y + jy)
                    .allowsHitTesting(false)
            }
        }
    }

    /// 4 seeds bursting up out of the bucket on land.
    @ViewBuilder
    private func seedBurstView(geo: GeometryProxy) -> some View {
        if seedBurst {
            let p = bucketPoint(geo.size)
            ForEach(0..<4, id: \.self) { i in
                let a = (Double(i) / 4) * 2 * .pi - .pi / 2
                DandelionSeed(size: 9, opacity: 0.8)
                    .position(x: p.x + CGFloat(cos(a)) * 60,
                              y: p.y - 40 + CGFloat(sin(a)) * 40)
                    .opacity(seedBurst ? 0 : 0.8)
                    .animation(.easeOut(duration: 0.8), value: seedBurst)
                    .allowsHitTesting(false)
            }
        }
    }

    // ── Clouds — same fluffy style as the send ──────────────────────────────

    private struct CloudSpec: Identifiable {
        let id = UUID()
        let y: CGFloat; let scale: CGFloat; let speed: Double; let phase: CGFloat
    }
    private static let cloudSpecs: [CloudSpec] = [
        CloudSpec(y: 0.14, scale: 0.70, speed: 12, phase: 0.10),
        CloudSpec(y: 0.28, scale: 1.05, speed:  8, phase: 0.55),
        CloudSpec(y: 0.44, scale: 0.85, speed: 10, phase: 0.30),
        CloudSpec(y: 0.60, scale: 0.55, speed: 14, phase: 0.78),
    ]

    @ViewBuilder
    private func clouds(geo: GeometryProxy, elapsed: Double) -> some View {
        let span = geo.size.width + 240
        ForEach(Self.cloudSpecs) { spec in
            let raw = spec.phase * span + CGFloat(elapsed * spec.speed)
            let x = raw.truncatingRemainder(dividingBy: span) - 120
            cloudShape
                .scaleEffect(spec.scale)
                .position(x: x, y: geo.size.height * spec.y)
                .opacity(0.55 + Double(spec.scale) * 0.18)
                .allowsHitTesting(false)
        }
    }

    private var cloudShape: some View {
        ZStack {
            Circle().frame(width: 64, height: 64).offset(x: -30)
            Circle().frame(width: 92, height: 92)
            Circle().frame(width: 70, height: 70).offset(x: 34, y: 6)
            Capsule().frame(width: 150, height: 50).offset(y: 18)
        }
        .foregroundColor(Self.cloudColor.opacity(0.78))
        .blur(radius: 4)
    }

    // ── Messages — patience, arriving ───────────────────────────────────────

    @ViewBuilder
    private func messageView(geo: GeometryProxy, elapsed: Double) -> some View {
        VStack {
            Spacer()
            Text(message(elapsed: elapsed))
                .font(.system(size: 20, design: .serif).italic())
                .foregroundColor(InstrumentBackground.accentText)
                .shadow(color: .black.opacity(0.4), radius: 6)
                .padding(.bottom, 200)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.5), value: message(elapsed: elapsed))
        }
    }

    private func message(elapsed: Double) -> String {
        let name = fromName.isEmpty ? "someone" : fromName
        let lt = elapsed - Self.enterEnd            // drift-local seconds
        if lt < 2.0   { return "\(name) is thinking of you ✦" }
        if lt < 3.5   { return "a feeling is on its way ✦" }
        return "almost here ✦"
    }

    // ── Easing + interpolation ──────────────────────────────────────────────

    private func easeOut(_ t: Double) -> Double {
        let x = min(max(t, 0), 1); return 1 - pow(1 - x, 3)
    }
    private func easeInOut(_ t: Double) -> Double {
        let x = min(max(t, 0), 1)
        return x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
    }
    private func lerp(_ a: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * CGFloat(t), y: a.y + (b.y - a.y) * CGFloat(t))
    }
}
