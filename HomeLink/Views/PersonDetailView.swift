// PersonDetailView.swift
// Pointward › Views
//
// Tap a person card → this sheet: who they are, whether your compasses are
// linked, ways to connect if not, presence ("active recently"), and the
// history of thoughts between you.

import SwiftUI
import MessageUI

struct PersonDetailView: View {

    let person: Person
    @EnvironmentObject var people: PeopleManager
    @EnvironmentObject var compass: CompassManager
    @EnvironmentObject var pings: PingManager
    @Environment(\.dismiss) private var dismiss

    @State private var codeInput = ""
    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var lastSeen: Date?
    @State private var showConnectOptions = false
    @State private var connectedNow = false   // refresh after in-sheet pairing
    @State private var personInvite: String?  // full message tied to THIS person
    @State private var personInviteLink: String?  // just the pair URL (copy)
    @State private var showMessageComposer = false
    @State private var linkCopied = false

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

                        // ── Thought history — expandable memory trail ─────
                        if isConnected, partnerID != nil {
                            thoughtsSection
                                .padding(.horizontal, 24)
                        }

                        // (push-style history retired for inline expand; kept)
                        if false, isConnected, let partnerID {
                            NavigationLink {
                                PingHistoryView(personName: person.name, partnerID: partnerID,
                                                bearing: compass.state.bearingDegrees)
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
        // iMessage composer for the personal invite (primary share path)
        .sheet(isPresented: $showMessageComposer) {
            MessageComposerView(body: personInvite ?? "")
        }
        // A felt receipt just landed (realtime UPDATE on our sent ping) —
        // refresh so the grey dot turns into the lavender pair live.
        .onChange(of: pings.lastFeltAt) { _, _ in
            guard let partnerID else { return }
            Task {
                historyRecords = await SupabaseService.shared.fetchPings(with: partnerID)
            }
        }
        // Replay overlay — this sheet is the visible presentation context,
        // so the full-screen replay presents from here while it's open.
        .fullScreenCover(item: $pings.replayRequest) { request in
            ZStack {
                DesignTokens.Color.background.ignoresSafeArea()
                ReplayOverlayView(
                    emoji: request.emoji,
                    bearingDegrees: request.bearingDegrees,
                    style: SenderStyle.from(request.styleRaw)
                ) {
                    pings.replayRequest = nil
                }
                VStack {
                    Spacer()
                    Text("tap to dismiss")
                        .font(.system(size: 11, design: .serif).italic())
                        .foregroundColor(DesignTokens.Color.textDim)
                        .padding(.bottom, 28)
                }
                .allowsHitTesting(false)
            }
        }
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
                if let lastSeen, let presence = Self.presenceText(for: lastSeen) {
                    Text(presence)
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
                    Text("not yet linked")
                        .font(.system(size: 13))
                        .foregroundColor(DesignTokens.Color.textMuted)
                }

                if !showConnectOptions {
                    Button {
                        withAnimation(.easeOut(duration: 0.25)) { showConnectOptions = true }
                        prepareInvite()
                    } label: {
                        Text("connect with \(person.name)")
                            .font(DesignTokens.Font.label)
                            .foregroundColor(DesignTokens.Color.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(DesignTokens.Spacing.md)
                            .background(DesignTokens.Color.accentStrong)
                            .cornerRadius(DesignTokens.Radius.button)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignTokens.Radius.button)
                                    .stroke(Color(hex: "#c4a8d4").opacity(0.5), lineWidth: 1)
                            )
                            .shadow(color: Color(hex: "#c4a8d4").opacity(0.3), radius: 8)
                    }
                } else {
                    // The invite is tied to THIS person — the code is stored
                    // with owner_person_id + name + emoji, so accepting links
                    // the right card on both sides.

                    // PRIMARY: iMessage
                    Button {
                        if MFMessageComposeViewController.canSendText(), personInvite != nil {
                            showMessageComposer = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text("📱")
                            Text("send via iMessage")
                        }
                        .font(DesignTokens.Font.label)
                        .foregroundColor(DesignTokens.Color.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(DesignTokens.Spacing.md)
                        .background(DesignTokens.Color.accentStrong)
                        .cornerRadius(DesignTokens.Radius.button)
                    }
                    .disabled(personInvite == nil || !MFMessageComposeViewController.canSendText())
                    .opacity((personInvite == nil || !MFMessageComposeViewController.canSendText()) ? 0.45 : 1)

                    // SECONDARY: anywhere else
                    ShareLink(item: personInvite ?? "") {
                        HStack(spacing: 8) {
                            Text("📤")
                            Text("share another way")
                        }
                        .font(DesignTokens.Font.label)
                        .foregroundColor(DesignTokens.Color.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(DesignTokens.Spacing.md)
                        .background(DesignTokens.Color.backgroundLift)
                        .cornerRadius(DesignTokens.Radius.button)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.button)
                                .stroke(DesignTokens.Color.borderMid, lineWidth: 1)
                        )
                    }
                    .disabled(personInvite == nil)
                    .opacity(personInvite == nil ? 0.45 : 1)

                    // Copy just the link
                    Button {
                        if let link = personInviteLink {
                            UIPasteboard.general.string = link
                            HapticEngine.personSelected()
                            withAnimation(.easeOut(duration: 0.25)) { linkCopied = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                withAnimation { linkCopied = false }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: linkCopied ? "checkmark" : "link")
                                .font(.system(size: 11))
                            Text(linkCopied ? "copied ✓" : "copy link")
                                .font(DesignTokens.Font.caption)
                        }
                        .foregroundColor(linkCopied ? Color(hex: "#5dcaa5")
                                                    : DesignTokens.Color.accentSoft)
                    }
                    .disabled(personInviteLink == nil)

                    // FALLBACK: manual code entry
                    VStack(alignment: .leading, spacing: 6) {
                        Text("or enter their code")
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

    /// Create the invite tied to this exact person (name + emoji travel
    /// with it; owner_person_id re-links the card when they accept).
    private func prepareInvite() {
        guard personInvite == nil else { return }
        guard SupabaseService.localUserID != nil else {
            errorMessage = "Sign in first (Settings → account)."
            return
        }
        isBusy = true
        errorMessage = nil
        Task {
            defer { isBusy = false }
            do {
                // Stored server-side as: owner=me, owner_person_id=this card,
                // person_name + person_emoji — acceptance links the right
                // person on both phones.
                let code = try await SupabaseService.shared.createInvite(
                    personName: person.name, personEmoji: person.emoji, personID: person.id)
                personInvite = AppLinks.personInviteMessage(personName: person.name,
                                                            code: code)
                personInviteLink = AppLinks.pairLink(code: code)
            } catch {
                errorMessage = error.localizedDescription
            }
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
                // Entering a code on THIS card is an explicit choice — the
                // claim carries this card's id as friend_person_id.
                let result = try await SupabaseService.shared.redeem(codeInput,
                                                                     friendPersonID: person.id)
                person.pairedUserID = result.ownerID.uuidString   // bind to this person
                try? people.save()
                connectedNow = true
                HapticEngine.connectionFelt()
                fetchPresence()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Expandable memory trail

    @State private var historyExpanded = false
    @State private var historyRecords: [SupabaseService.PingRecord] = []
    @State private var historyLoaded = false
    @State private var replayingID: UUID?

    private var thoughtsSection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.3)) { historyExpanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 15))
                        .foregroundColor(DesignTokens.Color.accentSoft)
                    Text(historyLoaded
                         ? "\(historyRecords.count) thought\(historyRecords.count == 1 ? "" : "s")"
                         : "thoughts")
                        .font(DesignTokens.Font.label)
                        .foregroundColor(DesignTokens.Color.textPrimary)
                    Spacer()
                    Image(systemName: historyExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Color.textDim)
                }
                .padding(DesignTokens.Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if historyExpanded {
                if historyRecords.isEmpty {
                    Text("no thoughts yet")
                        .font(.system(size: 13, design: .serif).italic())
                        .foregroundColor(DesignTokens.Color.textMuted)
                        .padding(.vertical, 16)
                } else {
                    VStack(spacing: 0) {
                        ForEach(historyRecords) { record in
                            trailRow(record)
                            if record.id != historyRecords.last?.id {
                                Rectangle()
                                    .fill(Color.white.opacity(0.10))
                                    .frame(height: 1)
                                    .padding(.leading, 52)
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .background(DesignTokens.Color.backgroundCard)
        .cornerRadius(DesignTokens.Radius.card)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.card)
                .stroke(DesignTokens.Color.border, lineWidth: 1)
        )
        .task {
            guard let partnerID else { return }
            historyRecords = await SupabaseService.shared.fetchPings(with: partnerID)
            historyLoaded = true
        }
    }

    /// Memory trail row: emoji · felt dots · poetic time. Tap for the FULL
    /// replay — the thought re-enters from its original direction (the
    /// overlay presents app-wide through PingManager.replayRequest).
    private func trailRow(_ record: SupabaseService.PingRecord) -> some View {
        let sent = record.toUser == partnerID
        return Button {
            HapticEngine.thoughtArrived()
            withAnimation(.easeOut(duration: 0.35)) { replayingID = record.id }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                withAnimation(.easeIn(duration: 0.4)) { replayingID = nil }
            }
            // Sent thoughts replay outward; received ones come back in
            // from the sender's side.
            pings.requestReplay(
                emoji: record.emoji,
                bearingDegrees: sent ? compass.state.bearingDegrees
                                     : compass.state.bearingDegrees + 180,
                styleRaw: record.senderStyle
            )
        } label: {
            HStack(spacing: 14) {
                Text(record.emoji)
                    .font(.system(size: 28))
                    .frame(width: 38)
                    .scaleEffect(replayingID == record.id ? 1.25 : 1.0)
                if sent {
                    feltDots(felt: record.openedAt != nil)
                }
                Spacer()
                Text(PoeticTime.string(for: record.createdAt))
                    .font(.system(size: 12, design: .serif).italic())
                    .foregroundColor(DesignTokens.Color.textMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Read receipt, quiet as a journal margin:
    ///   one grey dot      · sent, not yet felt
    ///   two lavender dots · felt
    @ViewBuilder
    private func feltDots(felt: Bool) -> some View {
        if felt {
            HStack(spacing: 3) {
                Circle().fill(Color(hex: "#c4a8d4")).frame(width: 5, height: 5)
                Circle().fill(Color(hex: "#c4a8d4")).frame(width: 5, height: 5)
            }
        } else {
            Circle()
                .fill(DesignTokens.Color.textDim.opacity(0.5))
                .frame(width: 5, height: 5)
        }
    }

    private func fetchPresence() {
        guard isConnected, let partnerID else { return }
        Task {
            lastSeen = await SupabaseService.shared.fetchLastSeen(of: partnerID)
        }
    }

    /// Presence in poetic buckets — nothing shown beyond a week:
    ///   < 1 hour        "active recently"
    ///   today           "last seen this morning/afternoon/evening"
    ///   yesterday       "last seen yesterday"
    ///   this week       "last seen Tuesday"
    ///   older           nil (the card stays quiet)
    static func presenceText(for date: Date) -> String? {
        let calendar = Calendar.current
        if Date.now.timeIntervalSince(date) < 3600 { return "active recently" }
        if calendar.isDateInToday(date) {
            switch calendar.component(.hour, from: date) {
            case ..<12:  return "last seen this morning"
            case ..<18:  return "last seen this afternoon"
            default:     return "last seen this evening"
            }
        }
        if calendar.isDateInYesterday(date) { return "last seen yesterday" }
        if Date.now.timeIntervalSince(date) < 7 * 86400 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return "last seen \(formatter.string(from: date))"
        }
        return nil
    }
}

// MARK: - Memory trail

/// The history of thoughts between you — an emotional archive, not a chat.
/// No bubbles, no cards. Quiet rows, hairline separators, poetic time.
/// Tap a row to feel that thought again.
struct PingHistoryView: View {

    let personName: String
    let partnerID: UUID
    /// The current bearing toward this person, for the tiny needle marks.
    var bearing: Double = 0

    @State private var records: [SupabaseService.PingRecord] = []
    @State private var loaded = false
    @State private var replayingID: UUID?   // brief swell on tapped row
    /// Full replay — the thought re-enters from its original direction.
    @State private var replayRecord: SupabaseService.PingRecord?

    @EnvironmentObject var appState: AppStateManager
    @EnvironmentObject var subscription: SubscriptionManager
    @EnvironmentObject var pings: PingManager

    private static let lavender = Color(red: 196/255, green: 168/255, blue: 212/255)

    var body: some View {
        ZStack {
            DesignTokens.Color.background.ignoresSafeArea()

            if !loaded {
                ProgressView().tint(DesignTokens.Color.accentSoft)
            } else if records.isEmpty {
                Text("the needle is ready · send your first thought")
                    .font(.system(size: 14, design: .serif).italic())
                    .foregroundColor(DesignTokens.Color.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(records) { record in
                            row(record)
                            if record.id != records.last?.id {
                                Rectangle()
                                    .fill(Color.white.opacity(0.10))
                                    .frame(height: 1)
                                    .padding(.leading, 52)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
            }
            // ── REPLAY — a memory, not a new message ─────────────────────
            // 30 % dim, original direction, compressed duration,
            // easeInOutQuad throughout.
            if let record = replayRecord {
                let sent = record.toUser == partnerID
                ReplayOverlayView(
                    emoji: record.emoji,
                    bearingDegrees: sent ? bearing : bearing + 180,
                    // The ORIGINAL sender style from the record — a memory
                    // replays the way it first arrived (glow when unknown)
                    style: SenderStyle.from(record.senderStyle)
                ) {
                    replayRecord = nil
                    appState.transition(to: .idle)
                }
                .zIndex(5)
            }
        }
        .navigationTitle("thoughts with \(personName)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            records = await SupabaseService.shared.fetchPings(with: partnerID)
            loaded = true
        }
        // Felt receipt landed while we're looking — dots update live
        .onChange(of: pings.lastFeltAt) { _, _ in
            Task {
                records = await SupabaseService.shared.fetchPings(with: partnerID)
            }
        }
    }

    private func row(_ record: SupabaseService.PingRecord) -> some View {
        let sent = record.toUser == partnerID
        return Button {
            replay(record)
        } label: {
            HStack(spacing: 14) {
                // The thought, floating quietly on the left
                Text(record.emoji)
                    .font(.system(size: 28))
                    .frame(width: 38)
                    .scaleEffect(replayingID == record.id ? 1.25 : 1.0)

                // Tiny compass needle — the direction it traveled
                Image(systemName: "location.north.fill")
                    .font(.system(size: 8))
                    .foregroundColor(DesignTokens.Color.textDim.opacity(0.7))
                    .rotationEffect(.degrees(sent ? bearing : bearing + 180))

                // Felt indicator — soft dots, never a tick
                //   one grey dot      · sent, waiting
                //   two lavender dots · felt
                if sent {
                    if record.openedAt != nil {
                        HStack(spacing: 3) {
                            Circle().fill(Self.lavender).frame(width: 5, height: 5)
                            Circle().fill(Self.lavender).frame(width: 5, height: 5)
                        }
                    } else {
                        Circle()
                            .fill(DesignTokens.Color.textDim.opacity(0.5))
                            .frame(width: 5, height: 5)
                    }
                }

                Spacer()

                // Poetic time, right-aligned — a journal, not a log
                Text(PoeticTime.string(for: record.createdAt))
                    .font(.system(size: 12, design: .serif).italic())
                    .foregroundColor(DesignTokens.Color.textMuted)
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Tap to feel again — the full replay: background dims, the thought
    /// re-enters from its original direction and blooms at center.
    /// NEVER interrupts catch mode (the state machine refuses).
    private func replay(_ record: SupabaseService.PingRecord) {
        guard appState.transition(to: .replay) else { return }
        // The row acknowledges the touch with a brief swell
        withAnimation(.easeOut(duration: 0.35)) { replayingID = record.id }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.easeIn(duration: 0.4)) { replayingID = nil }
        }
        // App-wide replay: the local sheet-bound overlay never showed over
        // the People tab. Close the whole detail sheet (notification — this
        // view is nav-pushed inside it), then play full screen above all.
        // replayRecord = record   // (local presentation retired)
        let emoji = record.emoji
        let style = record.senderStyle
        let storedBearing = bearing
        NotificationCenter.default.post(name: .pointwardCloseSheetsForReplay, object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            pings.requestReplay(emoji: emoji, bearingDegrees: storedBearing, styleRaw: style)
        }
    }
}
