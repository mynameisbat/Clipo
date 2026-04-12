import AppKit
import XCTest
@testable import Clipo

@MainActor
final class MenuBarControllerTests: XCTestCase {
    func testTogglePopoverUsesAnchoredPresentation() async {
        let presenter = PopupPresenterSpy()
        let controller = MenuBarController(panelController: presenter)

        await controller.togglePopover()

        XCTAssertEqual(presenter.toggleRelativeToViewCalls, 1)
        XCTAssertEqual(presenter.toggleCalls, 0)
    }
}

@MainActor
private final class PopupPresenterSpy: ClipboardPopupPresenting {
    private(set) var toggleCalls = 0
    private(set) var toggleRelativeToViewCalls = 0

    func toggle() async {
        toggleCalls += 1
    }

    func toggle(relativeTo positioningView: NSView?) async {
        toggleRelativeToViewCalls += 1
    }
}
