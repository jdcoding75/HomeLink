// IncomingMessageView.swift
// Pointward › Views
//
// Phase 2 Build 4a — opens a tapped pointward.app/m/<id> link.
//
// Flow (happy path only — the short-code fallback is Build 4b):
//   1. A short, designed "incoming…" beat — a sealed envelope, the
//      anticipation moment BEFORE it opens (~1.6s, fetch runs concurrently).
//   2. get_message(p_id) RPC → Message. Empty/expired → a gentle empty state.
//   3. The NORMAL ReceiptView runs for the message's emoji + instrument — we
//      SEQUENCE before it; we do NOT modify any receipt/instrument animation.
//   4. `opened` flips ONLY at the receipt's natural completion (ReceiptView's
//      onRevealed — the reveal moment). Interruption before that (dismiss /
//      background) never flips → the message stays recoverable and replays.
//
// Build 5 (DONE): a VALID fetched message silently auto-creates/updates the
// sender as a contact, keyed on Message.senderID — see `people.upsertContact`
// in begin(). No prompt (silent, per TRUTH product principle #6).

import SwiftUI

/// The opened-flip gate. Flips ONCE, and ONLY when the receipt reaches its
/// natural completion — never on interruption. Extracted from the view so the
/// rule is unit-testable (see MessageLinkRouteTests).
struct OpenedFlipGate {
    private(set) var didFlip = false

    /// Call at the receipt's COMPLETION signal (onRevealed). Returns true iff
    /// THIS call should perform the write — the first completion only (idempotent).
    mutating func completionReached() -> Bool {
        guard !didFlip else { return false }
        didFlip = true
        return true
    }
}

struct IncomingMessageView: View {

    let messageID: UUID
    /// Dismiss the whole cover (clears the RootView request).
    var onFinished: () -> Void = {}

    // ReceiptView needs these; inherited from RootView's environment.
    @EnvironmentObject var compass: CompassManager
    @EnvironmentObject var pings:   PingManager
    // [phase2 build5] Auto-create the sender as a contact on a valid message.
    @EnvironmentObject var people:  PeopleManager

    private enum Phase { case incoming, receipt, notFound }
    @State private var phase: Phase = .incoming
    @State private var message: Message? = nil
    @State private var flipGate = OpenedFlipGate()
    @State private var started = false
    @State private var pulse = false

    /// Minimum on-screen time for the incoming beat (the fetch may finish sooner;
    /// if it takes LONGER, the beat keeps breathing until it resolves).
    private static let beatDuration: Double = 1.6

    private static let lavender = Color(hex: "#c4a8d4")
    private static let gold     = Color(hex: "#f0d060")

    var body: some View {
        ZStack {
            DesignTokens.Color.background.ignoresSafeArea()

            switch phase {
            case .incoming:  incomingBeat
            case .notFound:  notFoundState
            case .receipt:
                if let message {
                    ReceiptView(
                        ping:  receivedPing(from: message),
                        style: instrumentStyle(from: message),
                        onRevealed: { flipOpened() },          // ← completion signal
                        onFinished: { onFinished() }           // ← dismiss (no flip)
                    )
                    // [build5-done] Contact auto-create for this sender already
                    // fired at FETCH (see begin() → people.upsertContact). It is
                    // silent by design — no prompt hangs here (TRUTH principle #6).
                    .transition(.opacity)
                }
            }
        }
        .onAppear { begin() }
    }

    // MARK: - The incoming beat (envelope, before it opens)

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
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    // MARK: - Gentle empty state (bad / expired id)

    private var notFoundState: some View {
        VStack(spacing: 14) {
            Spacer()
            Text("✦")
                .font(.system(size: 34))
                .foregroundColor(Self.lavender.opacity(0.7))
            Text("this thought couldn't be found ✦")
                .font(.system(size: 19, design: .serif).italic())
                .foregroundColor(DesignTokens.Color.textPrimary)
                .multilineTextAlignment(.center)
            Text("it may have expired, or the link was mistyped")
                .font(.system(size: 13, design: .serif).italic())
                .foregroundColor(DesignTokens.Color.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button { onFinished() } label: {
                Text("close")
                    .font(DesignTokens.Font.label)
                    .foregroundColor(DesignTokens.Color.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(DesignTokens.Spacing.md)
                    .background(DesignTokens.Color.accentStrong)
                    .cornerRadius(DesignTokens.Radius.button)
            }
            .padding(.horizontal, 40)
            .padding(.top, 12)
            Spacer()
        }
        .transition(.opacity)
    }

    // MARK: - Sequencing

    private func begin() {
        guard !started else { return }   // onAppear can fire more than once
        started = true
        Task {
            // Fetch + beat run concurrently; we advance on whichever is LONGER,
            // so the beat is never cut short and a slow fetch is covered.
            async let fetched = fetch()
            try? await Task.sleep(for: .seconds(Self.beatDuration))
            let result = await fetched
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.4)) {
                    if let result {
                        message = result
                        phase = .receipt
                        // [phase2 build5] A VALID message means a real sender —
                        // silently create-or-update them as a contact, keyed on
                        // the immutable senderID. Fires at FETCH (not at the
                        // opened-flip), so the contact exists even if the receipt
                        // is interrupted before completion.
                        people.upsertContact(senderID: result.senderID.uuidString,
                                             displayName: result.senderDisplayName)
                        // [build9] Record the opened message into the unified
                        // (sender-agnostic) bucket. Previously /m/ opens were NEVER
                        // recorded — only short-code "rest" were — so opened link
                        // messages were missing from history. remoteID = message.id
                        // dedups against a later short-code claim of the same message.
                        pings.recordCaught(historyPing(from: result))
                        // [phase2 stage B] (S2 + connection signal) record that I
                        // connected to this sender — at FETCH, regardless of auth.
                        // Queue locally (drained post-sign-in if signed out), AND
                        // fire the RPC now (no-ops server-side when unauthenticated).
                        PendingConnections.append(result.id)
                        Task { await SupabaseService.shared.recordConnection(messageID: result.id) }
                    } else {
                        phase = .notFound
                    }
                }
            }
        }
    }

    private func fetch() async -> Message? {
        do { return try await SupabaseService.shared.getMessage(id: messageID) }
        catch { return nil }
    }

    /// Wired to ReceiptView's onRevealed — the receipt's natural end. The gate
    /// guarantees the write fires at most once, and ONLY on a real completion
    /// (interruption never reaches here).
    private func flipOpened() {
        guard flipGate.completionReached() else { return }
        let id = messageID
        Task { await SupabaseService.shared.markMessageOpened(id: id) }
    }

    // MARK: - Message → receipt inputs

    private func receivedPing(from m: Message) -> PingManager.ReceivedPing {
        let name = (m.senderDisplayName?.trimmingCharacters(in: .whitespaces)).flatMap {
            $0.isEmpty ? nil : $0
        } ?? "someone"
        let emoji = (m.emoji?.isEmpty == false ? m.emoji! : CuratedEmoji.defaultEmoji)
        return PingManager.ReceivedPing(
            fromName:    name,
            emoji:       emoji,
            timestamp:   .now,
            remoteID:    nil,                                  // a message is NOT a ping
            senderStyle: instrumentStyle(from: m).rawValue,
            message:     m.content,                            // nil/empty reads fine
            tagline:     nil,
            isTest:      false)
    }

    /// [build9] The opened message as a unified-bucket history entry. remoteID =
    /// message.id so a later short-code claim of the SAME message dedups (no
    /// duplicate). Distinct from `receivedPing` (which feeds the receipt with
    /// remoteID nil — "a message is NOT a ping").
    private func historyPing(from m: Message) -> PingManager.ReceivedPing {
        let name = (m.senderDisplayName?.trimmingCharacters(in: .whitespaces)).flatMap {
            $0.isEmpty ? nil : $0
        } ?? "someone"
        let emoji = (m.emoji?.isEmpty == false ? m.emoji! : CuratedEmoji.defaultEmoji)
        return PingManager.ReceivedPing(
            fromName:    name,
            emoji:       emoji,
            timestamp:   .now,
            remoteID:    m.id,
            senderStyle: instrumentStyle(from: m).rawValue,
            message:     m.content,
            tagline:     nil,
            isTest:      false)
    }

    private func instrumentStyle(from m: Message) -> SenderStyle {
        if let raw = m.instrument, let known = Instrument(rawValue: raw) {
            return known.senderStyle
        }
        // Registry-driven fallback: the manifest's first (default) live instrument
        // — .compass, whose style is .glow. Never a hardcoded style.
        return (AnimationManifest.liveInstruments.first?.instrument ?? .compass).senderStyle
    }
}

// MARK: - Envelope glyph (sealed — the "before it opens" anticipation)

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
