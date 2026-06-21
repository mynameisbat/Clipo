import Foundation

/// Protocol for adaptive clipboard monitoring
protocol AdaptiveClipboardMonitorable: Actor {
    func processCurrentPasteboard() async throws
}

/// Adaptive clipboard monitor that adjusts polling interval based on system activity
actor AdaptiveClipboardMonitor {
    typealias IntervalCallback = @Sendable (TimeInterval) -> Void

    private let clipboardMonitor: AdaptiveClipboardMonitorable
    private let activityDetector: ActivityLevelDetector
    @MainActor private var timer: Timer?
    private var currentLevel: ActivityLevel = .active
    private var intervalCallback: IntervalCallback?
    private var isPaused: Bool = false

    // Configuration — changeCount fast-exit makes frequent polling cheap
    private let intervals: [ActivityLevel: TimeInterval] = [
        .idle: 2.0,
        .active: 0.35,
        .focused: 0.2,
        .sleeping: 0 // Paused
    ]

    // Transition state
    private var isTransitioning = false
    private var transitionTask: Task<Void, Never>?

    init(clipboardMonitor: AdaptiveClipboardMonitorable, activityDetector: ActivityLevelDetector) {
        self.clipboardMonitor = clipboardMonitor
        self.activityDetector = activityDetector
    }

    deinit {
        transitionTask?.cancel()
    }

    // MARK: - Public API

    func startMonitoring() async {
        // Start activity detection
        await activityDetector.startMonitoring { [weak self] level in
            Task {
                await self?.handleActivityLevelChange(level)
            }
        }

        // Start with active interval
        adjustInterval(to: .active)
    }

    func stopMonitoring() {
        invalidateTimer()
        transitionTask?.cancel()
        transitionTask = nil
    }

    func adjustInterval(to level: ActivityLevel) {
        guard level != currentLevel else { return }

        currentLevel = level

        // Cancel any ongoing transition
        transitionTask?.cancel()
        transitionTask = nil
        isTransitioning = false

        // Get target interval
        guard let targetInterval = intervals[level] else { return }

        // Notify callback
        intervalCallback?(targetInterval)

        // Update timer
        if level == .sleeping || isPaused {
            // Pause monitoring
            invalidateTimer()
        } else {
            restartTimer(with: targetInterval)
        }
    }

    func setPaused(_ paused: Bool) {
        guard paused != isPaused else { return }
        isPaused = paused
        if paused {
            invalidateTimer()
        } else {
            restartTimer(with: currentInterval)
        }
    }

    func transitionToIdle() {
        guard !isTransitioning else { return }

        isTransitioning = true

        // Smooth transition: active (1s) → intermediate (2s) → idle (5s)
        transitionTask = Task {
            // Step 1: Stay at active for 30 seconds
            try? await Task.sleep(nanoseconds: 30_000_000_000)

            guard !Task.isCancelled else { return }

            // Step 2: Move to intermediate (1s) for buffer
            restartTimer(with: 1.0)
            intervalCallback?(1.0)

            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10s buffer

            guard !Task.isCancelled else { return }

            // Step 3: Finally move to idle (2s)
            adjustInterval(to: .idle)
            isTransitioning = false
        }
    }

    func notifyPopupOpened() async {
        await activityDetector.notifyPopupOpened()
    }

    func notifyPopupClosed() async {
        await activityDetector.notifyPopupClosed()
    }

    func onIntervalChange(callback: @escaping IntervalCallback) {
        self.intervalCallback = callback
    }

    var currentInterval: TimeInterval {
        intervals[currentLevel] ?? 1.0
    }

    // MARK: - Private Methods

    private func handleActivityLevelChange(_ level: ActivityLevel) {
        if level == .idle {
            // Use smooth transition for idle
            transitionToIdle()
        } else {
            // Immediate transition for user actions
            adjustInterval(to: level)
        }
    }

    private func invalidateTimer() {
        Task { @MainActor in
            self.timer?.invalidate()
            self.timer = nil
        }
    }

    private func restartTimer(with interval: TimeInterval) {
        // Invalidate existing timer
        invalidateTimer()

        // Create new timer on main thread
        let clipboardMonitor = self.clipboardMonitor
        Task { @MainActor in
            let newTimer = Timer.scheduledTimer(
                withTimeInterval: interval,
                repeats: true
            ) { _ in
                Task {
                    try? await clipboardMonitor.processCurrentPasteboard()
                }
            }
            self.timer = newTimer
        }
    }
}

// MARK: - ClipboardMonitor Conformance

extension ClipboardMonitor: AdaptiveClipboardMonitorable {}
