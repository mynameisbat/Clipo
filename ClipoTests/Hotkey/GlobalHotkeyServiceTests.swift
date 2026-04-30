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

    func testScreenExtensionToggleShortcutHasDefaultValue() {
        let shortcut = ShortcutName.screenExtensionTogglePopup.defaultShortcut

        XCTAssertEqual(shortcut?.key, .v)
        XCTAssertEqual(shortcut?.modifiers, [.control, .option])
    }

    func testScreenExtensionPastePickerShortcutHasDefaultValue() {
        let shortcut = ShortcutName.screenExtensionOpenPastePicker.defaultShortcut

        XCTAssertEqual(shortcut?.key, .v)
        XCTAssertEqual(shortcut?.modifiers, [.control, .option, .shift])
    }

    @MainActor
    func testRestoreDefaultsIfNeededReenablesDisabledShortcuts() {
        let service = GlobalHotkeyService()
        KeyboardShortcuts.setShortcut(nil, for: ShortcutName.togglePopup)
        KeyboardShortcuts.setShortcut(nil, for: ShortcutName.openPastePicker)
        KeyboardShortcuts.setShortcut(nil, for: ShortcutName.screenExtensionTogglePopup)
        KeyboardShortcuts.setShortcut(nil, for: ShortcutName.screenExtensionOpenPastePicker)

        service.restoreDefaultsIfNeeded()

        XCTAssertEqual(ShortcutName.togglePopup.shortcut, ShortcutName.togglePopup.defaultShortcut)
        XCTAssertEqual(ShortcutName.openPastePicker.shortcut, ShortcutName.openPastePicker.defaultShortcut)
        XCTAssertEqual(ShortcutName.screenExtensionTogglePopup.shortcut, ShortcutName.screenExtensionTogglePopup.defaultShortcut)
        XCTAssertEqual(ShortcutName.screenExtensionOpenPastePicker.shortcut, ShortcutName.screenExtensionOpenPastePicker.defaultShortcut)
    }

    @MainActor
    func testShortcutActionRecognizesToggleShortcut() {
        let service = GlobalHotkeyService()
        let event = makeKeyEvent(
            keyCode: UInt16(ShortcutName.togglePopup.defaultShortcut?.carbonKeyCode ?? 0),
            modifiers: [.command, .shift]
        )

        XCTAssertEqual(service.shortcutAction(for: event), .togglePopup)
    }

    @MainActor
    func testShortcutActionRecognizesPastePickerShortcut() {
        let service = GlobalHotkeyService()
        let event = makeKeyEvent(
            keyCode: UInt16(ShortcutName.openPastePicker.defaultShortcut?.carbonKeyCode ?? 0),
            modifiers: [.command, .option]
        )

        XCTAssertEqual(service.shortcutAction(for: event), .openPastePicker)
    }

    @MainActor
    func testShortcutActionRecognizesScreenExtensionToggleShortcut() {
        let service = GlobalHotkeyService()
        let event = makeKeyEvent(
            keyCode: UInt16(ShortcutName.screenExtensionTogglePopup.defaultShortcut?.carbonKeyCode ?? 0),
            modifiers: [.control, .option]
        )

        XCTAssertEqual(service.shortcutAction(for: event), .togglePopup)
    }

    @MainActor
    func testShortcutActionRecognizesScreenExtensionPastePickerShortcut() {
        let service = GlobalHotkeyService()
        let event = makeKeyEvent(
            keyCode: UInt16(ShortcutName.screenExtensionOpenPastePicker.defaultShortcut?.carbonKeyCode ?? 0),
            modifiers: [.control, .option, .shift]
        )

        XCTAssertEqual(service.shortcutAction(for: event), .openPastePicker)
    }

    @MainActor
    func testShortcutActionIgnoresRepeatedKeyDown() {
        let service = GlobalHotkeyService()
        let event = makeKeyEvent(
            keyCode: UInt16(ShortcutName.togglePopup.defaultShortcut?.carbonKeyCode ?? 0),
            modifiers: [.command, .shift],
            isARepeat: true
        )

        XCTAssertNil(service.shortcutAction(for: event))
    }

    private func makeKeyEvent(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags,
        isARepeat: Bool = false
    ) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: isARepeat,
            keyCode: keyCode
        )!
    }
}
