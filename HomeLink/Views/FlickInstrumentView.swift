// FlickInstrumentView.swift
// Pointward › Views
//
// INSTRUMENT 4 — FLICK (Pro). SLINGSHOT REDESIGN: a dramatic Y-shaped
// slingshot — warm wood fork, wrapped leather handle, a dark elastic band
// with a leather pocket cradling the thought. The whole rig rotates to face
// the person; pull the pocket BACK to stretch the band, and release to
// launch the thought toward them. Within 5° it's "✦ perfect".
//
// onSend(perfect) fires the shared send pipeline (full-screen slingshot
// launch lives in SenderAnimationView).

import SwiftUI

struct FlickInstrumentView: View {

    let loadedToken: String?
    let loadedSymbol: AnyView?
    /// Resolved emoji for the loaded thought — drives the pocket glow hue.
    var loadedEmoji: String? = nil
    let bearingDegrees: Double
    let personName: String
    var personEmoji: String = "💜"
    /// perfect = released within 5°.
    let onSend: (_ perfect: Bool) -> Void

    @State private var stretch: CGFloat = 0          // 0…80 px pull-back
    @State private var dragging = false
    @State private var pocketPulse = false           // rest breathing 0.97–1.03
    @State private var bandVibrate = false           // post-release shudder
    @State private var missWobble = false
    @State private var showMissHint = false
    @State private var showPerfect = false
    @State private var showRelease = false           // "release to launch" at max
    @State private var haptic30 = false
    @State private var haptic60 = false
    @State private var hapticMax = false

    private static let wood     = Color(hex: "#8B4513")
    private static let woodLit   = Color(hex: "#B5703A")
    private static let leather   = Color(hex: "#3a1a0a")
    private static let pocketCol = Color(hex: "#5a3020")
    private static let elastic   = Color(hex: "#1a0a0a")
    private static let lavender  = Color(hex: "#c4a8d4")
    private static let orange    = Color(hex: "#e08a3c")

    private let maxStretch: CGFloat = 80

    // Local geometry (unrotated, fork pointing "up" toward the person)
    private let forkJoint   = CGPoint(x: 0, y: 34)
    private let handleEnd   = CGPoint(x: 0, y: 120)
    private let leftTip     = CGPoint(x: -70, y: -94)
    private let rightTip    = CGPoint(x: 70, y: -94)
    private var pocketRest: CGPoint { CGPoint(x: 0, y: -74) }   // slight band sag

    private var rad: Double { bearingDegrees * .pi / 180 }
    private var alignDiff: Double { BearingCalculator.alignmentError(relativeBearing: bearingDegrees) }
    private var aligned: Bool { BearingCalculator.isSendAligned(bearingDegrees) }
    private var perfect: Bool { BearingCalculator.isLockAligned(bearingDegrees) }
    private var tension: CGFloat { stretch / maxStretch }   // 0…1
    private var pocketLocal: CGPoint { CGPoint(x: 0, y: pocketRest.y + stretch) }
    private var hue: Color { EmojiHue.color(for: loadedEmoji ?? "💜") }

    var body: some View {
        ZStack {
            // ── The dark instrument circle ──
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                .frame(width: 360, height: 360)

            // ── Where they are — shared marker · arc (outside the rig) ──
            DirectionIndicator(bearingDegrees: bearingDegrees,
                               personName: personName,
                               personEmoji: personEmoji,
                               ringRadius: 165,
                               showHint: loadedToken == nil)

            // ── The slingshot frame (rotates to face the person) ──
            slingshotFrame

            // ── Trajectory while pulling — where it will fly ──
            if dragging, stretch > 12 {
                trajectory
            }

            // ── The elastic band + pocket + thought ──
            elasticBand
            pocketAndThought

            // ── "✦ perfect" / "release to launch" ──
            if showPerfect {
                Text("✦ perfect")
                    .font(.system(size: 15, design: .serif).italic())
                    .foregroundColor(Color(hex: "#FFD700"))
                    .shadow(color: Color(hex: "#FFD700").opacity(0.7), radius: 8)
                    .offset(y: -150)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
            }

            // ── Instructions ──
            VStack {
                Spacer()
                if showMissHint {
                    Text("aim toward \(personName)")
                        .font(.system(size: 12, design: .serif).italic())
                        .foregroundColor(Self.orange)
                } else if showRelease {
                    Text("release to launch")
                        .font(.system(size: 13, design: .serif).italic())
                        .foregroundColor(Self.lavender)
                } else if loadedToken != nil && !dragging {
                    Text("pull back to aim at \(personName)")
                        .font(.system(size: 12, design: .serif).italic())
                        .foregroundColor(Self.lavender.opacity(0.85))
                }
            }
            .padding(.bottom, 2)
            .allowsHitTesting(false)
        }
        .frame(width: 370, height: 370)
        .animation(.easeOut(duration: 0.25), value: showMissHint)
        .animation(.easeOut(duration: 0.25), value: showRelease)
        .animation(.easeOut(duration: 0.3), value: showPerfect)
        .onAppear {
            withAnimation(AnimationSystem.easeInOutSine(2.0)
                            .repeatForever(autoreverses: true)) {
                pocketPulse = true
            }
        }
    }

    // ── Geometry helpers ──────────────────────────────────────────────────

    /// Rotate a local point into screen space by the person's bearing, so
    /// the fork always points at them.
    private func screen(_ p: CGPoint) -> CGSize {
        let c = cos(rad), s = sin(rad)
        return CGSize(width: p.x * c - p.y * s, height: p.x * s + p.y * c)
    }

    private func screenPoint(_ p: CGPoint, in size: CGSize) -> CGPoint {
        let o = screen(p)
        return CGPoint(x: size.width / 2 + o.width, y: size.height / 2 + o.height)
    }

    // ── The wooden frame ──────────────────────────────────────────────────

    private var slingshotFrame: some View {
        GeometryReader { geo in
            ZStack {
                // Two fork posts — joint → each tip (the V)
                forkPath(geo.size)
                    .stroke(Self.wood, style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                forkPath(geo.size)   // wood-grain: a thinner lighter pass
                    .stroke(Self.woodLit.opacity(0.5),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .offset(x: -1, y: -1)

                // Handle — joint → bottom, wrapped leather grip
                Path { p in
                    p.move(to: screenPoint(forkJoint, in: geo.size))
                    p.addLine(to: screenPoint(handleEnd, in: geo.size))
                }
                .stroke(Self.leather, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                // Grip marks — short rungs across the handle
                gripMarks(geo.size)
            }
            .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
        }
        .frame(width: 360, height: 360)
        .allowsHitTesting(false)
    }

    private func forkPath(_ size: CGSize) -> Path {
        Path { p in
            p.move(to: screenPoint(leftTip, in: size))
            p.addLine(to: screenPoint(forkJoint, in: size))
            p.addLine(to: screenPoint(rightTip, in: size))
        }
    }

    private func gripMarks(_ size: CGSize) -> some View {
        ForEach(0..<4, id: \.self) { i in
            let f = CGFloat(i) / 3
            let y = forkJoint.y + (handleEnd.y - forkJoint.y) * (0.2 + f * 0.6)
            Capsule()
                .fill(Color.black.opacity(0.5))
                .frame(width: 16, height: 2)
                .rotationEffect(.radians(rad))
                .position(screenPoint(CGPoint(x: 0, y: y), in: size))
        }
    }

    // ── The elastic band ──────────────────────────────────────────────────

    private var elasticBand: some View {
        GeometryReader { geo in
            // Band thins (2→1 px) and lightens under tension.
            let width = 2 - tension * 1.0
            let bandColor = Self.elastic.opacity(1 - Double(tension) * 0.55)
            Path { p in
                p.move(to: screenPoint(leftTip, in: geo.size))
                if dragging || stretch > 0 {
                    p.addLine(to: screenPoint(pocketLocal, in: geo.size))
                    p.addLine(to: screenPoint(rightTip, in: geo.size))
                } else {
                    // At rest the band sags gently between the tips
                    p.addQuadCurve(to: screenPoint(rightTip, in: geo.size),
                                   control: screenPoint(CGPoint(x: 0, y: pocketRest.y + 10),
                                                        in: geo.size))
                }
            }
            .stroke(bandColor, style: StrokeStyle(lineWidth: max(1, width), lineCap: .round))
            .offset(x: bandVibrate ? 2 : 0)
            .animation(.spring(response: 0.18, dampingFraction: 0.3), value: bandVibrate)
        }
        .frame(width: 360, height: 360)
        .allowsHitTesting(false)
    }

    // ── The pocket + thought (the draggable part) ─────────────────────────

    private var pocketAndThought: some View {
        let restScale: CGFloat = pocketPulse ? 1.03 : 0.97
        return ZStack {
            // Leather pocket
            RoundedRectangle(cornerRadius: 8)
                .fill(Self.pocketCol)
                .frame(width: 40, height: 30)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black.opacity(0.4), lineWidth: 1)
                )
                .shadow(color: hue.opacity(0.25), radius: dragging ? 12 : 6)

            // The thought, glowing in its hue, breathing at rest
            if let loadedSymbol {
                loadedSymbol
                    .scaleEffect(dragging ? 1.0 : restScale)
                    .shadow(color: hue.opacity(dragging ? 0.55 : 0.25),
                            radius: dragging ? 10 : 6)
            }
        }
        .rotationEffect(.radians(missWobble ? rad + 0.16 : rad))   // upright-ish, wobble on miss
        .offset(screen(pocketLocal))
        .animation(missWobble ? .spring(response: 0.16, dampingFraction: 0.25)
                              : .easeOut(duration: 0.2), value: missWobble)
        .gesture(loadedToken != nil ? pullGesture : nil)
    }

    // ── The trajectory hint ───────────────────────────────────────────────

    private var trajectory: some View {
        GeometryReader { geo in
            Path { p in
                // From the pocket forward through the fork toward the person.
                p.move(to: screenPoint(pocketLocal, in: geo.size))
                p.addLine(to: screenPoint(CGPoint(x: 0, y: -176), in: geo.size))
            }
            .stroke(aligned ? Self.lavender.opacity(0.75) : Self.orange.opacity(0.75),
                    style: StrokeStyle(lineWidth: 2, dash: [4, 7]))
        }
        .frame(width: 360, height: 360)
        .allowsHitTesting(false)
    }

    // ── The pull-and-release gesture ──────────────────────────────────────

    private var pullGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                guard loadedToken != nil else { return }
                dragging = true
                // Project the drag onto the pull-back axis (local +y).
                let c = cos(-rad), s = sin(-rad)
                let localY = value.translation.width * s + value.translation.height * c
                stretch = min(maxStretch, max(0, localY))
                // Tension haptics at 30 / 60 / 80 px
                if stretch >= 30 && !haptic30 { haptic30 = true; HapticEngine.sendSoft() }
                if stretch >= 60 && !haptic60 { haptic60 = true; HapticEngine.send() }
                if stretch >= maxStretch - 0.5 && !hapticMax {
                    hapticMax = true; HapticEngine.lockOn()
                    withAnimation { showRelease = true }
                }
                if stretch < 30 { haptic30 = false }
                if stretch < 60 { haptic60 = false }
                if stretch < maxStretch - 0.5 {
                    hapticMax = false
                    if showRelease { withAnimation { showRelease = false } }
                }
            }
            .onEnded { _ in
                dragging = false
                let launched = stretch
                resetHaptics()
                withAnimation { showRelease = false }

                guard loadedToken != nil, launched > 24 else {
                    snapBack()
                    return
                }

                if aligned {
                    bandVibrate = true
                    HapticEngine.thoughtLaunched()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { bandVibrate = false }
                    if perfect {
                        HapticEngine.lockOn()
                        withAnimation { showPerfect = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            withAnimation { showPerfect = false }
                        }
                    }
                    snapBack()
                    onSend(perfect)
                } else {
                    // MISS — comic wobble, the band snaps back empty-handed
                    HapticEngine.sendSoft()
                    missWobble = true
                    showMissHint = true
                    snapBack()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { missWobble = false }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                        withAnimation { showMissHint = false }
                    }
                }
            }
    }

    /// The band SNAPS back — easeOutBack overshoot and settle.
    private func snapBack() {
        withAnimation(AnimationSystem.easeOutBack(0.4)) { stretch = 0 }
    }

    private func resetHaptics() {
        haptic30 = false; haptic60 = false; hapticMax = false
    }
}
