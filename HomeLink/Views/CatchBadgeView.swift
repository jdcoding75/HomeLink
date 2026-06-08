// CatchBadgeView.swift
// Pointward › Views
//
// "X thoughts waiting ✦" — the soft lavender capsule above the emoji row.
// Shows whenever unread thoughts exist; tap begins the catch.

import SwiftUI

struct CatchBadgeView: View {

    let count: Int
    let onTap: () -> Void

    @State private var pulse = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Text(count == 1 ? "1 thought waiting" : "\(count) thoughts waiting")
                    .font(.system(size: 13, design: .serif).italic())
                Text("✦")
                    .font(.system(size: 12))
            }
            .foregroundColor(DesignTokens.Color.accentSoft)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(DesignTokens.Color.backgroundLift.opacity(0.95))
                    .overlay(Capsule().stroke(DesignTokens.Color.accentMid.opacity(0.5), lineWidth: 1))
            )
            .shadow(color: Color(hex: "#9b7fc0").opacity(pulse ? 0.5 : 0.2), radius: 10)
            .scaleEffect(pulse ? 1.04 : 1.0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
