// BucketCatchView.swift
// Pointward › Views
//
// [1/5] THE UNIVERSAL CATCH — a warm wooden bucket that catches every thought,
// the same for all instruments. A thought arrives at the sender's bearing;
// you turn the phone to aim; on lock it drops into the bucket and settles as
// a glowing bubble. Tap a bubble to reveal it full-screen. Warm, consistent,
// immediately understood — replaces the per-instrument CatchModeView.
//
// Guidance text sits ABOVE the bucket (never top, never bottom): the sender's
// name, the live direction, and a small sub-instruction. [5/5]

import SwiftUI
import Combine
import os

struct BucketCatchView: View {

    private static let log = Logger(subsystem: "com.jdcoding75.pointward", category: "bucket")

    let ping: PingManager.ReceivedPing
    let style: SenderStyle
    /// Fired at the reveal moment — "felt" means felt (sets opened_at).
    let onRevealed: () -> Void
    /// The moment has fully landed (or the user chose later).
    let onFinished: () -> Void

    @EnvironmentObject var compass: CompassManager
    @EnvironmentObject var pings:   PingManager

    private enum Phase { case arriving, seeking, locked, dropping, caught, revealed }
    @State private var phase: Phase = .arriving

    // Arrival
    @State private var arrivalPulse = false
    @State private var arrivalTextIn = false
    @State private var orbEntered = false
    // Drop
    @State private var dropProgress: CGFloat = 0      // edge → bucket mouth
    @State private var bubbleSettle = false           // soft bounce settle
    @State private var lockFlash = false
    @State private var dimOthers = false
    // Reveal
    @State private var bloomed = false
    @State private var revealFlood = false
    @State private var named = false
    @State private var debugBypass = false
    @State private var orbPulse = false

    private let tick = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    private var hue: Color { EmojiHue.color(for: ping.emoji) }
    private static let lavender = Color(hex: "#c4a8d4")
    private static let wood     = Color(hex: "#8B4513")
    private static let woodDark = Color(hex: "#6E3A1E")
    private static let band     = Color(hex: "#888888")

    /// Bucket geometry — 200×180, centered slightly above screen center.
    private let bucketW: CGFloat = 200
    private let bucketH: CGFloat = 180
    private let bucketYOffset: CGFloat = -10

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

    /// Bubbles already resting in the bucket — the queue + this one once caught.
    private var bucketEmojis: [String] {
        var list = pings.queue.map(\.emoji)
        if phase == .caught || phase == .revealed { list.append(ping.emoji) }
        return Array(list.suffix(5))
    }

    var body: some View {
        GeometryReader { geo in
            let rad   = compass.state.bearingDegrees * .pi / 180
            let reach = min(geo.size.width, geo.size.height) * 0.42
            let edge  = CGSize(width: CGFloat(sin(rad)) * reach,
                               height: -CGFloat(cos(rad)) * reach)
            let center = CGPoint(x: geo.size.width / 2,
                                 y: geo.size.height / 2 + bucketYOffset)

            ZStack {
                // ── [2/4] THEMED CATCH WORLD — each instrument arrives into
                // its own animated world (sky · space · cork · target · magic). ──
                CatchWorldBackground(style: style)
                    .ignoresSafeArea()
                Color.black.opacity(dimOthers ? 0.25 : 0)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.4), value: dimOthers)

                // ── Arrival lavender wash ──
                Self.lavender.opacity(arrivalPulse ? 0.2 : 0)
                    .ignoresSafeArea().allowsHitTesting(false)

                // ── The bucket ──
                bucketView(center: center, geo: geo)

                // ── The incoming thought orb (seeking → dropping) ──
                if phase == .seeking || phase == .locked || phase == .dropping {
                    incomingOrb
                        .scaleEffect(orbEntered ? (angleError < 5 ? 1.15 : 1.0) : 0.01)
                        .animation(AnimationSystem.easeOutBack(0.5), value: orbEntered)
                        .animation(AnimationSystem.easeInOutSine(0.3), value: angleError < 5)
                        .modifier(DropEffect(progress: dropProgress, edge: edge,
                                             mouth: CGSize(width: 0, height: bucketYOffset - bucketH/2 + 24)))
                        .animation(.easeIn(duration: 0.55), value: dropProgress)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }

                // ── [5/5] Guidance — ABOVE the bucket, three lines ──
                if phase == .arriving || phase == .seeking || phase == .locked {
                    guidance
                        .position(x: geo.size.width / 2,
                                  y: center.y - bucketH/2 - 86)
                }

                // ── Lock flash ──
                Color.white.opacity(lockFlash ? 0.55 : 0)
                    .ignoresSafeArea().allowsHitTesting(false)

                // ── Reveal flood + full-screen reveal ──
                Color(hex: "#fff3d8").opacity(revealFlood ? 0.15 : 0)
                    .ignoresSafeArea().allowsHitTesting(false)
                if phase == .revealed {
                    revealOverlay
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }

                // ── Bottom indicator + escape hatch ──
                if phase != .revealed {
                    VStack {
                        Spacer()
                        Text("\(max(bucketEmojis.count, 1)) thought\(bucketEmojis.count == 1 ? "" : "s") in your bucket ✦")
                            .font(.system(size: 13, design: .serif).italic())
                            .foregroundColor(Self.lavender.opacity(0.8))
                        Button("later · it keeps") { onFinished() }
                            .font(.system(size: 11, design: .serif).italic())
                            .foregroundColor(DesignTokens.Color.textMuted)
                            .padding(.top, 6)
                            .padding(.bottom, 30)
                    }
                }
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

    // ── The bucket drawing ──────────────────────────────────────────────────

    private func bucketView(center: CGPoint, geo: GeometryProxy) -> some View {
        ZStack {
            // Warm glow behind the bucket
            Circle()
                .fill(hue.opacity(0.16))
                .frame(width: 260, height: 260)
                .blur(radius: 40)

            // Handle arcing above
            BucketHandleShape()
                .stroke(Self.band, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: bucketW * 0.9, height: 70)
                .offset(y: -bucketH/2 - 20)

            // Bucket body — wood planks, wider at top
            BucketShape()
                .fill(LinearGradient(colors: [Self.wood, Self.woodDark],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: bucketW, height: bucketH)
                .overlay(bucketPlanks)
                .overlay(bucketBands)
                // The bubbles resting inside (clipped to the bucket)
                .overlay(bucketBubbles.clipShape(BucketShape()))
                .shadow(color: .black.opacity(0.4), radius: 10, y: 6)
        }
        .position(x: center.x, y: center.y)
    }

    private var bucketPlanks: some View {
        HStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { i in
                Rectangle()
                    .stroke(Self.woodDark.opacity(0.5), lineWidth: 1)
                    .frame(maxWidth: .infinity)
                    .overlay(i % 2 == 0 ? Color.white.opacity(0.04) : Color.clear)
            }
        }
        .clipShape(BucketShape())
    }

    private var bucketBands: some View {
        VStack {
            Capsule().fill(Self.band).frame(height: 7).padding(.horizontal, -2).padding(.top, 14)
            Spacer()
            Capsule().fill(Self.band).frame(height: 7).padding(.horizontal, 6).padding(.bottom, 18)
        }
        .frame(width: bucketW, height: bucketH)
        .opacity(0.85)
    }

    /// Thought bubbles stacked from the bottom up — tap to reveal.
    private var bucketBubbles: some View {
        VStack(spacing: -6) {
            Spacer()
            ForEach(Array(bucketEmojis.enumerated()), id: \.offset) { idx, emoji in
                let isNew = idx == bucketEmojis.count - 1 && (phase == .caught || phase == .revealed)
                Circle()
                    .fill(RadialGradient(colors: [EmojiHue.color(for: emoji).opacity(0.5),
                                                  EmojiHue.color(for: emoji).opacity(0.15)],
                                         center: .center, startRadius: 2, endRadius: 26))
                    .frame(width: 50, height: 50)
                    .overlay(Text(emoji).font(.system(size: 24)))
                    .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
                    .shadow(color: EmojiHue.color(for: emoji).opacity(0.5), radius: isNew && bubbleSettle ? 10 : 5)
                    .scaleEffect(isNew ? (bubbleSettle ? 1.0 : 0.5) : 1.0)
                    .offset(x: CGFloat((idx % 2 == 0 ? -1 : 1) * 14))
                    .animation(.spring(response: 0.4, dampingFraction: 0.55), value: bubbleSettle)
            }
            Spacer().frame(height: 18)
        }
        .frame(width: bucketW, height: bucketH)
    }

    // ── The incoming orb ────────────────────────────────────────────────────

    private var incomingOrb: some View {
        Circle()
            .fill(RadialGradient(colors: [hue.opacity(0.95), hue.opacity(0.3), .clear],
                                 center: .center, startRadius: 4, endRadius: 26))
            .frame(width: 48, height: 48)
            .overlay(Text(ping.emoji).font(.system(size: 22)).opacity(0.85))
            .blur(radius: phase == .dropping ? 0 : 0.5)
            .opacity(orbPulse ? 1.0 : 0.82)
            .shadow(color: hue.opacity(0.7), radius: 14)
    }

    // ── Guidance ────────────────────────────────────────────────────────────

    private var guidanceLine2: String {
        if phase == .locked { return "locked ✦" }
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

    private var guidance: some View {
        VStack(spacing: 6) {
            // [copy 2026-06-25] added ✦ to match unified sentence. was: "\(ping.fromName) sent you something"
            Text("\(ping.fromName) sent you something ✦")
                .font(.system(size: 24, design: .serif))
                .foregroundColor(Self.lavender)
            Text(guidanceLine2)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: Self.lavender.opacity(angleError < 5 ? 0.8 : 0.3), radius: 8)
                .animation(.easeInOut(duration: 0.2), value: guidanceLine2)
            Text("turn your phone toward them")
                .font(.system(size: 14))
                .foregroundColor(DesignTokens.Color.textMuted)
            #if DEBUG
            Button("⚙︎ align (sim)") { debugBypass = true }
                .font(.system(size: 9)).foregroundColor(DesignTokens.Color.textDim)
            #endif
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
    }

    // ── Reveal overlay ──────────────────────────────────────────────────────

    private var revealOverlay: some View {
        ZStack {
            Circle()
                .fill(hue.opacity(0.22))
                .frame(width: 200, height: 200)
                .blur(radius: 40)
            VStack(spacing: 18) {
                Text(ping.emoji)
                    .font(.system(size: 72))
                    .scaleEffect(bloomed ? 1.0 : 0.3)
                    .shadow(color: hue.opacity(0.6), radius: 24)
                    .animation(AnimationSystem.easeOutBack(0.4), value: bloomed)
                // [2/5] sender name — the most important text, always visible
                Text("from \(ping.fromName) ✦")
                    .font(.system(size: 28, design: .serif))
                    .foregroundColor(Self.lavender)
                    .opacity(named ? 1 : 0)
                    .animation(.easeIn(duration: 0.5), value: named)
                Text("tap to keep it in your bucket")
                    .font(.system(size: 12, design: .serif).italic())
                    .foregroundColor(DesignTokens.Color.textMuted)
                    .opacity(named ? 0.8 : 0)
            }
        }
    }

    // ── Sequencing ──────────────────────────────────────────────────────────

    private func begin() {
        Self.log.info("bucket: ACTIVATED from=\(ping.fromName, privacy: .public) emoji=\(ping.emoji, privacy: .public)")
        phase = .arriving
        HapticEngine.catchArrival()
        SoundEngine.shared.play(for: "catch.arrival")
        withAnimation(.easeOut(duration: 0.4)) { arrivalPulse = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeIn(duration: 0.4)) { arrivalPulse = false }
        }
        withAnimation(.easeInOut(duration: 0.6).delay(0.15)) { arrivalTextIn = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { enterSeeking() }
    }

    private func enterSeeking() {
        guard phase == .arriving else { return }
        phase = .seeking
        withAnimation(AnimationSystem.easeInOutSine(0.9).repeatForever(autoreverses: true)) {
            orbPulse = true
        }
        SoundEngine.shared.play(for: "catch.lock")
        withAnimation(AnimationSystem.easeOutBack(0.5)) { orbEntered = true }
    }

    private func heartbeat() {
        guard phase == .seeking || phase == .locked else { return }
        HapticEngine.catchAlignment(angleError: angleError)
        if angleError < 5 {
            if phase == .seeking { lockOn() }
        } else if phase == .locked {
            phase = .seeking
            withAnimation(.easeOut(duration: 0.3)) { dimOthers = false }
        }
    }

    private func lockOn() {
        phase = .locked
        Self.log.info("bucket: LOCKED — dropping into the bucket")
        HapticEngine.catchLock()
        SoundEngine.shared.play(for: "catch.lock")
        withAnimation(.easeOut(duration: 0.05)) { lockFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.12)) { lockFlash = false }
        }
        withAnimation(.easeOut(duration: 0.3)) { dimOthers = true }
        // Drop on a committed trajectory into the bucket
        phase = .dropping
        withAnimation(.easeIn(duration: 0.55)) { dropProgress = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { caught() }
    }

    private func caught() {
        phase = .caught
        HapticEngine.rocketLanding()                 // soft thud
        SoundEngine.shared.play(for: "style.bell")
        withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) { bubbleSettle = true }
        // "from [Name]" appears briefly, then the user can tap to reveal
        withAnimation(.easeIn(duration: 0.4)) { named = true }
    }

    private func revealFromBucket() {
        phase = .revealed
        onRevealed()                                 // felt means felt
        HapticEngine.catchReveal()
        SoundEngine.shared.play(for: "style.bell")
        SoundEngine.shared.play(for: ping.emoji)
        withAnimation(.easeOut(duration: 0.2)) { revealFlood = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeIn(duration: 0.2)) { revealFlood = false }
        }
        bloomed = true
        named = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) { onFinished() }
    }

    /// A friendly full-word compass direction ("Northeast").
    private static func fullCardinal(_ degrees: Double) -> String {
        let words = ["North", "North-Northeast", "Northeast", "East-Northeast",
                     "East", "East-Southeast", "Southeast", "South-Southeast",
                     "South", "South-Southwest", "Southwest", "West-Southwest",
                     "West", "West-Northwest", "Northwest", "North-Northwest"]
        let i = ((Int((degrees / 22.5).rounded()) % 16) + 16) % 16
        return words[i]
    }
}

// ════════════════════════════════════════════════════════════════════════
// MARK: - Bucket shapes
// ════════════════════════════════════════════════════════════════════════

/// A cylindrical bucket — wider at the top than the bottom, rounded base.
struct BucketShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let topInset: CGFloat = 0
        let botInset: CGFloat = w * 0.10
        p.move(to: CGPoint(x: topInset, y: 0))
        p.addLine(to: CGPoint(x: w - topInset, y: 0))
        p.addLine(to: CGPoint(x: w - botInset, y: h * 0.92))
        p.addQuadCurve(to: CGPoint(x: w * 0.5, y: h),
                       control: CGPoint(x: w - botInset, y: h))
        p.addQuadCurve(to: CGPoint(x: botInset, y: h * 0.92),
                       control: CGPoint(x: botInset, y: h))
        p.closeSubpath()
        return p
    }
}

/// The handle — a semicircular arc above the bucket.
struct BucketHandleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.height))
        p.addQuadCurve(to: CGPoint(x: rect.width, y: rect.height),
                       control: CGPoint(x: rect.width / 2, y: -rect.height * 0.5))
        return p
    }
}

/// Moves the orb from the sender's edge into the bucket mouth as progress 0→1.
struct DropEffect: GeometryEffect {
    var progress: CGFloat
    var edge: CGSize
    var mouth: CGSize

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let x = edge.width + (mouth.width - edge.width) * progress
        let y = edge.height + (mouth.height - edge.height) * progress
        return ProjectionTransform(CGAffineTransform(translationX: x, y: y))
    }
}
