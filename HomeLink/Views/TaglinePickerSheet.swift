// TaglinePickerSheet.swift
// Pointward › Views
//
// [4/4] The full tagline picker — long-press a person's tagline to open it.
// "none" sits at the top (no tagline travels with their thoughts); the rest
// is the poetic library, the current one highlighted. Per person: each keeps
// their own.

import SwiftUI

struct TaglinePickerSheet: View {

    /// The person's current tagline (nil = none).
    let current: String?
    /// nil → "no tagline"; a string → that tagline.
    let onSelect: (String?) -> Void

    @Environment(\.dismiss) private var dismiss

    private static let lavender = Color(hex: "#c4a8d4")

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.Color.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {
                        // "none" — clears the tagline.
                        row(title: "no tagline",
                            subtitle: "thoughts travel without a tagline",
                            selected: current == nil,
                            italic: false) {
                            onSelect(nil); dismiss()
                        }

                        Rectangle()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 1)
                            .padding(.horizontal, 20)

                        ForEach(TaglineSystem.poeticLibrary, id: \.self) { tagline in
                            row(title: tagline, subtitle: nil,
                                selected: current == tagline, italic: true) {
                                onSelect(tagline); dismiss()
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("their tagline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("done") { dismiss() }
                        .foregroundColor(Self.lavender)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func row(title: String, subtitle: String?, selected: Bool,
                     italic: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(italic ? .system(size: 17, design: .serif).italic()
                                     : .system(size: 16, design: .serif))
                        .foregroundColor(selected ? Self.lavender : DesignTokens.Color.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundColor(DesignTokens.Color.textMuted)
                    }
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Self.lavender)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 13)
            .background(selected ? Self.lavender.opacity(0.10) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
