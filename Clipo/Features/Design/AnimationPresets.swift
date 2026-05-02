import SwiftUI

extension Animation {
    // MARK: - Liquid Glass Animations

    /// Primary animation for Liquid Glass material transitions
    /// Response: 0.4s, Damping: 0.75 (smooth with subtle bounce)
    static let liquidGlass = Animation.spring(
        response: 0.4,
        dampingFraction: 0.75,
        blendDuration: 0.2
    )

    /// Quick bounce animation for interactive elements
    /// Response: 0.3s, Damping: 0.6 (more pronounced bounce)
    static let quickBounce = Animation.spring(
        response: 0.3,
        dampingFraction: 0.6
    )

    /// Smooth slide animation for list items and panels
    /// Response: 0.5s, Damping: 0.85 (very smooth, minimal bounce)
    static let smoothSlide = Animation.spring(
        response: 0.5,
        dampingFraction: 0.85
    )

    // MARK: - Interaction Animations

    /// Hover animation for row highlights
    /// Response: 0.25s, Damping: 0.7 (snappy and responsive)
    static let hoverHighlight = Animation.spring(
        response: 0.25,
        dampingFraction: 0.7
    )

    /// Selection animation for active items
    /// Response: 0.35s, Damping: 0.65 (balanced bounce)
    static let selection = Animation.spring(
        response: 0.35,
        dampingFraction: 0.65
    )

    // MARK: - Entrance/Exit Animations

    /// Popup entrance animation (scale + opacity)
    /// Response: 0.45s, Damping: 0.8 (smooth entrance)
    static let popupEntrance = Animation.spring(
        response: 0.45,
        dampingFraction: 0.8
    )

    /// Item deletion animation (slide out + fade)
    /// Response: 0.3s, Damping: 0.9 (quick and smooth exit)
    static let itemDeletion = Animation.spring(
        response: 0.3,
        dampingFraction: 0.9
    )
}
