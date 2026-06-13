// ArrivalPreviewView.swift
// Pointward › Views
//
// [5/6] THE ARRIVAL PREVIEW — a brief, warm glimpse of what the recipient sees
// the moment after you send. Their themed catch world fills the screen, the
// thought drifts in from the sender's edge and grows, and "arriving for [Name]
// ✦" sits beneath it. ~2.5 s, soft crossfade in and out, then back to the
// compass with a quiet "sent ✦". On by default for the first sends; toggle in
// Settings → notifications.

// ───────────────────────────────────────────────────────────────────────────
// [cleanup 2026-06-13] ORPHAN — entire file disabled, not deleted (per CLAUDE.md
// never-delete rule). ArrivalPreviewView has ZERO live callers; it was
// SUPERSEDED by the shared EmojiRevealView(.sent) confirmation. Wrapped in
// `#if false` so the code is preserved verbatim for reference / possible restore
// of the arrival-preview feature, but excluded from compilation.
// ───────────────────────────────────────────────────────────────────────────
#if false

import SwiftUI

struct ArrivalPreviewView: View {

    let emoji: String
    let style: SenderStyle
    /// The recipient's name — "arriving for [Name] ✦".
    let name: String
    let onDone: () -> Void

    @State private var shown   = false
    @State private var arrived = false

    private var hue: Color { EmojiHue.color(for: emoji) }
    private static let lavender = Color(hex: "#c4a8d4")

    var body: some View {
        ZStack {
            DesignTokens.Color.background.ignoresSafeArea()
            // The recipient's themed world — the same one their catch shows.
            CatchWorldBackground(style: style).ignoresSafeArea()
            Color.black.opacity(0.22).ignoresSafeArea()

            // The thought arriving from the top edge, growing toward centre.
            Circle()
                .fill(RadialGradient(colors: [hue.opacity(0.95), hue.opacity(0.3), .clear],
                                     center: .center, startRadius: 6, endRadius: 62))
                .frame(width: 128, height: 128)
                .overlay(Text(emoji).font(.system(size: 58)))
                .shadow(color: hue.opacity(0.7), radius: 20)
                .scaleEffect(arrived ? 1.0 : 0.35)
                .offset(y: arrived ? -10 : -340)

            VStack {
                Spacer()
                Text("arriving for \(name) ✦")
                    .font(.system(size: 22, design: .serif).italic())
                    .foregroundColor(Self.lavender)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                    .shadow(color: .black.opacity(0.55), radius: 8)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 60)
            }
        }
        .opacity(shown ? 1 : 0)
        .allowsHitTesting(false)
        .onAppear {
            // [5/6] Brief 300 ms crossfade in, a 2–3 s glimpse, crossfade out.
            withAnimation(.easeOut(duration: 0.3)) { shown = true }
            withAnimation(.easeInOut(duration: 1.2).delay(0.2)) { arrived = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeIn(duration: 0.3)) { shown = false }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) { onDone() }
            }
        }
    }
}

#endif  // [cleanup 2026-06-13] end ORPHAN ArrivalPreviewView
