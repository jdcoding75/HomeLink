// FlickInstrumentView.swift
// Pointward › Views
//
// INSTRUMENT 4 — FLICK (Pro). Clean minimal circle: a launch pocket at the
// bottom, a glowing bearing arc up top. Load a thought into the pocket,
// drag it back like a rubber band, and flick. Within 15° it streaks away;
// within 5° it's "✦ perfect". Off-target it bounces home comically.

import SwiftUI

struct FlickInstrumentView: View {

    let loadedToken: String?
    let loadedSymbol: AnyView?
    let bearingDegrees: Double
    let personName: String
    var personEmoji: String = "💜"
    /// perfect = released within 5°.
    let onSend: (_ perfect: Bool) -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var dragging = false
    @State private var missWobble = false
    @State private var showMissHint = false
    @State private var showPerfect = false
    @State private var nearHapticFired = false
    @State private var perfectHapticFired = false

    private static let lavender = Color(hex: "#c4a8d4")
    private static let orange   = Color(hex: "#e08a3c")

    private var rad: Double { bearingDegrees * .pi / 180 }
    private var alignDiff: Double { BearingCalculator.alignmentError(relativeBearing: bearingDegrees) }
    private var aligned: Bool { BearingCalculator.isSendAligned(bearingDegrees) }
    private var perfect: Bool { BearingCalculator.isLockAligned(bearingDegrees) }

    /// The pocket sits at the bottom of the circle.
    private let pocketOffset = CGSize(width: 0, height: 130)

    var body: some View {
        ZStack {
            // ── The clean circle ──
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                .frame(width: 360, height: 360)

            // ── Where they are — shared marker · arc · hint ──
            // (previous bespoke arc + north icon superseded:)
            // BearingArcShape(rad: rad)
            //     .stroke(Self.lavender.opacity(aligned ? 0.85 : 0.4),
            //             style: StrokeStyle(lineWidth: 3, lineCap: .round))
            //     .frame(width: 330, height: 330)
            //     .shadow(color: Self.lavender.opacity(aligned ? 0.5 : 0), radius: 8)
            // Image(systemName: "location.north.fill")
            //     .font(.system(size: 11))
            //     .foregroundColor(Self.lavender.opacity(0.8))
            //     .offset(x: CGFloat(sin(rad)) * 150, y: -CGFloat(cos(rad)) * 150)
            //     .rotationEffect(.radians(rad), anchor: .center)
            DirectionIndicator(bearingDegrees: bearingDegrees,
                               personName: personName,
                               personEmoji: personEmoji,
                               ringRadius: 165,
                               showHint: loadedToken == nil)   // own hints while loaded

            // ── The launch pocket — a soft recessed cup ──
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.5)
                    .stroke(Self.lavender.opacity(0.5), lineWidth: 2)
                    .frame(width: 80, height: 80)
                Circle()
                    .trim(from: 0, to: 0.5)
                    .fill(Color.black.opacity(0.25))
                    .frame(width: 80, height: 80)
            }
            .offset(pocketOffset)

            // ── Trajectory while dragging ──
            if dragging, dragDistance > 12 {
                TrajectoryArcShape(rad: rad)
                    .stroke(aligned ? Self.lavender.opacity(0.7)
                                    : Self.orange.opacity(0.7),
                            style: StrokeStyle(lineWidth: 2, dash: [4, 7]))
                    .frame(width: 333, height: 333)
                    .allowsHitTesting(false)
            }

            // ── The loaded thought — in the pocket, rubber-banded ──
            if let loadedSymbol {
                loadedSymbol
                    .shadow(color: Self.lavender.opacity(dragging ? 0.8 : 0.5),
                            radius: dragging ? 12 : 8)
                    .offset(CGSize(width: pocketOffset.width + rubberBanded.width,
                                   height: pocketOffset.height + rubberBanded.height))
                    .rotationEffect(.degrees(missWobble ? 9 : 0))
                    .animation(missWobble
                               ? .spring(response: 0.16, dampingFraction: 0.2)
                               : .easeOut(duration: 0.2),
                               value: missWobble)
                    .gesture(flickGesture)
            }

            // ── "✦ perfect" flash ──
            if showPerfect {
                Text("✦ perfect")
                    .font(.system(size: 15, design: .serif).italic())
                    .foregroundColor(Color(hex: "#FFD700"))
                    .shadow(color: Color(hex: "#FFD700").opacity(0.7), radius: 8)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
            }

            // ── Instructions ──
            VStack {
                Spacer()
                if showMissHint {
                    Text("aim toward \(personName)")
                        .font(.system(size: 12, design: .serif).italic())
                        .foregroundColor(Self.orange)
                } else if loadedToken != nil && !dragging {
                    Text("flick toward \(personName)")
                        .font(.system(size: 12, design: .serif).italic())
                        .foregroundColor(Self.lavender.opacity(0.85))
                }
            }
            .padding(.bottom, 2)
            .allowsHitTesting(false)
        }
        .frame(width: 370, height: 370)
        .animation(.easeOut(duration: 0.25), value: showMissHint)
        .animation(.easeOut(duration: 0.3), value: showPerfect)
    }

    private var dragDistance: CGFloat {
        sqrt(dragOffset.width * dragOffset.width + dragOffset.height * dragOffset.height)
    }

    /// Rubber band: resistance grows with distance, hard max at 80 px.
    private var rubberBanded: CGSize {
        let distance = dragDistance
        guard distance > 0 else { return .zero }
        let banded = 80 * (1 - exp(-distance / 80))
        let scale = banded / distance
        return CGSize(width: dragOffset.width * scale,
                      height: dragOffset.height * scale)
    }

    private var flickGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard loadedToken != nil else { return }
                dragging = true
                dragOffset = value.translation
                // Alignment haptics while aiming
                if aligned && !nearHapticFired {
                    nearHapticFired = true
                    HapticEngine.sendSoft()
                }
                if perfect && !perfectHapticFired {
                    perfectHapticFired = true
                    HapticEngine.send()
                }
                if !aligned { nearHapticFired = false; perfectHapticFired = false }
            }
            .onEnded { _ in
                dragging = false
                let distance = dragDistance
                dragOffset = .zero
                nearHapticFired = false
                perfectHapticFired = false
                guard loadedToken != nil, distance > 28 else { return }

                if aligned {
                    if perfect {
                        // PERFECT AIM — extra burst, extra haptic, the flash
                        HapticEngine.lockOn()
                        withAnimation { showPerfect = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            withAnimation { showPerfect = false }
                        }
                    }
                    onSend(perfect)
                } else {
                    // MISS — comic bounce home
                    HapticEngine.sendSoft()
                    missWobble = true
                    showMissHint = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                        missWobble = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                        withAnimation { showMissHint = false }
                    }
                }
            }
    }
}

/// A short glowing arc centered on the person's bearing at the rim.
struct BearingArcShape: Shape {
    let rad: Double

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let bearingAngle = Angle(radians: rad - .pi / 2)   // shape space: 0 = +x
        p.addArc(center: CGPoint(x: rect.midX, y: rect.midY),
                 radius: rect.width / 2,
                 startAngle: bearingAngle - .degrees(16),
                 endAngle: bearingAngle + .degrees(16),
                 clockwise: false)
        return p
    }
}
