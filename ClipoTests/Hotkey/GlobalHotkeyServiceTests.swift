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

    func testScreenCaptureShortcutHasDefaultValue() {
        let shortcut = ShortcutName.screenCapture.defaultShortcut

        XCTAssertEqual(shortcut?.key, .s)
        XCTAssertEqual(shortcut?.modifiers, [.command, .option])
    }

    @MainActor
    func testRestoreDefaultsIfNeededReenablesDisabledShortcuts() {
        let service = GlobalHotkeyService()
        KeyboardShortcuts.setShortcut(nil, for: ShortcutName.togglePopup)
        KeyboardShortcuts.setShortcut(nil, for: ShortcutName.openPastePicker)
        KeyboardShortcuts.setShortcut(nil, for: ShortcutName.screenExtensionTogglePopup)
        KeyboardShortcuts.setShortcut(nil, for: ShortcutName.screenExtensionOpenPastePicker)
        KeyboardShortcuts.setShortcut(nil, for: ShortcutName.screenCapture)

        service.restoreDefaultsIfNeeded()

        XCTAssertEqual(ShortcutName.togglePopup.shortcut, ShortcutName.togglePopup.defaultShortcut)
        XCTAssertNil(ShortcutName.openPastePicker.shortcut) // Conflict with Finder is cleared by default
        XCTAssertEqual(ShortcutName.screenExtensionTogglePopup.shortcut, ShortcutName.screenExtensionTogglePopup.defaultShortcut)
        XCTAssertEqual(ShortcutName.screenExtensionOpenPastePicker.shortcut, ShortcutName.screenExtensionOpenPastePicker.defaultShortcut)
        XCTAssertEqual(ShortcutName.screenCapture.shortcut, ShortcutName.screenCapture.defaultShortcut)
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
        let testShortcut = KeyboardShortcuts.Shortcut(.p, modifiers: [.command, .option])
        KeyboardShortcuts.setShortcut(testShortcut, for: ShortcutName.openPastePicker)

        let event = makeKeyEvent(
            keyCode: UInt16(testShortcut.carbonKeyCode),
            modifiers: [.command, .option]
        )

        XCTAssertEqual(service.shortcutAction(for: event), .openPastePicker)
        
        KeyboardShortcuts.setShortcut(nil, for: ShortcutName.openPastePicker)
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
    func testShortcutActionRecognizesScreenCaptureShortcut() {
        let service = GlobalHotkeyService()
        let event = makeKeyEvent(
            keyCode: UInt16(ShortcutName.screenCapture.defaultShortcut?.carbonKeyCode ?? 0),
            modifiers: [.command, .option]
        )

        XCTAssertEqual(service.shortcutAction(for: event), .screenCapture)
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
