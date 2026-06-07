// AppStateManager.swift
// Pointward › Managers
//
// One state at a time. Animations queue, never overlap.
//
//   Rules:
//     · catchMode outranks sending — an arriving thought owns the screen
//     · replay NEVER interrupts catch mode
//     · sender confirmation never interrupts sending (it queues)
//     · animationLock blocks everything until released
//     · transitions back to idle drain the queued animations, in order

import Foundation
import Combine

enum AppState: String {
    case idle
    case sending
    case catchMode
    case replay
    case historyView
    case animationLock
    case transitioning
}

@MainActor
final class AppStateManager: ObservableObject {

    @Published private(set) var currentState: AppState = .idle

    /// Animations waiting for the screen to be free again — FIFO.
    private var animationQueue: [() -> Void] = []

    // ── Priority ladder — higher never yields to lower ───────────────────
    private func priority(of state: AppState) -> Int {
        switch state {
        case .idle:          return 0
        case .historyView:   return 1
        case .replay:        return 2   // replay never interrupts catch
        case .sending:       return 3
        case .transitioning: return 4
        case .catchMode:     return 5   // catchMode > sending
        case .animationLock: return 6
        }
    }

    func canTransition(to state: AppState) -> Bool {
        if state == currentState { return true }
        // Returning to rest is always allowed — it releases the screen.
        if state == .idle { return true }
        // Nothing pre-empts an animation lock except its own release.
        if currentState == .animationLock { return false }
        // A higher-priority moment may take over; equal/lower must wait.
        return priority(of: state) > priority(of: currentState)
    }

    /// Enforces the rules above. Returns whether the transition happened —
    /// callers that get `false` should queue (queueAnimation) or drop.
    @discardableResult
    func transition(to state: AppState) -> Bool {
        guard canTransition(to: state) else { return false }
        currentState = state
        if state == .idle { drainQueue() }
        return true
    }

    /// Runs immediately when the screen is free, otherwise waits its turn.
    /// Queued animations fire (FIFO) when the state returns to idle.
    func queueAnimation(_ animation: @escaping () -> Void) {
        if currentState == .idle {
            animation()
        } else {
            animationQueue.append(animation)
        }
    }

    private func drainQueue() {
        guard !animationQueue.isEmpty else { return }
        let pending = animationQueue
        animationQueue.removeAll()
        for animation in pending {
            animation()
        }
    }
}
