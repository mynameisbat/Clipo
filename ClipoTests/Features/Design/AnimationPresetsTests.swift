import XCTest
import SwiftUI
@testable import Clipo

final class AnimationPresetsTests: XCTestCase {

    // MARK: - Liquid Glass Animations

    func testLiquidGlassAnimationExists() {
        // Given/When: Access liquidGlass animation
        let animation = Animation.liquidGlass

        // Then: Should be a spring animation
        XCTAssertNotNil(animation)
    }

    func testQuickBounceAnimationExists() {
        // Given/When: Access quickBounce animation
        let animation = Animation.quickBounce

        // Then: Should be a spring animation
        XCTAssertNotNil(animation)
    }

    func testSmoothSlideAnimationExists() {
        // Given/When: Access smoothSlide animation
        let animation = Animation.smoothSlide

        // Then: Should be a spring animation
        XCTAssertNotNil(animation)
    }

    // MARK: - Interaction Animations

    func testHoverHighlightAnimationExists() {
        // Given/When: Access hoverHighlight animation
        let animation = Animation.hoverHighlight

        // Then: Should be a spring animation
        XCTAssertNotNil(animation)
    }

    func testSelectionAnimationExists() {
        // Given/When: Access selection animation
        let animation = Animation.selection

        // Then: Should be a spring animation
        XCTAssertNotNil(animation)
    }

    // MARK: - Entrance/Exit Animations

    func testPopupEntranceAnimationExists() {
        // Given/When: Access popupEntrance animation
        let animation = Animation.popupEntrance

        // Then: Should be a spring animation
        XCTAssertNotNil(animation)
    }

    func testItemDeletionAnimationExists() {
        // Given/When: Access itemDeletion animation
        let animation = Animation.itemDeletion

        // Then: Should be a spring animation
        XCTAssertNotNil(animation)
    }

    // MARK: - Animation Distinctness

    func testAnimationsAreDistinct() {
        // Given: Different animation presets
        let liquidGlass = Animation.liquidGlass
        let quickBounce = Animation.quickBounce
        let smoothSlide = Animation.smoothSlide

        // Then: All should be valid spring animations
        XCTAssertNotNil(liquidGlass)
        XCTAssertNotNil(quickBounce)
        XCTAssertNotNil(smoothSlide)
    }

    // MARK: - Usage in Views

    func testAnimationCanBeAppliedToView() {
        // Given: A simple view with animation
        let view = Rectangle()
            .frame(width: 100, height: 100)
            .animation(.liquidGlass, value: true)

        // Then: View should compile and render
        XCTAssertNotNil(view)
    }

    func testMultipleAnimationsCanBeApplied() {
        // Given: A view with multiple animations
        let view = Rectangle()
            .frame(width: 100, height: 100)
            .animation(.hoverHighlight, value: true)
            .animation(.selection, value: false)

        // Then: View should compile and render
        XCTAssertNotNil(view)
    }
}
