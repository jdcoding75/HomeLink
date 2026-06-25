// ArrivalSequenceView.swift
// Pointward › Views
//
// [arrival-parity stage1] The reusable arrival sequence: envelope → transit →
// receipt → reveal, from a neutral `Arrival`. NO fetch / landing / compose-back /
// opened-flip POLICY — that stays with each caller (PATH-2 = IncomingMessageView,
// which builds the Arrival + does the policy in onOpened/onFinished). PATH-1 / replay
// route into this in Stages 2-3. Transit renders via the Stage-0 AnimationDispatch
// (the single dispatch source of truth). EnvelopeGlyph + the envelope beat + the
// per-instrument transit were RELOCATED here verbatim from IncomingMessageView
// (resolvedName → arrival?.senderName).

import SwiftUI

/// Neutral input to the arrival sequence — everything envelope→transit→receipt→reveal
/// needs, with NO fetch / landing / opened-flip policy. PATH-2 builds it from a fetched
/// Message; PATH-1 / replay (Stages 2-3) build it from a ReceivedPing they already hold.
struct Arrival {
    /// Receipt + transit input. `fromName` is the resolved sender name (drives the
    /// envelope "from", the "Message from" overlay, and the receipt caption). For PATH-2
    /// this is `receivedPing(from:)` (remoteID nil — "a message is NOT a ping").
    let ping: PingManager.ReceivedPing
    /// Transit exit bearing (PATH-2: `compass.rawBearingToTarget ?? 120` at build time).
    let senderBearing: Double

    var style: SenderStyle { SenderStyle.from(ping.senderStyle) }
    var emoji: String      { ping.emoji }
    var message: String?   { ping.message }
    var senderName: String { ping.fromName }
}

struct ArrivalSequenceView: View {

    /// nil while the caller is still resolving the arrival (PATH-2 fetch in flight) →
    /// the envelope keeps breathing; once non-nil AND the beat floor has elapsed, it
    /// advances to the transit. (PATH-1/replay pass it non-nil from the start.)
    let arrival: Arrival?
    /// Minimum on-screen time for the envelope beat. PATH-2 passes 0 (its `begin()`
    /// already gates the 1.6s beat before it sets `arrival`); PATH-1/replay pass 1.6.
    var beatFloor: Double = 1.6
    /// [arrival-parity stage1] The sender name shown ON the envelope, available BEFORE
    /// `arrival` resolves — so the "from [name]" fade-in lands mid-beat exactly as today
    /// (PATH-2 feeds its existing mid-fetch `resolvedName` here). Envelope shows
    /// `earlyName ?? arrival?.senderName`. PATH-1/replay can leave it nil.
    var earlyName: String? = nil
    /// The receipt reached its natural reveal (caller flips `opened`). == ReceiptView.onRevealed.
    var onOpened: () -> Void = {}
    /// The whole sequence finished (caller does landing/dismiss). == ReceiptView.onFinished.
    var onFinished: () -> Void = {}

    private enum Phase { case incoming, sending, receipt }
    @State private var phase: Phase = .incoming
    @State private var pulse = false
    @State private var beatElapsed = false

    private static let lavender = Color(hex: "#c4a8d4")

    var body: some View {
        ZStack {
            DesignTokens.Color.background.ignoresSafeArea()

            switch phase {
            case .incoming:
                incomingBeat   // breathes until (arrival != nil && beatElapsed)
            case .sending:
                if let arrival {
                    sendStage(for: arrival)
                        .transition(.opacity)
                }
            case .receipt:
                if let arrival {
                    ReceiptView(
                        ping:  arrival.ping,
                        style: arrival.style,
                        onRevealed: { onOpened() },
                        onFinished: { onFinished() }
                    )
                    .transition(.opacity)
                    // [copy-declutter] CUT redundant middle name-show — envelope "from {name}"
                    // (incomingBeat) + reveal "from {name} ✦" remain; ReceiptView render untouched.
                    /*
                    // [build10 fixbatch 2a] "Message from [Name]" — relocated verbatim.
                    .overlay(alignment: .top) {
                        Text("Message from \(arrival.senderName)")
                            .font(.system(size: 13, design: .serif).italic())
                            .foregroundColor(DesignTokens.Color.textMuted)
                            .padding(.top, 16)
                            .allowsHitTesting(false)
                    }
                    */
                }
            }
        }
        .onAppear {
            Task {
                try? await Task.sleep(for: .seconds(beatFloor))
                await MainActor.run { beatElapsed = true; advanceIfReady() }
            }
        }
        .onChange(of: arrivalIsReady) { _, _ in advanceIfReady() }
    }

    private var arrivalIsReady: Bool { arrival != nil }

    /// The name on the envelope — `earlyName` (mid-beat) first, then the resolved arrival.
    private var envelopeName: String? { earlyName ?? arrival?.senderName }

    /// Advance envelope → transit when BOTH the beat floor elapsed AND the arrival
    /// resolved — reproducing PATH-2's `max(beatDuration, fetch)` exactly.
    private func advanceIfReady() {
        guard phase == .incoming, beatElapsed, arrival != nil else { return }
        withAnimation(.easeInOut(duration: 0.4)) { phase = .sending }
    }

    // MARK: - The incoming beat (envelope, before it opens) — relocated verbatim
    //         from IncomingMessageView.incomingBeat (resolvedName → arrival?.senderName)

    private var incomingBeat: some View {
        ZStack {
            RadialGradient(colors: [Self.lavender.opacity(0.18), .clear],
                           center: .center, startRadius: 10, endRadius: 260)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                EnvelopeGlyph(glow: pulse)
                    .frame(width: 132, height: 96)
                    .scaleEffect(pulse ? 1.05 : 0.97)
                    .shadow(color: Self.lavender.opacity(pulse ? 0.5 : 0.2), radius: 18)

                Text("a thought is arriving ✦")
                    .font(.system(size: 18, design: .serif).italic())
                    .foregroundColor(DesignTokens.Color.textPrimary)
                    .opacity(0.9)

                // [envelope-name] The arrival's natural "who's this from" surface. Fades
                // in mid-beat via `earlyName` (PATH-2's mid-fetch resolvedName), falling
                // back to arrival?.senderName once resolved. Same precedence as the receipt
                // caption. Reserve the line's height so nothing jumps.
                Text(envelopeName.map { "from \($0)" } ?? " ")
                    .font(.system(size: 14, design: .serif).italic())
                    .foregroundColor(Self.lavender)
                    .opacity(envelopeName == nil ? 0 : 0.85)
            }
            .animation(.easeIn(duration: 0.5), value: envelopeName != nil)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    // MARK: - [a2-send-on-receive] The SEND (transit) stage — re-pointed to the
    //         Stage-0 AnimationDispatch (was IncomingMessageView.sendStage's if/else).
    //         Played AS-IS (same direction); on completion advances to .receipt.

    @ViewBuilder
    private func sendStage(for a: Arrival) -> some View {
        let advance = { withAnimation(.easeInOut(duration: 0.4)) { phase = .receipt } }
        switch AnimationDispatch.sendAnimationKind(for: a.style, emoji: a.emoji) {
        case .firework:
            FireworkSendAnimation(emoji: a.emoji, onComplete: advance)
        case .birthday:
            BirthdayCakeSendAnimationV2(emoji: a.emoji, onComplete: advance)
        case .wand:
            WandSendAnimation(transition: sendTransition(.wand, a.emoji, a.senderBearing, a.message),
                              personName: a.senderName, onComplete: advance)
        case .bowArrow:
            BowSendAnimationV2(transition: sendTransition(.bow, a.emoji, a.senderBearing, a.message),
                               personName: a.senderName, onComplete: advance)
        case .plane:
            PlaneSendAnimation(transition: sendTransition(.plane, a.emoji, a.senderBearing, a.message),
                               personName: a.senderName, onComplete: advance)
        case .fingerFlick:
            FlickSendAnimationV2(transition: sendTransition(.flick, a.emoji, a.senderBearing, a.message),
                                 personName: a.senderName, onComplete: advance)
        case .shared:
            // glow / shootingStar / firefly(wind) / rocket — the shared dispatcher.
            SenderAnimationView(style: a.style, emoji: a.emoji, bearingDegrees: a.senderBearing,
                                symbol: Text(a.emoji).font(.system(size: 45))) { advance() }
        }
    }

    /// Builds the InstrumentTransition the dedicated sends need (exitPoint .zero,
    /// exitBearing = the sender's bearing; tagline nil on receive). Relocated verbatim.
    private func sendTransition(_ instrument: Instrument, _ emoji: String,
                                _ bearing: Double, _ message: String?) -> InstrumentTransition {
        InstrumentTransition(exitBearing: bearing, exitPoint: .zero, instrument: instrument,
                             emoji: emoji, message: message, tagline: nil)
    }
}

// MARK: - Envelope glyph (sealed — the "before it opens" anticipation) — relocated
//         verbatim from IncomingMessageView.

private struct EnvelopeGlyph: View {
    var glow: Bool

    private static let paper   = Color(hex: "#2a2336")
    private static let paperHi = Color(hex: "#3a3048")
    private static let edge    = Color(hex: "#c4a8d4")
    private static let seal    = Color(hex: "#f0d060")

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                // Body
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: [Self.paperHi, Self.paper],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(Self.edge.opacity(0.55), lineWidth: 1.5))
                // The closed flap (a downward "V")
                Path { p in
                    p.move(to: CGPoint(x: 0, y: 0))
                    p.addLine(to: CGPoint(x: w / 2, y: h * 0.52))
                    p.addLine(to: CGPoint(x: w, y: 0))
                }
                .stroke(Self.edge.opacity(0.7), lineWidth: 1.5)
                // Wax seal where the flap meets — pulses softly.
                Circle()
                    .fill(RadialGradient(colors: [Self.seal, Self.seal.opacity(0.5)],
                                         center: .center, startRadius: 1, endRadius: 9))
                    .frame(width: 16, height: 16)
                    .position(x: w / 2, y: h * 0.52)
                    .shadow(color: Self.seal.opacity(glow ? 0.8 : 0.3), radius: glow ? 8 : 3)
            }
        }
        .allowsHitTesting(false)
    }
}
