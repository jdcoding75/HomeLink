// AnimationSystem.swift
// HomeLink › DesignSystem

import SwiftUI

enum AnimationSystem {

    // MARK: - Needle
    static let needleSettle = Animation.spring(
        response: 0.8, dampingFraction: 0.55, blendDuration: 0.2
    )
    static let needleSettleQuiet = Animation.spring(
        response: 1.4, dampingFraction: 0.75, blendDuration: 0.3
    )
    static let needleAmbient = Animation.easeInOut(duration: 5)
        .repeatForever(autoreverses: true)

    // MARK: - Breathing ring
    static let ringBreath = Animation.easeInOut(duration: 4)
        .repeatForever(autoreverses: true)
    static let ringBreathQuiet = Animation.easeInOut(duration: 8)
        .repeatForever(autoreverses: true)

    // MARK: - Ping events
    static let pingPulse = Animation.spring(response: 0.6, dampingFraction: 0.4)
    static let pingBurst = Animation.spring(response: 0.5, dampingFraction: 0.5)
    static let pingGlow  = Animation.easeInOut(duration: 0.4)

    // MARK: - Compass lock moment
    static let lockPop = Animation.spring(response: 0.45, dampingFraction: 0.45)

    // MARK: - Navigation and UI
    static let softAppear       = Animation.easeOut(duration: 0.35)
    static let buttonPress      = Animation.spring(response: 0.25, dampingFraction: 0.7)
    static let sheetAppear      = Animation.spring(response: 0.5, dampingFraction: 0.8)
    static let taglineTransition = Animation.easeOut(duration: 0.4)
}
