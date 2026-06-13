import SwiftUI

enum DT {
    enum Color {
        static let surface = SwiftUI.Color(red: 0.04, green: 0.07, blue: 0.12)
        static let surfaceElevated = SwiftUI.Color(red: 0.06, green: 0.09, blue: 0.16)
        static let stroke = SwiftUI.Color.white.opacity(0.08)
        static let textPrimary = SwiftUI.Color(red: 0.94, green: 0.96, blue: 0.98)
        static let textSecondary = SwiftUI.Color(red: 0.58, green: 0.64, blue: 0.72)
        static let accent = SwiftUI.Color(red: 0.08, green: 0.72, blue: 0.65)
        static let accentMuted = accent.opacity(0.16)
        static let warning = SwiftUI.Color(red: 0.98, green: 0.78, blue: 0.20)
        static let danger = SwiftUI.Color(red: 0.96, green: 0.42, blue: 0.42)
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
