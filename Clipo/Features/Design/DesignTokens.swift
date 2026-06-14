import SwiftUI

enum DT {
    enum Color {
        static let surface = SwiftUI.Color(red: 0.043, green: 0.047, blue: 0.063) // Deep graphite/slate
        static let surfaceElevated = SwiftUI.Color(red: 0.075, green: 0.078, blue: 0.11) // Soft elevated slate
        static let stroke = SwiftUI.Color.white.opacity(0.06) // Refined thin stroke
        static let textPrimary = SwiftUI.Color(red: 0.945, green: 0.953, blue: 0.961) // Crisp off-white
        static let textSecondary = SwiftUI.Color(red: 0.557, green: 0.584, blue: 0.647) // Muted graphite gray
        static let accent = SwiftUI.Color(red: 0.00, green: 0.86, blue: 0.51) // Premium Emerald Mint
        static let accentMuted = accent.opacity(0.12) // Subtle tint highlight
        static let warning = SwiftUI.Color(red: 0.98, green: 0.64, blue: 0.18) // Warm amber warning
        static let danger = SwiftUI.Color(red: 0.96, green: 0.31, blue: 0.31) // Rose danger
    }

    enum Radius {
        static let xs: CGFloat = 6
        static let s: CGFloat = 8
        static let m: CGFloat = 10
        static let l: CGFloat = 14
        static let xl: CGFloat = 18
        static let panel: CGFloat = 20
    }

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 6
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }
}
