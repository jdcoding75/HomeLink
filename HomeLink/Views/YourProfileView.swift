// YourProfileView.swift
// Pointward › Views
//
// Settings › "your name" sheet — the post-onboarding self-editor for the ONE
// piece of identity the app keeps: your DISPLAY NAME. (Own-location was stripped
// 2026-06-06 — onboarding is name-only, so this editor is name-only too.)
//
// Pre-filled from the current profile (people.profile?.displayName, falling back
// to the UserDefaults snapshot). Saves via the SAME local + server path the
// onboarding/reply flows use (people.saveProfile + updateUserProfile), preserving
// the current emoji so UserProfile.emoji is never blanked. No sign-in step — the
// user is already signed in to reach Settings.
//
// Design: one field, one button, one reassurance line — bigger type + generous
// spacing so it feels calm and intentional, not cramped. Field labelling matches
// the house pattern (label above, placeholder inside, formInput styling).

import SwiftUI

struct YourProfileView: View {
    @EnvironmentObject var people: PeopleManager
    @Environment(\.dismiss) private var dismiss

    // Seed from the static snapshot (valid in an initializer); .onAppear prefers the
    // live people.profile when available — i.e. people.profile?.displayName ?? snapshot.
    @State private var name: String = UserProfile.snapshot?.displayName ?? ""

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }
    private var canSave: Bool { !trimmed.isEmpty }

    var body: some View {
        ZStack {
            DesignTokens.Color.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Minimal header — just the dismiss affordance (the big title lives
                // in the body for the spacious feel).
                HStack {
                    Button("cancel") { dismiss() }
                        .font(DesignTokens.Font.label)
                        .foregroundColor(DesignTokens.Color.textMuted)
                    Spacer()
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.vertical, DesignTokens.Spacing.md)

                Spacer()

                VStack(spacing: 40) {
                    // Title — large, serif (the app's emotional voice).
                    Text("Your Name")
                        .font(.system(size: 34, weight: .semibold, design: .serif))
                        .foregroundColor(DesignTokens.Color.textPrimary)

                    // The single field — label above (house style), placeholder inside,
                    // helper beneath. Larger type than the default sheet sizing.
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Name")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(DesignTokens.Color.textMuted)

                        TextField("your name", text: $name)
                            .font(.system(size: 24, design: .serif))
                            .formInput()
                            .submitLabel(.done)
                            .onSubmit { if canSave { save() } }

                        Text("How others will see you.")
                            .font(.system(size: 15, design: .serif).italic())
                            .foregroundColor(DesignTokens.Color.textMuted)
                            .padding(.top, 2)
                    }

                    // Substantial primary button.
                    Button { save() } label: {
                        Text("Continue")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(DesignTokens.Color.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(DesignTokens.Color.accentStrong)
                            .cornerRadius(DesignTokens.Radius.button)
                    }
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.4)
                    .animation(.easeOut(duration: 0.25), value: canSave)

                    // Tiny reassurance.
                    Text("Others only see the name you choose ✦")
                        .font(.system(size: 13, design: .serif).italic())
                        .foregroundColor(DesignTokens.Color.textMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 36)

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            // Prefer the live SwiftData profile name when present (snapshot is the fallback).
            if let live = people.profile?.displayName, !live.isEmpty { name = live }
        }
    }

    // MARK: - Save (same local + server path as onboarding/reply; emoji preserved)

    private func save() {
        guard canSave else { return }
        let emoji = people.profile?.emoji ?? "❤️"          // keep current emoji — never blank UserProfile.emoji
        people.saveProfile(name: trimmed, emoji: emoji)     // LOCAL
        Task { await SupabaseService.shared.updateUserProfile(name: trimmed, emoji: emoji) }  // SERVER
        dismiss()
    }
}
