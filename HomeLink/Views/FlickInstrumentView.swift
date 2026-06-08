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
    private let restOffset = CGSize(width: 0, height: 120)

    private let minFlickSpeed: CGFloat = 300          // points / second
    private let aimTolerance: Double   = 45           // forgiving

    var body: some View {
        ZStack {
            // ── The dark instrument circle ──
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                .frame(width: 360, height: 360)

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

            // ── Instructions ──
            VStack {
                Spacer()
                instructionLine
                    .padding(.bottom, 2)
            }
            .allowsHitTesting(false)
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

    private var paperScroll: some View {
        ZStack {
            if unrolled {
                // UNROLLED — a flat little sheet, emoji revealed, tumbling
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(colors: [Self.paper, Self.paperEdge],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 46, height: 56)
                    .overlay(
                        VStack(spacing: 5) {
                            ForEach(0..<4, id: \.self) { _ in
                                Capsule().fill(Self.paperLine.opacity(0.4))
                                    .frame(height: 1).padding(.horizontal, 8)
                            }
                        }
                    )
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                if let loadedSymbol {
                    loadedSymbol
                        .scaleEffect(1.2)
                        .rotationEffect(.degrees(Double(flightProgress) * 220))
                        .shadow(color: hue.opacity(0.6), radius: 10)
                }
            } else {
                // ROLLED — a little tube, emoji peeking from the top
                if let loadedSymbol {
                    loadedSymbol
                        .scaleEffect(0.62)
                        .offset(y: -20)
                        .shadow(color: hue.opacity(0.4), radius: 5)
                }
                RolledScrollShape()
                    .fill(LinearGradient(colors: [Self.paper, Self.paperEdge],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 34, height: 44)
                    .overlay(
                        // Roll lines + the dark opening at the top
                        VStack {
                            Ellipse().fill(Self.paperEdge)
                                .overlay(Ellipse().stroke(Self.paperLine.opacity(0.6), lineWidth: 1))
                                .frame(width: 30, height: 9)
                            Spacer()
                            Capsule().fill(Self.paperLine.opacity(0.5))
                                .frame(width: 30, height: 1.2)
                            Spacer()
                        }
                        .padding(.vertical, 3)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 5, y: 3)
                    .scaleEffect(dragging ? 1.05 : (scrollPulse ? 1.03 : 0.97))
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
