import Foundation

actor TelemetryCollector {
    struct PerformanceMetrics: Codable, Sendable {
        let timestamp: Date
        let cpuUsage: Double
        let memoryUsage: Int64
        let popupLatency: TimeInterval
        let searchLatency: TimeInterval
        let frameRate: Double
        let itemCount: Int
    }

    private var metrics: [PerformanceMetrics] = []
    private let maxMetrics = 1000

    /// Record a performance metric
    /// - Parameter metric: Performance metrics to record
    func record(_ metric: PerformanceMetrics) {
        metrics.append(metric)
        if metrics.count > maxMetrics {
            metrics.removeFirst(metrics.count - maxMetrics)
        }
    }

    /// Get average performance metrics
    /// - Returns: Tuple of average CPU, memory, latency, and FPS
    func getAverages() -> (cpu: Double, memory: Int64, latency: TimeInterval, fps: Double) {
        guard !metrics.isEmpty else {
            return (0, 0, 0, 0)
        }

        let avgCPU = metrics.map(\.cpuUsage).reduce(0, +) / Double(metrics.count)
        let avgMemory = metrics.map(\.memoryUsage).reduce(0, +) / Int64(metrics.count)
        let avgLatency = metrics.map(\.popupLatency).reduce(0, +) / Double(metrics.count)
        let avgFPS = metrics.map(\.frameRate).reduce(0, +) / Double(metrics.count)

        return (avgCPU, avgMemory, avgLatency, avgFPS)
    }

    /// Export performance report as formatted string
    /// - Returns: Human-readable performance report
    func exportReport() -> String {
        let averages = getAverages()
        return """
        Performance Report
        ==================
        Average CPU: \(String(format: "%.2f", averages.cpu))%
        Average Memory: \(ByteCountFormatter.string(fromByteCount: averages.memory, countStyle: .memory))
        Average Popup Latency: \(String(format: "%.0f", averages.latency * 1000))ms
        Average Frame Rate: \(String(format: "%.1f", averages.fps))fps
        Sample Count: \(metrics.count)
        """
    }

    /// Get all recorded metrics
    /// - Returns: Array of all performance metrics
    func getAllMetrics() -> [PerformanceMetrics] {
        return metrics
    }

    /// Clear all recorded metrics
    func clearMetrics() {
        metrics.removeAll()
    }

    /// Get metrics count
    var metricsCount: Int {
        metrics.count
    }

    /// Get peak values
    /// - Returns: Tuple of peak CPU, memory, latency, and lowest FPS
    func getPeaks() -> (cpu: Double, memory: Int64, latency: TimeInterval, lowestFps: Double) {
        guard !metrics.isEmpty else {
            return (0, 0, 0, 0)
        }

        let peakCPU = metrics.map(\.cpuUsage).max() ?? 0
        let peakMemory = metrics.map(\.memoryUsage).max() ?? 0
        let peakLatency = metrics.map(\.popupLatency).max() ?? 0
        let lowestFPS = metrics.map(\.frameRate).min() ?? 0

        return (peakCPU, peakMemory, peakLatency, lowestFPS)
    }

    /// Get metrics within time range
    /// - Parameters:
    ///   - start: Start date
    ///   - end: End date
    /// - Returns: Filtered metrics within range
    func getMetrics(from start: Date, to end: Date) -> [PerformanceMetrics] {
        return metrics.filter { metric in
            metric.timestamp >= start && metric.timestamp <= end
        }
    }
}
