// AboutView.swift
// Pointward › Views
//
// The story screen — why Pointward exists. Reached from Settings › about.
// Same deep purple aesthetic as the rest of the app; meant to be read
// once and felt, not configured.

import SwiftUI

struct AboutView: View {

    @Environment(\.dismiss) var dismiss

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        ZStack {
            // Deep purple ground with a soft center glow
            DesignTokens.Color.background.ignoresSafeArea()
            RadialGradient(
                colors: [Color(hex: "#9b7fc0").opacity(0.08), .clear],
                center: .center, startRadius: 20, endRadius: 320
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Spacer()
                    Button("done") { dismiss() }
                        .font(DesignTokens.Font.label)
                        .foregroundColor(DesignTokens.Color.accentSoft)
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.vertical, DesignTokens.Spacing.md)

                Spacer()

                // App mark
                ZStack {
                    Circle()
                        .stroke(DesignTokens.Color.accentMid.opacity(0.3), lineWidth: 1)
                        .frame(width: 96, height: 96)
                    Circle()
                        .stroke(DesignTokens.Color.accentMid.opacity(0.12), lineWidth: 1)
                        .frame(width: 114, height: 114)
                    Text("🧭")
                        .font(.system(size: 40))
                }
                .padding(.bottom, 24)

                Text("Pointward")
                    .font(DesignTokens.Font.compassName)
                    .foregroundColor(DesignTokens.Color.textPrimary)
                    .padding(.bottom, 4)

                Text("version \(appVersion)")
                    .font(DesignTokens.Font.caption)
                    .foregroundColor(DesignTokens.Color.textMuted)
                    .padding(.bottom, 36)

                // The story
                // [copy-declutter] story copy replaced. Was:
                // """
                // Pointward was made for the feeling of distance. \
                // For the moment you wonder which direction home is. \
                // For everyone who has someone worth pointing toward.
                // """
                Text("""
                Pointward is my first app — a tiny experiment that turned into something I really love. Right now it's completely free, because I want people to try it, break it, enjoy it, and tell me what feels magical (or not).

                If it takes off, I'll add more animations, more polish, and maybe one day a mix of free + paid features so I can keep building at a good pace. But for now, it's just me, making this better piece by piece.

                Thanks for being here. Your thoughts help shape this thing ✦
                """)
                .font(.system(size: 15).italic())
                .foregroundColor(DesignTokens.Color.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.horizontal, 40)

                Spacer()

                // Footer
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 11))
                        Text("offline by design")
                            .font(DesignTokens.Font.caption)
                    }
                    .foregroundColor(Color(hex: "#5dcaa5"))

                    // [copy 2026-06-25] unified version format. was: "v\(appVersion)"
                    Text("version \(appVersion)")
                        .font(.system(size: 10))
                        .foregroundColor(DesignTokens.Color.textDim)
                }
                .padding(.bottom, 32)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AboutView()
        .preferredColorScheme(.dark)
}
