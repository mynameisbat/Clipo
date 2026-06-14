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

        // Intercept all keyboard inputs when the Action Menu is open
        if viewModel.isActionMenuVisible {
            let actionsCount = viewModel.availableActions.count
            
            if keyCode == 126 && !modifiers.contains(.command) { // Arrow Up
                viewModel.selectedActionIndex = max(0, viewModel.selectedActionIndex - 1)
                return nil
            }
            if keyCode == 125 && !modifiers.contains(.command) { // Arrow Down
                viewModel.selectedActionIndex = min(max(actionsCount - 1, 0), viewModel.selectedActionIndex + 1)
                return nil
            }
            if keyCode == 36 || keyCode == 76 { // Enter
                let actions = viewModel.availableActions
                if actions.indices.contains(viewModel.selectedActionIndex) {
                    let action = actions[viewModel.selectedActionIndex]
                    await viewModel.executeAction(action)
                }
                return nil
            }
            if keyCode == 53 { // Escape
                viewModel.isActionMenuVisible = false
                return nil
            }
            if characters.lowercased() == "k" && modifiers.contains(.command) { // Cmd+K
                viewModel.isActionMenuVisible = false
                return nil
            }
            return nil
        }

        // Cmd+K - Open action menu
        if characters.lowercased() == "k" && modifiers.contains(.command) {
            if viewModel.selectedItem != nil {
                viewModel.selectedActionIndex = 0
                viewModel.isActionMenuVisible = true
            }
            return nil
        }

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

        // Option + Enter/Return (keyCode 36 or 76 with Option modifier) - Paste next item in Paste Stack
        if (keyCode == 36 || keyCode == 76) && modifiers.contains(.option) {
            await viewModel.popAndPasteStack()
            return nil
        }

        // Shift + Enter/Return (keyCode 36 or 76 with Shift modifier) - Paste as Plain Text
        if (keyCode == 36 || keyCode == 76) && modifiers.contains(.shift) {
            await viewModel.pasteSelectedAsPlainText()
            return nil
        }

        // Enter/Return (keyCode 36 or 76) - Confirm selection
        if (keyCode == 36 || keyCode == 76) && !modifiers.contains(.command) && !modifiers.contains(.option) && !modifiers.contains(.shift) {
            await viewModel.confirmSelection()
            return nil
        }

        // Cmd+P - Toggle pin
        if characters.lowercased() == "p" && modifiers.contains(.command) {
            await viewModel.togglePinnedSelection()
            return nil
        }

        // Cmd+C - Copy selected item as plain text
        if characters.lowercased() == "c" && modifiers.contains(.command) && !modifiers.contains(.shift) && !modifiers.contains(.option) {
            if let index = viewModel.visibleItems.firstIndex(where: { $0.id == viewModel.selectedItem?.id }) {
                await viewModel.copyAsPlainText(at: index)
                return nil
            }
        }

        // Cmd+Shift+C - Add to Paste Stack
        if characters.lowercased() == "c" && modifiers.contains(.command) && modifiers.contains(.shift) {
            if let item = viewModel.selectedItem {
                viewModel.addToStack(item)
                return nil
            }
        }

        // Cmd+T - Toggle pause/resume history collection
        if characters.lowercased() == "t" && modifiers.contains(.command) {
            AppEnvironment.shared?.toggleMonitoringPaused()
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

        // Space key (keyCode 49) - Toggle Quick Look (only when search field is NOT focused)
        if keyCode == 49 && !currentSearchFocused {
            viewModel.toggleQuickLook()
            return nil
        }

        // Escape (keyCode 53) - Close Quick Look, clear search, or close popup
        if keyCode == 53 {
            if viewModel.isQuickLookVisible {
                viewModel.isQuickLookVisible = false
            } else if !viewModel.searchText.isEmpty {
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
