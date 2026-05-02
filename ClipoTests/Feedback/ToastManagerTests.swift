import XCTest
@testable import Clipo

@MainActor
final class ToastManagerTests: XCTestCase {
    func testShowToast() async {
        let manager = ToastManager()
        let toast = ToastMessage.success("Test")

        manager.show(toast)

        XCTAssertEqual(manager.currentToast, toast)
    }

    func testAutoDismiss() async throws {
        let manager = ToastManager()
        let toast = ToastMessage(
            id: UUID(),
            type: .success,
            message: "Test",
            duration: 0.1
        )

        manager.show(toast)
        XCTAssertNotNil(manager.currentToast)

        try await Task.sleep(nanoseconds: 150_000_000) // 150ms
        XCTAssertNil(manager.currentToast)
    }

    func testQueueProcessing() async throws {
        let manager = ToastManager()

        manager.show(ToastMessage.success("First"))
        manager.show(ToastMessage.success("Second"))

        XCTAssertEqual(manager.currentToast?.message, "First")

        try await Task.sleep(nanoseconds: 2_600_000_000) // 2.6s
        XCTAssertEqual(manager.currentToast?.message, "Second")
    }

    func testQueueOverflow() {
        let manager = ToastManager()

        // Add 6 toasts (max is 5)
        for i in 1...6 {
            manager.show(ToastMessage.success("Toast \(i)"))
        }

        // First toast should be dropped
        // Current: Toast 1, Queue: [Toast 3, 4, 5, 6]
        XCTAssertEqual(manager.currentToast?.message, "Toast 1")
    }

    func testClear() {
        let manager = ToastManager()

        manager.show(ToastMessage.success("Test"))
        XCTAssertNotNil(manager.currentToast)

        manager.clear()
        XCTAssertNil(manager.currentToast)
    }

    func testMultipleRapidShows() {
        let manager = ToastManager()

        // Rapid fire 3 toasts
        manager.show(ToastMessage.success("First"))
        manager.show(ToastMessage.success("Second"))
        manager.show(ToastMessage.success("Third"))

        // First should be displaying
        XCTAssertEqual(manager.currentToast?.message, "First")
    }
}
