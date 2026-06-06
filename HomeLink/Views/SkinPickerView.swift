// SkinPickerView.swift
// Pointward › Views
// Note: Triangle shape is defined in NeedleView.swift — not duplicated here.

import SwiftUI

struct SkinPickerView: View {

    @EnvironmentObject var skinStore:    SkinStore
    @EnvironmentObject var subscription: SubscriptionManager
    @Environment(\.dismiss) var dismiss

    @State private var showUnlock = false

    var body: some View {
        ZStack {
            DesignTokens.Color.background.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Text("compass skins")
                        .font(DesignTokens.Font.label)
                        .foregroundColor(DesignTokens.Color.textPrimary)
                    Spacer()
                    Button("done") { dismiss() }
                        .font(DesignTokens.Font.label)
                        .foregroundColor(DesignTokens.Color.accentSoft)
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.vertical, DesignTokens.Spacing.md)

                Divider().background(DesignTokens.Color.border)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        skinSection(title: "skins", skins: CompassSkin.allCases)
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                }
            }
        }
        .sheet(isPresented: $showUnlock) { PaywallView() }
    }

    private func skinSection(title: String, skins: [CompassSkin]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(DesignTokens.Font.overline)
                .foregroundColor(DesignTokens.Color.textMuted)
                .padding(.top, DesignTokens.Spacing.lg)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                ForEach(skins) { skin in
                    let locked = skin.requiresUnlock && subscription.tier == .free
                    SkinCard(
                        skin:       skin,
                        isSelected: skinStore.activeSkin == skin,
                        isLocked:   locked
                    )
                    .onTapGesture {
                        if locked {
                            // One-time $1.99 unlock opens all six skins
                            HapticEngine.paywallReached()
                            showUnlock = true
                        } else {
                            skinStore.select(skin, subscription: subscription)
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - SkinCard

struct SkinCard: View {
    let skin:       CompassSkin
    let isSelected: Bool
    let isLocked:   Bool

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                miniCompassPreview
                    .frame(width: 80, height: 80)
                if isLocked {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "#0d0d14").opacity(0.6))
                        .frame(width: 80, height: 80)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16))
                        .foregroundColor(DesignTokens.Color.accentSoft)
                }
            }
            .cornerRadius(12)

            Text(skin.displayName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(DesignTokens.Color.textPrimary)
                .lineLimit(1)

            Text(skin.description)
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Color.textMuted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(isSelected ? DesignTokens.Color.backgroundLift : DesignTokens.Color.backgroundCard)
        .cornerRadius(DesignTokens.Radius.card)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.card)
                .stroke(isSelected ? DesignTokens.Color.accentMid : DesignTokens.Color.border,
                        lineWidth: isSelected ? 1.5 : 1)
        )
        .overlay(alignment: .topLeading) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(DesignTokens.Color.accentSoft)
                    .padding(8)
            }
        }
    }

    @ViewBuilder
    private var miniCompassPreview: some View {
        ZStack {
            Circle().fill(DesignTokens.Color.backgroundLift)
            Circle().stroke(DesignTokens.Color.border, lineWidth: 0.8)
            skinAccent
            miniNeedle
            Circle().fill(DesignTokens.Color.accentMid).frame(width: 6, height: 6)
        }
    }

    @ViewBuilder
    private var skinAccent: some View {
        switch skin {
        case .heart:
            HeartShape()
                .stroke(DesignTokens.Color.accentMid.opacity(0.5), lineWidth: 1)
                .frame(width: 40, height: 36).offset(y: 2)
        case .celestial:
            Circle()
                .stroke(style: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                .foregroundColor(DesignTokens.Color.accentMid.opacity(0.4))
                .frame(width: 55, height: 55)
        case .aurora:
            Circle()
                .stroke(Color(hex: "#5dcaa5").opacity(0.3), lineWidth: 2)
                .frame(width: 48, height: 48)
        default:
            Circle()
                .stroke(DesignTokens.Color.border, lineWidth: 0.6)
                .frame(width: 52, height: 52)
        }
    }

    private var miniNeedle: some View {
        ZStack {
            Triangle()
                .fill(skin == .aurora ? Color(hex: "#5dcaa5") : DesignTokens.Color.accentSoft)
                .frame(width: 6, height: 22).offset(y: -12)
            Triangle()
                .fill(DesignTokens.Color.accentStrong)
                .frame(width: 5, height: 14)
                .rotationEffect(.degrees(180)).offset(y: 8)
        }
        .rotationEffect(.degrees(340))
    }
}
