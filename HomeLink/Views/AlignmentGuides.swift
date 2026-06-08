// AlignmentGuides.swift
// Pointward › Views
//
// THE THREE ALIGNMENT LAYERS — users could not find the direction with a
// subtle arc alone. Now it's unmissable:
//
//   LAYER 1  plain-text instruction ("Mum is to your Southeast" →
//            "turn right to align" → "almost there ✦" → "locked ✦")
//   LAYER 2  ring scanner — 8 cardinal segments around the instrument,
//            the correct one brightening as you sweep toward it
//   LAYER 3  screen-edge glow on the side they're on — visible even
//            when sweeping fast
//
// Plus the 🎯 scope: a targeting reticle that locks on at 5° with haptics.

import SwiftUI
import Combine

// ════════════════════════════════════════════════════════════════════════
// MARK: - Alignment bands
// ════════════════════════════════════════════════════════════════════════

enum AlignmentBand {
    case scanning   // > 30°
    case near       // 15–30°
    case close      // 5–15°
    case locked     // < 5°

    static func from(error: Double) -> AlignmentBand {
        switch error {
        case ..<5:  return .locked
        case ..<15: return .close
        case ..<30: return .near
        default:    return .scanning
        }
    }
}

enum AlignmentText {

    static let cardinals = ["North", "Northeast", "East", "Southeast",
                            "South", "Southwest", "West", "Northwest"]

    static func cardinal(forAbsolute bearing: Double) -> String {
        let index = Int(((bearing + 22.5).truncatingRemainder(dividingBy: 360)) / 45) % 8
        return cardinals[index]
    }

    /// Layer 1 — the always-readable instruction.
    /// `relative` = bearing on screen (0 = aligned); `absolute` = true bearing.
    static func guidance(relative: Double, absolute: Double?,
                         personName: String, lockedAction: String) -> String {
        let error = min(relative, 360 - relative)
        switch AlignmentBand.from(error: error) {
        case .locked:
            return "locked ✦ · \(lockedAction)"
        case .close:
            return "almost there ✦"
        case .near:
            return relative < 180 ? "turn right to align" : "turn left to align"
        case .scanning:
            if (150...210).contains(relative) {
                return "\(personName) is behind you — turn around"
            }
            if let absolute {
                return "\(personName) is to your \(cardinal(forAbsolute: absolute))"
            }
            return "finding \(personName)…"
        }
    }
}

// ════════════════════════════════════════════════════════════════════════
// MARK: - Layer 2 · Ring scanner
// ════════════════════════════════════════════════════════════════════════

/// Eight 45° segments around the instrument. The segment containing the
/// person's on-screen direction brightens through the bands; its neighbors
/// glow faintly; the rest rest at 5 %.
struct RingScannerView: View {

    let relativeBearing: Double

    @State private var pulse = false
    @State private var scanPulse = false

    private static let lavender = Color(hex: "#c4a8d4")

    private var error: Double { min(relativeBearing, 360 - relativeBearing) }
    private var band: AlignmentBand { .from(error: error) }

    /// Which of the 8 segments holds the person's screen direction.
    private var hotSegment: Int {
        Int(((relativeBearing + 22.5).truncatingRemainder(dividingBy: 360)) / 45) % 8
    }

    private func opacity(for segment: Int) -> Double {
        let distance = min(abs(segment - hotSegment), 8 - abs(segment - hotSegment))
        switch band {
        case .scanning:
            // Gentle pulse around the whole ring while searching
            return distance == 0 ? 0.3 : (scanPulse ? 0.10 : 0.05)
        case .near:
            return distance == 0 ? 0.6 : (distance == 1 ? 0.2 : 0.05)
        case .close:
            return distance == 0 ? (pulse ? 0.9 : 0.7) : (distance == 1 ? 0.4 : 0.05)
        case .locked:
            return distance == 0 ? (pulse ? 1.0 : 0.85) : (distance == 1 ? 0.4 : 0.05)
        }
    }

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { segment in
                RingSegmentShape(segment: segment)
                    .stroke(Self.lavender.opacity(opacity(for: segment)),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round))
            }
            // The lock burst — full lavender glow at < 5°
            if band == .locked {
                Circle()
                    .stroke(Self.lavender.opacity(pulse ? 0.45 : 0.2), lineWidth: 14)
                    .blur(radius: 12)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: hotSegment)
        .animation(.easeInOut(duration: 0.25), value: error < 30)
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                pulse = true
            }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                scanPulse = true
            }
        }
    }
}

/// One of eight 45° ring segments (6° gaps), screen-space compass positions.
struct RingSegmentShape: Shape {
    let segment: Int

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = Angle(degrees: Double(segment) * 45 - 90)   // N = up
        p.addArc(center: CGPoint(x: rect.midX, y: rect.midY),
                 radius: rect.width / 2 - 4,
                 startAngle: center - .degrees(19.5),
                 endAngle: center + .degrees(19.5),
                 clockwise: false)
        return p
    }
}

// ════════════════════════════════════════════════════════════════════════
// MARK: - Layer 3 · Screen edge glow
// ════════════════════════════════════════════════════════════════════════

/// The screen edge on the person's side glows — top for ahead, right for
/// rightward, corners for diagonals. Impossible to miss when sweeping.
struct AlignmentEdgeGlowView: View {

    let relativeBearing: Double

    private static let lavender = Color(hex: "#c4a8d4")

    private var error: Double { min(relativeBearing, 360 - relativeBearing) }

    private var intensity: Double {
        switch AlignmentBand.from(error: error) {
        case .locked:   return 0.75
        case .close:    return 0.5
        case .near:     return 0.38
        case .scanning: return 0.30
        }
    }

    var body: some View {
        let rad = relativeBearing * .pi / 180
        RadialGradient(
            colors: [Self.lavender.opacity(intensity), .clear],
            center: UnitPoint(x: 0.5 + 0.58 * sin(rad),
                              y: 0.5 - 0.58 * cos(rad)),
            startRadius: 6,
            endRadius: 360
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.3), value: intensity)
    }
}

// ════════════════════════════════════════════════════════════════════════
// MARK: - 🎯 Scope
// ════════════════════════════════════════════════════════════════════════

/// The small always-visible reticle button, bottom right of the instrument.
struct ScopeButton: View {

    let active: Bool
    let onTap: () -> Void

    private static let lavender = Color(hex: "#c4a8d4")

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .stroke(Self.lavender.opacity(active ? 0.9 : 0.55), lineWidth: 1.3)
                    .frame(width: 26, height: 26)
                Circle()
                    .stroke(Self.lavender.opacity(active ? 0.9 : 0.55), lineWidth: 1.3)
                    .frame(width: 15, height: 15)
                Circle()
                    .fill(Self.lavender.opacity(active ? 1.0 : 0.7))
                    .frame(width: 3, height: 3)
                // Four cardinal ticks
                ForEach(0..<4, id: \.self) { i in
                    Rectangle()
                        .fill(Self.lavender.opacity(active ? 0.9 : 0.55))
                        .frame(width: 1.3, height: 5)
                        .offset(y: -16)
                        .rotationEffect(.degrees(Double(i) * 90))
                }
            }
            .frame(width: 44, height: 44)   // full tap target
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Tap the scope → a targeting reticle over the instrument: rotating scan,
/// an arrow growing toward the person, banded haptic pulses, and a green
/// snap when locked at 5°.
struct ScopeReticleOverlay: View {

    let relativeBearing: Double
    let personName: String
    let onDismiss: () -> Void

    @State private var appeared = false
    @State private var scanAngle: Double = 0
    @State private var lockedSnap = false
    @State private var lastHaptic = Date.distantPast

    private let hapticTick = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    private static let lavender = Color(hex: "#c4a8d4")
    private static let green    = Color(hex: "#5dcaa5")

    private var error: Double { min(relativeBearing, 360 - relativeBearing) }
    private var band: AlignmentBand { .from(error: error) }
    private var locked: Bool { band == .locked }
    private var rad: Double { relativeBearing * .pi / 180 }

    var body: some View {
        ZStack {
            // Tap anywhere outside dismisses
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            ZStack {
                // The two concentric circles, animating in
                Circle()
                    .stroke(ringColor.opacity(0.7), lineWidth: 1.5)
                    .frame(width: appeared ? 220 : 120, height: appeared ? 220 : 120)
                Circle()
                    .stroke(ringColor.opacity(0.55), lineWidth: 1.5)
                    .frame(width: appeared ? 120 : 60, height: appeared ? 120 : 60)

                // The scanning sweep — stops dead on lock
                if !locked {
                    Rectangle()
                        .fill(LinearGradient(colors: [Self.lavender.opacity(0.6), .clear],
                                             startPoint: .bottom, endPoint: .top))
                        .frame(width: 1.5, height: 108)
                        .offset(y: -54)
                        .rotationEffect(.degrees(scanAngle))
                }

                // The arrow — grows toward the correct direction
                Triangle()
                    .fill(locked ? Self.green : Self.lavender)
                    .frame(width: 10, height: 24)
                    .scaleEffect(locked ? 1.4 : (band == .close ? 1.2 : 1.0))
                    .offset(y: -86)
                    .rotationEffect(.radians(rad))
                    .shadow(color: (locked ? Self.green : Self.lavender).opacity(0.8),
                            radius: locked ? 12 : 6)
                    .animation(.easeOut(duration: 0.2), value: relativeBearing)

                // Lock confirmation
                if locked {
                    Circle()
                        .stroke(Self.green.opacity(lockedSnap ? 0 : 0.6), lineWidth: 2)
                        .frame(width: 240, height: 240)
                        .scaleEffect(lockedSnap ? 1.25 : 0.9)
                    Text("locked ✦")
                        .font(.system(size: 15, design: .serif).italic())
                        .foregroundColor(Self.green)
                        .shadow(color: Self.green.opacity(0.7), radius: 8)
                        .offset(y: 138)
                        .transition(.opacity)
                }
            }
            .scaleEffect(appeared ? 1 : 0.7)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { appeared = true }
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                scanAngle = 360
            }
        }
        .onChange(of: locked) { _, isLocked in
            if isLocked {
                HapticEngine.lockOn()   // strong satisfying snap
                withAnimation(.easeOut(duration: 0.6)) { lockedSnap = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { lockedSnap = false }
            }
        }
        // Banded haptic pulses while hunting
        .onReceive(hapticTick) { _ in
            guard !locked else { return }
            let interval: TimeInterval
            switch band {
            case .scanning: interval = 2.0
            case .near:     interval = 1.5
            case .close:    interval = 1.0
            case .locked:   return
            }
            if Date.now.timeIntervalSince(lastHaptic) >= interval {
                lastHaptic = .now
                HapticEngine.sendSoft()
            }
        }
    }

    private var ringColor: Color { locked ? Self.green : Self.lavender }
}
