// FireworkSendAnimation.swift
// Pointward › Instruments › _Shared › EmojiReveal
//
// THE BIG MOMENT — the full-screen 🎆 send. A rocket streaks up into deep
// space, a scatter of small multicolour pops builds anticipation, then ONE
// enormous central supernova erupts — long radial arms in layered colours,
// expanding shockwave rings, a white-hot 4-point star core — before raining
// down curved, fading embers over a warm afterglow.
//
//   LAUNCH  (0.0–0.6s)  rocket rises from the bottom on a spark trail
//   POPS    (0.6–1.8s)  4–5 small bursts, staggered, different colours
//   BURST   (1.8–2.8s)  the massive central explosion (the WOW)
//   EMBERS  (2.8–4.0s)  curved falling embers + lingering afterglow
//   → finishSend (NOT EmojiRevealView)                                 = 4.0s
//
// Particles are index-derived (no render-time randomness) so the show is
// deterministic and cheap. Screen-coordinate rules: GeometryReader root,
// .ignoresSafeArea() background, all positions from geo.size.

import SwiftUI

struct FireworkSendAnimation: View {
    var emoji: String = "🎆"
    var onComplete: () -> Void = {}

    // Phase boundaries (seconds)
    private static let launchEnd: Double = 0.6
    private static let popsEnd:   Double = 1.8
    private static let burstAt:   Double = 1.8
    private static let burstEnd:  Double = 2.8
    private static let total:     Double = 4.0

    // Palette
    private static let gold     = Color(hex: "#ffeb3b")
    private static let amber    = Color(hex: "#fbc02d")
    private static let red       = Color(hex: "#f44336")
    private static let lavender = Color(hex: "#c4a8d4")
    private static let white     = Color.white
    private static let palette: [Color] = [gold, lavender, red, amber, white]

    // Background stars (fractional positions, size) — static.
    private static let stars: [(x: CGFloat, y: CGFloat, s: CGFloat, o: Double)] = {
        var out: [(x: CGFloat, y: CGFloat, s: CGFloat, o: Double)] = []
        for i in 0..<70 {
            out.append((x: CGFloat((i * 97) % 100) / 100,
                        y: CGFloat((i * 53) % 100) / 100,
                        s: CGFloat(1 + (i * 7) % 3),
                        o: 0.2 + Double((i * 13) % 10) / 35.0))
        }
        return out
    }()

    // Small pops: centre (frac), colour, start time.
    private static let smallPops: [(x: CGFloat, y: CGFloat, color: Color, start: Double)] = [
        (0.26, 0.30, gold,     0.6),
        (0.72, 0.26, lavender, 0.8),
        (0.40, 0.20, red,      1.0),
        (0.66, 0.46, amber,    1.2),
        (0.32, 0.50, white,    1.4),
    ]

    // Massive-burst arms — angle, colour, length factor.
    private static let armCount = 30
    private static let arms: [(angle: Double, color: Color, len: CGFloat)] = {
        var out: [(angle: Double, color: Color, len: CGFloat)] = []
        for i in 0..<armCount {
            out.append((angle: (Double(i) / Double(armCount)) * 2 * .pi,
                        color: palette[i % palette.count],
                        len: CGFloat(0.78 + Double((i * 31) % 22) / 100.0)))
        }
        return out
    }()

    // Falling embers — angle, speed, colour.
    private static let emberCount = 26
    private static let embers: [(angle: Double, speed: CGFloat, color: Color)] = {
        var out: [(angle: Double, speed: CGFloat, color: Color)] = []
        let cols = [gold, red, amber]
        for i in 0..<emberCount {
            out.append((angle: (Double(i) / Double(emberCount)) * 2 * .pi + Double(i % 3) * 0.2,
                        speed: CGFloat(0.55 + Double((i * 17) % 45) / 100.0),
                        color: cols[i % 3]))
        }
        return out
    }()

    @State private var start: Date? = nil
    @State private var popsSoundFired = false
    @State private var burstFired = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let cx = w / 2, burstCY = h * 0.42

            TimelineView(.animation) { timeline in
                let e = elapsed(now: timeline.date)
                ZStack {
                    // ── DEEP SPACE ──
                    Color(hex: "#080911").ignoresSafeArea()
                    starsLayer(w: w, h: h)
                    afterglow(cx: cx, cy: burstCY, e: e)

                    rocket(cx: cx, h: h, e: e)
                    rocketTrail(cx: cx, h: h, e: e)
                    smallPopsLayer(w: w, h: h, e: e)
                    burstArms(cx: cx, cy: burstCY, R: max(w, h), e: e)
                    burstRings(cx: cx, cy: burstCY, R: max(w, h), e: e)
                    burstCore(cx: cx, cy: burstCY, e: e)
                    embersLayer(cx: cx, cy: burstCY, h: h, e: e)
                }
                .frame(width: w, height: h)
                .onChange(of: e) { _, v in tick(v) }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            start = Date()
            InstrumentSoundPlayer.shared.playCue(file: "firework_launch", duration: 0.8)
            HapticEngine.thoughtLaunched()
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.total) { onComplete() }
        }
    }

    private func elapsed(now: Date) -> Double {
        guard let start else { return 0 }
        return min(max(0, now.timeIntervalSince(start)), Self.total)
    }

    private func tick(_ e: Double) {
        if !popsSoundFired && e >= Self.launchEnd {
            popsSoundFired = true
            InstrumentSoundPlayer.shared.playCue(file: "firework_small_pops", duration: 1.5)
        }
        if !burstFired && e >= Self.burstAt {
            burstFired = true
            InstrumentSoundPlayer.shared.playCue(file: "firework_big_burst", duration: 1.2)
            HapticPattern.singleHeavy.fire()
        }
    }

    // ── Background stars ──────────────────────────────────────────────────

    private func starsLayer(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            ForEach(0..<Self.stars.count, id: \.self) { i in
                let s = Self.stars[i]
                Circle().fill(Color.white.opacity(s.o))
                    .frame(width: s.s, height: s.s)
                    .position(x: s.x * w, y: s.y * h)
            }
        }
        .allowsHitTesting(false)
    }

    // ── PHASE 1 — the rocket rising ───────────────────────────────────────

    @ViewBuilder
    private func rocket(cx: CGFloat, h: CGFloat, e: Double) -> some View {
        if e < Self.launchEnd {
            let p = easeOut(e / Self.launchEnd)
            let y = h * 1.02 - (h * 0.60) * CGFloat(p)     // bottom → ~0.42h
            ZStack {
                RoundedRectangle(cornerRadius: 4).fill(LinearGradient(
                    colors: [Self.red, Color(hex: "#d32f2f")], startPoint: .top, endPoint: .bottom))
                    .frame(width: 10, height: 26)
                Triangle().fill(Self.gold).frame(width: 10, height: 9).offset(y: -17)
            }
            .position(x: cx, y: y)
            .opacity(1 - Double(max(0, (p - 0.85) / 0.15)))   // fades into the pops
        }
    }

    @ViewBuilder
    private func rocketTrail(cx: CGFloat, h: CGFloat, e: Double) -> some View {
        if e < Self.launchEnd {
            ForEach(0..<10, id: \.self) { k in
                let tb = e - Double(k) * 0.03
                if tb > 0 {
                    let p = easeOut(tb / Self.launchEnd)
                    let y = h * 1.02 - (h * 0.60) * CGFloat(p)
                    let frac = Double(k) / 10
                    Circle()
                        .fill((k % 2 == 0 ? Self.gold : Self.amber).opacity((1 - frac) * 0.7))
                        .frame(width: 7 - CGFloat(frac) * 4, height: 7 - CGFloat(frac) * 4)
                        .position(x: cx + CGFloat(sin(tb * 30)) * 3, y: y + 16 + CGFloat(k) * 3)
                        .blur(radius: 1)
                }
            }
        }
    }

    // ── PHASE 2 — small scattered pops ────────────────────────────────────

    @ViewBuilder
    private func smallPopsLayer(w: CGFloat, h: CGFloat, e: Double) -> some View {
        ForEach(0..<Self.smallPops.count, id: \.self) { i in
            let pop = Self.smallPops[i]
            let local = e - pop.start
            if local >= 0 && local < 0.6 {
                let p = local / 0.6
                let center = CGPoint(x: pop.x * w, y: pop.y * h)
                let radius = CGFloat(easeOut(p)) * 70
                let fade = 1 - p
                ZStack {
                    // radial streaks
                    ForEach(0..<10, id: \.self) { k in
                        let a = (Double(k) / 10) * 2 * .pi
                        Capsule()
                            .fill(pop.color.opacity(fade * 0.9))
                            .frame(width: 3, height: 12)
                            .offset(x: CGFloat(cos(a)) * radius, y: CGFloat(sin(a)) * radius)
                            .rotationEffect(.radians(a + .pi / 2),
                                            anchor: .center)
                    }
                    // spark dots
                    ForEach(0..<10, id: \.self) { k in
                        let a = (Double(k) / 10) * 2 * .pi + 0.3
                        Circle().fill(pop.color.opacity(fade))
                            .frame(width: 4, height: 4)
                            .offset(x: CGFloat(cos(a)) * radius * 1.15, y: CGFloat(sin(a)) * radius * 1.15)
                    }
                }
                .position(center)
                .allowsHitTesting(false)
            }
        }
    }

    // ── PHASE 3 — the massive central burst ───────────────────────────────

    @ViewBuilder
    private func burstArms(cx: CGFloat, cy: CGFloat, R: CGFloat, e: Double) -> some View {
        if e >= Self.burstAt {
            let local = (e - Self.burstAt) / (Self.total - Self.burstAt)   // 0…1 over the rest
            let grow = easeOut(min(1, local / 0.25))                       // arms shoot out fast
            let fade = 1 - easeIn(min(1, max(0, (local - 0.3) / 0.7)))
            let maxLen = R * 0.5
            ForEach(0..<Self.arms.count, id: \.self) { i in
                let arm = Self.arms[i]
                let len = maxLen * arm.len * CGFloat(grow)
                let tip = CGPoint(x: cx + CGFloat(cos(arm.angle)) * len,
                                  y: cy + CGFloat(sin(arm.angle)) * len)
                ZStack {
                    // the arm line (drawn as a thin capsule from centre to tip)
                    Path { p in p.move(to: CGPoint(x: cx, y: cy)); p.addLine(to: tip) }
                        .stroke(arm.color.opacity(fade * 0.85),
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    // spark dot at the tip
                    Circle().fill(arm.color.opacity(fade))
                        .frame(width: 6, height: 6)
                        .position(tip)
                        .shadow(color: arm.color.opacity(fade * 0.8), radius: 5)
                }
            }
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func burstRings(cx: CGFloat, cy: CGFloat, R: CGFloat, e: Double) -> some View {
        if e >= Self.burstAt {
            let local = e - Self.burstAt
            ForEach(0..<4, id: \.self) { k in
                let rl = local - Double(k) * 0.12
                if rl > 0 && rl < 0.9 {
                    let p: Double = rl / 0.9
                    let ringColor: Color = Self.palette[k % Self.palette.count].opacity((1 - p) * 0.5)
                    let lw: CGFloat = CGFloat(3 * (1 - p) + 0.5)
                    let diameter: CGFloat = CGFloat(easeOut(p)) * R
                    Circle()
                        .stroke(ringColor, lineWidth: lw)
                        .frame(width: diameter, height: diameter)
                        .position(x: cx, y: cy)
                }
            }
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func burstCore(cx: CGFloat, cy: CGFloat, e: Double) -> some View {
        if e >= Self.burstAt {
            let local = e - Self.burstAt
            let pop = easeOut(min(1, local / 0.15))
            let fade = 1 - easeIn(min(1, max(0, (local - 0.25) / 0.6)))
            ZStack {
                // intense glow
                Circle()
                    .fill(RadialGradient(colors: [Self.white.opacity(fade), Self.gold.opacity(fade * 0.5), .clear],
                                         center: .center, startRadius: 2, endRadius: 90))
                    .frame(width: 200, height: 200)
                    .blendMode(.screen)
                // 4-point white-hot star
                FourPointStar()
                    .fill(Self.white.opacity(fade))
                    .frame(width: 120 * CGFloat(pop), height: 120 * CGFloat(pop))
                    .shadow(color: Self.gold.opacity(fade), radius: 12)
            }
            .position(x: cx, y: cy)
            .allowsHitTesting(false)
        }
    }

    // ── PHASE 4 — falling embers + afterglow ──────────────────────────────

    @ViewBuilder
    private func embersLayer(cx: CGFloat, cy: CGFloat, h: CGFloat, e: Double) -> some View {
        if e >= Self.burstEnd {
            let local = e - Self.burstEnd                       // 0 … 1.2
            ForEach(0..<Self.embers.count, id: \.self) { i in
                let em = Self.embers[i]
                let p = local / (Self.total - Self.burstEnd)    // 0…1
                // initial outward velocity + gravity pulling down (curved path)
                let dist = CGFloat(easeOut(min(1, local / 0.4))) * 180 * em.speed
                let x = cx + CGFloat(cos(em.angle)) * dist
                let gravity = CGFloat(p * p) * h * 0.5
                let y = cy + CGFloat(sin(em.angle)) * dist + gravity
                Circle()
                    .fill(em.color.opacity((1 - p) * 0.9))
                    .frame(width: 5 - CGFloat(p) * 3, height: 5 - CGFloat(p) * 3)
                    .position(x: x, y: y)
                    .shadow(color: em.color.opacity((1 - p) * 0.6), radius: 3)
            }
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func afterglow(cx: CGFloat, cy: CGFloat, e: Double) -> some View {
        if e >= Self.burstAt {
            let local = e - Self.burstAt
            let op = max(0, 0.22 - local * 0.06)
            Circle()
                .fill(RadialGradient(colors: [Self.amber.opacity(op), Self.red.opacity(op * 0.6), .clear],
                                     center: .center, startRadius: 4, endRadius: 220))
                .frame(width: 460, height: 460)
                .position(x: cx, y: cy)
                .blendMode(.screen)
                .allowsHitTesting(false)
        }
    }

    // ── Easing ────────────────────────────────────────────────────────────

    private func easeOut(_ t: Double) -> Double { let x = min(max(t,0),1); return 1 - pow(1 - x, 3) }
    private func easeIn(_ t: Double) -> Double { let x = min(max(t,0),1); return x * x }
}

/// A 4-point sparkle star (supernova core).
private struct FourPointStar: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let R = min(rect.width, rect.height) / 2
        let r = R * 0.16
        var p = Path()
        let pts = 4
        for i in 0..<(pts * 2) {
            let a = Double(i) * .pi / Double(pts) - .pi / 2
            let rad = i % 2 == 0 ? R : r
            let pt = CGPoint(x: c.x + CGFloat(cos(a)) * rad, y: c.y + CGFloat(sin(a)) * rad)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}
