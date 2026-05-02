import SwiftUI
import AppKit

@MainActor
struct KeyboardNavigationHandler {
    enum Action {
        case moveUp
        case moveDown
        case moveToTop
        case moveToBottom
        case confirmSelection
        case togglePin
        case deleteItem
        case focusSearch
        case clearSearch
        case closePopup
    }

    static func handleKeyEvent(
        _ eventData: KeyEventData,
        viewModel: ClipboardPopupViewModel,
        currentSearchFocused: Bool,
        popupDismisser: ClipboardPopupDismissing?
    ) async -> Bool? {
        let modifiers = eventData.modifiers
        let keyCode = eventData.keyCode
        let characters = eventData.characters

        // Arrow Up (keyCode 126) - Move selection up
        if keyCode == 126 && !modifiers.contains(.command) {
            viewModel.moveSelection(delta: -1)
            return nil
        }

        // Arrow Down (keyCode 125) - Move selection down
        if keyCode == 125 && !modifiers.contains(.command) {
            viewModel.moveSelection(delta: 1)
            return nil
        }

        // Cmd+Arrow Up - Move to top
        if keyCode == 126 && modifiers.contains(.command) {
            viewModel.moveToTop()
            return nil
        }

        // Cmd+Arrow Down - Move to bottom
        if keyCode == 125 && modifiers.contains(.command) {
            viewModel.moveToBottom()
            return nil
        }

        // Enter/Return (keyCode 36 or 76) - Confirm selection
        if (keyCode == 36 || keyCode == 76) && !modifiers.contains(.command) {
            await viewModel.confirmSelection()
            return nil
        }

        // Cmd+P - Toggle pin
        if characters.lowercased() == "p" && modifiers.contains(.command) {
            await viewModel.togglePinnedSelection()
            return nil
        }

        // Cmd+Backspace (keyCode 51) - Delete item
        if keyCode == 51 && modifiers.contains(.command) {
            await viewModel.deleteSelectedItem()
            return nil
        }

        // Cmd+F - Focus search
        if characters.lowercased() == "f" && modifiers.contains(.command) {
            return true
        }

        // Escape (keyCode 53) - Clear search or close popup
        if keyCode == 53 {
            if !viewModel.searchText.isEmpty {
                viewModel.searchText = ""
                Task { await viewModel.applySearch() }
            } else {
                await popupDismisser?.dismiss()
            }
            return nil
        }

        return nil
    }
}
