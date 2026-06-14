import XCTest
@testable import Clipo

actor ActivityTestState {
    var detectedLevel: ActivityLevel?
    var transitions: [ActivityLevel] = []

    func setLevel(_ level: ActivityLevel) {
        detectedLevel = level
    }

    func addTransition(_ level: ActivityLevel) {
        transitions.append(level)
    }

    func getLevel() -> ActivityLevel? {
        detectedLevel
    }

    func getTransitions() -> [ActivityLevel] {
        transitions
    }
}

final class ActivityLevelDetectorTests: XCTestCase {
    var detector: ActivityLevelDetector!

    override func setUp() {
        super.setUp()
        detector = ActivityLevelDetector(idleThreshold: 0.1, checkIntervalSeconds: 0.02)
    }

    override func tearDown() {
        detector = nil
        super.tearDown()
    }

    // MARK: - Basic State Detection

    func testDetectsIdleStateAfter30Seconds() async {
        // Given: No activity for 0.1 seconds
        let expectation = XCTestExpectation(description: "Idle state detected")
        let state = ActivityTestState()

        await detector.startMonitoring { level in
            Task {
                await state.setLevel(level)
                if level == .idle {
                    expectation.fulfill()
                }
            }
        }

        // When: Wait 0.15 seconds
        try? await Task.sleep(nanoseconds: 150_000_000)

        // Then: Should detect idle
        await fulfillment(of: [expectation], timeout: 1.0)
        let level = await state.getLevel()
        XCTAssertEqual(level, .idle)
    }

    func testDoesNotDetectIdleBeforeThreshold() async {
        // Given: Activity detector running
        let state = ActivityTestState()
        await detector.startMonitoring { level in
            Task {
                await state.setLevel(level)
            }
        }

        // When: Wait only 0.05 seconds (below 0.1s threshold)
        try? await Task.sleep(nanoseconds: 50_000_000)

        // Then: Should still be active
        let level = await state.getLevel()
        XCTAssertNotEqual(level, .idle)
    }

    // MARK: - Focused State Detection

    func testDetectsFocusedStateWhenPopupOpens() async {
        // Given: Detector running
        let expectation = XCTestExpectation(description: "Focused state detected")
        let state = ActivityTestState()

        await detector.startMonitoring { level in
            Task {
                await state.setLevel(level)
                if level == .focused {
                    expectation.fulfill()
                }
            }
        }

        // When: Popup opens
        await detector.notifyPopupOpened()

        // Then: Should detect focused
        await fulfillment(of: [expectation], timeout: 1.0)
        let level = await state.getLevel()
        XCTAssertEqual(level, .focused)
    }

    func testReturnsToActiveWhenPopupCloses() async {
        // Given: Detector in focused state
        await detector.notifyPopupOpened()

        let expectation = XCTestExpectation(description: "Active state detected")
        let state = ActivityTestState()

        await detector.startMonitoring { level in
            Task {
                await state.setLevel(level)
                if level == .active {
                    expectation.fulfill()
                }
            }
        }

        // When: Popup closes
        await detector.notifyPopupClosed()

        // Then: Should return to active
        await fulfillment(of: [expectation], timeout: 1.0)
        let level = await state.getLevel()
        XCTAssertEqual(level, .active)
    }
}
