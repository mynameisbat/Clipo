import XCTest
import AppKit
@testable import Clipo

@MainActor
final class CaptureTests: XCTestCase {
    
    func testCaptureOverlayWindowIsReleasedWhenClosedIsFalse() {
        // Given
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let image = NSImage(size: NSSize(width: 100, height: 100))
        
        // When
        let window = CaptureOverlayWindow(
            screen: screen,
            screenImage: image,
            windows: [],
            mode: .image,
            onCaptured: { _ in },
            onRecordStart: { _, _, _ in },
            onCancel: {}
        )
        
        // Then
        XCTAssertFalse(window.isReleasedWhenClosed, "CaptureOverlayWindow must set isReleasedWhenClosed to false to prevent use-after-free crashes when closed.")
    }
}
