// BirthdayCakeSendAnimationV2.swift
// Pointward › Instruments › _Shared › EmojiReveal
//
// V2 — the full-screen birthday SEND (Screen 3). The lit cake sits centred over
// a warm afterglow; a soft, premium CONFETTI BURST blooms outward — rounded
// ovals and rounded rectangles in gold/lavender/pink/white, tumbling as they
// fly — then drifts and fades while the cake settles. Celebratory, never harsh.
//
//   PHASE 1 (0.0–0.4s)  cake + tall flaring flames + warm afterglow cloud
//   PHASE 2 (0.4–1.5s)  confetti burst expands outward (firework timing, soft
//                       shapes); birthday_confetti plays
//   PHASE 3 (1.5–2.5s)  confetti drifts/fades; cake gently drifts; afterglow
//   → finishSend pipeline (NOT EmojiRevealView)                        = 2.5s
//
// Screen-coordinate rules: GeometryReader root, .ignoresSafeArea() background.

import SwiftUI

struct BirthdayCakeSendAnimationV2: View {
    var emoji: String = "🎂"
    var onComplete: () -> Void = {}

    private static let burstAt: Double = 0.4
    private static let driftAt: Double = 1.5
    private static let total:   Double = 2.5

    // [tweak] RISE-IN entrance — the cake rises up into its start position over
    // riseDur (ease-out), THEN the existing send sequence begins, unchanged.
    private static let riseDur:  Double = 0.6
    private static let riseFrac: CGFloat = 0.22   // of screen height it rises through

    // Confetti pieces — index-derived (no render-time randomness).
    private struct Confetti { let angle: Double; let speed: CGFloat; let color: Color; let oval: Bool; let spin: Double }
    private static let pieces: [Confetti] = {
        var out: [Confetti] = []
        let cols = [BirthdayCakeV2.gold, BirthdayCakeV2.lavender, BirthdayCakeV2.pink, Color.white]
        for i in 0..<44 {
            out.append(Confetti(
                angle: (Double(i) / 44) * 2 * .pi + Double(i % 4) * 0.18,
                speed: CGFloat(0.6 + Double((i * 23) % 40) / 100.0),
                color: cols[i % cols.count],
                oval: i % 2 == 0,
                spin: (i % 2 == 0 ? 1.0 : -1.0) * (220 + Double((i * 17) % 180))))
        }
        return out
    }()

    @State private var start: Date? = nil
    @State private var appearAt: Date? = nil
    @State private var confettiFired = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let center = CGPoint(x: w / 2, y: h * 0.44)
            TimelineView(.animation) { timeline in
                let e = elapsed(now: timeline.date)
                // [tweak] rise-in: the cake sits lower and rises into `center`.
                let riseY = riseOffset(now: timeline.date, h: h)
                let cakeCenter = CGPoint(x: center.x, y: center.y + riseY)
                ZStack {
                    Color(hex: "#06070c").ignoresSafeArea()
                    LinearGradient(colors: [Color(hex: "#06070c"), Color(hex: "#111526"), Color(hex: "#181324")],
                                   startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()

                    afterglow(center: center, e: e)
                    cake(center: cakeCenter, e: e)
                    confetti(center: center, w: w, h: h, e: e)
                }
                .frame(width: w, height: h)
                .onChange(of: e) { _, v in
                    if !confettiFired && v >= Self.burstAt {
                        confettiFired = true
                        InstrumentSoundPlayer.shared.playCue(file: "birthday_confetti", duration: 1.0)
                        HapticEngine.connectionFelt()
                    }
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            appearAt = Date()
            // Warm "Happy Birthday to You" music-box melody plays throughout the send.
            InstrumentSoundPlayer.shared.playCue(file: BirthdaySounds.melodyFile,
                                                 duration: BirthdaySounds.melodyDuration)
            HapticPattern.singleSoft.fire()
            // [tweak] the cake rises in first; only AFTER riseDur does the
            // existing send clock start, so the rest plays exactly as before.
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.riseDur) {
                start = Date()
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.total) { onComplete() }
            }
        }
    }

    private func elapsed(now: Date) -> Double {
        guard let start else { return 0 }
        return min(max(0, now.timeIntervalSince(start)), Self.total)
    }

    /// [tweak] The cake's downward offset during the rise-in: from `riseFrac` of
    /// the screen height up to 0 (ease-out) over `riseDur`, then it stays at 0.
    private func riseOffset(now: Date, h: CGFloat) -> CGFloat {
        guard let appearAt else { return h * Self.riseFrac }
        let p = min(1, max(0, now.timeIntervalSince(appearAt) / Self.riseDur))
        return (1 - CGFloat(easeOut(p))) * h * Self.riseFrac
    }

    // ── Warm afterglow cloud (pink + lavender + gold soft circles) ───────────

    @ViewBuilder
    private func afterglow(center: CGPoint, e: Double) -> some View {
        let pulse = 1 + CGFloat(sin(e * 2)) * 0.04
        let driftFade: Double = e > Self.driftAt ? max(0, 1 - (e - Self.driftAt) / (Self.total - Self.driftAt)) : 1
        ZStack {
            Circle().fill(BirthdayCakeV2.pink.opacity(0.18 * driftFade))
                .frame(width: 280, height: 280).blur(radius: 40).offset(x: -30, y: 10)
            Circle().fill(BirthdayCakeV2.lavender.opacity(0.18 * driftFade))
                .frame(width: 300, height: 300).blur(radius: 44).offset(x: 36, y: -8)
            Circle().fill(BirthdayCakeV2.warmGold.opacity(0.16 * driftFade))
                .frame(width: 240, height: 240).blur(radius: 38)
        }
        .scaleEffect(pulse)
        .position(center)
        .blendMode(.screen)
        .allowsHitTesting(false)
    }

    // ── The cake — all candles flaring; gentle drift in phase 3 ──────────────

    @ViewBuilder
    private func cake(center: CGPoint, e: Double) -> some View {
        let scale: CGFloat = 1.25
        let drift: CGFloat = e > Self.driftAt ? CGFloat((e - Self.driftAt) / (Self.total - Self.driftAt)) * -18 : 0
        let c = CGPoint(x: center.x, y: center.y + drift)
        ZStack {
            BirthdayCakeBody(center: c, scale: scale)
            ForEach(0..<BirthdayCakeV2.candleCount, id: \.self) { i in
                let cd = BirthdayCakeV2.candle(i, center: c, scale: scale)
                // candle stick
                RoundedRectangle(cornerRadius: 3 * scale).fill(cd.color)
                    .frame(width: cd.width, height: cd.bottomY - cd.wickY)
                    .position(x: cd.x, y: (cd.bottomY + cd.wickY) / 2)
                // tall flaring flame
                let flare = 1.25 + CGFloat(sin(e * 6 + Double(i))) * 0.12
                BirthdayFlame(lit: 1, lean: 0, sway: sin(e * 3 + Double(i)) * 2, scale: scale * flare)
                    .position(x: cd.x, y: cd.wickY - 11 * scale)
            }
        }
    }

    // ── Confetti burst ───────────────────────────────────────────────────────

    @ViewBuilder
    private func confetti(center: CGPoint, w: CGFloat, h: CGFloat, e: Double) -> some View {
        if e >= Self.burstAt {
            let local = e - Self.burstAt                          // 0 … 2.1
            let span = Self.total - Self.burstAt
            ForEach(0..<Self.pieces.count, id: \.self) { i in
                let pc = Self.pieces[i]
                let p = local / span                              // 0…1
                let dist = CGFloat(easeOut(min(1, local / 0.9))) * 230 * pc.speed
                let gravity = CGFloat(p * p) * h * 0.32
                let x = center.x + CGFloat(cos(pc.angle)) * dist
                let y = center.y + CGFloat(sin(pc.angle)) * dist + gravity
                let fade = 1 - easeIn(min(1, max(0, (Double(p) - 0.4) / 0.6)))
                confettiPiece(pc: pc, x: x, y: y, rot: local * pc.spin, fade: fade)
            }
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func confettiPiece(pc: Confetti, x: CGFloat, y: CGFloat, rot: Double, fade: Double) -> some View {
        Group {
            if pc.oval {
                Ellipse().fill(pc.color.opacity(fade))
                    .frame(width: 9, height: 6)
            } else {
                RoundedRectangle(cornerRadius: 2).fill(pc.color.opacity(fade))
                    .frame(width: 8, height: 8)
            }
        }
        .rotationEffect(.degrees(rot))
        .position(x: x, y: y)
    }

    private func easeOut(_ t: Double) -> Double { let x = min(max(t,0),1); return 1 - pow(1 - x, 3) }
    private func easeIn(_ t: Double) -> Double { let x = min(max(t,0),1); return x * x }
}
