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
}
