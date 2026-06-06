// PersonDetailView.swift
// Pointward › Views
//
// Tap a person card → this sheet: who they are, whether your compasses are
// linked, ways to connect if not, presence ("active recently"), and the
// history of thoughts between you.

import SwiftUI

struct PersonDetailView: View {

    let person: Person
    @EnvironmentObject var people: PeopleManager
    @Environment(\.dismiss) private var dismiss

    @State private var codeInput = ""
    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var lastSeen: Date?
    @State private var showConnectOptions = false
    @State private var connectedNow = false   // refresh after in-sheet pairing

    private var isConnected: Bool {
        if connectedNow { return true }
        guard let friend = SupabaseService.connectedFriendID else { return false }
        return person.pairedUserID == friend.uuidString
    }

    private var partnerID: UUID? {
        person.pairedUserID.flatMap(UUID.init)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.Color.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // ── Who ───────────────────────────────────────────
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#9b7fc0").opacity(0.20))
                                .frame(width: 84, height: 84)
                                .blur(radius: 16)
                            Text(person.emoji)
                                .font(.system(size: 48))
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 10)

                        Text(person.name)
                            .font(.system(size: 28, weight: .semibold, design: .serif))
                            .foregroundColor(DesignTokens.Color.textPrimary)

                        Text(person.resolvedTagline)
                            .font(.system(size: 14, design: .serif).italic())
                            .foregroundColor(DesignTokens.Color.accentMid)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 36)
                            .padding(.top, 2)

                        Text(person.displayAddress.isEmpty
                             ? person.locationDisplayName : person.displayAddress)
                            .font(.system(size: 12))
                            .foregroundColor(DesignTokens.Color.textMuted)
                            .lineLimit(1)
                            .padding(.top, 6)
                            .padding(.bottom, 24)

                        // ── Connection ────────────────────────────────────
                        connectionCard
                            .padding(.horizontal, 24)
                            .padding(.bottom, 16)

                        // ── Thought history ───────────────────────────────
                        if isConnected, let partnerID {
                            NavigationLink {
                                PingHistoryView(personName: person.name, partnerID: partnerID)
                            } label: {
                                HStack {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.system(size: 15))
                                        .foregroundColor(DesignTokens.Color.accentSoft)
                                    Text("thought history")
                                        .font(DesignTokens.Font.label)
                                        .foregroundColor(DesignTokens.Color.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(DesignTokens.Color.textDim)
                                }
                                .padding(DesignTokens.Spacing.md)
                                .background(DesignTokens.Color.backgroundCard)
                                .cornerRadius(DesignTokens.Radius.card)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignTokens.Radius.card)
                                        .stroke(DesignTokens.Color.border, lineWidth: 1)
                                )
                            }
                            .padding(.horizontal, 24)
                        }

                        Spacer(minLength: 40)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("done") { dismiss() }
                        .foregroundColor(DesignTokens.Color.accentSoft)
                }
            }
        }
        .onAppear { fetchPresence() }
    }

    // MARK: - Connection card

    @ViewBuilder
    private var connectionCard: some View {
        if isConnected {
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Circle().fill(Color(hex: "#5dcaa5")).frame(width: 8, height: 8)
                    Text("Connected ✓")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "#5dcaa5"))
                }
                if let lastSeen {
                    Text(Self.presenceText(for: lastSeen))
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Color.textMuted)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color(hex: "#5dcaa5").opacity(0.07))
            .cornerRadius(DesignTokens.Radius.card)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.card)
                    .stroke(Color(hex: "#5dcaa5").opacity(0.3), lineWidth: 1)
            )
            // Green glow for the linked state
            .shadow(color: Color(hex: "#5dcaa5").opacity(0.25), radius: 10)
        } else {
            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    Circle().fill(DesignTokens.Color.textDim).frame(width: 8, height: 8)
                    Text("not connected")
                        .font(.system(size: 13))
                        .foregroundColor(DesignTokens.Color.textMuted)
                }

                if !showConnectOptions {
                    Button {
                        withAnimation(.easeOut(duration: 0.25)) { showConnectOptions = true }
                    } label: {
                        Text("Connect with \(person.name)")
                            .font(DesignTokens.Font.label)
                            .foregroundColor(DesignTokens.Color.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(DesignTokens.Spacing.md)
                            .background(DesignTokens.Color.accentStrong)
                            .cornerRadius(DesignTokens.Radius.button)
                    }
                } else {
                    // a) Send them everything they need
                    ShareLink(item: AppLinks.friendInvite(code: SupabaseService.localPairingCode)) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                            Text("send invite")
                        }
                        .font(DesignTokens.Font.label)
                        .foregroundColor(DesignTokens.Color.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(DesignTokens.Spacing.md)
                        .background(DesignTokens.Color.accentStrong)
                        .cornerRadius(DesignTokens.Radius.button)
                    }

                    // b) Or redeem theirs
                    VStack(alignment: .leading, spacing: 6) {
                        Text("enter their code")
                            .font(DesignTokens.Font.overline)
                            .foregroundColor(DesignTokens.Color.textMuted)
                        HStack(spacing: 10) {
                            TextField("POINT-XXXX", text: $codeInput)
                                .font(.system(size: 16, design: .monospaced))
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .formInput()
                            Button {
                                connect()
                            } label: {
                                Text("connect")
                                    .font(DesignTokens.Font.label)
                                    .foregroundColor(DesignTokens.Color.textPrimary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 13)
                                    .background(DesignTokens.Color.accentStrong)
                                    .cornerRadius(DesignTokens.Radius.button)
                            }
                            .disabled(codeInput.trimmingCharacters(in: .whitespaces).isEmpty || isBusy)
                        }
                    }

                    if isBusy { ProgressView().tint(DesignTokens.Color.accentSoft) }
                    if let errorMessage {
                        Text(errorMessage)
                            .font(DesignTokens.Font.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .padding(16)
            .background(DesignTokens.Color.backgroundCard)
            .cornerRadius(DesignTokens.Radius.card)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.card)
                    .stroke(DesignTokens.Color.border, lineWidth: 1)
            )
        }
    }

    private func connect() {
        guard SupabaseService.localUserID != nil else {
            errorMessage = "Sign in first (Settings → account)."
            return
        }
        isBusy = true
        errorMessage = nil
        Task {
            defer { isBusy = false }
            do {
                let friend = try await SupabaseService.shared.redeemCode(codeInput)
                person.pairedUserID = friend.uuidString   // bind connection to this person
                try? people.save()
                connectedNow = true
                HapticEngine.connectionFelt()
                fetchPresence()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func fetchPresence() {
        guard isConnected, let partnerID else { return }
        Task {
            lastSeen = await SupabaseService.shared.fetchLastSeen(of: partnerID)
        }
    }

    /// "active recently" within the hour, else "last seen 2 hours ago".
    static func presenceText(for date: Date) -> String {
        if Date.now.timeIntervalSince(date) < 3600 { return "active recently" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "last seen \(formatter.localizedString(for: date, relativeTo: .now))"
    }
}

// MARK: - Ping history

/// Every thought between you and this person, newest first.
struct PingHistoryView: View {

    let personName: String
    let partnerID: UUID

    @State private var records: [SupabaseService.PingRecord] = []
    @State private var loaded = false

    private let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    var body: some View {
        ZStack {
            DesignTokens.Color.background.ignoresSafeArea()

            if !loaded {
                ProgressView().tint(DesignTokens.Color.accentSoft)
            } else if records.isEmpty {
                VStack(spacing: 8) {
                    Text("🌙").font(.system(size: 40))
                    Text("no thoughts yet")
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundColor(DesignTokens.Color.textPrimary)
                    Text("send the first one")
                        .font(.system(size: 13, design: .serif).italic())
                        .foregroundColor(DesignTokens.Color.textMuted)
                }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(records) { record in
                            row(record)
                            if record.id != records.last?.id {
                                Divider()
                                    .background(DesignTokens.Color.border)
                                    .padding(.leading, 56)
                            }
                        }
                    }
                    .background(DesignTokens.Color.backgroundCard)
                    .cornerRadius(DesignTokens.Radius.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.card)
                            .stroke(DesignTokens.Color.border, lineWidth: 1)
                    )
                    .padding(20)
                }
            }
        }
        .navigationTitle("thoughts with \(personName)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            records = await SupabaseService.shared.fetchPings(with: partnerID)
            loaded = true
        }
    }

    private func row(_ record: SupabaseService.PingRecord) -> some View {
        let sent = record.toUser == partnerID
        return HStack(spacing: 14) {
            Text(record.emoji)
                .font(.system(size: 26))
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(sent ? "sent" : "received")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DesignTokens.Color.textPrimary)
                Text(relative.localizedString(for: record.createdAt, relativeTo: .now))
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Color.textMuted)
            }

            Spacer()

            // Read receipts on the thoughts we sent
            if sent {
                if record.openedAt != nil {
                    Text("felt ✓")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#5dcaa5"))
                } else {
                    Text("sent")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Color.textDim)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
