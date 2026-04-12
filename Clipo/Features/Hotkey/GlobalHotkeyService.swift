import KeyboardShortcuts

enum ShortcutName {
    nonisolated(unsafe) static let togglePopup = KeyboardShortcuts.Name(
        "togglePopup",
        default: .init(.v, modifiers: [.command, .shift])
    )
}

final class GlobalHotkeyService {
    func register(handler: @escaping () -> Void) {
        KeyboardShortcuts.onKeyUp(for: ShortcutName.togglePopup, action: handler)
    }
}
