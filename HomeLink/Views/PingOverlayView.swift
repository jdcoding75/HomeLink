// PingOverlayView.swift
// HomeLink › Views

import SwiftUI

struct PingOverlayView: View {

    let ping:      PingManager.ReceivedPing
    let onDismiss: () -> Void

    @State private var scale:   CGFloat = 0.1
    @State private var opacity: Double  = 0
    @State private var floatOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 4) {
            Text(ping.emoji)
                .font(.system(size: 48))
                .offset(y: floatOffset)
            Text(ping.fromName)
                .font(DesignTokens.Font.caption)
                .foregroundColor(DesignTokens.Color.textSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(DesignTokens.Color.backgroundCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(DesignTokens.Color.borderMid, lineWidth: 1)
                )
        )
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(AnimationSystem.pingBurst) {
                scale   = 1.0
                opacity = 1.0
            }
            // Float up and back — gives the emoji a living quality
            withAnimation(
                Animation.easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true)
            ) {
                floatOffset = -6
            }
        }
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.2)) {
                scale   = 0.8
                opacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                onDismiss()
            }
        }
    }
}
