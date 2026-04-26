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

    func testShowPastePickerUsesAnchoredPresentationWithoutToggle() async {
        let presenter = PopupPresenterSpy()
        let controller = MenuBarController(panelController: presenter)

        await controller.showPastePicker()

        XCTAssertEqual(presenter.presentRelativeToViewCalls, 1)
        XCTAssertEqual(presenter.toggleRelativeToViewCalls, 0)
    }

    func testTogglePopoverNearCursorUsesUnanchoredPresentation() async {
        let presenter = PopupPresenterSpy()
        let controller = MenuBarController(panelController: presenter)

        await controller.togglePopoverNearCursor()

        XCTAssertEqual(presenter.toggleCalls, 1)
        XCTAssertEqual(presenter.toggleRelativeToViewCalls, 0)
    }

    func testShowPastePickerNearCursorUsesUnanchoredPresentation() async {
        let presenter = PopupPresenterSpy()
        let controller = MenuBarController(panelController: presenter)

        await controller.showPastePickerNearCursor()

        XCTAssertEqual(presenter.presentRelativeToViewCalls, 1)
        XCTAssertNil(presenter.lastPresentedView)
    }
}

@MainActor
private final class PopupPresenterSpy: ClipboardPopupPresenting {
    private(set) var toggleCalls = 0
    private(set) var toggleRelativeToViewCalls = 0
    private(set) var presentRelativeToViewCalls = 0
    private(set) var lastPresentedView: NSView?

    func toggle() async {
        toggleCalls += 1
    }

    func toggle(relativeTo positioningView: NSView?) async {
        toggleRelativeToViewCalls += 1
    }

    func present(relativeTo positioningView: NSView?) async {
        presentRelativeToViewCalls += 1
        lastPresentedView = positioningView
    }
}
