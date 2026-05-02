import Foundation
import Combine

/// Manages toast notification queue and display lifecycle.
/// Uses @MainActor for thread-safe UI updates and @Published for SwiftUI observation.
@MainActor
final class ToastManager: ObservableObject {
    /// Currently displayed toast, nil when idle.
    @Published private(set) var currentToast: ToastMessage?

    /// Queue of pending toasts (FIFO).
    private var queue: [ToastMessage] = []

    /// Task handling auto-dismiss of current toast.
    private var dismissTask: Task<Void, Never>?

    /// Maximum queue size to prevent spam.
    private let maxQueueSize = 5

    /// Shows a toast notification. Queues if another toast is displaying.
    /// - Parameter message: The toast message to display
    func show(_ message: ToastMessage) {
        // Drop oldest if queue full
        if queue.count >= maxQueueSize {
            queue.removeFirst()
        }
        queue.append(message)

        // Process immediately if idle
        if currentToast == nil {
            processQueue()
        }
    }

    /// Clears current toast and queue.
    func clear() {
        dismissTask?.cancel()
        currentToast = nil
        queue.removeAll()
    }

    /// Processes next toast in queue.
    private func processQueue() {
        guard !queue.isEmpty else { return }

        // Cancel previous dismiss task
        dismissTask?.cancel()

        // Show next toast
        currentToast = queue.removeFirst()

        // Schedule auto-dismiss
        let duration = currentToast?.duration ?? 2.5
        dismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            self.currentToast = nil
            self.processQueue()
        }
    }
}
