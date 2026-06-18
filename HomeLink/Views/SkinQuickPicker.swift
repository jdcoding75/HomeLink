// SkinQuickPicker.swift
// Pointward › Views
//
// [cleanup] Extracted verbatim from CompassView.swift (safe-containment pass) — an
// independent subview (zero external callers; used only by CompassView, same module,
// callers unchanged). No logic change.

import SwiftUI

// MARK: - SkinQuickPicker

/// Long-press the compass face → switch skins right here, no Settings trip.
struct SkinQuickPicker: View {

    let isPro: Bool
    let onLockedTap: () -> Void
    let onDismiss: () -> Void

    @EnvironmentObject var skinStore: SkinStore

    private static let lavender = Color(hex: "#c4a8d4")

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 16) {
                Text("compass skin")
                    .font(.system(size: 15, design: .serif).italic())
                    .foregroundColor(DesignTokens.Color.textMuted)

                HStack(spacing: 14) {
                    card(.minimal, locked: false)
                    card(.vintage, locked: !isPro)
                    card(.heart,   locked: !isPro)
                }
            }
            .padding(22)
            .background(DesignTokens.Color.backgroundCard)
            .cornerRadius(22)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(DesignTokens.Color.borderMid, lineWidth: 1)
            )
            .shadow(color: Color(hex: "#9b7fc0").opacity(0.3), radius: 24)
            .padding(.horizontal, 36)
        }
    }

    private func card(_ skin: CompassSkin, locked: Bool) -> some View {
        let isActive = skinStore.activeSkin == skin
        return Button {
            if locked {
                HapticEngine.paywallReached()
                onLockedTap()
            } else {
                skinStore.activeSkin = skin
                HapticEngine.skinSelected()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onDismiss() }
            }
        } label: {
            VStack(spacing: 7) {
                ZStack {
                    Circle()
                        .stroke(isActive ? Self.lavender : DesignTokens.Color.borderMid,
                                lineWidth: isActive ? 2 : 1)
                        .frame(width: 56, height: 56)
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 15))
                            .foregroundColor(Self.lavender.opacity(0.8))
                    } else {
                        Image(systemName: "location.north.fill")
                            .font(.system(size: 18))
                            .foregroundColor(isActive ? Self.lavender : DesignTokens.Color.textDim)
                    }
                    if isActive {
                        VStack { HStack { Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Self.lavender)
                        }; Spacer() }
                        .frame(width: 62, height: 62)
                    }
                }
                .shadow(color: isActive ? Self.lavender.opacity(0.55) : .clear, radius: 9)
                Text(skin.displayName)
                    .font(.system(size: 11))
                    .foregroundColor(isActive ? DesignTokens.Color.textPrimary
                                              : DesignTokens.Color.textMuted)
            }
            .frame(width: 76)
        }
        .buttonStyle(.plain)
    }
}
