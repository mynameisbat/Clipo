import XCTest
@testable import Clipo

final class PurgeSchedulerTests: XCTestCase {
    var scheduler: PurgeScheduler!

    override func setUp() {
        super.setUp()
        scheduler = PurgeScheduler()
    }

    override func tearDown() {
        scheduler = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testShouldPurgeReturnsTrueInitially() async {
        // Given: Fresh scheduler

        // When: Check if should purge
        let shouldPurge = await scheduler.shouldPurge()

        // Then: Should return true (never purged before)
        XCTAssertTrue(shouldPurge)
    }

    // MARK: - Purge Interval

    func testShouldPurgeReturnsFalseBeforeInterval() async {
        // Given: Just purged
        await scheduler.markPurged()

        // When: Check immediately
        let shouldPurge = await scheduler.shouldPurge()

        // Then: Should return false (interval not elapsed)
        XCTAssertFalse(shouldPurge)
    }

    func testShouldPurgeReturnsTrueAfterInterval() async {
        // Given: Purged with short interval
        let shortIntervalScheduler = PurgeScheduler(purgeInterval: 0.5) // 0.5 seconds
        await shortIntervalScheduler.markPurged()

        // When: Wait for interval to elapse
        try? await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds

        // Then: Should return true (interval elapsed)
        let shouldPurge = await shortIntervalScheduler.shouldPurge()
        XCTAssertTrue(shouldPurge)
    }

    func testShouldPurgeReturnsFalseJustBeforeInterval() async {
        // Given: Purged with short interval
        let shortIntervalScheduler = PurgeScheduler(purgeInterval: 1.0) // 1 second
        await shortIntervalScheduler.markPurged()

        // When: Wait just before interval
        try? await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds

        // Then: Should return false (interval not yet elapsed)
        let shouldPurge = await shortIntervalScheduler.shouldPurge()
        XCTAssertFalse(shouldPurge)
    }

    // MARK: - Multiple Purge Cycles

    func testMultiplePurgeCycles() async {
        // Given: Scheduler with short interval
        let shortIntervalScheduler = PurgeScheduler(purgeInterval: 0.5)

        // First purge
        let shouldPurge1 = await shortIntervalScheduler.shouldPurge()
        XCTAssertTrue(shouldPurge1, "Should purge initially")

        await shortIntervalScheduler.markPurged()

        // Immediately after - should not purge
        let shouldPurge2 = await shortIntervalScheduler.shouldPurge()
        XCTAssertFalse(shouldPurge2, "Should not purge immediately after")

        // Wait for interval
        try? await Task.sleep(nanoseconds: 600_000_000)

        // After interval - should purge again
        let shouldPurge3 = await shortIntervalScheduler.shouldPurge()
        XCTAssertTrue(shouldPurge3, "Should purge after interval")

        await shortIntervalScheduler.markPurged()

        // Immediately after second purge - should not purge
        let shouldPurge4 = await shortIntervalScheduler.shouldPurge()
        XCTAssertFalse(shouldPurge4, "Should not purge immediately after second purge")
    }

    // MARK: - Edge Cases

    func testMarkPurgedWithoutCheckingFirst() async {
        // Given: Fresh scheduler

        // When: Mark purged without checking
        await scheduler.markPurged()

        // Then: Should not purge immediately after
        let shouldPurge = await scheduler.shouldPurge()
        XCTAssertFalse(shouldPurge)
    }

    func testRepeatedShouldPurgeCallsWithoutMarking() async {
        // Given: Fresh scheduler

        // When: Call shouldPurge multiple times without marking
        let shouldPurge1 = await scheduler.shouldPurge()
        let shouldPurge2 = await scheduler.shouldPurge()
        let shouldPurge3 = await scheduler.shouldPurge()

        // Then: All should return true (never marked as purged)
        XCTAssertTrue(shouldPurge1)
        XCTAssertTrue(shouldPurge2)
        XCTAssertTrue(shouldPurge3)
    }

    func testDefaultIntervalIsOneHour() async {
        // Given: Scheduler with default interval
        let defaultScheduler = PurgeScheduler()
        await defaultScheduler.markPurged()

        // When: Check interval value
        // Note: We can't directly test 1 hour wait, but we can verify it doesn't purge immediately
        let shouldPurge = await defaultScheduler.shouldPurge()

        // Then: Should not purge immediately (1 hour not elapsed)
        XCTAssertFalse(shouldPurge)
    }
}
