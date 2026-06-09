// FlickInstrumentView.swift
// Pointward › Views
//
// INSTRUMENT 4 — FLICK (Pro). [5/7] PAPER MESSAGE redesign (slingshot retired):
// the thought is wrapped in a little rolled paper scroll resting at the bottom
// of the circle, the emoji peeking from its end. A gentle looping finger shows
// the mechanic — pull back, flick forward. The user FLICKS the scroll toward
// the person's initial marker: a quick swipe (fast enough to count, forgiving
// on aim — within 45°) launches it. Mid-flight the paper unrolls and the emoji
// tumbles forward. A weak or wild flick bounces back comically.
//
// onSend(perfect) fires the shared send pipeline (the full-screen flick lives
// in SenderAnimationView).

import SwiftUI

struct FlickInstrumentView: View {

    let loadedToken: String?
    let loadedSymbol: AnyView?
    /// Resolved emoji for the loaded thought — drives the glow hue.
    var loadedEmoji: String? = nil
    let bearingDegrees: Double
    let personName: String
    var personEmoji: String = "💜"
    /// perfect = flicked nearly straight at them (within 15°).
    let onSend: (_ perfect: Bool) -> Void

    @State private var dragOffset: CGSize = .zero    // live finger drag
    @State private var dragging = false
    @State private var interacted = false            // hides the finger hint
    @State private var fingerPhase = false           // looping demo finger
    @State private var scrollPulse = false           // gentle rest breathing
    // Launch
    @State private var flying = false
    @State private var flightProgress: CGFloat = 0
    @State private var unrolled = false
    @State private var flightDir: Double = 0          // radians the scroll flies
    // Miss
    @State private var missBounce = false
    @State private var showMissHint = false

    private static let paper    = Color(hex: "#F5E6C8")
    private static let paperEdge = Color(hex: "#E0C99A")
    private static let paperLine = Color(hex: "#C9A86A")
    private static let lavender = Color(hex: "#c4a8d4")
    private static let orange   = Color(hex: "#e08a3c")

    private var rad: Double { bearingDegrees * .pi / 180 }
    private var hue: Color { EmojiHue.color(for: loadedEmoji ?? "💜") }

    /// The scroll rests near the bottom of the circle.
    // [2/5] The note rests at the COMPASS CENTRE — drag backward in ANY
    // direction and flick toward the person, full travel distance for every
    // bearing, no dead zones.
    private let restOffset = CGSize(width: 0, height: 0)

    private let minFlickSpeed: CGFloat = 300          // points / second
    private let aimTolerance: Double   = 45           // forgiving

    var body: some View {
        ZStack {
            // ── [4/5] CORK BOARD — warm tan cork fills the instrument circle,
            // tactile and natural. Deep purple stays outside the circle. ──
            CorkBoardView()
                .frame(width: 360, height: 360)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color(hex: "#7a5230").opacity(0.6), lineWidth: 3))
                .shadow(color: .black.opacity(0.35), radius: 10)

            // ── Where they are — the person-initial marker, bright to aim at ──
            DirectionIndicator(bearingDegrees: bearingDegrees,
                               personName: personName,
                               personEmoji: personEmoji,
                               ringRadius: 165,
                               showHint: false)

            // ── Flight trail — tiny paper flecks behind the scroll ──
            if flying {
                ForEach(0..<6, id: \.self) { i in
                    Circle()
                        .fill(Self.paper.opacity(0.5))
                        .frame(width: 4, height: 4)
                        .offset(scrollOffset(progressLag: CGFloat(i) * 0.08))
                        .opacity(1 - Double(flightProgress))
                }
            }

            // ── The demo finger — loops the flick motion, fades on first touch ──
            if loadedToken != nil && !interacted && !flying {
                fingerHint
            }

            // ── The paper scroll (or the unrolled reveal in flight) ──
            if loadedSymbol != nil {
                paperScroll
                    .offset(flying ? flightOffset
                                   : CGSize(width: restOffset.width + dragOffset.width,
                                            height: restOffset.height + dragOffset.height))
                    .rotationEffect(.degrees(missBounce ? -12 : 0))
                    .gesture(flying ? nil : flickGesture)
            }

            // [4/7] In-instrument instruction REMOVED — single instruction at
            // the bottom of the compass screen only (sendControl).
        }
        .frame(width: 370, height: 370)
        .animation(.easeOut(duration: 0.25), value: showMissHint)
        .animation(.spring(response: 0.3, dampingFraction: 0.4), value: missBounce)
        .onAppear {
            withAnimation(AnimationSystem.easeInOutSine(2.0).repeatForever(autoreverses: true)) {
                scrollPulse = true
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                fingerPhase = true
            }
        }
        .onChange(of: loadedToken) { _, _ in
            // Fresh thought → reset for a new flick
            flying = false; flightProgress = 0; unrolled = false
            interacted = false; dragOffset = .zero
        }
    }

    // ── The paper scroll ────────────────────────────────────────────────────

    /// [4/5] The paper note — a cream square with a folded corner and the
    /// emoji printed on its face, pinned to the cork with a little red pin.
    /// When flying, the pin is gone and the note tumbles flat.
    private var paperScroll: some View {
        ZStack {
            PaperNoteShape()
                // [3/5] Classic yellow post-it — material yellow, a touch
                // deeper toward the bottom.
                .fill(LinearGradient(colors: [Color(hex: "#FFEB3B"), Color(hex: "#FFD600")],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 52, height: 58)
                .overlay(
                    // Faint ruled lines, darker yellow — reads as a post-it
                    VStack(spacing: 9) {
                        ForEach(0..<3, id: \.self) { _ in
                            Capsule().fill(Color(hex: "#F0C800").opacity(0.55))
                                .frame(height: 1)
                        }
                    }
                    .padding(.horizontal, 9)
                    .padding(.top, 22)
                    .frame(width: 52, height: 58, alignment: .top)
                )
                .overlay(
                    // Folded corner at the top-right — darker yellow
                    PaperFoldShape()
                        .fill(Color(hex: "#F0C800"))
                        .frame(width: 52, height: 58)
                )
                .overlay {
                    if let loadedSymbol { loadedSymbol.scaleEffect(0.95) }
                }
                .shadow(color: .black.opacity(0.3), radius: dragging ? 8 : 4,
                        y: dragging ? 6 : 2)               // lifts off the board on drag
                .rotationEffect(.degrees(flying ? Double(flightProgress) * 200 : 0))
                .scaleEffect(flying ? 1.0 + flightProgress * 0.4
                                    : (dragging ? 1.04 : (scrollPulse ? 1.02 : 0.98)))

            // The red pin holding it to the board — pops out on flick
            if !flying {
                ZStack {
                    Circle().fill(Color.black.opacity(0.25)).frame(width: 12, height: 12).offset(y: 1)
                    Circle()
                        .fill(RadialGradient(colors: [Color(hex: "#FF5533"), Color(hex: "#CC2200")],
                                             center: UnitPoint(x: 0.35, y: 0.3),
                                             startRadius: 1, endRadius: 6))
                        .frame(width: 11, height: 11)
                }
                .offset(y: -26)
                .scaleEffect(dragging ? 0.9 : 1.0)
            }
        }
    }

    // ── The looping demo finger ─────────────────────────────────────────────

    private var fingerHint: some View {
        // Pulls back (down) then flicks forward (up) on a loop.
        Image(systemName: "hand.point.up.fill")
            .font(.system(size: 26))
            .foregroundColor(.white.opacity(0.85))
            .rotationEffect(.degrees(fingerPhase ? -8 : 14))
            .offset(x: restOffset.width + 18,
                    y: restOffset.height + (fingerPhase ? -16 : 18))
            .shadow(color: .black.opacity(0.4), radius: 4)
            .transition(.opacity)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var instructionLine: some View {
        if showMissHint {
            Text("flick toward \(personName)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Self.orange)
                .minimumScaleFactor(0.7).lineLimit(1)
                .shadow(color: .black.opacity(0.4), radius: 4)
        } else if loadedToken != nil && !flying {
            Text("flick toward \(personName)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.7).lineLimit(1)
                .shadow(color: Self.lavender.opacity(0.7), radius: 6)
        }
    }

    // ── Flight geometry ──────────────────────────────────────────────────────

    /// Where the scroll is during flight — from rest out past the rim along the
    /// flick direction, growing then receding.
    private var flightOffset: CGSize {
        let reach: CGFloat = 230 * flightProgress
        return CGSize(width: restOffset.width + CGFloat(sin(flightDir)) * reach,
                      height: restOffset.height - CGFloat(cos(flightDir)) * reach
                               - CGFloat(flightProgress) * 120)   // arcs upward
    }

    private func scrollOffset(progressLag: CGFloat) -> CGSize {
        let p = max(0, flightProgress - progressLag)
        let reach: CGFloat = 230 * p
        return CGSize(width: restOffset.width + CGFloat(sin(flightDir)) * reach,
                      height: restOffset.height - CGFloat(cos(flightDir)) * reach
                               - p * 120)
    }

    // ── The flick gesture ────────────────────────────────────────────────────

    private var flickGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                guard loadedToken != nil, !flying else { return }
                interacted = true
                dragging = true
                dragOffset = value.translation
            }
            .onEnded { value in
                dragging = false
                guard loadedToken != nil, !flying else { return }

                let v = value.velocity
                let speed = hypot(v.width, v.height)
                // Flick direction as a bearing (0 = up, clockwise).
                let flickDeg = atan2(Double(v.width), -Double(v.height)) * 180 / .pi
                let dirError = BearingCalculator.alignmentError(
                    relativeBearing: flickDeg - bearingDegrees)

                // Fast enough AND roughly toward them (forgiving 45°).
                if speed >= minFlickSpeed && dirError <= aimTolerance {
                    launch(perfect: dirError <= 15)
                } else {
                    miss()
                }
            }
    }

    private func launch(perfect: Bool) {
        // Fly toward the person (snaps onto their exact bearing for a clean arc).
        flightDir = rad
        withAnimation(.easeOut(duration: 0.18)) { dragOffset = .zero }
        flying = true
        HapticEngine.flickRelease()
        // Unroll + tumble mid-flight
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeOut(duration: 0.2)) { unrolled = true }
        }
        withAnimation(.easeIn(duration: 0.5)) { flightProgress = 1 }
        // Hand to the full-screen send
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onSend(perfect)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            flying = false; flightProgress = 0; unrolled = false
        }
    }

    private func miss() {
        HapticEngine.sendSoft()
        missBounce = true
        showMissHint = true
        withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { dragOffset = .zero }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { missBounce = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation { showMissHint = false }
        }
    }
}

// ════════════════════════════════════════════════════════════════════════
// MARK: - Paper scroll shape
// ════════════════════════════════════════════════════════════════════════

/// A little rolled scroll — a rounded tube, slightly fuller in the middle.
struct RolledScrollShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(roundedRect: rect, cornerRadius: rect.width * 0.32)
    }
}

// ════════════════════════════════════════════════════════════════════════
// MARK: - [4/5] Cork board + paper note
// ════════════════════════════════════════════════════════════════════════

/// A warm tan cork board — base fill with scattered darker ellipses for the
/// natural cork-grain texture, frozen at first appearance.
struct CorkBoardView: View {
    private static let tan  = Color(hex: "#C4956A")
    private static let dark = Color(hex: "#B8835A")

    private struct Grain: Identifiable {
        let id = UUID()
        let x: CGFloat; let y: CGFloat
        let w: CGFloat; let h: CGFloat
        let angle: Double; let opacity: Double
    }
    @State private var grains: [Grain] = CorkBoardView.makeGrains()

    private static func makeGrains() -> [Grain] {
        var result: [Grain] = []
        for i in 0..<60 {
            let x: CGFloat = CGFloat((i * 53) % 360) - 180
            let y: CGFloat = CGFloat((i * 97) % 360) - 180
            let w: CGFloat = CGFloat(4 + (i * 7) % 12)
            let h: CGFloat = CGFloat(3 + (i * 5) % 8)
            let angle = Double((i * 37) % 180)
            let opacity = 0.12 + Double((i * 13) % 10) / 60.0
            result.append(Grain(x: x, y: y, w: w, h: h, angle: angle, opacity: opacity))
        }
        return result
    }

    var body: some View {
        ZStack {
            Self.tan
            ForEach(grains) { g in
                Ellipse()
                    .fill(Self.dark.opacity(g.opacity))
                    .frame(width: g.w, height: g.h)
                    .rotationEffect(.degrees(g.angle))
                    .offset(x: g.x, y: g.y)
            }
            // A soft inner shadow at the rim
            Circle()
                .stroke(Color.black.opacity(0.18), lineWidth: 14)
                .blur(radius: 8)
                .frame(width: 372, height: 372)
        }
    }
}

/// A square paper note with a clipped (folded) top-right corner.
struct PaperNoteShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let fold = w * 0.26
        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: w - fold, y: 0))
        p.addLine(to: CGPoint(x: w, y: fold))
        p.addLine(to: CGPoint(x: w, y: h))
        p.addLine(to: CGPoint(x: 0, y: h))
        p.closeSubpath()
        return p
    }
}

/// The little folded-corner triangle at the note's top-right.
struct PaperFoldShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let fold = w * 0.26
        p.move(to: CGPoint(x: w - fold, y: 0))
        p.addLine(to: CGPoint(x: w, y: fold))
        p.addLine(to: CGPoint(x: w - fold, y: fold))
        p.closeSubpath()
        return p
    }
}

// MARK: - Naming alias (structural move — zero behavior change)
// The struct keeps its original name so all existing call sites compile
// unchanged; this alias gives the new per-instrument name used by the
// folder system and the animation state-machine work.
typealias FlickCompassFace = FlickInstrumentView
