import AppKit
import XCTest
@testable import Clipo

@MainActor
final class ClipboardPanelControllerTests: XCTestCase {
    func testAnchoredStyleUsesNativePopoverBackground() {
        XCTAssertTrue(ClipboardPopupStyle.anchoredToMenuBar.usesNativePopoverBackground)
        XCTAssertFalse(ClipboardPopupStyle.nearCursor.usesNativePopoverBackground)
    }

    func testShortcutActionRecognizesToggleShortcut() {
        let controller = makeController()
        let event = makeKeyEvent(keyCode: UInt16(ShortcutName.togglePopup.defaultShortcut?.carbonKeyCode ?? 0), modifiers: [.command, .shift])

        XCTAssertEqual(controller.shortcutAction(for: event), .toggle)
    }

    func testShortcutActionRecognizesPastePickerShortcut() {
        let controller = makeController()
        let event = makeKeyEvent(keyCode: UInt16(ShortcutName.openPastePicker.defaultShortcut?.carbonKeyCode ?? 0), modifiers: [.command, .option])

        XCTAssertEqual(controller.shortcutAction(for: event), .present)
    }

    func testShortcutActionRecognizesScreenExtensionToggleShortcut() {
        let controller = makeController()
        let event = makeKeyEvent(keyCode: UInt16(ShortcutName.screenExtensionTogglePopup.defaultShortcut?.carbonKeyCode ?? 0), modifiers: [.control, .option])

        XCTAssertEqual(controller.shortcutAction(for: event), .toggle)
    }

    func testShortcutActionRecognizesScreenExtensionPastePickerShortcut() {
        let controller = makeController()
        let event = makeKeyEvent(keyCode: UInt16(ShortcutName.screenExtensionOpenPastePicker.defaultShortcut?.carbonKeyCode ?? 0), modifiers: [.control, .option, .shift])

        XCTAssertEqual(controller.shortcutAction(for: event), .present)
    }

    func testShortcutActionIgnoresNonMatchingShortcut() {
        let controller = makeController()
        let event = makeKeyEvent(keyCode: 0, modifiers: [.command])

        XCTAssertNil(controller.shortcutAction(for: event))
    }

    func testFloatingPanelFrameUsesPopupContentSize() {
        let controller = makeController()

        let frame = controller.floatingPanelFrame(
            near: NSPoint(x: 600, y: 600),
            visibleFrame: NSRect(x: 0, y: 0, width: 1200, height: 900)
        )

        XCTAssertEqual(frame.size, NSSize(width: 420, height: 500))
    }

    func testToggleStartsOutsideClickMonitoringWhenPanelIsShown() async {
        let panelWindow = ClipboardPanelWindowSpy()
        let monitor = OutsideClickMonitorSpy()
        let scheduler = DeferredActionSchedulerSpy()
        let controller = makeController(
            panelWindow: panelWindow,
            outsideClickMonitor: monitor,
            scheduleOutsideClickMonitoring: scheduler.schedule(action:)
        )

        await controller.toggle()

        XCTAssertEqual(panelWindow.showCalls, 1)
        XCTAssertEqual(panelWindow.activateCalls, 1)
        XCTAssertEqual(monitor.startCalls, 0)
        XCTAssertEqual(scheduler.scheduleCalls, 1)

        scheduler.runScheduledAction()

        XCTAssertEqual(monitor.startCalls, 1)
        XCTAssertNotNil(monitor.handler)
    }

    func testOutsideClickClosesPanel() async {
        let panelWindow = ClipboardPanelWindowSpy()
        let monitor = OutsideClickMonitorSpy()
        let controller = makeController(panelWindow: panelWindow, outsideClickMonitor: monitor)

        await controller.toggle()
        monitor.handler?(NSPoint(x: 20, y: 20))

        XCTAssertEqual(panelWindow.closeCalls, 1)
        XCTAssertEqual(monitor.stopCalls, 1)
    }

    func testInsideClickKeepsPanelOpen() async throws {
        let panelWindow = ClipboardPanelWindowSpy()
        let monitor = OutsideClickMonitorSpy()
        let controller = makeController(panelWindow: panelWindow, outsideClickMonitor: monitor)

        await controller.toggle()
        let frame = try XCTUnwrap(panelWindow.frame)
        monitor.handler?(NSPoint(x: frame.midX, y: frame.midY))

        XCTAssertEqual(panelWindow.closeCalls, 0)
        XCTAssertEqual(monitor.stopCalls, 0)
    }

    func testAnchoredFloatingPanelFrameCentersBelowAnchor() {
        let controller = makeController()
        let visibleFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let anchor = NSRect(x: 700, y: 870, width: 28, height: 24)

        let frame = controller.floatingPanelFrame(anchoredTo: anchor, visibleFrame: visibleFrame)

        XCTAssertEqual(frame.midX, anchor.midX)
        XCTAssertLessThan(frame.maxY, anchor.minY)
        XCTAssertEqual(frame.size, NSSize(width: 420, height: 500))
    }

    func testFloatingPanelFrameStaysInsideExternalScreenVisibleFrame() {
        let controller = makeController()
        let visibleFrame = NSRect(x: -1920, y: 0, width: 1920, height: 1080)

        let frame = controller.floatingPanelFrame(
            near: NSPoint(x: -20, y: 40),
            visibleFrame: visibleFrame
        )

        XCTAssertGreaterThanOrEqual(frame.minX, visibleFrame.minX + 8)
        XCTAssertLessThanOrEqual(frame.maxX, visibleFrame.maxX - 8)
        XCTAssertGreaterThanOrEqual(frame.minY, visibleFrame.minY + 8)
        XCTAssertLessThanOrEqual(frame.maxY, visibleFrame.maxY - 8)
    }

    private func makeController(
        panelWindow: any ClipboardPanelWindowManaging = ClipboardPanelWindowSpy(),
        outsideClickMonitor: OutsideClickMonitoring = OutsideClickMonitorSpy(),
        scheduleOutsideClickMonitoring: @escaping (@escaping @MainActor () -> Void) -> Void = { action in action() }
    ) -> ClipboardPanelController {
        let viewModel = ClipboardPopupViewModel(
            historyStore: InMemoryClipboardHistoryStore(items: []),
            pasteService: MockPasteService(),
            permissions: StubAccessibilityPermissionService(isTrusted: true)
        )

        return ClipboardPanelController(
            viewModel: viewModel,
            prepareForPresentation: {},
            panelWindow: panelWindow,
            outsideClickMonitor: outsideClickMonitor,
            scheduleOutsideClickMonitoring: scheduleOutsideClickMonitoring
        )
    }

    private func makeKeyEvent(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: keyCode
        )!
    }
}

@MainActor
private final class ClipboardPanelWindowSpy: ClipboardPanelWindowManaging {
    var isVisible = false
    var frame: NSRect?
    var window: NSWindow?
    private(set) var showCalls = 0
    private(set) var lastStyle: ClipboardPopupStyle?
    private(set) var activateCalls = 0
    private(set) var closeCalls = 0

    func show(
        viewModel: ClipboardPopupViewModel,
        frame: NSRect,
        screen: NSScreen?,
        style: ClipboardPopupStyle
    ) {
        showCalls += 1
        isVisible = true
        lastStyle = style
        self.frame = frame
        window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: true
        )
    }

    func activate() {
        activateCalls += 1
    }

    func close() {
        closeCalls += 1
        isVisible = false
        frame = nil
        window = nil
    }
}

@MainActor
private final class OutsideClickMonitorSpy: OutsideClickMonitoring {
    private(set) var startCalls = 0
    private(set) var stopCalls = 0
    var handler: ((NSPoint) -> Void)?

    func start(handler: @escaping (NSPoint) -> Void) {
        startCalls += 1
        self.handler = handler
    }

    func stop() {
        stopCalls += 1
        handler = nil
    }
}

@MainActor
private final class DeferredActionSchedulerSpy {
    private(set) var scheduleCalls = 0
    private var action: (@MainActor () -> Void)?

    func schedule(action: @escaping @MainActor () -> Void) {
        scheduleCalls += 1
        self.action = action
    }

    func runScheduledAction() {
        action?()
    }
}
