// DesignTokens.swift
// HomeLink › DesignSystem

import SwiftUI

enum DesignTokens {

    // MARK: - Colors
    enum Color {
        static let background      = SwiftUI.Color(hex: "#0d0d14")
        static let backgroundCard  = SwiftUI.Color(hex: "#1e1828")
        static let backgroundLift  = SwiftUI.Color(hex: "#2a2040")
        static let border          = SwiftUI.Color(hex: "#3a3050")
        static let borderMid       = SwiftUI.Color(hex: "#5a4870")

        static let textPrimary     = SwiftUI.Color(hex: "#e8e0f0")
        static let textSecondary   = SwiftUI.Color(hex: "#9b8fa8")
        static let textMuted       = SwiftUI.Color(hex: "#6b5f7a")
        static let textDim         = SwiftUI.Color(hex: "#4a3860")

        static let accentSoft      = SwiftUI.Color(hex: "#c4a8d4")
        static let accentMid       = SwiftUI.Color(hex: "#7c6b8e")
        static let accentStrong    = SwiftUI.Color(hex: "#3a2e50")

        static let pingGlow        = SwiftUI.Color(hex: "#7c6b8e")
        static let successGreen    = SwiftUI.Color(hex: "#5dcaa5")
        static let warmAmber       = SwiftUI.Color(hex: "#c4845a")
    }

    // MARK: - Typography
    enum Font {
        static let compassName     = SwiftUI.Font.system(size: 22, weight: .medium, design: .rounded)
        static let compassDistance = SwiftUI.Font.system(size: 13, weight: .regular, design: .rounded)
        static let label           = SwiftUI.Font.system(size: 14, weight: .medium)
        static let caption         = SwiftUI.Font.system(size: 11, weight: .regular)
        static let overline        = SwiftUI.Font.system(size: 10, weight: .regular)
            .uppercaseSmallCaps()
    }

    // MARK: - Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 40
    }

    // MARK: - Corner radius
    enum Radius {
        static let card:   CGFloat = 20
        static let button: CGFloat = 12
        static let pill:   CGFloat = 100
    }
}

// MARK: - Color hex init
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int & 0xFF)          / 255
        self.init(red: r, green: g, blue: b)
    }
}
