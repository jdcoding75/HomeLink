// BirthdayCakeReceiptV2.swift
// Pointward › Instruments › _Shared › EmojiReveal
//
// V2 — THE HERO. The receiver's half of the wish ritual (Screen 4). A lit cake
// floats above the wooden bucket; the receiver BLOWS into the mic to put the
// candles out — a TWO-STAGE blow that mirrors the sender's tap-to-light:
//
//   FIRST blow   → flames flicker and lean sideways (do not go out)
//   SECOND blow  → flames extinguish, each wick puffs smoke
//
// Then the 🎂 emerges from the smoke, drifts on a gold sparkle trail into the
// bucket (cyan catch glow), and hands off to the shared EmojiRevealView.
//
// MIC: reuses Wind's BreathDetector exactly (same onExhale / level / micDenied).
// If the mic is denied, it degrades gracefully to TAP-to-blow-out.
//
// Screen-coordinate rules: GeometryReader root, .ignoresSafeArea() background,
// bucket at (width-80, height-95).

import SwiftUI

struct BirthdayCakeReceiptV2: View {
    var emoji: String = "🎂"
    var message: String? = nil
    var tagline: String? = nil
    let fromName: String
    var onRevealed: () -> Void = {}
    var onFinished: () -> Void = {}

    @StateObject private var breath = BreathDetector()

    @State private var stage = 0                 // 0 lit · 1 leaned · 2 out
    @State private var extinguishedAt: Date? = nil
    @State private var lastBlowAt: Date? = nil
    @State private var leanPulse: CGFloat = 0
    @State private var landed = false
    @State private var revealing = false
    @State private var appearAt: Date? = nil   // [tweak] lower-in entrance clock

    private static let cyan = Color(hex: "#50B4F0")
    private static let wood     = Color(hex: "#8B4513")
    private static let woodDark = Color(hex: "#6E3A1E")
    private static let brass    = Color(hex: "#C9A86A")
    private static let bucketW: CGFloat = 140
    private static let bucketH: CGFloat = 120

    // Post-extinguish timeline (seconds from extinguishedAt)
    private static let smokeDur:  Double = 0.8
    private static let bloomAt:   Double = 0.6
    private static let driftAt:   Double = 1.6
    private static let landAt:    Double = 3.0
    private static let revealAt:  Double = 3.3

    // [tweak] LOWER-IN entrance — the cake descends from the top, small→big, and
    // settles full size ~2/3 down. Visual entrance only; blow-out is unchanged.
    private static let descDur: Double = 0.65

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            // [tweak] cake settles FULL SIZE ~2/3 of the way down the screen.
            let restCenter = CGPoint(x: w / 2, y: h * 0.62)
            ZStack {
                if revealing {
                    EmojiRevealView(emoji: emoji, message: message, tagline: tagline,
                                    context: .received(fromName: fromName),
                                    ambient: .compass,
                                    onDismiss: onFinished)
                        .transition(.opacity)
                } else {
                    Color(hex: "#06070c").ignoresSafeArea()
                    LinearGradient(colors: [Color(hex: "#06070c"), Color(hex: "#0f1429"),
                                            Color(hex: "#1f162b"), Color(hex: "#120c1c")],
                                   startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()

                    TimelineView(.animation) { timeline in
                        let now = timeline.date
                        let t = now.timeIntervalSinceReferenceDate
                        let since = extinguishedAt.map { now.timeIntervalSince($0) } ?? -1
                        // [tweak] lower-in entrance: descend from the top edge,
                        // growing small→big, into the rest position.
                        let ep = easeOut(entranceP(now: now))
                        let topY = -h * 0.04
                        let entranceCenter = CGPoint(
                            x: restCenter.x,
                            y: topY + (restCenter.y - topY) * CGFloat(ep))
                        let entranceScale: CGFloat = 0.35 + 0.65 * CGFloat(ep)
                        // [tweak] final cake 25% larger: base 1.15 → 1.4375.
                        let cakeScale: CGFloat = 1.4375 * entranceScale
                        ZStack {
                            // [tweak] bucket REMOVED — the descending cake IS the
                            // arrival (no bucket catch, no bucket art).
                            // bucket(w: w, h: h)
                            cakeGlow(center: entranceCenter, scale: entranceScale)
                            BirthdayCakeBody(center: entranceCenter, scale: cakeScale)
                            candles(center: entranceCenter, t: t, since: since, scale: cakeScale)
                            smoke(center: restCenter, since: since)
                            // [tweak] bucket-drift choreography removed with the bucket:
                            // sparkleTrail(center: restCenter, w: w, h: h, since: since)
                            // emojiView(center: restCenter, w: w, h: h, since: since)
                            // emojiInBucket(w: w, h: h, since: since)
                            instruction(w: w, h: h)
                        }
                        .frame(width: w, height: h)
                    }
                }
            }
            .frame(width: w, height: h)
            // Tap fallback when the mic is denied (graceful degradation).
            .contentShape(Rectangle())
            .onTapGesture { if breath.micDenied { advanceBlow() } }
        }
        .ignoresSafeArea()
        .onAppear { begin() }
        .onDisappear { breath.stop() }
    }

    // ── Lifecycle ────────────────────────────────────────────────────────────

    private func begin() {
        appearAt = Date()                       // [tweak] start the lower-in entrance
        breath.onExhale = { advanceBlow() }
        breath.start()
    }

    /// [tweak] Entrance progress 0…1 over `descDur` from first appearance.
    private func entranceP(now: Date) -> Double {
        guard let appearAt else { return 0 }
        return min(1, max(0, now.timeIntervalSince(appearAt) / Self.descDur))
    }

    /// Two-stage blow, with a small debounce so one long breath can't skip a
    /// stage instantly (≥0.4s between stages).
    private func advanceBlow() {
        let now = Date()
        if let last = lastBlowAt, now.timeIntervalSince(last) < 0.4 { return }
        lastBlowAt = now
        if stage == 0 {
            stage = 1
            InstrumentSoundPlayer.shared.playCue(file: "birthday_blow_first", duration: 0.6)
            HapticPattern.singleSoft.fire()
            withAnimation(.easeOut(duration: 0.18)) { leanPulse = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.4)) { leanPulse = 0 }
            }
        } else if stage == 1 {
            stage = 2
            extinguishedAt = Date()
            breath.stop()
            InstrumentSoundPlayer.shared.playCue(file: "birthday_blow_out", duration: 0.8)
            HapticPattern.doubleSoft.fire()
            // The reveal chime as the emoji emerges.
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.bloomAt) {
                InstrumentSoundPlayer.shared.playCue(file: "birthday_reveal", duration: 0.8)
                HapticPattern.heartbeat.fire()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.landAt) {
                withAnimation(.easeOut(duration: 0.4)) { landed = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.revealAt) {
                onRevealed()
                withAnimation(.easeInOut(duration: 0.3)) { revealing = true }
            }
        }
    }

    // ── Candles + flames (lit → leaning → out) ───────────────────────────────

    @ViewBuilder
    private func candles(center: CGPoint, t: Double, since: Double, scale: CGFloat) -> some View {
        // Live lean from the mic level (visible reaction to breath) + the pulse.
        let liveLean = CGFloat(breath.level) * 0.7
        let lean = min(1, leanPulse + liveLean)
        let out = stage == 2
        ForEach(0..<BirthdayCakeV2.candleCount, id: \.self) { i in
            let c = BirthdayCakeV2.candle(i, center: center, scale: scale)
            RoundedRectangle(cornerRadius: 3 * scale).fill(c.color)
                .frame(width: c.width, height: c.bottomY - c.wickY)
                .position(x: c.x, y: (c.bottomY + c.wickY) / 2)
            Rectangle().fill(Color(hex: "#3a2a20"))
                .frame(width: 1.6 * scale, height: 5 * scale)
                .position(x: c.x, y: c.wickY - 2 * scale)
            // flame shrinks to nothing as it goes out
            let litAmt: CGFloat = {
                guard out else { return 1 }
                let p = max(0, min(1, since / 0.35))
                return 1 - CGFloat(p)
            }()
            if litAmt > 0.02 {
                let sway = sin(t * 2.4 + Double(i)) * 2.0
                let flick = stage == 1 ? CGFloat(sin(t * 30 + Double(i))) * 0.15 : 0
                BirthdayFlame(lit: litAmt + flick, lean: lean, sway: sway, scale: scale)
                    .position(x: c.x, y: c.wickY - 10 * scale)
            }
        }
    }

    // ── Smoke wisps rising from each extinguished wick ───────────────────────
    // [tweak] Clearer "just blown out" read: distinct CURLING WISP LINES rise
    // from each wick (two staggered strands, widening as they climb), drifting
    // up and fading over a brief readable beat — not a vague blurred puff.

    @ViewBuilder
    private func smoke(center: CGPoint, since: Double) -> some View {
        if stage == 2 && since >= 0 && since < 1.6 {
            let scale: CGFloat = 1.4375   // [tweak] match the 25%-larger cake
            Canvas { ctx, _ in
                for i in 0..<BirthdayCakeV2.candleCount {
                    let c = BirthdayCakeV2.candle(i, center: center, scale: scale)
                    let baseX = c.x
                    let baseY = c.wickY - 10 * scale
                    // Two staggered strands per wick → a defined little plume.
                    for strand in 0..<2 {
                        let phase = Double(i) * 0.8 + Double(strand) * 2.3
                        let local = since - Double(strand) * 0.18
                        if local <= 0 { continue }
                        let p = min(1.0, local / 1.3)
                        let rise = CGFloat(p) * 54 * scale
                        let drift = CGFloat(p) * 10
                        let op = (1 - p) * 0.6
                        var path = Path()
                        let steps = 18
                        for s in 0...steps {
                            let f = CGFloat(s) / CGFloat(steps)
                            let yy = baseY - rise * f - drift
                            let amp = (2.5 + 8.0 * f) * scale          // curl widens as it rises
                            let xx = baseX + CGFloat(sin(Double(f) * .pi * 2.4 + phase + Double(p) * 1.6)) * amp
                            let pt = CGPoint(x: xx, y: yy)
                            if s == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                        }
                        ctx.stroke(path,
                                   with: .color(Color(white: 0.93).opacity(op)),
                                   style: StrokeStyle(lineWidth: 2.0 * scale,
                                                      lineCap: .round, lineJoin: .round))
                    }
                }
            }
            .blur(radius: 0.6)
            .allowsHitTesting(false)
        }
    }

    // ── The emoji (emerges from smoke → drifts to bucket) ────────────────────

    private func centerEmojiPoint(_ center: CGPoint) -> CGPoint {
        CGPoint(x: center.x, y: center.y - 6)
    }
    private func bucketPoint(_ w: CGFloat, _ h: CGFloat) -> CGPoint {
        CGPoint(x: w - 80, y: h - 95)
    }

    private func emojiPos(center: CGPoint, w: CGFloat, h: CGFloat, since: Double) -> CGPoint {
        let c = centerEmojiPoint(center)
        guard since >= Self.driftAt else { return c }
        let b = bucketPoint(w, h)
        let p = easeInOut(min(1, (since - Self.driftAt) / (Self.landAt - Self.driftAt)))
        let mid = CGPoint(x: (c.x + b.x) / 2, y: c.y + (b.y - c.y) * 0.35)
        let q = CGFloat(p)
        return CGPoint(
            x: (1 - q) * (1 - q) * c.x + 2 * (1 - q) * q * mid.x + q * q * b.x,
            y: (1 - q) * (1 - q) * c.y + 2 * (1 - q) * q * mid.y + q * q * b.y)
    }

    @ViewBuilder
    private func emojiView(center: CGPoint, w: CGFloat, h: CGFloat, since: Double) -> some View {
        if stage == 2 && since >= Self.bloomAt && since < Self.landAt {
            let bloom: CGFloat = {
                let lp = (since - Self.bloomAt) / 0.6
                if lp < 0.7 { return CGFloat(easeOut(max(0, lp) / 0.7)) * 1.2 }
                if lp < 1.0 { return 1.2 - 0.2 * CGFloat((lp - 0.7) / 0.3) }
                return 1.0
            }()
            let drifting = since >= Self.driftAt
            let driftScale = CGFloat((since - Self.driftAt) / (Self.landAt - Self.driftAt))
            let scale = drifting ? max(0.6, 1.0 - driftScale * 0.4) : bloom
            // [phase3] Custom cake ART (not the 🎂 glyph) emerges from the smoke
            // and drifts into the bucket — matching the cake on every screen.
            BirthdayCakeGlyph(height: 92)
                .scaleEffect(scale)
                .shadow(color: BirthdayCakeV2.warmGold.opacity(0.5), radius: 16)
                .position(emojiPos(center: center, w: w, h: h, since: since))
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func sparkleTrail(center: CGPoint, w: CGFloat, h: CGFloat, since: Double) -> some View {
        if stage == 2 && since >= Self.driftAt && since < Self.landAt {
            ForEach(0..<8, id: \.self) { k in
                let tb = since - Double(k) * 0.05
                if tb >= Self.driftAt {
                    let frac = Double(k) / 8
                    let p = emojiPos(center: center, w: w, h: h, since: tb)
                    Circle().fill(BirthdayCakeV2.warmGold.opacity((1 - frac) * 0.6))
                        .frame(width: 6 - CGFloat(frac) * 3, height: 6 - CGFloat(frac) * 3)
                        .position(x: p.x, y: p.y - CGFloat(k) * 2)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    @ViewBuilder
    private func emojiInBucket(w: CGFloat, h: CGFloat, since: Double) -> some View {
        if stage == 2 && since >= Self.landAt {
            let p = bucketPoint(w, h)
            let settle = easeOut(min(1, (since - Self.landAt) / (Self.revealAt - Self.landAt)))
            ZStack {
                ForEach(0..<8, id: \.self) { k in
                    let a = (Double(k) / 8) * 2 * .pi
                    Circle().fill(BirthdayCakeV2.warmGold.opacity((1 - settle) * 0.8))
                        .frame(width: 4, height: 4)
                        .offset(x: CGFloat(cos(a)) * CGFloat(settle) * 48,
                                y: -Self.bucketH * 0.3 + CGFloat(sin(a)) * CGFloat(settle) * 28)
                }
                BirthdayCakeGlyph(height: 42)
                    .scaleEffect(0.6 + 0.4 * CGFloat(settle))
                    .offset(y: -Self.bucketH * 0.16)
                    .opacity(settle)
            }
            .position(p)
            .allowsHitTesting(false)
        }
    }

    // ── Cake glow ────────────────────────────────────────────────────────────

    private func cakeGlow(center: CGPoint, scale: CGFloat) -> some View {
        let warm = stage < 2
        return Circle()
            .fill(RadialGradient(colors: [BirthdayCakeV2.warmGold.opacity(warm ? 0.20 : 0.06), .clear],
                                 center: .center, startRadius: 6, endRadius: 130))
            .frame(width: 260, height: 260)
            .scaleEffect(scale)               // [tweak] scales with the entrance
            .position(center)
            .blendMode(.screen)
            .allowsHitTesting(false)
    }

    // ── The wooden bucket ─────────────────────────────────────────────────

    private func bucket(w: CGFloat, h: CGFloat) -> some View {
        let p = bucketPoint(w, h)
        return ZStack {
            Ellipse()
                .fill(RadialGradient(colors: [Self.cyan.opacity(landed ? 0.2 : 0), .clear],
                                     center: .center, startRadius: 2, endRadius: 80))
                .frame(width: Self.bucketW * 1.2, height: 110)
                .offset(y: -Self.bucketH / 2).blur(radius: 6)
            BucketHandleShape()
                .stroke(Self.brass, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: Self.bucketW * 0.9, height: 48)
                .offset(y: -Self.bucketH / 2 - 14)
            BucketShape()
                .fill(LinearGradient(colors: [Self.wood, Self.woodDark], startPoint: .top, endPoint: .bottom))
                .frame(width: Self.bucketW, height: Self.bucketH)
                .overlay(
                    VStack {
                        Capsule().fill(Self.brass).frame(height: 6).padding(.horizontal, -2).padding(.top, 11)
                        Spacer()
                        Capsule().fill(Self.brass).frame(height: 6).padding(.horizontal, 6).padding(.bottom, 13)
                    }
                    .frame(width: Self.bucketW, height: Self.bucketH).opacity(0.85)
                )
                .shadow(color: .black.opacity(0.4), radius: 10, y: 6)
        }
        .position(p)
    }

    // ── Instruction ──────────────────────────────────────────────────────────

    @ViewBuilder
    private func instruction(w: CGFloat, h: CGFloat) -> some View {
        if stage < 2 {
            let text = breath.micDenied ? "tap to blow out the candles 🎂" : "blow out the candles 🎂"
            Text(text)
                .font(.system(size: 18, design: .serif).italic())
                .foregroundColor(BirthdayCakeV2.lavender)
                .shadow(color: .black.opacity(0.5), radius: 6)
                .position(x: w / 2, y: h * 0.84)
        }
    }

    private func easeOut(_ t: Double) -> Double { let x = min(max(t,0),1); return 1 - pow(1 - x, 3) }
    private func easeInOut(_ t: Double) -> Double {
        let x = min(max(t,0),1); return x < 0.5 ? 4*x*x*x : 1 - pow(-2*x + 2, 3) / 2
    }
}
