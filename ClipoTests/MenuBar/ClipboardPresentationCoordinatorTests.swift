import XCTest
@testable import Clipo

@MainActor
final class ClipboardPresentationCoordinatorTests: XCTestCase {
    func testPrepareForPresentationProcessesClipboardThenReloadsPopup() async {
        let events = EventLog()
        let monitor = RecordingClipboardMonitor(events: events)
        let loader = RecordingPopupLoader(events: events)
        let coordinator = ClipboardPresentationCoordinator(monitor: monitor, popupLoader: loader)

        await coordinator.prepareForPresentation()

        let recordedEvents = await events.snapshot()
        XCTAssertEqual(recordedEvents, ["process", "load"])
    }
}

actor EventLog {
    private var events: [String] = []

    func append(_ event: String) {
        events.append(event)
    }

    func snapshot() -> [String] {
        events
    }
}

actor RecordingClipboardMonitor: ClipboardMonitoring {
    private let events: EventLog

    init(events: EventLog) {
        self.events = events
    }

    func processCurrentPasteboard() async throws {
        await events.append("process")
    }

    nonisolated func notifyItemPasted(_ itemId: UUID) {
        // No-op for tests
    }
}

@MainActor
final class RecordingPopupLoader: ClipboardPopupLoading {
    private let events: EventLog

    init(events: EventLog) {
        self.events = events
    }

    func load() async {
        await events.append("load")
    }
}
