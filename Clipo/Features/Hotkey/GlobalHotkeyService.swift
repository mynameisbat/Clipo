import AppKit
@preconcurrency import KeyboardShortcuts

enum ShortcutName {
    nonisolated(unsafe) static let togglePopup = KeyboardShortcuts.Name(
        "togglePopup",
        default: .init(.v, modifiers: [.command, .shift])
    )
    nonisolated(unsafe) static let openPastePicker = KeyboardShortcuts.Name(
        "openPastePicker",
        default: .init(.v, modifiers: [.command, .option])
    )
    nonisolated(unsafe) static let screenExtensionTogglePopup = KeyboardShortcuts.Name(
        "screenExtensionTogglePopup",
        default: .init(.v, modifiers: [.control, .option])
    )
    nonisolated(unsafe) static let screenExtensionOpenPastePicker = KeyboardShortcuts.Name(
        "screenExtensionOpenPastePicker",
        default: .init(.v, modifiers: [.control, .option, .shift])
    )
    nonisolated(unsafe) static let pauseToggle = KeyboardShortcuts.Name(
        "pauseToggle",
        default: .init(.t, modifiers: [.command])
    )
    nonisolated(unsafe) static let sequentialPaste = KeyboardShortcuts.Name(
        "sequentialPaste",
        default: .init(.v, modifiers: [.command, .control])
    )
    nonisolated(unsafe) static let screenCapture = KeyboardShortcuts.Name(
        "screenCapture",
        default: .init(.s, modifiers: [.command, .option])
    )
    nonisolated(unsafe) static let screenRecording = KeyboardShortcuts.Name(
        "screenRecording",
        default: .init(.r, modifiers: [.command, .option])
    )

    nonisolated(unsafe) static let quickPaste1 = KeyboardShortcuts.Name("quickPaste1", default: .init(.one, modifiers: [.command]))
    nonisolated(unsafe) static let quickPaste2 = KeyboardShortcuts.Name("quickPaste2", default: .init(.two, modifiers: [.command]))
    nonisolated(unsafe) static let quickPaste3 = KeyboardShortcuts.Name("quickPaste3", default: .init(.three, modifiers: [.command]))
    nonisolated(unsafe) static let quickPaste4 = KeyboardShortcuts.Name("quickPaste4", default: .init(.four, modifiers: [.command]))
    nonisolated(unsafe) static let quickPaste5 = KeyboardShortcuts.Name("quickPaste5", default: .init(.five, modifiers: [.command]))
    nonisolated(unsafe) static let quickPaste6 = KeyboardShortcuts.Name("quickPaste6", default: .init(.six, modifiers: [.command]))
    nonisolated(unsafe) static let quickPaste7 = KeyboardShortcuts.Name("quickPaste7", default: .init(.seven, modifiers: [.command]))
    nonisolated(unsafe) static let quickPaste8 = KeyboardShortcuts.Name("quickPaste8", default: .init(.eight, modifiers: [.command]))
    nonisolated(unsafe) static let quickPaste9 = KeyboardShortcuts.Name("quickPaste9", default: .init(.nine, modifiers: [.command]))

    static let quickPasteNames: [KeyboardShortcuts.Name] = [
        quickPaste1, quickPaste2, quickPaste3,
        quickPaste4, quickPaste5, quickPaste6,
        quickPaste7, quickPaste8, quickPaste9
    ]
}

@MainActor
final class GlobalHotkeyService {
    enum ShortcutAction: Equatable {
        case togglePopup
        case openPastePicker
        case togglePause
        case sequentialPaste
        case quickPaste(Int)
        case screenCapture
        case screenRecording
    }

    private var screenCaptureHandler: (() -> Void)?
    private var screenRecordingHandler: (() -> Void)?

    private var togglePopupHandler: (() -> Void)?
    private var openPastePickerHandler: (() -> Void)?
    private var pauseToggleHandler: (() -> Void)?
    private var sequentialPasteHandler: (() -> Void)?
    private var quickPasteHandlers: [Int: () -> Void] = [:]
    private var globalKeyMonitor: Any?
    private var lastHandledShortcutAt: Date?

    func restoreDefaultsIfNeeded() {
        restoreDefaultIfNeeded(ShortcutName.togglePopup)
        restoreDefaultIfNeeded(ShortcutName.openPastePicker)
        restoreDefaultIfNeeded(ShortcutName.screenExtensionTogglePopup)
        restoreDefaultIfNeeded(ShortcutName.screenExtensionOpenPastePicker)
        restoreDefaultIfNeeded(ShortcutName.pauseToggle)
        restoreDefaultIfNeeded(ShortcutName.sequentialPaste)
        restoreDefaultIfNeeded(ShortcutName.screenCapture)
        restoreDefaultIfNeeded(ShortcutName.screenRecording)
        for name in ShortcutName.quickPasteNames {
            restoreDefaultIfNeeded(name)
        }
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

    func registerPauseToggle(handler: @escaping () -> Void) {
        pauseToggleHandler = handler
        KeyboardShortcuts.onKeyDown(for: ShortcutName.pauseToggle) { [weak self] in
            Task { @MainActor in
                self?.runShortcutAction(.togglePause)
            }
        }
    }

    func registerSequentialPaste(handler: @escaping () -> Void) {
        sequentialPasteHandler = handler
        KeyboardShortcuts.onKeyDown(for: ShortcutName.sequentialPaste) { [weak self] in
            Task { @MainActor in
                self?.runShortcutAction(.sequentialPaste)
            }
        }
    }

    func registerScreenCapture(handler: @escaping () -> Void) {
        screenCaptureHandler = handler
        registerShortcut(ShortcutName.screenCapture, action: .screenCapture)
    }

    func registerScreenRecording(handler: @escaping () -> Void) {
        screenRecordingHandler = handler
        registerShortcut(ShortcutName.screenRecording, action: .screenRecording)
    }

    func registerQuickPaste(at index: Int, handler: @escaping () -> Void) {
        guard index >= 1, index <= 9 else { return }
        quickPasteHandlers[index] = handler
        let name = ShortcutName.quickPasteNames[index - 1]
        KeyboardShortcuts.onKeyDown(for: name) { [weak self] in
            Task { @MainActor in
                self?.runShortcutAction(.quickPaste(index))
            }
        }
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

        if shortcut == KeyboardShortcuts.Shortcut(name: ShortcutName.pauseToggle) {
            return .togglePause
        }

        if shortcut == KeyboardShortcuts.Shortcut(name: ShortcutName.sequentialPaste) {
            return .sequentialPaste
        }

        if shortcut == KeyboardShortcuts.Shortcut(name: ShortcutName.screenCapture) {
            return .screenCapture
        }

        if shortcut == KeyboardShortcuts.Shortcut(name: ShortcutName.screenRecording) {
            return .screenRecording
        }

        for (index, name) in ShortcutName.quickPasteNames.enumerated() {
            if shortcut == KeyboardShortcuts.Shortcut(name: name) {
                return .quickPaste(index + 1)
            }
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
        case .togglePause:
            pauseToggleHandler?()
        case .sequentialPaste:
            sequentialPasteHandler?()
        case .quickPaste(let index):
            quickPasteHandlers[index]?()
        case .screenCapture:
            screenCaptureHandler?()
        case .screenRecording:
            screenRecordingHandler?()
        }
    }

    private func shouldHandleShortcutNow() -> Bool {
        let now = Date()
        defer { lastHandledShortcutAt = now }

        guard let lastHandledShortcutAt else { return true }
        return now.timeIntervalSince(lastHandledShortcutAt) > 0.25
    }
}
