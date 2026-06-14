import Foundation
import AppKit

/// Activity level for adaptive clipboard monitoring
enum ActivityLevel: Equatable {
    case idle      // No user activity for 30s - 5s polling interval
    case active    // Normal app usage - 1s polling interval
    case focused   // Popup open - 0.5s polling interval
    case sleeping  // System sleep - pause monitoring
}

/// Detects system activity level for adaptive polling
actor ActivityLevelDetector {
    typealias ActivityCallback = @Sendable (ActivityLevel) -> Void

    private var currentLevel: ActivityLevel = .active
    private var callback: ActivityCallback?
    private var lastActivityTime: Date = Date()
    private var isPopupOpen = false
    private var monitoringTask: Task<Void, Never>?

    // Notification observers
    private var appActivationObserver: NSObjectProtocol?
    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?

    // Configuration
    private let idleThreshold: TimeInterval
    private let checkIntervalNanoseconds: UInt64

    init(idleThreshold: TimeInterval = 30.0, checkIntervalSeconds: TimeInterval = 5.0) {
        self.idleThreshold = idleThreshold
        self.checkIntervalNanoseconds = UInt64(checkIntervalSeconds * 1_000_000_000)
    }

    deinit {
        monitoringTask?.cancel()
    }

    // MARK: - Public API

    func startMonitoring(callback: @escaping ActivityCallback) {
        self.callback = callback

        // Register for system notifications
        registerNotifications()

        // Start idle detection loop
        monitoringTask = Task {
            await monitorIdleState()
        }
    }

    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil

        unregisterNotifications()
    }

    func notifyPopupOpened() {
        isPopupOpen = true
        updateActivityLevel(.focused)
    }

    func notifyPopupClosed() {
        isPopupOpen = false
        updateActivityLevel(.active)
    }

    // MARK: - Private Methods

    private func registerNotifications() {
        let notificationCenter = NSWorkspace.shared.notificationCenter

        // App activation notification
        appActivationObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.handleAppActivation()
            }
        }

        // System sleep notification
        sleepObserver = notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.handleSystemSleep()
            }
        }

        // System wake notification
        wakeObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.handleSystemWake()
            }
        }
    }

    private func unregisterNotifications() {
        let notificationCenter = NSWorkspace.shared.notificationCenter

        if let observer = appActivationObserver {
            notificationCenter.removeObserver(observer)
            appActivationObserver = nil
        }

        if let observer = sleepObserver {
            notificationCenter.removeObserver(observer)
            sleepObserver = nil
        }

        if let observer = wakeObserver {
            notificationCenter.removeObserver(observer)
            wakeObserver = nil
        }
    }

    private func handleAppActivation() {
        lastActivityTime = Date()

        // If not focused (popup open), update to active
        if !isPopupOpen && currentLevel != .active {
            updateActivityLevel(.active)
        }
    }

    private func handleSystemSleep() {
        updateActivityLevel(.sleeping)
    }

    private func handleSystemWake() {
        lastActivityTime = Date()
        updateActivityLevel(.active)
    }

    private func monitorIdleState() async {
        while !Task.isCancelled {
            // Check if idle threshold exceeded
            let timeSinceLastActivity = Date().timeIntervalSince(lastActivityTime)

            if timeSinceLastActivity >= idleThreshold && currentLevel == .active {
                updateActivityLevel(.idle)
            }

            // Check every checkInterval
            try? await Task.sleep(nanoseconds: checkIntervalNanoseconds)
        }
    }

    private func updateActivityLevel(_ newLevel: ActivityLevel) {
        guard newLevel != currentLevel else { return }

        currentLevel = newLevel
        callback?(newLevel)
    }
}

// MARK: - Test Helpers

#if DEBUG
extension ActivityLevelDetector {
    func simulateIdleState() async {
        lastActivityTime = Date().addingTimeInterval(-idleThreshold - 1)
        updateActivityLevel(.idle)
    }

    func simulateAppActivation() async {
        handleAppActivation()
    }

    func simulateSystemSleep() async {
        handleSystemSleep()
    }

    func simulateSystemWake() async {
        handleSystemWake()
    }
}
#endif
