// LiveArrivalView.swift
// Pointward › Views
//
// [live-arrival-fix] The LIVE receive experience — forward-only, tap-to-advance, ONE envelope at a
// time (like opening mail one at a time). Plays the FULL arrival (ArrivalSequenceView → ReceiptView
// → EmojiRevealView) for the current `nowPlaying` thought, then RESTS with controls:
//   • more queued behind it → Next + Delete
//   • last / only one        → Done + Delete
// No Prev/back, no auto-dismiss, no auto-advance, and no instant-reveal downgrade — that downgrade
// is the HISTORY ReplaySwipeContainer's snappy-browse choice; this forward-only flow never uses it,
// so every live thought plays its full arrival. The history container + the /m PendingLink path are
// untouched.

import SwiftUI

struct LiveArrivalView: View {
    let playing: PingManager.ReceivedPing

    @EnvironmentObject private var pings:    PingManager
    @EnvironmentObject private var compass:  CompassManager
    @EnvironmentObject private var people:   PeopleManager
    @EnvironmentObject private var appState: AppStateManager

    @State private var rested = false

    private var moreQueued: Bool { !pings.queue.isEmpty }

    var body: some View {
        ZStack {
            ArrivalSequenceView(
                arrival:    Arrival(ping: playing,
                                    senderBearing: compass.rawBearingToTarget ?? 120),
                beatFloor:  1.6,
                earlyName:  playing.fromName,
                onOpened:   { pings.markOpened(playing) },   // lands in received history = "kept by default"
                onFinished: { withAnimation(.easeIn(duration: 0.3)) { rested = true } }   // REST — no dismiss/advance
            )
            .id(playing.id)

            if rested {
                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        ctl("trash", "Delete") {
                            pings.removeFromHistory(id: playing.remoteID ?? playing.id)
                            advanceOrClose()
                        }
                        if moreQueued {
                            ctl("chevron.right", "Next") { pings.playNext() }   // → new nowPlaying → its own full arrival
                        } else {
                            ctl("checkmark", "Done") { close() }
                        }
                    }
                    .padding(.bottom, 40)
                }
                .transition(.opacity)
            }
        }
        // Catch-mode + aim-at-sender — moved verbatim from the old inline cover.
        .onAppear {
            appState.transition(to: .catchMode)
            if let sender = people.people.first(where: { $0.name == playing.fromName }),
               people.selectedPerson?.id != sender.id {
                people.select(sender)
                compass.start(tracking: sender)
            }
        }
    }

    private func advanceOrClose() { if moreQueued { pings.playNext() } else { close() } }
    private func close() { pings.finishedPlaying(playing); appState.transition(to: .idle) }

    private func ctl(_ icon: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 20))
                Text(label).font(.system(size: 12, design: .serif))
            }
            .foregroundColor(DesignTokens.Color.textPrimary)
            .frame(width: 78, height: 64)
            .background(DesignTokens.Color.backgroundCard)
            .cornerRadius(DesignTokens.Radius.card)
            .overlay(RoundedRectangle(cornerRadius: DesignTokens.Radius.card)
                .stroke(DesignTokens.Color.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
