import SwiftUI

extension Animation {
    static let liquidGlass = Animation.spring(
        response: 0.3,
        dampingFraction: 0.8,
        blendDuration: 0.15
    )

    static let quickBounce = Animation.spring(
        response: 0.25,
        dampingFraction: 0.7
    )

    static let smoothSlide = Animation.spring(
        response: 0.35,
        dampingFraction: 0.9
    )

    static let hoverHighlight = Animation.spring(
        response: 0.25,
        dampingFraction: 0.7
    )

    static let selection = Animation.spring(
        response: 0.28,
        dampingFraction: 0.75
    )

    static let popupEntrance = Animation.spring(
        response: 0.32,
        dampingFraction: 0.85
    )

    static let itemDeletion = Animation.spring(
        response: 0.22,
        dampingFraction: 0.92
    )

    static let quickFeedback = Animation.spring(
        response: 0.18,
        dampingFraction: 0.85
    )
}
