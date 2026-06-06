// HapticEngine.swift
// HomeLink › DesignSystem

import UIKit

enum HapticEngine {

    private static var isQuiet: Bool {
        UserDefaults.standard.bool(forKey: "quietMode")
    }
    private static var hapticsEnabled: Bool {
        UserDefaults.standard.bool(forKey: "hapticsEnabled")
    }

    static func connectionFelt() {
        guard hapticsEnabled else { return }
        let intensity: CGFloat = isQuiet ? 0.35 : 0.65
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: intensity)
    }

    static func pingSent() {
        guard hapticsEnabled else { return }
        if isQuiet {
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.4)
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    static func pingReceived() {
        guard hapticsEnabled else { return }
        let gen = UIImpactFeedbackGenerator(style: .soft)
        let i1: CGFloat = isQuiet ? 0.45 : 0.85
        let i2: CGFloat = isQuiet ? 0.25 : 0.5
        gen.impactOccurred(intensity: i1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            gen.impactOccurred(intensity: i2)
        }
    }

    static func paywallReached() {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: isQuiet ? 0.25 : 0.45)
    }

    static func skinSelected() {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: isQuiet ? 0.3 : 0.55)
    }

    static func saved() {
        guard hapticsEnabled else { return }
        if isQuiet {
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.4)
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    static func destructive() {
        guard hapticsEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
