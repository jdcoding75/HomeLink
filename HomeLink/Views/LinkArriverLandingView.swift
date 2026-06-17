// LinkArriverLandingView.swift
// Pointward › Views
//
// BUILD 10 — LINK-ARRIVER LANDING (PLACEHOLDER, first representation).
//
// After a link-arriver's message finishes playing (the ReceiptView completes
// inside IncomingMessageView), instead of the cover just dismissing into the
// app, we present this LANDING — the "what next" moment with three doors:
//
//   1. "Send one back to [Name]" — the primary path (the reciprocity loop).
//   2. "See what Pointward is"   — the showcase (InstrumentPreview).
//   3. "I'm good for now"        — quiet exit into the app.
//
// ⚠️ PLACEHOLDER — functional, minimally styled. Joshua walks it on-device and
// refines copy/look/feel in situ. The DESIGN (3 doors + each door's destination)
// is locked in POINTWARD_TRUTH.md (the link-arriver path). This view is additive:
// it does NOT touch the arrival flow, the send backbone, or any animation file.
//
// TODOs (Build 10 Shot 2 / polish) marked inline:
//  - Door 1 currently dismisses into the app + selects the compass (the existing
//    send surface). Real "compose straight back to [Name]" (prefilled recipient,
//    no signup wall) is the Shot-2 plumbing.
//  - Door 2 shows a single-instrument placeholder showcase; the full carousel /
//    relocated onboarding showcase content is a polish round.

import SwiftUI

struct LinkArriverLandingView: View {

    /// The sender's resolved display name (from the message / connected record).
    /// nil → a generic fallback ("them").
    let senderName: String?

    /// Door 1 — send one back. Placeholder: routes to the existing send surface.
    var onSendBack: () -> Void = {}
    /// Door 3 — quiet exit into the app.
    var onDismiss: () -> Void = {}

    @State private var showShowcase = false

    private var name: String {
        if let n = senderName?.trimmingCharacters(in: .whitespaces), !n.isEmpty { return n }
        return "them"
    }

    var body: some View {
        ZStack {
            DesignTokens.Color.background.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                Text("✦")
                    .font(.system(size: 30))
                    .foregroundColor(Color(hex: "#c4a8d4").opacity(0.8))

                Text("what would you like to do?")
                    .font(.system(size: 22, design: .serif).italic())
                    .foregroundColor(DesignTokens.Color.textPrimary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 14) {
                    // ── Door 1 — primary ──────────────────────────────────
                    door(title: "Send one back to \(name)", primary: true) {
                        // TODO (Shot 2): real compose-straight-back to [Name]
                        // (prefilled recipient, no signup wall). For now, route to
                        // the existing send surface (the compass) on dismiss.
                        onSendBack()
                    }

                    // ── Door 2 — showcase ─────────────────────────────────
                    door(title: "See what Pointward is", primary: false) {
                        withAnimation(.easeInOut(duration: 0.3)) { showShowcase = true }
                    }

                    // ── Door 3 — quiet exit ───────────────────────────────
                    door(title: "I'm good for now", primary: false) {
                        onDismiss()
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
                Spacer()
            }

            // ── Placeholder showcase overlay (door 2) ─────────────────────
            if showShowcase {
                showcaseOverlay
                    .transition(.opacity)
                    .zIndex(5)
            }
        }
    }

    // MARK: - Door button (placeholder styling)

    private func door(title: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(DesignTokens.Font.label)
                .foregroundColor(primary ? DesignTokens.Color.textPrimary
                                         : DesignTokens.Color.textPrimary.opacity(0.85))
                .frame(maxWidth: .infinity)
                .padding(DesignTokens.Spacing.md)
                .background(primary ? DesignTokens.Color.accentStrong
                                    : DesignTokens.Color.backgroundCard)
                .cornerRadius(DesignTokens.Radius.button)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.button)
                        .stroke(Color(hex: "#c4a8d4").opacity(primary ? 0 : 0.4), lineWidth: 1)
                )
        }
    }

    // MARK: - Showcase placeholder (door 2)

    private var showcaseOverlay: some View {
        ZStack {
            DesignTokens.Color.background.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                Text("this is Pointward ✦")
                    .font(.system(size: 22, design: .serif).italic())
                    .foregroundColor(DesignTokens.Color.textPrimary)

                // The existing showcase component (placeholder: one instrument).
                // TODO (polish): the full carousel / relocated onboarding showcase.
                InstrumentPreview(instrument: .compass)
                    .frame(width: 220, height: 220)

                Text("a quiet way to point a thought toward someone you love")
                    .font(.system(size: 14, design: .serif).italic())
                    .foregroundColor(DesignTokens.Color.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()

                // [build10 fixbatch 2b] The showcase's PRIMARY exit now routes INTO THE APP
                // (the same guest dismiss-into-app the other doors use, via onDismiss) —
                // previously it returned to the landing doors. So "See what Pointward is" →
                // showcase → enter the app, not back to the menu.
                Button {
                    onDismiss()
                } label: {
                    Text("enter Pointward →")
                        .font(DesignTokens.Font.label)
                        .foregroundColor(DesignTokens.Color.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(DesignTokens.Spacing.md)
                        .background(DesignTokens.Color.accentStrong)
                        .cornerRadius(DesignTokens.Radius.button)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
        }
    }
}
