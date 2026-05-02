import XCTest
import AppKit
import SwiftUI
@testable import Clipo

@MainActor
final class VisualEffectViewTests: XCTestCase {

    // MARK: - Initialization

    func testDefaultInitialization() {
        // Given/When: Create view with defaults
        let view = VisualEffectView()

        // Then: Should have default properties
        XCTAssertEqual(view.material, .hudWindow)
        XCTAssertEqual(view.blendingMode, .behindWindow)
    }

    func testCustomMaterialInitialization() {
        // Given/When: Create view with custom material
        let view = VisualEffectView(material: .popover, blendingMode: .withinWindow)

        // Then: Should use specified material and blending
        XCTAssertEqual(view.material, .popover)
        XCTAssertEqual(view.blendingMode, .withinWindow)
    }

    // MARK: - NSView Creation

    func testMakeNSViewCreatesVisualEffectView() {
        // Given: View with specific material
        let view = VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)

        // When: Create NSView (using a mock context)
        let nsView = NSVisualEffectView()
        nsView.material = view.material
        nsView.blendingMode = view.blendingMode
        nsView.state = .active

        // Then: NSView should have correct properties
        XCTAssertEqual(nsView.material, .hudWindow)
        XCTAssertEqual(nsView.blendingMode, .behindWindow)
        XCTAssertEqual(nsView.state, .active)
    }

    func testUpdateNSViewUpdatesProperties() {
        // Given: NSView with initial properties
        let nsView = NSVisualEffectView()
        nsView.material = .hudWindow
        nsView.blendingMode = .behindWindow

        // When: Update with different material
        let updatedView = VisualEffectView(material: .popover, blendingMode: .withinWindow)
        nsView.material = updatedView.material
        nsView.blendingMode = updatedView.blendingMode

        // Then: NSView should reflect new material
        XCTAssertEqual(nsView.material, .popover)
        XCTAssertEqual(nsView.blendingMode, .withinWindow)
    }
}
