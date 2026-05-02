import Foundation

/// Represents a toast notification message with type, content, and display duration.
struct ToastMessage: Identifiable, Equatable, Sendable {
    let id: UUID
    let type: ToastType
    let message: String
    let duration: TimeInterval

    /// Types of toast notifications with different visual styles and priorities.
    enum ToastType: Sendable {
        case success
        case error
        case info
        case warning
    }
}

// MARK: - Convenience Initializers

extension ToastMessage {
    /// Creates a success toast with default 2.5s duration.
    static func success(_ message: String) -> ToastMessage {
        ToastMessage(id: UUID(), type: .success, message: message, duration: 2.5)
    }

    /// Creates an error toast with longer 3.0s duration.
    static func error(_ message: String) -> ToastMessage {
        ToastMessage(id: UUID(), type: .error, message: message, duration: 3.0)
    }

    /// Creates an info toast with shorter 2.0s duration.
    static func info(_ message: String) -> ToastMessage {
        ToastMessage(id: UUID(), type: .info, message: message, duration: 2.0)
    }

    /// Creates a warning toast with default 2.5s duration.
    static func warning(_ message: String) -> ToastMessage {
        ToastMessage(id: UUID(), type: .warning, message: message, duration: 2.5)
    }
}
