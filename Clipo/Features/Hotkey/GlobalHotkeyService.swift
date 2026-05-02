import AppKit
import KeyboardShortcuts

enum ShortcutName {
    nonisolated(unsafe) static let togglePopup = KeyboardShortcuts.Name(
        "togglePopup",
        default: .init(.v, modifiers: [.command, .shift])
    )
    nonisolated(unsafe) static let openPastePicker = KeyboardShortcuts.Name(
        "openPastePicker"
    )
    nonisolated(unsafe) static let screenExtensionTogglePopup = KeyboardShortcuts.Name(
        "screenExtensionTogglePopup",
        default: .init(.v, modifiers: [.control, .option])
    )
    nonisolated(unsafe) static let screenExtensionOpenPastePicker = KeyboardShortcuts.Name(
        "screenExtensionOpenPastePicker",
        default: .init(.v, modifiers: [.control, .option, .shift])
    )
}

@MainActor
final class GlobalHotkeyService {
    enum ShortcutAction: Equatable {
        case togglePopup
        case openPastePicker
    }

    private var togglePopupHandler: (() -> Void)?
    private var openPastePickerHandler: (() -> Void)?
    private var globalKeyMonitor: Any?
    private var lastHandledShortcutAt: Date?

    func restoreDefaultsIfNeeded() {
        restoreDefaultIfNeeded(ShortcutName.togglePopup)
        restoreDefaultIfNeeded(ShortcutName.openPastePicker)
        restoreDefaultIfNeeded(ShortcutName.screenExtensionTogglePopup)
        restoreDefaultIfNeeded(ShortcutName.screenExtensionOpenPastePicker)
        clearConflictingShortcuts()
    }

    // Cmd+Option+V conflicts with macOS Finder "Move Here" (cut file)
    private func clearConflictingShortcuts() {
        let cmdOptionV = KeyboardShortcuts.Shortcut(.v, modifiers: [.command, .option])
        if ShortcutName.openPastePicker.shortcut == cmdOptionV {
            KeyboardShortcuts.setShortcut(nil, for: ShortcutName.openPastePicker)
        }
    }

    func registerTogglePopup(handler: @escaping () -> Void) {
        togglePopupHandler = handler
        registerShortcut(ShortcutName.togglePopup, action: .togglePopup)
        registerShortcut(ShortcutName.screenExtensionTogglePopup, action: .togglePopup)
        startFallbackGlobalKeyMonitorIfNeeded()
    }

    func registerOpenPastePicker(handler: @escaping () -> Void) {
        openPastePickerHandler = handler
        registerShortcut(ShortcutName.openPastePicker, action: .openPastePicker)
        registerShortcut(ShortcutName.screenExtensionOpenPastePicker, action: .openPastePicker)
        startFallbackGlobalKeyMonitorIfNeeded()
    }

    func shortcutAction(for event: NSEvent) -> ShortcutAction? {
        guard !event.isARepeat, let shortcut = KeyboardShortcuts.Shortcut(event: event) else {
            return nil
        }

        if shortcut == KeyboardShortcuts.Shortcut(name: ShortcutName.togglePopup)
            || shortcut == KeyboardShortcuts.Shortcut(name: ShortcutName.screenExtensionTogglePopup) {
            return .togglePopup
        }

        if shortcut == KeyboardShortcuts.Shortcut(name: ShortcutName.openPastePicker)
            || shortcut == KeyboardShortcuts.Shortcut(name: ShortcutName.screenExtensionOpenPastePicker) {
            return .openPastePicker
        }

        return nil
    }

    private func restoreDefaultIfNeeded(_ name: KeyboardShortcuts.Name) {
        if name.shortcut == nil {
            KeyboardShortcuts.reset(name)
        }
    }

    private func registerShortcut(_ name: KeyboardShortcuts.Name, action: ShortcutAction) {
        KeyboardShortcuts.onKeyDown(for: name) { [weak self] in
            Task { @MainActor in
                self?.runShortcutAction(action)
            }
        }
    }

    private func startFallbackGlobalKeyMonitorIfNeeded() {
        guard globalKeyMonitor == nil else { return }

        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                guard let self, let action = self.shortcutAction(for: event) else { return }
                self.runShortcutAction(action)
            }
        }
    }

    private func runShortcutAction(_ action: ShortcutAction) {
        guard shouldHandleShortcutNow() else { return }

        switch action {
        case .togglePopup:
            togglePopupHandler?()
        case .openPastePicker:
            openPastePickerHandler?()
        }
    }

    private func shouldHandleShortcutNow() -> Bool {
        let now = Date()
        defer { lastHandledShortcutAt = now }

        guard let lastHandledShortcutAt else { return true }
        return now.timeIntervalSince(lastHandledShortcutAt) > 0.25
    }
}
