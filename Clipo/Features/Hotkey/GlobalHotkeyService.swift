import KeyboardShortcuts

enum ShortcutName {
    nonisolated(unsafe) static let togglePopup = KeyboardShortcuts.Name(
        "togglePopup",
        default: .init(.v, modifiers: [.command, .shift])
    )
    nonisolated(unsafe) static let openPastePicker = KeyboardShortcuts.Name(
        "openPastePicker",
        default: .init(.v, modifiers: [.command, .option])
    )
}

final class GlobalHotkeyService {
    func restoreDefaultsIfNeeded() {
        if ShortcutName.togglePopup.shortcut == nil {
            KeyboardShortcuts.reset(ShortcutName.togglePopup)
        }

        if ShortcutName.openPastePicker.shortcut == nil {
            KeyboardShortcuts.reset(ShortcutName.openPastePicker)
        }
    }

    func registerTogglePopup(handler: @escaping () -> Void) {
        KeyboardShortcuts.onKeyUp(for: ShortcutName.togglePopup, action: handler)
    }

    func registerOpenPastePicker(handler: @escaping () -> Void) {
        KeyboardShortcuts.onKeyUp(for: ShortcutName.openPastePicker, action: handler)
    }
}
