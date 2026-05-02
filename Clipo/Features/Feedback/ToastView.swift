import SwiftUI

/// SwiftUI view for displaying toast notifications with animations.
struct ToastView: View {
    let toast: ToastMessage

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(iconColor)

            Text(toast.message)
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .lineLimit(2)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(backgroundColor)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isStaticText)
        .onAppear {
            announceToVoiceOver()
        }
    }

    private var iconName: String {
        switch toast.type {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }

    private var iconColor: Color {
        switch toast.type {
        case .success: return .green
        case .error: return .red
        case .info: return .blue
        case .warning: return .orange
        }
    }

    private var backgroundColor: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    private var accessibilityLabel: String {
        let typeLabel: String
        switch toast.type {
        case .success: typeLabel = "Success"
        case .error: typeLabel = "Error"
        case .info: typeLabel = "Info"
        case .warning: typeLabel = "Warning"
        }
        return "\(typeLabel): \(toast.message)"
    }

    private func announcementPriority() -> NSAccessibilityPriorityLevel {
        switch toast.type {
        case .error: return .high
        case .warning: return .medium
        case .success, .info: return .low
        }
    }

    private func announceToVoiceOver() {
        NSAccessibility.post(
            element: NSApp.mainWindow as Any,
            notification: .announcementRequested,
            userInfo: [
                .announcement: accessibilityLabel,
                .priority: announcementPriority().rawValue
            ]
        )
    }

    static var slideInTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .top)
                .combined(with: .opacity)
                .animation(.spring(response: 0.3, dampingFraction: 0.8)),
            removal: .opacity
                .animation(.easeOut(duration: 0.2))
        )
    }
}

#Preview("Success Toast") {
    ToastView(toast: ToastMessage.success("Item pasted successfully"))
        .padding()
}

#Preview("Error Toast") {
    ToastView(toast: ToastMessage.error("Failed to delete item"))
        .padding()
}

#Preview("Info Toast") {
    ToastView(toast: ToastMessage.info("No results found"))
        .padding()
}

#Preview("Warning Toast") {
    ToastView(toast: ToastMessage.warning("History cleared"))
        .padding()
}

#Preview("Long Message") {
    ToastView(toast: ToastMessage.success("This is a very long message that should be truncated after two lines to prevent the toast from becoming too large"))
        .padding()
}
