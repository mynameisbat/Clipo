import XCTest
@testable import Clipo

@MainActor
final class PasteActionServiceTests: XCTestCase {
    func testPasteFallsBackToCopyOnlyWhenPermissionIsMissing() async throws {
        let clipboard = RecordingClipboardWriter()
        let driver = RecordingAutoPasteDriver()
        let permissions = StubAccessibilityPermissionService(isTrusted: false)
        let service = PasteActionService(
            clipboardWriter: clipboard,
            autoPasteDriver: driver,
            permissions: permissions,
            targetApplicationActivator: RecordingTargetApplicationActivator()
        )

        let result = try await service.paste(.stub(title: "Hello", contentText: "Hello"))

        XCTAssertEqual(result, .copiedOnly)
        XCTAssertEqual(driver.callCount, 0)
        XCTAssertEqual(clipboard.lastText, "Hello")
        XCTAssertEqual(permissions.requestTrustCalls, 0)
    }

    func testPasteReactivatesPreviousAppBeforeSendingPasteShortcut() async throws {
        let order = EventOrder()
        let clipboard = RecordingClipboardWriter(eventOrder: order)
        let driver = RecordingAutoPasteDriver(eventOrder: order)
        let activator = RecordingTargetApplicationActivator(eventOrder: order)
        let permissions = StubAccessibilityPermissionService(isTrusted: true)
        let service = PasteActionService(
            clipboardWriter: clipboard,
            autoPasteDriver: driver,
            permissions: permissions,
            targetApplicationActivator: activator
        )

        let result = try await service.paste(.stub(title: "Hello", contentText: "Hello"))

        XCTAssertEqual(result, .pasted)
        XCTAssertEqual(order.events, ["write", "activate", "paste"])
    }
}

final class RecordingClipboardWriter: ClipboardWriting {
    private(set) var lastText: String?
    private let eventOrder: EventOrder?

    init(eventOrder: EventOrder? = nil) {
        self.eventOrder = eventOrder
    }

    func write(item: ClipboardItem) throws {
        lastText = item.contentText ?? item.title
        eventOrder?.events.append("write")
    }
}

final class RecordingAutoPasteDriver: AutoPasteDriving {
    private(set) var callCount = 0
    private let eventOrder: EventOrder?

    init(eventOrder: EventOrder? = nil) {
        self.eventOrder = eventOrder
    }

    func pasteCurrentClipboard() throws {
        callCount += 1
        eventOrder?.events.append("paste")
    }
}

@MainActor
final class RecordingTargetApplicationActivator: TargetApplicationActivating {
    private let eventOrder: EventOrder?

    init(eventOrder: EventOrder? = nil) {
        self.eventOrder = eventOrder
    }

    func prepareForReturnToPreviousApp() {}

    func activatePreviousApp() {
        eventOrder?.events.append("activate")
    }
}

final class EventOrder {
    var events: [String] = []
}

final class StubAccessibilityPermissionService: AccessibilityPermissionChecking {
    let isTrusted: Bool
    private(set) var requestTrustCalls = 0
    private(set) var openSystemSettingsCalls = 0

    init(isTrusted: Bool) {
        self.isTrusted = isTrusted
    }

    func requestTrustIfNeeded() {
        requestTrustCalls += 1
    }

    func openSystemSettings() {
        openSystemSettingsCalls += 1
    }
}
