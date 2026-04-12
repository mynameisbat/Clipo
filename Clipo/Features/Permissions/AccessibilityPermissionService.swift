import ApplicationServices
import AppKit

private let axTrustedCheckOptionPromptKey = "AXTrustedCheckOptionPrompt"

protocol AccessibilityPermissionChecking {
    var isTrusted: Bool { get }
    func requestTrustIfNeeded()
    func openSystemSettings()
}

struct AccessibilityPermissionService: AccessibilityPermissionChecking {
    var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    func requestTrustIfNeeded() {
        guard !isTrusted else { return }
        let options = [axTrustedCheckOptionPromptKey: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
