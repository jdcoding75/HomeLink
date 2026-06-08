// ReceiptView.swift
// Pointward › Views
//
// THE RECEIPT — a dedicated full-screen receive experience. When a thought
// arrives, this takes over the whole screen (tab bar hidden) with three zones:
//
//   TOP (20%)     "[Name] sent you something ✦" — 28pt serif lavender, always
//   MIDDLE (60%)  the instrument's THEMED CATCH WORLD — the thought travels
//                 toward you, growing, then drops into the bucket
//   BOTTOM (20%)  alignment guidance (cardinal direction + turn) → "locked ✦"
//
// After the reveal the middle shows the emoji at 72pt with "from [Name] ✦",
// and the bottom reads "tap anywhere to continue". Dismiss returns to the
// compass; the bucket icon there updates with the new count.

import SwiftUI
import Combine
import os

struct ReceiptView: View {

    private static let log = Logger(subsystem: "com.jdcoding75.pointward", category: "receipt")

    let ping: PingManager.ReceivedPing
    let style: SenderStyle
    let onRevealed: () -> Void
    let onFinished: () -> Void

    @EnvironmentObject var compass: CompassManager
    @EnvironmentObject var pings:   PingManager

    private enum Phase { case arriving, seeking, locked, landing, dropping, caught, revealed }
    @State private var phase: Phase = .arriving

    @State private var arrivalPulse = false
    @State private var approach: CGFloat = 0       // 0 far → 1 arrived (grows)
    @State private var orbEntered = false
    @State private var lockFlash = false
    @State private var dimWorld = false
    @State private var bubbleSettle = false
    @State private var bloomed = false
    @State private var revealFlood = false
    @State private var named = false
    @State private var debugBypass = false
    @State private var pulse = false

    private let tick = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    private var hue: Color { EmojiHue.color(for: ping.emoji) }
    private static let lavender  = Color(hex: "#c4a8d4")
    private static let warmWhite = Color(hex: "#f3ecdf")

    private var angleError: Double {
        guard compass.isHeadingAvailable else { return 0 }
        if debugBypass { return 0 }
        return BearingCalculator.alignmentError(relativeBearing: compass.state.bearingDegrees)
    }
    private var turnRight: Bool {
        var b = compass.state.bearingDegrees.truncatingRemainder(dividingBy: 360)
        if b < 0 { b += 360 }
        return b < 180
    }
    private var caughtEmojis: [String] {
        var list = pings.queue.map(\.emoji)
        if phase == .caught || phase == .revealed { list.append(ping.emoji) }
        return Array(list.suffix(5))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ── THE THEMED WORLD fills the whole screen ──
                DesignTokens.Color.background.ignoresSafeArea()
                CatchWorldBackground(style: style).ignoresSafeArea()
                Color.black.opacity(dimWorld ? 0.3 : 0).ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.4), value: dimWorld)
                Self.lavender.opacity(arrivalPulse ? 0.18 : 0).ignoresSafeArea()

                VStack(spacing: 0) {
                    topZone.frame(height: geo.size.height * 0.2)
                    middleZone(geo: geo).frame(height: geo.size.height * 0.6)
                    bottomZone.frame(height: geo.size.height * 0.2)
                }

                // ── Reveal flash/flood over everything ──
                Color.white.opacity(lockFlash ? 0.5 : 0).ignoresSafeArea().allowsHitTesting(false)
                Color(hex: "#fff3d8").opacity(revealFlood ? 0.15 : 0).ignoresSafeArea().allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if phase == .caught { revealFromBucket() }
                else if phase == .revealed { onFinished() }
            }
        }
        .onAppear { begin() }
        .onReceive(tick) { _ in heartbeat() }
    }

    // ── TOP 20% — the sender name, always visible ──────────────────────────

    private var topZone: some View {
        VStack {
            Spacer(minLength: 24)
            Text("\(ping.fromName) sent you something ✦")
                .font(.system(size: 28, design: .serif))
                .foregroundColor(Self.lavender)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .shadow(color: .black.opacity(0.5), radius: 8)
                .padding(.horizontal, 24)
            Spacer()
        }
    }

    // ── MIDDLE 60% — the themed approach + bucket, or the reveal ───────────

    private func middleZone(geo: GeometryProxy) -> some View {
        ZStack {
            if phase == .landing {
                // The dramatic per-instrument landing plays over the world.
                InstrumentLandingView(style: style, emoji: ping.emoji,
                                      onComplete: { revealAfterLanding() })
            } else if phase == .revealed {
                VStack(spacing: 18) {
                    ZStack {
                        Circle().fill(hue.opacity(0.22)).frame(width: 220, height: 220).blur(radius: 44)
                        Text(ping.emoji)
                            .font(.system(size: 72))
                            .scaleEffect(bloomed ? 1.0 : 0.3)
                            .shadow(color: hue.opacity(0.6), radius: 26)
                            .animation(AnimationSystem.easeOutBack(0.4), value: bloomed)
                    }
                    Text("from \(ping.fromName) ✦")
                        .font(.system(size: 28, design: .serif))
                        .foregroundColor(Self.warmWhite)
                        .opacity(named ? 1 : 0)
                        .animation(.easeIn(duration: 0.5), value: named)
                    // [ReceiptView] optional short message, if the sender added one
                    if let message = ping.message, !message.isEmpty {
                        Text(message)
                            .font(.system(size: 18, design: .serif).italic())
                            .foregroundColor(Self.lavender.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .opacity(named ? 1 : 0)
                            .animation(.easeIn(duration: 0.6), value: named)
                            .padding(.horizontal, 30)
                    }
                }
            } else {
                // The bucket near the bottom of the middle zone
                VStack {
                    Spacer()
                    bucket
                }
                // The incoming thought — travels toward you, GROWING, then drops
                themedIncoming
                    .scaleEffect(incomingScale)
                    .opacity(phase == .dropping ? max(0, 1 - Double(approach)) : 1)
                    .offset(y: incomingY(geo: geo))
                    .animation(.easeOut(duration: 0.5), value: orbEntered)
                    .animation(.easeInOut(duration: 0.4), value: approach)
            }
        }
    }

    /// The incoming thought grows as it approaches and pops a touch on lock.
    private var incomingScale: CGFloat {
        let grow: CGFloat = 0.4 + approach * 0.9
        let entered: CGFloat = orbEntered ? 1 : 0.01
        let pop: CGFloat = angleError < 5 ? 1.1 : 1.0
        return grow * entered * pop
    }

    /// The thought drifts down from the top of the middle zone toward the
    /// bucket as `approach` grows; on drop it dives into the bucket mouth.
    private func incomingY(geo: GeometryProxy) -> CGFloat {
        let top = -geo.size.height * 0.22
        let bucketMouth = geo.size.height * 0.16
        if phase == .dropping { return bucketMouth + 30 }
        return top + (bucketMouth - top) * approach
    }

    // ── BOTTOM 20% — alignment guidance / continue ─────────────────────────

    private var bottomZone: some View {
        VStack {
            Spacer()
            if phase == .revealed {
                Text("tap anywhere to continue")
                    .font(.system(size: 13, design: .serif).italic())
                    .foregroundColor(DesignTokens.Color.textMuted)
            } else {
                VStack(spacing: 8) {
                    Text(guidanceLine)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7).lineLimit(2)
                        .shadow(color: Self.lavender.opacity(angleError < 5 ? 0.8 : 0.4), radius: 8)
                        .animation(.easeInOut(duration: 0.2), value: guidanceLine)
                    Text("turn your phone toward them")
                        .font(.system(size: 13))
                        .foregroundColor(DesignTokens.Color.textMuted)
                    #if DEBUG
                    Button("⚙︎ align (sim)") { debugBypass = true }
                        .font(.system(size: 9)).foregroundColor(DesignTokens.Color.textDim)
                    #endif
                }
                .padding(.horizontal, 24)
            }
            Spacer(minLength: 18)
        }
    }

    private var guidanceLine: String {
        if phase == .locked || phase == .dropping || phase == .caught { return "locked ✦" }
        switch angleError {
        case ..<5:  return "locked ✦"
        case ..<15: return "almost there ✦"
        case ..<45: return "turn \(turnRight ? "right" : "left") to align"
        default:
            if let abs = compass.rawBearingToTarget {
                return "\(ping.fromName) is to your \(Self.fullCardinal(abs))"
            }
            return "turn \(turnRight ? "right" : "left") to align"
        }
    }

    // ── The bucket ──────────────────────────────────────────────────────────

    private var bucket: some View {
        ZStack {
            Circle().fill(hue.opacity(0.16)).frame(width: 240, height: 240).blur(radius: 40)
            BucketHandleShape()
                .stroke(Color(hex: "#888888"), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 170, height: 60).offset(y: -100)
            BucketShape()
                .fill(LinearGradient(colors: [Color(hex: "#8B4513"), Color(hex: "#6E3A1E")],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 180, height: 160)
                .overlay(bucketBubbles.clipShape(BucketShape()))
                .shadow(color: .black.opacity(0.4), radius: 10, y: 6)
        }
        .padding(.bottom, 8)
    }

    private var bucketBubbles: some View {
        VStack(spacing: -6) {
            Spacer()
            ForEach(Array(caughtEmojis.enumerated()), id: \.offset) { idx, emoji in
                let isNew = idx == caughtEmojis.count - 1 && (phase == .caught || phase == .revealed)
                Circle()
                    .fill(RadialGradient(colors: [EmojiHue.color(for: emoji).opacity(0.5),
                                                  EmojiHue.color(for: emoji).opacity(0.15)],
                                         center: .center, startRadius: 2, endRadius: 24))
                    .frame(width: 46, height: 46)
                    .overlay(Text(emoji).font(.system(size: 22)))
                    .scaleEffect(isNew ? (bubbleSettle ? 1.0 : 0.4) : 1.0)
                    .offset(x: CGFloat((idx % 2 == 0 ? -1 : 1) * 12))
                    .animation(.spring(response: 0.4, dampingFraction: 0.55), value: bubbleSettle)
            }
            Spacer().frame(height: 16)
        }
        .frame(width: 180, height: 160)
    }

    // ── The incoming thought, themed per instrument ────────────────────────

    @ViewBuilder
    private var themedIncoming: some View {
        switch style {
        case .firefly:  // wind — a leaf carrying the emoji
            ZStack {
                LeafShape().fill(Color(hex: "#5a8a3a"))
                    .frame(width: 64, height: 44)
                Text(ping.emoji).font(.system(size: 26)).offset(y: -6)
            }
            .rotationEffect(.degrees(pulse ? 6 : -6))
        case .rocket:   // rocket descending
            VStack(spacing: -2) {
                Text("🚀").font(.system(size: 40)).rotationEffect(.degrees(180))
                Text(ping.emoji).font(.system(size: 22))
            }
        case .fingerFlick:  // a paper note tumbling
            ZStack {
                RoundedRectangle(cornerRadius: 4).fill(Color(hex: "#F5F0E0"))
                    .frame(width: 54, height: 58)
                Text(ping.emoji).font(.system(size: 26))
            }
            .rotationEffect(.degrees(approach * 360))
            .shadow(color: .black.opacity(0.3), radius: 5)
        case .bowArrow: // an arrow with the emoji, growing toward you
            ZStack {
                Circle().fill(RadialGradient(colors: [hue.opacity(0.9), .clear],
                                             center: .center, startRadius: 2, endRadius: 30))
                    .frame(width: 60, height: 60)
                Text(ping.emoji).font(.system(size: 30))
            }
        case .wand:     // sparkles converging into the emoji
            ZStack {
                ForEach(0..<8, id: \.self) { i in
                    let a = Double(i) / 8 * 2 * .pi
                    let r: CGFloat = (1 - approach) * 50 + 10
                    Image(systemName: "sparkle")
                        .font(.system(size: 8))
                        .foregroundColor(i % 2 == 0 ? Color(hex: "#D4AF37") : Self.lavender)
                        .offset(x: CGFloat(cos(a)) * r, y: CGFloat(sin(a)) * r)
                }
                Text(ping.emoji).font(.system(size: 30)).opacity(Double(approach))
            }
        default:        // compass + plane + glow — a warm glowing orb
            ZStack {
                Circle().fill(RadialGradient(colors: [hue.opacity(0.95), hue.opacity(0.3), .clear],
                                             center: .center, startRadius: 4, endRadius: 28))
                    .frame(width: 56, height: 56)
                Text(ping.emoji).font(.system(size: 26)).opacity(0.9)
            }
        }
    }

    // ── Sequencing ──────────────────────────────────────────────────────────

    private func begin() {
        Self.log.info("receipt: from=\(ping.fromName, privacy: .public) emoji=\(ping.emoji, privacy: .public) style=\(style.rawValue, privacy: .public)")
        phase = .arriving
        HapticEngine.catchArrival()
        SoundEngine.shared.play(for: "catch.arrival")
        withAnimation(.easeOut(duration: 0.4)) { arrivalPulse = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeIn(duration: 0.4)) { arrivalPulse = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { enterSeeking() }
    }

    private func enterSeeking() {
        guard phase == .arriving else { return }
        phase = .seeking
        SoundEngine.shared.play(for: "catch.lock")
        withAnimation(AnimationSystem.easeOutBack(0.5)) { orbEntered = true }
        withAnimation(AnimationSystem.easeInOutSine(0.9).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }

    private func heartbeat() {
        guard phase == .seeking || phase == .locked else { return }
        HapticEngine.catchAlignment(angleError: angleError)
        // The thought drifts closer (grows) as you align — you watch it come.
        let target: CGFloat = CGFloat(max(0, min(1, (45 - angleError) / 45)))
        if abs(approach - target) > 0.02 {
            withAnimation(.easeOut(duration: 0.4)) { approach = target }
        }
        if angleError < 5 {
            if phase == .seeking { lockOn() }
        }
    }

    private func lockOn() {
        phase = .locked
        HapticEngine.catchLock()
        SoundEngine.shared.play(for: "catch.lock")
        withAnimation(.easeOut(duration: 0.05)) { lockFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.12)) { lockFlash = false }
        }
        // The thought is locked — the dramatic per-instrument LANDING plays.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeInOut(duration: 0.3)) { phase = .landing }
        }
    }

    /// The landing animation finished (emoji emerged) → settle into the reveal.
    private func revealAfterLanding() {
        guard phase == .landing else { return }
        phase = .revealed
        onRevealed()
        bloomed = true
        named = true
        withAnimation(.easeOut(duration: 0.2)) { revealFlood = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeIn(duration: 0.2)) { revealFlood = false }
        }
    }

    private func caught() {
        phase = .caught
        HapticEngine.rocketLanding()
        SoundEngine.shared.play(for: "style.bell")
        withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) { bubbleSettle = true }
        withAnimation(.easeIn(duration: 0.4)) { named = true }
    }

    private func revealFromBucket() {
        phase = .revealed
        onRevealed()
        HapticEngine.catchReveal()
        SoundEngine.shared.play(for: "style.bell")
        SoundEngine.shared.play(for: ping.emoji)
        withAnimation(.easeOut(duration: 0.2)) { revealFlood = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeIn(duration: 0.2)) { revealFlood = false }
        }
        bloomed = true
        named = true
    }

    static func fullCardinal(_ degrees: Double) -> String {
        let words = ["North", "North-Northeast", "Northeast", "East-Northeast",
                     "East", "East-Southeast", "Southeast", "South-Southeast",
                     "South", "South-Southwest", "Southwest", "West-Southwest",
                     "West", "West-Northwest", "Northwest", "North-Northwest"]
        let i = ((Int((degrees / 22.5).rounded()) % 16) + 16) % 16
        return words[i]
    }
}

// ════════════════════════════════════════════════════════════════════════
// MARK: - [2/4] CatchWorldBackground — a themed animated world per instrument
// ════════════════════════════════════════════════════════════════════════

struct CatchWorldBackground: View {
    let style: SenderStyle

    var body: some View {
        switch style {
        case .firefly:     SkyWorld()      // wind — day sky + clouds
        case .fingerFlick: CorkWorld()     // flick — cork board
        case .bowArrow:    TargetWorld()   // bow — archery range
        case .wand:        MagicWorld()    // wand — magical sparkles
        default:           SpaceWorld()    // rocket · compass · plane · glow — space
        }
    }
}

/// A warm daytime sky with slow drifting clouds.
private struct SkyWorld: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#87CEEB"), Color(hex: "#B8D4E8"), Color(hex: "#E8F4F8")],
                           startPoint: .top, endPoint: .bottom)
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(0..<4, id: \.self) { i in
                        let p = (t / (28 + Double(i) * 6)).truncatingRemainder(dividingBy: 1)
                        cloud
                            .scaleEffect(0.7 + CGFloat(i) * 0.22)
                            .position(x: CGFloat(p) * 520 - 110,
                                      y: [120, 280, 440, 620][i])
                            .opacity(0.85)
                    }
                }
            }
        }
    }
    private var cloud: some View {
        ZStack {
            Circle().frame(width: 50, height: 50).offset(x: -32, y: 6)
            Circle().frame(width: 70, height: 70)
            Circle().frame(width: 54, height: 54).offset(x: 32, y: 4)
            Capsule().frame(width: 104, height: 32).offset(y: 16)
        }
        .foregroundColor(Color(hex: "#FFFAF0").opacity(0.85))
        .blur(radius: 3)
    }
}

/// A scattered decorative element used by the worlds.
struct WorldDot: Identifiable {
    let id = UUID()
    let x: CGFloat; let y: CGFloat
    let w: CGFloat; let h: CGFloat
    let angle: Double; let opacity: Double
    let gold: Bool; let period: Double
}

private func scatterDots(_ count: Int, wMin: CGFloat, wRange: Int,
                         hMin: CGFloat, hRange: Int) -> [WorldDot] {
    var out: [WorldDot] = []
    for i in 0..<count {
        let x: CGFloat = CGFloat((i * 71) % 400) - 30
        let y: CGFloat = CGFloat((i * 137) % 760)
        let w: CGFloat = wMin + CGFloat((i * 7) % wRange)
        let h: CGFloat = hMin + CGFloat((i * 5) % hRange)
        let angle = Double((i * 37) % 180)
        let opacity = 0.1 + Double((i * 13) % 10) / 60.0
        let period = 1.0 + Double((i * 9) % 18) / 10.0
        out.append(WorldDot(x: x, y: y, w: w, h: h, angle: angle,
                            opacity: opacity, gold: i % 2 == 0, period: period))
    }
    return out
}

/// Deep space — a dark gradient with gently twinkling stars.
private struct SpaceWorld: View {
    @State private var twinkle = false
    private let stars = scatterDots(46, wMin: 1, wRange: 3, hMin: 1, hRange: 3)
    var body: some View {
        ZStack {
            RadialGradient(colors: [Color(hex: "#15111c"), Color(hex: "#08060c")],
                           center: .center, startRadius: 40, endRadius: 480)
            ForEach(stars) { s in
                Circle().fill(.white)
                    .frame(width: s.w, height: s.w)
                    .position(x: s.x, y: s.y)
                    .opacity(twinkle ? 0.7 : 0.25)
                    .animation(AnimationSystem.easeInOutSine(s.period).repeatForever(autoreverses: true), value: twinkle)
            }
        }
        .onAppear { twinkle = true }
    }
}

/// A warm cork board with a few pin holes.
private struct CorkWorld: View {
    private let grains = scatterDots(90, wMin: 5, wRange: 14, hMin: 4, hRange: 9)
    var body: some View {
        ZStack {
            Color(hex: "#C4956A")
            ForEach(grains) { g in
                Ellipse().fill(Color(hex: "#B8835A").opacity(g.opacity))
                    .frame(width: g.w, height: g.h)
                    .rotationEffect(.degrees(g.angle))
                    .position(x: g.x, y: g.y)
            }
            // A few old pin holes
            ForEach(0..<5, id: \.self) { i in
                Circle().fill(Color.black.opacity(0.25))
                    .frame(width: 5, height: 5)
                    .position(x: CGFloat([60, 300, 180, 340, 120][i]),
                              y: CGFloat([200, 350, 520, 180, 640][i]))
            }
        }
    }
}

/// A soft archery range — dark with subtle concentric target rings.
private struct TargetWorld: View {
    var body: some View {
        ZStack {
            RadialGradient(colors: [Color(hex: "#1a1620"), Color(hex: "#0d0b12")],
                           center: .center, startRadius: 30, endRadius: 460)
            ForEach(1..<6, id: \.self) { i in
                Circle()
                    .stroke(Color(hex: "#c4a8d4").opacity(0.10 + Double(6 - i) * 0.02),
                            lineWidth: 2)
                    .frame(width: CGFloat(i) * 120, height: CGFloat(i) * 120)
            }
        }
    }
}

/// A magical night — dark with scattered, twinkling gold/lavender sparkles.
private struct MagicWorld: View {
    @State private var shimmer = false
    private let sparks = scatterDots(40, wMin: 4, wRange: 8, hMin: 4, hRange: 8)
    var body: some View {
        ZStack {
            RadialGradient(colors: [Color(hex: "#1a1228"), Color(hex: "#0a0712")],
                           center: .center, startRadius: 30, endRadius: 480)
            ForEach(sparks) { s in
                Image(systemName: "sparkle")
                    .font(.system(size: s.w))
                    .foregroundColor(s.gold ? Color(hex: "#D4AF37") : Color(hex: "#c4a8d4"))
                    .position(x: s.x, y: s.y)
                    .opacity(shimmer ? 0.8 : 0.25)
                    .animation(AnimationSystem.easeInOutSine(s.period).repeatForever(autoreverses: true), value: shimmer)
            }
        }
        .onAppear { shimmer = true }
    }
}
