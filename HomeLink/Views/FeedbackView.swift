// FeedbackView.swift
// Pointward › Views
//
// Settings › "send feedback" sheet. A warm category chip + a free-text note → one
// anon-allowed insert into public.feedback (SupabaseService.insertFeedback). Identity
// (user_id / display_name) attaches only when available; signed-out still sends.
// Text is never lost on a failed send (kept in @State); success shows a brief "sent ✓"
// then auto-dismisses. body is clamped to the table's 4000-char CHECK.

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss

    private enum Phase { case idle, sending, sent }
    @State private var phase: Phase = .idle
    @State private var category = "bug"           // [feedback chips 2026-06] default-selected (first option) → the NOT-NULL column is always set
    @State private var bodyText = ""
    @State private var errorText: String? = nil

    private static let bodyLimit = 4000

    /// 6 options → internal category keys (the row stores the KEY, a readable slug).
    /// [feedback chips 2026-06] labels + keys replaced to spec; the chip SELECTION
    /// mechanic (FlowChips) is unchanged. Historical rows keep their old keys (free-text
    /// column, no migration) — old rows = old keys, new rows = new keys.
    private let chips: [(key: String, label: String)] = [
        ("bug",       "Bug Report"),
        ("animation", "Animation Idea"),
        ("feature",   "Feature Idea"),
        ("loved_it",  "Loved It"),
        ("how_do_i",  "How Do I…"),
        ("other",     "Other")
    ]

    private var trimmedBody: String { bodyText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSend: Bool { !trimmedBody.isEmpty && phase != .sending }

    var body: some View {
        ZStack {
            DesignTokens.Color.background.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Pointward is my first app — I'm learning as I go. Your thoughts help me decide what to improve next ✦")
                            .font(.system(size: 14, design: .serif).italic())
                            .foregroundColor(DesignTokens.Color.textMuted)

                        chipRow
                        bodyEditor

                        if let errorText {
                            Text(errorText)
                                .font(DesignTokens.Font.caption)
                                .foregroundColor(.red)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        sendButton
                    }
                    .padding(DesignTokens.Spacing.lg)
                }
                Spacer()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button("cancel") { dismiss() }
                .font(DesignTokens.Font.label)
                .foregroundColor(DesignTokens.Color.textMuted)
            Spacer()
            Text("Help Make This Better")
                .font(DesignTokens.Font.label)
                .foregroundColor(DesignTokens.Color.textPrimary)
            Spacer()
            // Balance the cancel button so the title stays centered.
            Text("cancel").font(DesignTokens.Font.label).foregroundColor(.clear)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
    }

    // MARK: - Category chips

    private var chipRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("what's this about?")
                .font(DesignTokens.Font.overline)
                .foregroundColor(DesignTokens.Color.textMuted)
            FlowChips(chips: chips, selected: $category)
        }
    }

    // MARK: - Body editor

    private var bodyEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tell me more (optional)")
                .font(DesignTokens.Font.overline)
                .foregroundColor(DesignTokens.Color.textMuted)
            ZStack(alignment: .topLeading) {
                if bodyText.isEmpty {
                    Text("type your note…")
                        .font(.system(size: 15, design: .serif))
                        .foregroundColor(DesignTokens.Color.textDim)
                        .padding(.horizontal, 5).padding(.vertical, 10)
                }
                TextEditor(text: $bodyText)
                    .font(.system(size: 15, design: .serif))
                    .foregroundColor(DesignTokens.Color.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 140)
                    .onChange(of: bodyText) { _, new in
                        if new.count > Self.bodyLimit { bodyText = String(new.prefix(Self.bodyLimit)) }
                    }
            }
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.Color.backgroundCard)
            .cornerRadius(DesignTokens.Radius.button)
            .overlay(RoundedRectangle(cornerRadius: DesignTokens.Radius.button)
                .stroke(DesignTokens.Color.border, lineWidth: 1))

            Text("\(bodyText.count)/\(Self.bodyLimit)")
                .font(.system(size: 10))
                .foregroundColor(DesignTokens.Color.textDim)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    // MARK: - Send

    private var sendButton: some View {
        Button { send() } label: {
            HStack(spacing: 8) {
                if phase == .sending {
                    ProgressView().tint(DesignTokens.Color.textPrimary)
                }
                Text(phase == .sent ? "sent ✓" : "Send feedback")
                    .font(DesignTokens.Font.label)
                    .foregroundColor(DesignTokens.Color.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.Color.accentStrong)
            .cornerRadius(DesignTokens.Radius.button)
        }
        .disabled(!canSend)
        .opacity(canSend ? 1 : 0.35)
    }

    private func send() {
        phase = .sending
        errorText = nil
        let body = trimmedBody
        let appVersion = Self.appVersion()
        let deviceInfo = Self.deviceInfo()
        let userID = SupabaseService.localUserID                 // null when signed-out (FK-safe)
        let displayName = UserProfile.snapshot?.displayName      // UserDefaults read — no PeopleManager
        Task {
            do {
                try await SupabaseService.shared.insertFeedback(
                    category: category, body: body,
                    userID: userID, displayName: displayName,
                    appVersion: appVersion, deviceInfo: deviceInfo)
                await MainActor.run {
                    phase = .sent
                    HapticEngine.connectionFelt()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { dismiss() }
                }
            } catch {
                // Never lose the typed note — return to idle, surface a retry.
                await MainActor.run {
                    phase = .idle
                    errorText = "couldn't send — try again"
                }
            }
        }
    }

    // MARK: - Metadata (nullable-safe — never crash, never block the send)

    private static func appVersion() -> String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(short) (\(build))"
    }

    /// "iOS 18.5 · iPhone16,1". A failed machine-id read degrades to just the OS
    /// string — never nil, never a crash (no force-unwrap), so it can't block the send.
    private static func deviceInfo() -> String {
        #if canImport(UIKit)
        let osPart = "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        var sys = utsname(); uname(&sys)
        let machine = withUnsafeBytes(of: &sys.machine) { raw -> String in
            guard let base = raw.baseAddress else { return "" }
            return String(cString: base.assumingMemoryBound(to: CChar.self))
                .trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
        }
        return machine.isEmpty ? osPart : "\(osPart) · \(machine)"
        #else
        return "—"
        #endif
    }
}

// MARK: - Wrapping category chips

private struct FlowChips: View {
    let chips: [(key: String, label: String)]
    @Binding var selected: String

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(chips, id: \.key) { chip in
                let on = selected == chip.key
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { selected = chip.key }
                    HapticEngine.personSelected()
                } label: {
                    Text(chip.label)
                        .font(.system(size: 13, design: .serif))
                        .foregroundColor(on ? DesignTokens.Color.textPrimary : DesignTokens.Color.textSecondary)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 12)
                            .fill(on ? DesignTokens.Color.accentStrong : DesignTokens.Color.backgroundCard))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(on ? DesignTokens.Color.accentMid : DesignTokens.Color.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    FeedbackView().preferredColorScheme(.dark)
}
