import AppKit
import XCTest
@testable import Clipo

@MainActor
final class ClipboardPanelControllerTests: XCTestCase {
    func testToggleStartsOutsideClickMonitoringWhenPopoverIsShown() async {
        let popover = PopoverSpy(frame: NSRect(x: 100, y: 100, width: 200, height: 200))
        let monitor = OutsideClickMonitorSpy()
        let scheduler = DeferredActionSchedulerSpy()
        let controller = makeController(
            popover: popover,
            outsideClickMonitor: monitor,
            scheduleOutsideClickMonitoring: scheduler.schedule(action:)
        )

        await controller.toggle(relativeTo: NSView(frame: NSRect(x: 0, y: 0, width: 10, height: 10)))

        XCTAssertEqual(popover.showCalls, 1)
        XCTAssertEqual(monitor.startCalls, 0)
        XCTAssertEqual(scheduler.scheduleCalls, 1)

        scheduler.runScheduledAction()

        XCTAssertEqual(monitor.startCalls, 1)
        XCTAssertNotNil(monitor.handler)
    }

    func testOutsideClickClosesPopover() async {
        let popover = PopoverSpy(frame: NSRect(x: 100, y: 100, width: 200, height: 200))
        let monitor = OutsideClickMonitorSpy()
        let controller = makeController(popover: popover, outsideClickMonitor: monitor)

        await controller.toggle(relativeTo: NSView(frame: NSRect(x: 0, y: 0, width: 10, height: 10)))
        monitor.handler?(NSPoint(x: 20, y: 20))

        XCTAssertEqual(popover.closeCalls, 1)
        XCTAssertEqual(monitor.stopCalls, 1)
    }

    func testInsideClickKeepsPopoverOpen() async {
        let popover = PopoverSpy(frame: NSRect(x: 100, y: 100, width: 200, height: 200))
        let monitor = OutsideClickMonitorSpy()
        let controller = makeController(popover: popover, outsideClickMonitor: monitor)

        await controller.toggle(relativeTo: NSView(frame: NSRect(x: 0, y: 0, width: 10, height: 10)))
        monitor.handler?(NSPoint(x: 150, y: 150))

        XCTAssertEqual(popover.closeCalls, 0)
        XCTAssertEqual(monitor.stopCalls, 0)
    }

    private func makeController(
        popover: PopoverManaging,
        outsideClickMonitor: OutsideClickMonitoring,
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
            popover: popover,
            outsideClickMonitor: outsideClickMonitor,
            scheduleOutsideClickMonitoring: scheduleOutsideClickMonitoring
        )
    }
}

@MainActor
private final class PopoverSpy: PopoverManaging {
    var isShown = false
    var contentWindowFrame: NSRect?
    var contentViewController: NSViewController?
    var contentSize: NSSize = .zero
    var behavior: NSPopover.Behavior = .transient
    var animates = true
    private(set) var showCalls = 0
    private(set) var closeCalls = 0

    init(frame: NSRect?) {
        self.contentWindowFrame = frame
    }

    func show(relativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge) {
        showCalls += 1
        isShown = true
    }

    func close() {
        closeCalls += 1
        isShown = false
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
