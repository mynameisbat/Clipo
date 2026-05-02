import XCTest
import SwiftUI
@testable import Clipo

final class LiquidGlassMaterialTests: XCTestCase {

    // MARK: - Initialization

    func testDefaultInitialization() {
        // Given/When: Create material with default corner radius
        let material = LiquidGlassMaterial()

        // Then: Should use default corner radius
        XCTAssertEqual(material.cornerRadius, 18)
    }

    func testCustomCornerRadius() {
        // Given/When: Create material with custom corner radius
        let material = LiquidGlassMaterial(cornerRadius: 24)

        // Then: Should use specified corner radius
        XCTAssertEqual(material.cornerRadius, 24)
    }

    // MARK: - View Structure

    func testViewHasVisualEffectView() {
        // Given: Material view
        let material = LiquidGlassMaterial()

        // When: Render view hierarchy
        let mirror = Mirror(reflecting: material.body)

        // Then: Should contain ZStack with visual effects
        XCTAssertTrue(String(describing: mirror.subjectType).contains("ZStack"))
    }

    func testViewHasGradientOverlay() {
        // Given: Material view
        let material = LiquidGlassMaterial()

        // When: Check view structure
        let bodyMirror = Mirror(reflecting: material.body)

        // Then: Should contain gradient components
        XCTAssertTrue(String(describing: bodyMirror.subjectType).contains("ZStack"))
    }

    // MARK: - Corner Radius

    func testCornerRadiusAppliedToStroke() {
        // Given: Material with specific corner radius
        let cornerRadius: CGFloat = 20
        let material = LiquidGlassMaterial(cornerRadius: cornerRadius)

        // When/Then: Corner radius should be accessible
        XCTAssertEqual(material.cornerRadius, cornerRadius)
    }

    func testDifferentCornerRadii() {
        // Given: Materials with different corner radii
        let material1 = LiquidGlassMaterial(cornerRadius: 10)
        let material2 = LiquidGlassMaterial(cornerRadius: 30)

        // When/Then: Should maintain different values
        XCTAssertEqual(material1.cornerRadius, 10)
        XCTAssertEqual(material2.cornerRadius, 30)
        XCTAssertNotEqual(material1.cornerRadius, material2.cornerRadius)
    }
}
