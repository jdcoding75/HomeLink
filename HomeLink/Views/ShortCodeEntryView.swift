// ShortCodeEntryView.swift
// Pointward › Views
//
// Phase 2 Build 4b — the SHORT-CODE FALLBACK entry (no-link receive path).
//
// "Someone sent me something but I have no link" → type the 6-char code from
// their message. We claim that sender's UNOPENED messages (newest-first):
//   • the NEWEST plays now through the SAME 4a receive chain (this view just
//     posts .pointwardOpenMessage; RootView owns the IncomingMessageView cover),
//   • the REST drop into the EXISTING history bucket (PingManager.caughtHistory
//     via recordCaught) — NOT marked opened, so they stay recoverable,
//   • zero results → a gentle empty state (bad code OR all already opened).
//
// This is the NEW short_code system — it is NOT pairing UI and touches no
// pairing view, the connections table, or the POINT-XXXX code.

import SwiftUI

struct ShortCodeEntryView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var pings: PingManager
    // [phase2 build5] Auto-create the claimed sender as a contact (once).
    @EnvironmentObject private var people: PeopleManager

    private enum Phase { case entry, claiming, empty }
    @State private var phase: Phase = .entry
    @State private var code = ""
    @FocusState private var fieldFocused: Bool

    private var canSubmit: Bool { ShortCode.isComplete(code) && phase != .claiming }

    var body: some View {
        ZStack {
            DesignTokens.Color.background.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                Spacer(minLength: 0)
                switch phase {
                case .entry, .claiming: entryBody
                case .empty:            emptyBody
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
        }
        .onAppear { fieldFocused = true }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Spacer()
            Button("done") { dismiss() }
                .font(DesignTokens.Font.label)
                .foregroundColor(DesignTokens.Color.accentSoft)
        }
        .padding(.top, DesignTokens.Spacing.md)
    }

    // MARK: - Entry

    private var entryBody: some View {
        VStack(spacing: 18) {
            Text("got a code? ✦")
                .font(DesignTokens.Font.compassName)
                .foregroundColor(DesignTokens.Color.textPrimary)

            Text("enter the 6-character code from\nsomeone's message")
                .font(.system(size: 14, design: .serif).italic())
                .foregroundColor(DesignTokens.Color.textMuted)
                .multilineTextAlignment(.center)

            TextField("", text: $code, prompt: Text("ABC234").foregroundColor(DesignTokens.Color.textDim))
                .font(.system(size: 30, weight: .semibold, design: .monospaced))
                .multilineTextAlignment(.center)
                .foregroundColor(DesignTokens.Color.textPrimary)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .focused($fieldFocused)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(DesignTokens.Color.backgroundCard)
                .cornerRadius(DesignTokens.Radius.card)
                .overlay(RoundedRectangle(cornerRadius: DesignTokens.Radius.card)
                    .stroke(DesignTokens.Color.border, lineWidth: 1))
                .onChange(of: code) { _, new in
                    // Gentle guide: uppercase, strip spaces + ambiguous chars, cap at 6.
                    let cleaned = ShortCode.normalize(new).filter { ShortCode.charset.contains($0) }
                    code = String(cleaned.prefix(ShortCode.length))
                }

            Button(action: submit) {
                HStack(spacing: 8) {
                    if phase == .claiming {
                        ProgressView().tint(DesignTokens.Color.textPrimary).scaleEffect(0.8)
                    }
                    Text(phase == .claiming ? "looking…" : "get it ✦")
                }
                .font(DesignTokens.Font.label)
                .foregroundColor(DesignTokens.Color.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(DesignTokens.Spacing.md)
                .background(canSubmit ? DesignTokens.Color.accentStrong
                                      : DesignTokens.Color.backgroundLift)
                .cornerRadius(DesignTokens.Radius.button)
            }
            .disabled(!canSubmit)
        }
    }

    // MARK: - Empty state (bad code OR all already opened — not an error)

    private var emptyBody: some View {
        VStack(spacing: 14) {
            Text("✦")
                .font(.system(size: 34))
                .foregroundColor(DesignTokens.Color.accentSoft.opacity(0.8))
            Text("no new thoughts for that code ✦")
                .font(.system(size: 19, design: .serif).italic())
                .foregroundColor(DesignTokens.Color.textPrimary)
                .multilineTextAlignment(.center)
            Text("double-check the code — or they may all\nbe opened already")
                .font(.system(size: 13, design: .serif).italic())
                .foregroundColor(DesignTokens.Color.textMuted)
                .multilineTextAlignment(.center)

            Button {
                code = ""
                phase = .entry
                fieldFocused = true
            } label: {
                Text("try another code")
                    .font(DesignTokens.Font.label)
                    .foregroundColor(DesignTokens.Color.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(DesignTokens.Spacing.md)
                    .background(DesignTokens.Color.accentStrong)
                    .cornerRadius(DesignTokens.Radius.button)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Claim

    private func submit() {
        guard canSubmit else { return }
        fieldFocused = false
        phase = .claiming
        let entered = code
        Task {
            let messages = (try? await SupabaseService.shared.getUnopenedForShortCode(entered)) ?? []
            await MainActor.run { handle(messages) }
        }
    }

    @MainActor
    private func handle(_ messages: [Message]) {
        let (newest, rest) = ShortCodeClaim.split(messages)

        // [build5-done] CONTACT AUTO-CREATE — link-era, senderID-keyed, pairing-FREE.
        // Every message claimed by ONE short code shares ONE senderID, so this is a
        // SINGLE upsert (create-or-update) — exactly one contact, never one per
        // message. Silent (no prompt). Runs even when only `rest` exist (all already
        // opened is impossible here — these are unopened), and is skipped on an
        // empty claim (nothing to attribute).
        if let sender = newest ?? rest.first {
            people.upsertContact(senderID: sender.senderID.uuidString,
                                 displayName: sender.senderDisplayName)
        }

        guard let newest else {
            HapticEngine.personSelected()   // a soft wink — gentle, not an error
            phase = .empty
            return
        }

        // The REST (older unopened) → the EXISTING history bucket. recordCaught
        // does NOT mark them opened (server stays unopened → re-claimable);
        // dedup across re-claims is by remoteID = message.id.
        for m in rest { pings.recordCaught(Self.historyPing(from: m)) }

        // The NEWEST plays through the SAME 4a chain. Dismiss first, then route
        // (a beat later) so the sheet finishes before the full-screen cover.
        let newestID = newest.id
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            NotificationCenter.default.post(name: .pointwardOpenMessage, object: newestID)
        }
    }

    // MARK: - Message → history ReceivedPing

    private static func historyPing(from m: Message) -> PingManager.ReceivedPing {
        PingManager.ReceivedPing(
            fromName:    (m.senderDisplayName?.isEmpty == false ? m.senderDisplayName! : "someone"),
            emoji:       (m.emoji?.isEmpty == false ? m.emoji! : CuratedEmoji.defaultEmoji),
            timestamp:   parseDate(m.createdAt) ?? .now,
            remoteID:    m.id,    // dedup key (never routed through markOpened)
            senderStyle: Instrument(rawValue: m.instrument ?? "")?.senderStyle.rawValue,
            message:     m.content,
            tagline:     nil,
            isTest:      false)
    }

    private static func parseDate(_ iso: String?) -> Date? {
        guard let iso else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: iso) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: iso)
    }
}
