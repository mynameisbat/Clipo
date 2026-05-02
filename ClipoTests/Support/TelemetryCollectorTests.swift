import XCTest
@testable import Clipo

final class TelemetryCollectorTests: XCTestCase {

    // MARK: - Recording Metrics

    func testRecordSingleMetric() async {
        // Given: TelemetryCollector and metric
        let collector = TelemetryCollector()
        let metric = TelemetryCollector.PerformanceMetrics(
            timestamp: Date(),
            cpuUsage: 25.5,
            memoryUsage: 1024 * 1024 * 100, // 100MB
            popupLatency: 0.05,
            searchLatency: 0.02,
            frameRate: 60.0,
            itemCount: 100
        )

        // When: Recording metric
        await collector.record(metric)

        // Then: Should have 1 metric
        let count = await collector.metricsCount
        XCTAssertEqual(count, 1)
    }

    func testRecordMultipleMetrics() async {
        // Given: TelemetryCollector and multiple metrics
        let collector = TelemetryCollector()

        // When: Recording multiple metrics
        for i in 0..<10 {
            let metric = TelemetryCollector.PerformanceMetrics(
                timestamp: Date(),
                cpuUsage: Double(i * 10),
                memoryUsage: Int64(i * 1024 * 1024),
                popupLatency: 0.05,
                searchLatency: 0.02,
                frameRate: 60.0,
                itemCount: 100
            )
            await collector.record(metric)
        }

        // Then: Should have 10 metrics
        let count = await collector.metricsCount
        XCTAssertEqual(count, 10)
    }

    func testMaxMetricsLimit() async {
        // Given: TelemetryCollector with max 1000 metrics
        let collector = TelemetryCollector()

        // When: Recording 1500 metrics
        for i in 0..<1500 {
            let metric = TelemetryCollector.PerformanceMetrics(
                timestamp: Date(),
                cpuUsage: Double(i),
                memoryUsage: Int64(i),
                popupLatency: 0.05,
                searchLatency: 0.02,
                frameRate: 60.0,
                itemCount: 100
            )
            await collector.record(metric)
        }

        // Then: Should cap at 1000 metrics
        let count = await collector.metricsCount
        XCTAssertEqual(count, 1000)
    }

    // MARK: - Averages

    func testGetAveragesWithNoMetrics() async {
        // Given: Empty TelemetryCollector
        let collector = TelemetryCollector()

        // When: Getting averages
        let averages = await collector.getAverages()

        // Then: Should return zeros
        XCTAssertEqual(averages.cpu, 0)
        XCTAssertEqual(averages.memory, 0)
        XCTAssertEqual(averages.latency, 0)
        XCTAssertEqual(averages.fps, 0)
    }

    func testGetAveragesWithSingleMetric() async {
        // Given: TelemetryCollector with one metric
        let collector = TelemetryCollector()
        let metric = TelemetryCollector.PerformanceMetrics(
            timestamp: Date(),
            cpuUsage: 50.0,
            memoryUsage: 1024 * 1024 * 200, // 200MB
            popupLatency: 0.1,
            searchLatency: 0.05,
            frameRate: 60.0,
            itemCount: 100
        )
        await collector.record(metric)

        // When: Getting averages
        let averages = await collector.getAverages()

        // Then: Should return same values
        XCTAssertEqual(averages.cpu, 50.0)
        XCTAssertEqual(averages.memory, 1024 * 1024 * 200)
        XCTAssertEqual(averages.latency, 0.1)
        XCTAssertEqual(averages.fps, 60.0)
    }

    func testGetAveragesWithMultipleMetrics() async {
        // Given: TelemetryCollector with multiple metrics
        let collector = TelemetryCollector()

        await collector.record(TelemetryCollector.PerformanceMetrics(
            timestamp: Date(),
            cpuUsage: 20.0,
            memoryUsage: 100,
            popupLatency: 0.05,
            searchLatency: 0.02,
            frameRate: 60.0,
            itemCount: 100
        ))

        await collector.record(TelemetryCollector.PerformanceMetrics(
            timestamp: Date(),
            cpuUsage: 40.0,
            memoryUsage: 200,
            popupLatency: 0.15,
            searchLatency: 0.08,
            frameRate: 50.0,
            itemCount: 200
        ))

        // When: Getting averages
        let averages = await collector.getAverages()

        // Then: Should return correct averages
        XCTAssertEqual(averages.cpu, 30.0) // (20 + 40) / 2
        XCTAssertEqual(averages.memory, 150) // (100 + 200) / 2
        XCTAssertEqual(averages.latency, 0.1) // (0.05 + 0.15) / 2
        XCTAssertEqual(averages.fps, 55.0) // (60 + 50) / 2
    }

    // MARK: - Peaks

    func testGetPeaksWithNoMetrics() async {
        // Given: Empty TelemetryCollector
        let collector = TelemetryCollector()

        // When: Getting peaks
        let peaks = await collector.getPeaks()

        // Then: Should return zeros
        XCTAssertEqual(peaks.cpu, 0)
        XCTAssertEqual(peaks.memory, 0)
        XCTAssertEqual(peaks.latency, 0)
        XCTAssertEqual(peaks.lowestFps, 0)
    }

    func testGetPeaksWithMultipleMetrics() async {
        // Given: TelemetryCollector with varying metrics
        let collector = TelemetryCollector()

        await collector.record(TelemetryCollector.PerformanceMetrics(
            timestamp: Date(),
            cpuUsage: 20.0,
            memoryUsage: 100,
            popupLatency: 0.05,
            searchLatency: 0.02,
            frameRate: 60.0,
            itemCount: 100
        ))

        await collector.record(TelemetryCollector.PerformanceMetrics(
            timestamp: Date(),
            cpuUsage: 80.0, // Peak CPU
            memoryUsage: 500, // Peak memory
            popupLatency: 0.2, // Peak latency
            searchLatency: 0.1,
            frameRate: 30.0, // Lowest FPS
            itemCount: 200
        ))

        await collector.record(TelemetryCollector.PerformanceMetrics(
            timestamp: Date(),
            cpuUsage: 40.0,
            memoryUsage: 200,
            popupLatency: 0.1,
            searchLatency: 0.05,
            frameRate: 50.0,
            itemCount: 150
        ))

        // When: Getting peaks
        let peaks = await collector.getPeaks()

        // Then: Should return peak values
        XCTAssertEqual(peaks.cpu, 80.0)
        XCTAssertEqual(peaks.memory, 500)
        XCTAssertEqual(peaks.latency, 0.2)
        XCTAssertEqual(peaks.lowestFps, 30.0)
    }

    // MARK: - Export Report

    func testExportReportWithNoMetrics() async {
        // Given: Empty TelemetryCollector
        let collector = TelemetryCollector()

        // When: Exporting report
        let report = await collector.exportReport()

        // Then: Should contain zero values
        XCTAssertTrue(report.contains("Average CPU: 0.00%"))
        XCTAssertTrue(report.contains("Sample Count: 0"))
    }

    func testExportReportWithMetrics() async {
        // Given: TelemetryCollector with metrics
        let collector = TelemetryCollector()

        await collector.record(TelemetryCollector.PerformanceMetrics(
            timestamp: Date(),
            cpuUsage: 25.5,
            memoryUsage: 1024 * 1024 * 100,
            popupLatency: 0.05,
            searchLatency: 0.02,
            frameRate: 60.0,
            itemCount: 100
        ))

        // When: Exporting report
        let report = await collector.exportReport()

        // Then: Should contain formatted values
        XCTAssertTrue(report.contains("Performance Report"))
        XCTAssertTrue(report.contains("Average CPU: 25.50%"))
        XCTAssertTrue(report.contains("Average Popup Latency: 50ms"))
        XCTAssertTrue(report.contains("Average Frame Rate: 60.0fps"))
        XCTAssertTrue(report.contains("Sample Count: 1"))
    }

    // MARK: - Clear Metrics

    func testClearMetrics() async {
        // Given: TelemetryCollector with metrics
        let collector = TelemetryCollector()

        for _ in 0..<10 {
            await collector.record(TelemetryCollector.PerformanceMetrics(
                timestamp: Date(),
                cpuUsage: 25.0,
                memoryUsage: 1024,
                popupLatency: 0.05,
                searchLatency: 0.02,
                frameRate: 60.0,
                itemCount: 100
            ))
        }

        let countBefore = await collector.metricsCount
        XCTAssertEqual(countBefore, 10)

        // When: Clearing metrics
        await collector.clearMetrics()

        // Then: Should have no metrics
        let countAfter = await collector.metricsCount
        XCTAssertEqual(countAfter, 0)
    }

    // MARK: - Time Range Filtering

    func testGetMetricsInTimeRange() async {
        // Given: TelemetryCollector with metrics at different times
        let collector = TelemetryCollector()
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)
        let twoHoursAgo = now.addingTimeInterval(-7200)

        await collector.record(TelemetryCollector.PerformanceMetrics(
            timestamp: twoHoursAgo,
            cpuUsage: 20.0,
            memoryUsage: 100,
            popupLatency: 0.05,
            searchLatency: 0.02,
            frameRate: 60.0,
            itemCount: 100
        ))

        await collector.record(TelemetryCollector.PerformanceMetrics(
            timestamp: oneHourAgo,
            cpuUsage: 30.0,
            memoryUsage: 200,
            popupLatency: 0.1,
            searchLatency: 0.05,
            frameRate: 55.0,
            itemCount: 150
        ))

        await collector.record(TelemetryCollector.PerformanceMetrics(
            timestamp: now,
            cpuUsage: 40.0,
            memoryUsage: 300,
            popupLatency: 0.15,
            searchLatency: 0.08,
            frameRate: 50.0,
            itemCount: 200
        ))

        // When: Getting metrics from last hour
        let filtered = await collector.getMetrics(from: oneHourAgo, to: now)

        // Then: Should return 2 metrics (oneHourAgo and now)
        XCTAssertEqual(filtered.count, 2)
    }

    // MARK: - Get All Metrics

    func testGetAllMetrics() async {
        // Given: TelemetryCollector with metrics
        let collector = TelemetryCollector()

        for i in 0..<5 {
            await collector.record(TelemetryCollector.PerformanceMetrics(
                timestamp: Date(),
                cpuUsage: Double(i * 10),
                memoryUsage: Int64(i * 100),
                popupLatency: 0.05,
                searchLatency: 0.02,
                frameRate: 60.0,
                itemCount: 100
            ))
        }

        // When: Getting all metrics
        let allMetrics = await collector.getAllMetrics()

        // Then: Should return all 5 metrics
        XCTAssertEqual(allMetrics.count, 5)
    }
}
