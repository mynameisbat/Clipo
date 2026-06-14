import XCTest
@testable import Clipo

actor TestState {
    var intervals: [TimeInterval] = []

    func addInterval(_ interval: TimeInterval) {
        intervals.append(interval)
    }

    func getIntervals() -> [TimeInterval] {
        intervals
    }
}

final class AdaptiveClipboardMonitorTests: XCTestCase {
    var monitor: AdaptiveClipboardMonitor!
    var mockClipboardMonitor: MockClipboardMonitor!
    var activityDetector: ActivityLevelDetector!

    override func setUp() async throws {
        try await super.setUp()
        mockClipboardMonitor = MockClipboardMonitor()
        activityDetector = ActivityLevelDetector()
        monitor = AdaptiveClipboardMonitor(
            clipboardMonitor: mockClipboardMonitor,
            activityDetector: activityDetector
        )
    }

    override func tearDown() {
        monitor = nil
        mockClipboardMonitor = nil
        activityDetector = nil
        super.tearDown()
    }

    // MARK: - Interval Adjustment Tests

    func testAdjustsIntervalToIdleState() async {
        // Given: Monitor running
        await monitor.startMonitoring()

        // When: Activity level changes to idle
        await monitor.adjustInterval(to: .idle)

        // Then: Interval should be 2s
        let interval = await monitor.currentInterval
        XCTAssertEqual(interval, 2.0, accuracy: 0.1)
    }

    func testAdjustsIntervalToActiveState() async {
        // Given: Monitor in idle state
        await monitor.adjustInterval(to: .idle)

        // When: Activity level changes to active
        await monitor.adjustInterval(to: .active)

        // Then: Interval should be 0.35s
        let interval = await monitor.currentInterval
        XCTAssertEqual(interval, 0.35, accuracy: 0.1)
    }

    func testAdjustsIntervalToFocusedState() async {
        // Given: Monitor in active state
        await monitor.adjustInterval(to: .active)

        // When: Activity level changes to focused
        await monitor.adjustInterval(to: .focused)

        // Then: Interval should be 0.2s
        let interval = await monitor.currentInterval
        XCTAssertEqual(interval, 0.2, accuracy: 0.1)
    }

    func testPausesMonitoringDuringSleep() async {
        // Given: Monitor running
        await monitor.startMonitoring()

        // When: System goes to sleep
        await monitor.adjustInterval(to: .sleeping)

        // Then: Interval should be 0 (paused)
        let interval = await monitor.currentInterval
        XCTAssertEqual(interval, 0.0, accuracy: 0.1)
    }

    // MARK: - Popup State Tests

    func testRespondsToPopupStateChanges() async {
        // Given: Monitor in active state
        await monitor.startMonitoring()
        await monitor.adjustInterval(to: .active)

        // When: Popup opens
        await monitor.notifyPopupOpened()

        // Wait for state change
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then: Should switch to focused state (0.2s)
        let interval = await monitor.currentInterval
        XCTAssertEqual(interval, 0.2, accuracy: 0.1)

        // When: Popup closes
        await monitor.notifyPopupClosed()

        // Wait for state change
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then: Should return to active state (0.35s)
        let newInterval = await monitor.currentInterval
        XCTAssertEqual(newInterval, 0.35, accuracy: 0.1)
    }
}

// MARK: - Mock Clipboard Monitor

actor MockClipboardMonitor: AdaptiveClipboardMonitorable {
    var pollCount = 0
    var detectedChanges: [String] = []
    private var changeQueue: [String] = []

    func processCurrentPasteboard() async throws {
        pollCount += 1

        // Process any queued changes
        if !changeQueue.isEmpty {
            let change = changeQueue.removeFirst()
            detectedChanges.append(change)
        }
    }

    func simulateClipboardChange() {
        let changeId = UUID().uuidString
        changeQueue.append(changeId)
    }
}
