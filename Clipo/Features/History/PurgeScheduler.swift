import Foundation

/// Schedules batch purge operations to reduce frequent database overhead
actor PurgeScheduler {
    private var lastPurge: Date?
    private let purgeInterval: TimeInterval

    init(purgeInterval: TimeInterval = 3600) { // Default 1 hour
        self.purgeInterval = purgeInterval
    }

    func shouldPurge() -> Bool {
        guard let lastPurge else { return true }
        return Date().timeIntervalSince(lastPurge) >= purgeInterval
    }

    func markPurged() {
        lastPurge = Date()
    }
}
