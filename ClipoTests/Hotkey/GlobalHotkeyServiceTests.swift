import AppKit
import KeyboardShortcuts
import XCTest
@testable import Clipo

final class GlobalHotkeyServiceTests: XCTestCase {
    func testTogglePopupShortcutHasDefaultValue() {
        let shortcut = ShortcutName.togglePopup.defaultShortcut

        XCTAssertEqual(shortcut?.key, .v)
        XCTAssertEqual(shortcut?.modifiers, [.command, .shift])
    }

    func testPastePickerShortcutHasDefaultValue() {
        let shortcut = ShortcutName.openPastePicker.defaultShortcut

        XCTAssertEqual(shortcut?.key, .v)
        XCTAssertEqual(shortcut?.modifiers, [.command, .option])
    }

    func testRestoreDefaultsIfNeededReenablesDisabledShortcuts() {
        let service = GlobalHotkeyService()
        KeyboardShortcuts.setShortcut(nil, for: ShortcutName.togglePopup)
        KeyboardShortcuts.setShortcut(nil, for: ShortcutName.openPastePicker)

        service.restoreDefaultsIfNeeded()

        XCTAssertEqual(ShortcutName.togglePopup.shortcut, ShortcutName.togglePopup.defaultShortcut)
        XCTAssertEqual(ShortcutName.openPastePicker.shortcut, ShortcutName.openPastePicker.defaultShortcut)
    }
}
