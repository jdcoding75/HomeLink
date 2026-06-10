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
    @State private var breathe = false       // [3/8] full-screen reveal breathing
    @State private var revealTapArmed = false // [3/8] ignore stray taps for ~1.2 s
    @State private var revealFlood = false
    @State private var named = false
    @State private var debugBypass = false
    @State private var pulse = false
    // [1/3] SPIN-TO-CATCH — finger spin on the bucket, NO phone rotation.
    @State private var thoughtAngle: Double = 120   // fixed sender direction (deg)
    @State private var bucketAngle: Double = 0        // finger-spun opening direction
    @State private var lastFingerAngle: Double? = nil

    private let tick = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    private var hue: Color { EmojiHue.color(for: ping.emoji) }
    private static let lavender  = Color(hex: "#c4a8d4")
    private static let warmWhite = Color(hex: "#f3ecdf")

    private var angleError: Double {
        if debugBypass { return 0 }
        // [2/3] Spin alignment ONLY — the angle between the bucket opening and
        // the fixed thought direction. No CLHeading / magnetometer / phone turn.
        return BearingCalculator.alignmentError(relativeBearing: thoughtAngle - bucketAngle)
    }

    /// SPIN — track the finger's angle around the bucket centre (the 240×260
    /// drag frame's centre is 120,130) and rotate by the wrap-safe DELTA.
    private var spinGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                let a = atan2(v.location.y - 130, v.location.x - 120) * 180 / .pi
                if let last = lastFingerAngle {
                    var d = a - last
                    if d > 180 { d -= 360 } else if d < -180 { d += 360 }
                    bucketAngle += d
                }
                lastFingerAngle = a
            }
            .onEnded { _ in lastFingerAngle = nil }
    }
    private var caughtEmojis: [String] {
        var list = pings.queue.map(\.emoji)
        if phase == .caught || phase == .revealed { list.append(ping.emoji) }
        return Array(list.suffix(5))
    }

    var body: some View {
        // [wind] DISPATCH — wind owns a dedicated, end-to-end receipt
        // (WindReceiptAnimation): the leaf enters from the sender's bearing,
        // drifts, AUTO-CATCHES into the bucket over 7.2s, plays wind_receipt.wav,
        // fires its haptics, and hands off to EmojiRevealView. Every OTHER
        // instrument keeps the shared spin-to-catch receipt below, untouched.
        // This intercepts at the receipt layer (the only place that carries
        // senderBearing/from/message/tagline) so no dispatcher signature
        // changes and no existing call site is affected.
        // [instrument versioning] V1 receipts are active: bow/flick/plane route to
        // the shared spin-to-catch `standardReceipt` (their proven original path).
        // Wind + Rocket keep their dedicated, approved full receipts. The today's
        // V2 receipts (BowReceiptAnimationV2 / FlickReceiptAnimationV2 /
        // PlaneReceiptAnimationV2) are parked for the Animation Test Lab only.
        if ping.emoji == "🎂" {
            // [birthday] 🎂 is a SPECIAL emoji receipt — the cake is the vessel,
            // there is NO bucket. Intercepted by emoji (not style) above every
            // instrument so a birthday always arrives as a cake.
            birthdayReceipt
        } else if style == .firefly {
            windReceipt
        } else if style == .rocket {
            rocketReceipt
        } else {
            standardReceipt
        }
    }

    // ── BIRTHDAY 🎂 — the special cake receipt (no bucket) ──────────────────

    private var birthdayReceipt: some View {
        BirthdayCakeReceipt(
            emoji: ping.emoji,
            message: ping.message,
            tagline: ping.tagline,
            fromName: ping.fromName,
            onRevealed: { revealHandoff() },
            onFinished: onFinished
        )
    }

    // ── PLANE / BOW / FLICK — V2 dedicated receipts (PARKED) ───────────────
    // These three full-screen receipts (the today's redesigns) are no longer
    // wired into the live path — bow/flick/plane receive via the shared
    // `standardReceipt` (V1) above. The V2 structs live in the instrument folders
    // (…ReceiptAnimationV2) and are exercised only from the Animation Test Lab.
    // Kept here (commented) so the live wiring is trivial to restore on promotion.
    //
    // private var planeReceipt: some View {
    //     PlaneReceiptAnimationV2(
    //         senderBearing: compass.rawBearingToTarget ?? 120,
    //         emoji: ping.emoji, message: ping.message, tagline: ping.tagline,
    //         fromName: ping.fromName,
    //         onRevealed: { revealHandoff() }, onFinished: onFinished)
    // }
    // private var bowReceipt: some View {
    //     BowReceiptAnimationV2(
    //         senderBearing: compass.rawBearingToTarget ?? 120,
    //         emoji: ping.emoji, message: ping.message, tagline: ping.tagline,
    //         fromName: ping.fromName,
    //         onRevealed: { revealHandoff() }, onFinished: onFinished)
    // }
    // private var flickReceipt: some View {
    //     FlickReceiptAnimationV2(
    //         senderBearing: compass.rawBearingToTarget ?? 120,
    //         emoji: ping.emoji, message: ping.message, tagline: ping.tagline,
    //         fromName: ping.fromName,
    //         onRevealed: { revealHandoff() }, onFinished: onFinished)
    // }

    // ── WIND — the dedicated full receipt ──────────────────────────────────

    private var windReceipt: some View {
        WindReceiptAnimation(
            senderBearing: compass.rawBearingToTarget ?? 120,
            emoji: ping.emoji,
            message: ping.message,
            tagline: ping.tagline,
            fromName: ping.fromName,
            onRevealed: { revealHandoff() },
            onFinished: onFinished
        )
    }

    // ── ROCKET — the dedicated v2 parachute receipt ────────────────────────

    private var rocketReceipt: some View {
        RocketReceiptAnimation(
            senderBearing: compass.rawBearingToTarget ?? 120,
            emoji: ping.emoji,
            message: ping.message,
            tagline: ping.tagline,
            fromName: ping.fromName,
            onRevealed: { revealHandoff() },
            onFinished: onFinished
        )
    }

    /// "Felt means felt" at the reveal, plus the auto-catch linger/advance —
    /// shared by every dedicated full-receipt instrument.
    private func revealHandoff() {
        onRevealed()
        if pings.isAutoCatching {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if pings.isAutoCatching { onFinished() }
            }
        }
    }

    // ── The shared spin-to-catch receipt (all non-wind instruments) ────────

    private var standardReceipt: some View {
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

                // [1/5] THE SENDER MARKER + INCOMING THOUGHT live in FULL-SCREEN
                // space (not the 60% middle band) so the thought begins at the
                // true screen edge and travels the full distance to the centred
                // bucket — a long, dramatic journey, never "already near."
                if phase == .arriving || phase == .seeking || phase == .locked || phase == .dropping {
                    // Sender initial, FAR out at the edge where the thought starts.
                    if phase == .seeking || phase == .locked {
                        PersonInitialMarker(initial: senderInitial, opacity: markerOpacity,
                                            near: angleError < 30, close: angleError < 15,
                                            perfect: angleError < 5, pulse: pulse)
                            .offset(edgeOffset(geo: geo))
                            .animation(.easeOut(duration: 0.2), value: angleError < 15)
                            .allowsHitTesting(false)
                    }
                    themedIncoming
                        .scaleEffect(incomingScale)
                        .opacity(phase == .dropping ? max(0, 1 - Double(approach)) : 1)
                        .offset(incomingOffset(geo: geo))
                        .animation(.easeOut(duration: 0.5), value: orbEntered)
                        .animation(.easeInOut(duration: 0.4), value: approach)
                        .animation(.easeInOut(duration: 0.4), value: thoughtAngle)
                        .allowsHitTesting(false)
                }

                // THE REVEAL — once landed, EVERY instrument hands off to the
                // ONE shared EmojiRevealView: emoji blooms to 156pt (🤗 arm
                // squeeze ×3), the emoji .wav + reveal haptic fire inside it,
                // "from [Name] ✦", over the instrument's own world (ambient).
                // (Wind takes the dedicated WindReceiptAnimation path instead.)
                if phase == .revealed {
                    EmojiRevealView(
                        emoji: ping.emoji,
                        message: ping.message,
                        tagline: ping.tagline,
                        context: .received(fromName: ping.fromName),
                        ambient: RevealAmbient.forStyle(style),
                        onDismiss: { onFinished() }
                    )
                    .transition(.opacity)
                }

                // ── Reveal flash/flood over everything ──
                Color.white.opacity(lockFlash ? 0.5 : 0).ignoresSafeArea().allowsHitTesting(false)
                Color(hex: "#fff3d8").opacity(revealFlood ? 0.15 : 0).ignoresSafeArea().allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if phase == .caught { revealFromBucket() }
                // [3/8] never rushed — ignore taps for the first ~1.2 s.
                else if phase == .revealed && revealTapArmed {
                    HapticEngine.stopRevealPresence()   // [4/8] end the lingering pulse
                    onFinished()
                }
            }
        }
        .onAppear {
            begin()
            // [4/5] AUTO-CATCH — when the bucket is draining automatically, bypass
            // the spin-to-align step so this receipt locks, lands, and reveals on
            // its own; revealAfterLanding then auto-advances to the next thought.
            if pings.isAutoCatching { debugBypass = true }
        }
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

    // ── [3/8] FULL-SCREEN REVEAL — the emoji fills the screen, like a letter ─
    private var fullScreenReveal: some View {
        ZStack {
            // Deep purple world.
            RadialGradient(colors: [Color(hex: "#1a1228"), Color(hex: "#0d0d14")],
                           center: .center, startRadius: 30, endRadius: 540)
                .ignoresSafeArea()
            // Warm glow in the emoji's hue, radiating slowly outward.
            Circle().fill(hue.opacity(0.30))
                .frame(width: 360, height: 360).blur(radius: 90)
                .scaleEffect(breathe ? 1.18 : 0.88)
                .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: breathe)

            VStack(spacing: 22) {
                Text(ping.emoji)
                    .font(.system(size: 140))
                    .scaleEffect(breathe ? 1.02 : 0.98)   // breathing 0.98–1.02, 3 s
                    .shadow(color: hue.opacity(0.6), radius: 42)
                    .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: breathe)

                if let message = ping.message, !message.isEmpty {
                    Text(message)
                        .font(.system(size: 28, design: .serif))
                        .foregroundColor(Self.lavender)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 36)
                }
                if let tagline = ping.tagline, !tagline.isEmpty {
                    Text(tagline)
                        .font(.system(size: 20, design: .serif).italic())
                        .foregroundColor(Self.lavender.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 36)
                }
                Text("from \(ping.fromName) ✦")
                    .font(.system(size: 24, design: .serif))
                    .foregroundColor(Self.warmWhite)
            }
            .padding(.bottom, 20)

            VStack {
                Spacer()
                Text("tap anywhere to continue")
                    .font(.system(size: 13, design: .serif).italic())
                    .foregroundColor(Self.lavender.opacity(0.5))
                    .opacity(revealTapArmed ? 1 : 0)
                    .animation(.easeIn(duration: 0.6), value: revealTapArmed)
                    .padding(.bottom, 44)
            }
        }
        .allowsHitTesting(false)   // taps fall through to the container's gesture
        .onAppear { breathe = true }
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
                    // AUDIT [5/6]: the sender's per-person tagline travels with
                    // the thought — show it on the live catch (was only in the
                    // orphaned CatchModeView before).
                    if let tagline = ping.tagline, !tagline.isEmpty {
                        Text(tagline)
                            .font(.system(size: 16, design: .serif).italic())
                            .foregroundColor(Self.lavender.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .opacity(named ? 1 : 0)
                            .animation(.easeIn(duration: 0.55), value: named)
                            .padding(.horizontal, 30)
                    }
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
                // [1/5] The bucket is CENTRED in the middle band — and since the
                // band is the screen's middle 60%, that puts the bucket at ~50%
                // vertical, with breathing room all around. (The incoming thought
                // + sender marker now live in full-screen space — see body.)
                bucket
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

    /// [2/3] The sender's bearing in radians (screen convention: 0° = up,
    /// x = sin, y = -cos — matches the rim arrow + the edge marker).
    private var thoughtRad: Double { thoughtAngle * .pi / 180 }

    /// [1/5] The point on the SCREEN EDGE in the sender's bearing direction,
    /// measured as an offset from screen centre. This is where the thought
    /// begins and where the sender marker sits — the full dramatic distance from
    /// the centred bucket. Computed as the ray/rectangle intersection so it's a
    /// true edge point for any bearing (kept a hair inside so it's never clipped).
    private func edgeOffset(geo: GeometryProxy, inset: CGFloat = 0.94) -> CGSize {
        let dx = sin(thoughtRad), dy = -cos(thoughtRad)
        let halfW = geo.size.width / 2, halfH = geo.size.height / 2
        let tx: CGFloat = abs(dx) < 0.0001 ? .greatestFiniteMagnitude : halfW / CGFloat(abs(dx))
        let ty: CGFloat = abs(dy) < 0.0001 ? .greatestFiniteMagnitude : halfH / CGFloat(abs(dy))
        let t = min(tx, ty) * inset
        return CGSize(width: CGFloat(dx) * t, height: CGFloat(dy) * t)
    }

    /// [1/5] The incoming thought's offset from screen centre. It MUST begin at
    /// the screen EDGE (sender's bearing) on its first frame, then travel the
    /// FULL distance inward to the centred bucket as `approach` grows
    /// (0 far → 1 arrived). Never centred first, never appears near the bucket.
    private func incomingOffset(geo: GeometryProxy) -> CGSize {
        let start = edgeOffset(geo: geo)
        // End at the bucket mouth — bucket is screen-centred, mouth sits a little
        // above its centre.
        let end = CGSize(width: 0, height: -40)
        if phase == .dropping { return CGSize(width: 0, height: -10) }
        let t = approach
        return CGSize(width: start.width + (end.width - start.width) * t,
                      height: start.height + (end.height - start.height) * t)
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
                    Text("spin until the arrow faces \(ping.fromName)")
                        .font(.system(size: 13))
                        .foregroundColor(DesignTokens.Color.textMuted)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.8)
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
        // [1/3] Spin the bucket — no phone turning.
        if phase == .locked || phase == .dropping || phase == .caught { return "locked ✦" }
        switch angleError {
        case ..<5:  return "locked ✦"
        case ..<15: return "almost there ✦"
        default:    return "spin the bucket toward \(ping.fromName)"
        }
    }

    // ── The bucket ──────────────────────────────────────────────────────────

    private var bucket: some View {
        // The bucket ART spins with your finger; its rim arrow is the opening.
        // The sender marker no longer orbits the rim — it now sits far out at the
        // screen edge (see body), where the thought begins its journey. [1/5]
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
            // [5/5] Rim arrow — the OPENING. It points outward from the rim
            // and rotates with the bucket, so "spin until the arrow faces
            // [Name]" is literally true: line it up with the edge marker.
            Triangle()
                .fill(angleError < 5 ? Self.lavender : Self.lavender.opacity(0.9))
                .frame(width: 18, height: 16)
                .offset(y: -86)
                .shadow(color: Self.lavender.opacity(angleError < 5 ? 0.9 : 0.35), radius: 6)
        }
        // [1/3] The art spins with your finger (no phone turning). The
        // rotation is on the art only; the gesture sits on the unrotated
        // 240×260 frame so spinning never feeds back on itself.
        .rotationEffect(.degrees(bucketAngle))
        .padding(.bottom, 8)
        .frame(width: 240, height: 260)
        .contentShape(Rectangle())
        .gesture(spinGesture)
    }

    /// The sender's first initial for the orbiting marker (• when unknown).
    private var senderInitial: String {
        let trimmed = ping.fromName.trimmingCharacters(in: .whitespaces)
        return trimmed.first.map { String($0).uppercased() } ?? "•"
    }

    /// Marker brightness — brightens steadily as the spin approaches the
    /// sender's bearing, mirroring DirectionIndicator's behaviour.
    private var markerOpacity: Double {
        switch angleError {
        case ..<5:   return pulse ? 1.0 : 0.9
        case ..<15:  return 0.9
        case ..<30:  return 0.65
        default:     return 0.45
        }
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
        // [3/4] Every traveling object is ~50% bigger — substantial, readable,
        // rocket-grade drama. The emoji is always clearly legible.
        switch style {
        case .firefly:  // wind — a big leaf carrying the emoji
            ZStack {
                LeafShape().fill(Color(hex: "#5a8a3a"))
                    .frame(width: 96, height: 66)
                Text(ping.emoji).font(.system(size: 40)).offset(y: -9)
            }
            .rotationEffect(.degrees(pulse ? 6 : -6))
        case .rocket:   // rocket descending
            VStack(spacing: -3) {
                Text("🚀").font(.system(size: 60)).rotationEffect(.degrees(180))
                Text(ping.emoji).font(.system(size: 33))
            }
        case .plane:    // [1/4] a plane banking in, carrying the emoji
            ZStack {
                Text("✈️").font(.system(size: 64))
                    .rotationEffect(.degrees(pulse ? 9 : -9))   // banks left/right — alive
                    .shadow(color: .black.opacity(0.22), radius: 10, y: 8)
                Text(ping.emoji).font(.system(size: 26)).offset(y: 3)
            }
        case .fingerFlick:  // [2/4] a BIG paper note tumbling in
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(Color(hex: "#F5F0E0"))
                    .frame(width: 84, height: 90)
                Text(ping.emoji).font(.system(size: 42))
            }
            .rotationEffect(.degrees(approach * 360))
            .shadow(color: .black.opacity(0.35), radius: 7, y: 4)
        case .bowArrow: // an arrow with the emoji, growing toward you
            ZStack {
                Circle().fill(RadialGradient(colors: [hue.opacity(0.9), .clear],
                                             center: .center, startRadius: 3, endRadius: 45))
                    .frame(width: 90, height: 90)
                Text(ping.emoji).font(.system(size: 45))
            }
        case .wand:     // sparkles converging into the emoji
            ZStack {
                ForEach(0..<8, id: \.self) { i in
                    let a = Double(i) / 8 * 2 * .pi
                    let r: CGFloat = (1 - approach) * 75 + 14
                    Image(systemName: "sparkle")
                        .font(.system(size: 12))
                        .foregroundColor(i % 2 == 0 ? Color(hex: "#D4AF37") : Self.lavender)
                        .offset(x: CGFloat(cos(a)) * r, y: CGFloat(sin(a)) * r)
                }
                Text(ping.emoji).font(.system(size: 45)).opacity(Double(approach))
            }
        default:        // compass + glow — a big warm glowing orb
            ZStack {
                Circle().fill(RadialGradient(colors: [hue.opacity(0.95), hue.opacity(0.3), .clear],
                                             center: .center, startRadius: 6, endRadius: 42))
                    .frame(width: 84, height: 84)
                Text(ping.emoji).font(.system(size: 40)).opacity(0.9)
            }
        }
    }

    // ── Sequencing ──────────────────────────────────────────────────────────

    private func begin() {
        Self.log.info("receipt: from=\(ping.fromName, privacy: .public) emoji=\(ping.emoji, privacy: .public) style=\(style.rawValue, privacy: .public)")
        phase = .arriving
        // [2/3] Lock the sender's bearing BEFORE the first frame so the incoming
        // thought is placed at the correct screen edge from the very start —
        // never centered, never re-homed when seeking begins.
        thoughtAngle = compass.rawBearingToTarget ?? 120
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
        // [1/3] Fix the thought at the sender's bearing (or a stable angle when
        // no location) — it never moves; the user spins the bucket to it.
        thoughtAngle = compass.rawBearingToTarget ?? 120
        bucketAngle = 0
        lastFingerAngle = nil
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
        // The emoji .wav + reveal haptic now fire INSIDE EmojiRevealView (the
        // single reveal screen) — no longer played here, so they never double.
        armRevealTap()
        withAnimation(.easeOut(duration: 0.2)) { revealFlood = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeIn(duration: 0.2)) { revealFlood = false }
        }
        // [4/5] AUTO-CATCH — linger on the reveal a beat, then move on by itself.
        if pings.isAutoCatching {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if pings.isAutoCatching { onFinished() }
            }
        }
    }

    /// [3/8] Arm the dismiss tap after a beat so the reveal is never rushed.
    private func armRevealTap() {
        revealTapArmed = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { revealTapArmed = true }
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
        armRevealTap()
        SoundEngine.shared.play(for: "style.bell")      // the soft catch chime
        // The emoji .wav + reveal haptic fire INSIDE EmojiRevealView (the single
        // reveal screen) — not here, so they never double.
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
        case .firefly:     SkyWorld()          // wind — day sky + clouds
        case .plane:       SkyWorld()          // plane — daytime blue sky + clouds
        case .fingerFlick: CorkWorld()         // flick — cork board
        case .bowArrow:    TargetWorld()       // bow — archery range
        case .wand:        MagicWorld()        // wand — magical sparkles
        case .glow:        CompassGlowWorld()  // [2/8] compass — deep purple glow
        default:           SpaceWorld()        // rocket — deep space + stars
        }
    }
}

/// [2/8] COMPASS — a deep purple glow that radiates slowly from the centre.
private struct CompassGlowWorld: View {
    var body: some View {
        ZStack {
            Color(hex: "#0d0d14")
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                let pulse = (sin(t / 2.0) + 1) / 2        // 0…1, ~12 s cycle
                RadialGradient(
                    colors: [Color(hex: "#7c6b8e").opacity(0.55),
                             Color(hex: "#3a2f4a").opacity(0.35),
                             Color(hex: "#0d0d14")],
                    center: .center,
                    startRadius: 20 + CGFloat(pulse) * 40,
                    endRadius: 360 + CGFloat(pulse) * 120)
                .opacity(0.85)
            }
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
        GeometryReader { geo in
            ZStack {
                RadialGradient(colors: [Color(hex: "#1a1620"), Color(hex: "#0d0b12")],
                               center: .center, startRadius: 30, endRadius: 460)
                    .ignoresSafeArea()
                // [6/6] The archery target — concentric rings pinned EXACTLY to
                // the centre of the screen (50% / 50%), so it reads as aiming
                // straight ahead, never tucked low and to the right.
                ForEach(1..<6, id: \.self) { i in
                    Circle()
                        .stroke(Color(hex: "#c4a8d4").opacity(0.10 + Double(6 - i) * 0.02),
                                lineWidth: 2)
                        .frame(width: CGFloat(i) * 120, height: CGFloat(i) * 120)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
            }
        }
        .ignoresSafeArea()
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
