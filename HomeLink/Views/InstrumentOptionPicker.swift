// InstrumentOptionPicker.swift
// Pointward › Views
//
// THE ONE PICKER — long-press any instrument screen and choose how you
// send: three free compass variants on top, the Pro instruments below
// (🔒 → paywall for free users; the rocket wears its coming-soon badge).
// Replaces SkinQuickPicker + the separate instrument selection.

import SwiftUI

struct InstrumentOptionPicker: View {

    let isPro: Bool
    let onLockedTap: () -> Void
    let onDismiss: () -> Void

    @EnvironmentObject var instrumentStore: InstrumentStore
    @EnvironmentObject var skinStore: SkinStore

    private static let lavender = Color(hex: "#c4a8d4")
    private static let green    = Color(hex: "#5dcaa5")

    private var freeOptions: [InstrumentOption] {
        InstrumentOption.allCases.filter { !$0.requiresPro }
    }
    private var proOptions: [InstrumentOption] {
        InstrumentOption.allCases.filter(\.requiresPro)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 14) {
                Text("your style")
                    .font(.system(size: 15, design: .serif).italic())
                    .foregroundColor(DesignTokens.Color.textMuted)

                // ── Free — the compass, three ways ──
                HStack(spacing: 10) {
                    ForEach(freeOptions) { option in
                        optionCard(option)
                    }
                }

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
                    .padding(.horizontal, 6)

                // ── Pro — the instruments. A 3-wide grid wraps the growing
                // lineup (bow · flick · rocket · wind · wand) without
                // overflowing the card. ──
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10),
                                         count: 3),
                          spacing: 12) {
                    ForEach(proOptions) { option in
                        optionCard(option)
                    }
                }
            }
            .padding(20)
            .background(DesignTokens.Color.backgroundCard)
            .cornerRadius(22)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(DesignTokens.Color.borderMid, lineWidth: 1)
            )
            .shadow(color: Color(hex: "#9b7fc0").opacity(0.3), radius: 24)
            .padding(.horizontal, 24)
        }
    }

    private func optionCard(_ option: InstrumentOption) -> some View {
        let locked   = option.requiresPro && !isPro
        let isActive = InstrumentOption.selected == option

        return Button {
            if option.comingSoon {
                HapticEngine.personSelected()   // a wink, nothing more
            } else if locked {
                HapticEngine.paywallReached()
                onLockedTap()
            } else {
                InstrumentOption.apply(option, instrumentStore: instrumentStore,
                                       skinStore: skinStore)
                HapticEngine.skinSelected()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onDismiss() }
            }
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .stroke(isActive ? Self.lavender : DesignTokens.Color.borderMid,
                                lineWidth: isActive ? 2 : 1)
                        .frame(width: 52, height: 52)
                    Text(option.icon)
                        .font(.system(size: 22))
                        .opacity(locked || option.comingSoon ? 0.45 : 1)
                    if locked && !option.comingSoon {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Self.lavender.opacity(0.9))
                            .offset(x: 16, y: -16)
                    }
                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(Self.lavender)
                            .offset(x: 19, y: -19)
                    }
                }
                .shadow(color: isActive ? Self.lavender.opacity(0.55) : .clear, radius: 9)

                Text(option.displayName)
                    .font(.system(size: 10))
                    .foregroundColor(isActive ? DesignTokens.Color.textPrimary
                                              : DesignTokens.Color.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if option.comingSoon {
                    Text("coming soon")
                        .font(.system(size: 8, design: .serif).italic())
                        .foregroundColor(DesignTokens.Color.accentMid)
                } else {
                    Text(option.requiresPro ? "pro" : "free")
                        .font(.system(size: 8, design: .serif).italic())
                        .foregroundColor(option.requiresPro
                                         ? Self.lavender.opacity(0.8) : Self.green)
                }
            }
            .frame(width: 72)
        }
        .buttonStyle(.plain)
    }
}
