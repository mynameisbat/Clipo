import XCTest
import AppKit
@testable import Clipo

@MainActor
final class KeyboardNavigationHandlerTests: XCTestCase {
    var viewModel: ClipboardPopupViewModel!
    var dismisser: MockPopupDismisser!
    var mockHistoryStore: MockKeyboardHistoryStore!

    override func setUp() async throws {
        try await super.setUp()
        mockHistoryStore = MockKeyboardHistoryStore()
        viewModel = ClipboardPopupViewModel(
            historyStore: mockHistoryStore,
            pasteService: MockKeyboardPasteService(),
            permissions: MockKeyboardPermissions(),
            applicationTerminator: MockKeyboardTerminator(),
            toastManager: ToastManager()
        )
        dismisser = MockPopupDismisser()
    }

    override func tearDown() async throws {
        viewModel = nil
        dismisser = nil
        mockHistoryStore = nil
        try await super.tearDown()
    }

    // MARK: - Arrow Navigation

    func testArrowUpMovesSelectionUp() async {
        // Given: Event data for arrow up, viewModel with items
        await viewModel.load()
        viewModel.selectedIndex = 5
        let eventData = KeyEventData(keyCode: 126, modifiers: [], characters: "")

        // When: Handle key event
        let result = await KeyboardNavigationHandler.handleKeyEvent(
            eventData,
            viewModel: viewModel,
            currentSearchFocused: false,
            popupDismisser: dismisser
        )

        // Then: Should move selection up
        XCTAssertEqual(viewModel.selectedIndex, 4)
        XCTAssertNil(result)
    }

    func testArrowDownMovesSelectionDown() async {
        // Given: Event data for arrow down
        await viewModel.load()
        viewModel.selectedIndex = 0
        let eventData = KeyEventData(keyCode: 125, modifiers: [], characters: "")

        // When: Handle key event
        let result = await KeyboardNavigationHandler.handleKeyEvent(
            eventData,
            viewModel: viewModel,
            currentSearchFocused: false,
            popupDismisser: dismisser
        )

        // Then: Should move selection down
        XCTAssertEqual(viewModel.selectedIndex, 1)
        XCTAssertNil(result)
    }

    func testCmdArrowUpMovesToTop() async {
        // Given: Event data for Cmd+Arrow Up
        await viewModel.load()
        viewModel.selectedIndex = 5
        let eventData = KeyEventData(keyCode: 126, modifiers: .command, characters: "")

        // When: Handle key event
        let result = await KeyboardNavigationHandler.handleKeyEvent(
            eventData,
            viewModel: viewModel,
            currentSearchFocused: false,
            popupDismisser: dismisser
        )

        // Then: Should move to top
        XCTAssertEqual(viewModel.selectedIndex, 0)
        XCTAssertNil(result)
    }

    func testCmdArrowDownMovesToBottom() async {
        // Given: Event data for Cmd+Arrow Down
        await viewModel.load()
        viewModel.selectedIndex = 0
        let eventData = KeyEventData(keyCode: 125, modifiers: .command, characters: "")

        // When: Handle key event
        let result = await KeyboardNavigationHandler.handleKeyEvent(
            eventData,
            viewModel: viewModel,
            currentSearchFocused: false,
            popupDismisser: dismisser
        )

        // Then: Should move to bottom
        XCTAssertTrue(viewModel.selectedIndex > 0)
        XCTAssertNil(result)
    }

    // MARK: - Action Keys

    func testCmdFFocusesSearch() async {
        // Given: Event data for Cmd+F
        let eventData = KeyEventData(keyCode: 3, modifiers: .command, characters: "f")

        // When: Handle key event
        let result = await KeyboardNavigationHandler.handleKeyEvent(
            eventData,
            viewModel: viewModel,
            currentSearchFocused: false,
            popupDismisser: dismisser
        )

        // Then: Should return true to focus search
        XCTAssertEqual(result, true)
    }

    // MARK: - Escape Key

    func testEscapeClearsSearchWhenNotEmpty() async {
        // Given: Event data for Escape with non-empty search
        await viewModel.load()
        viewModel.searchText = "test"
        let eventData = KeyEventData(keyCode: 53, modifiers: [], characters: "")

        // When: Handle key event
        let result = await KeyboardNavigationHandler.handleKeyEvent(
            eventData,
            viewModel: viewModel,
            currentSearchFocused: false,
            popupDismisser: dismisser
        )

        // Then: Should clear search text
        XCTAssertEqual(viewModel.searchText, "")
        XCTAssertFalse(dismisser.dismissed)
        XCTAssertNil(result)
    }

    func testEscapeDismissesPopupWhenSearchEmpty() async {
        // Given: Event data for Escape with empty search
        await viewModel.load()
        viewModel.searchText = ""
        let eventData = KeyEventData(keyCode: 53, modifiers: [], characters: "")

        // When: Handle key event
        let result = await KeyboardNavigationHandler.handleKeyEvent(
            eventData,
            viewModel: viewModel,
            currentSearchFocused: false,
            popupDismisser: dismisser
        )

        // Then: Should dismiss popup
        XCTAssertTrue(dismisser.dismissed)
        XCTAssertNil(result)
    }

    func testSpaceTogglesQuickLookWhenSearchNotFocused() async {
        // Given: Event data for Space key
        await viewModel.load()
        viewModel.selectedIndex = 0
        XCTAssertFalse(viewModel.isQuickLookVisible)
        let eventData = KeyEventData(keyCode: 49, modifiers: [], characters: " ")

        // When: Handle key event
        let result = await KeyboardNavigationHandler.handleKeyEvent(
            eventData,
            viewModel: viewModel,
            currentSearchFocused: false,
            popupDismisser: dismisser
        )

        // Then: Quick Look should toggle to visible
        XCTAssertTrue(viewModel.isQuickLookVisible)
        XCTAssertNil(result)

        // When: Escape is pressed with Quick Look open
        let escEvent = KeyEventData(keyCode: 53, modifiers: [], characters: "")
        _ = await KeyboardNavigationHandler.handleKeyEvent(
            escEvent,
            viewModel: viewModel,
            currentSearchFocused: false,
            popupDismisser: dismisser
        )

        // Then: Quick Look should close
        XCTAssertFalse(viewModel.isQuickLookVisible)
    }

    func testCmdKOpensAndNavigatesActionMenu() async {
        // Given: Event data for Cmd+K
        await viewModel.load()
        viewModel.selectedIndex = 0
        XCTAssertFalse(viewModel.isActionMenuVisible)
        let cmdKEvent = KeyEventData(keyCode: 40, modifiers: .command, characters: "k")

        // When: Handle Cmd+K
        let result = await KeyboardNavigationHandler.handleKeyEvent(
            cmdKEvent,
            viewModel: viewModel,
            currentSearchFocused: false,
            popupDismisser: dismisser
        )

        // Then: Action Menu should open
        XCTAssertTrue(viewModel.isActionMenuVisible)
        XCTAssertEqual(viewModel.selectedActionIndex, 0)
        XCTAssertNil(result)

        // When: Arrow Down is pressed inside Action Menu
        let arrowDownEvent = KeyEventData(keyCode: 125, modifiers: [], characters: "")
        _ = await KeyboardNavigationHandler.handleKeyEvent(
            arrowDownEvent,
            viewModel: viewModel,
            currentSearchFocused: false,
            popupDismisser: dismisser
        )

        // Then: Action menu index should increase
        XCTAssertEqual(viewModel.selectedActionIndex, 1)

        // When: Arrow Up is pressed inside Action Menu
        let arrowUpEvent = KeyEventData(keyCode: 126, modifiers: [], characters: "")
        _ = await KeyboardNavigationHandler.handleKeyEvent(
            arrowUpEvent,
            viewModel: viewModel,
            currentSearchFocused: false,
            popupDismisser: dismisser
        )

        // Then: Action menu index should decrease
        XCTAssertEqual(viewModel.selectedActionIndex, 0)

        // When: Escape is pressed inside Action Menu
        let escEvent = KeyEventData(keyCode: 53, modifiers: [], characters: "")
        _ = await KeyboardNavigationHandler.handleKeyEvent(
            escEvent,
            viewModel: viewModel,
            currentSearchFocused: false,
            popupDismisser: dismisser
        )

        // Then: Action menu should close
        XCTAssertFalse(viewModel.isActionMenuVisible)
    }

    func testOptionEnterPastsNextItemFromPasteStack() async {
        // Given: Paste stack has items
        await viewModel.load()
        let item1 = ClipboardItem(id: UUID(), kind: .text, title: "Item 1", contentText: "Item 1", resourcePath: nil, sourceAppBundleId: nil, createdAt: Date(), isPinned: false)
        let item2 = ClipboardItem(id: UUID(), kind: .text, title: "Item 2", contentText: "Item 2", resourcePath: nil, sourceAppBundleId: nil, createdAt: Date(), isPinned: false)
        viewModel.pasteStack = [item1, item2]
        viewModel.popupDismisser = dismisser

        // Event for Option+Enter (keyCode 36 with option modifier)
        let optionEnterEvent = KeyEventData(keyCode: 36, modifiers: .option, characters: "\r")

        // When: Option+Enter is pressed
        let result = await KeyboardNavigationHandler.handleKeyEvent(
            optionEnterEvent,
            viewModel: viewModel,
            currentSearchFocused: false,
            popupDismisser: dismisser
        )

        // Then: Should pop first item from stack, leaving 1 item
        XCTAssertEqual(viewModel.pasteStack.count, 1)
        XCTAssertEqual(viewModel.pasteStack.first?.title, "Item 2")
        XCTAssertTrue(dismisser.dismissed)
        XCTAssertNil(result)
    }
    
    func testShiftEnterPastesSelectedItemAsPlainText() async {
        // Given: View model loaded and item selected
        await viewModel.load()
        viewModel.selectedIndex = 0
        viewModel.popupDismisser = dismisser
        
        // Event for Shift+Enter (keyCode 36 with shift modifier)
        let shiftEnterEvent = KeyEventData(keyCode: 36, modifiers: .shift, characters: "\r")
        
        // When: Shift+Enter is pressed
        let result = await KeyboardNavigationHandler.handleKeyEvent(
            shiftEnterEvent,
            viewModel: viewModel,
            currentSearchFocused: false,
            popupDismisser: dismisser
        )
        
        // Then: Should dismiss popup and trigger paste
        XCTAssertTrue(dismisser.dismissed)
        XCTAssertNil(result)
    }

    func testCmdCCopiesSelectedItemAsPlainText() async {
        // Given: View model loaded and item selected
        await viewModel.load()
        viewModel.selectedIndex = 0
        
        // Event for Cmd+C (keyCode 8 with command modifier)
        let cmdCEvent = KeyEventData(keyCode: 8, modifiers: .command, characters: "c")
        
        // When: Cmd+C is pressed
        let result = await KeyboardNavigationHandler.handleKeyEvent(
            cmdCEvent,
            viewModel: viewModel,
            currentSearchFocused: false,
            popupDismisser: dismisser
        )
        
        // Then: Should intercept and copy
        XCTAssertNil(result)
        XCTAssertFalse(dismisser.dismissed)
    }

    func testCmdShiftCAddsToPasteStack() async {
        // Given: View model loaded and item selected
        await viewModel.load()
        viewModel.selectedIndex = 0
        XCTAssertEqual(viewModel.pasteStack.count, 0)
        
        // Event for Cmd+Shift+C (keyCode 8 with command and shift modifiers)
        let cmdShiftCEvent = KeyEventData(keyCode: 8, modifiers: [.command, .shift], characters: "c")
        
        // When: Cmd+Shift+C is pressed
        let result = await KeyboardNavigationHandler.handleKeyEvent(
            cmdShiftCEvent,
            viewModel: viewModel,
            currentSearchFocused: false,
            popupDismisser: dismisser
        )
        
        // Then: Should add selected item to paste stack
        XCTAssertEqual(viewModel.pasteStack.count, 1)
        XCTAssertEqual(viewModel.pasteStack.first?.title, "Item 0")
        XCTAssertNil(result)
        XCTAssertFalse(dismisser.dismissed)
    }

    func testCmdTKeyIntercepted() async {
        // Given: Key event for Cmd+T (keyCode 17 with command modifier)
        let cmdTEvent = KeyEventData(keyCode: 17, modifiers: .command, characters: "t")
        
        // When: Handle event
        let result = await KeyboardNavigationHandler.handleKeyEvent(
            cmdTEvent,
            viewModel: viewModel,
            currentSearchFocused: false,
            popupDismisser: dismisser
        )
        
        // Then: Should be intercepted and handled (returns nil)
        XCTAssertNil(result)
    }
}

// MARK: - Mock Objects

class MockPopupDismisser: ClipboardPopupDismissing {
    var dismissed = false

    func dismiss() async {
        dismissed = true
    }
}

final class MockKeyboardHistoryStore: ClipboardHistoryLoading, @unchecked Sendable {
    func recentItems(limit: Int) async throws -> [ClipboardItem] {
        // Return 10 mock items for testing
        (0..<10).map { index in
            ClipboardItem(
                id: UUID(),
                kind: .text,
                title: "Item \(index)",
                contentText: "Content \(index)",
                resourcePath: nil,
                sourceAppBundleId: nil,
                createdAt: Date(),
                isPinned: false
            )
        }
    }

    func search(query: String) async throws -> [ClipboardItem] { [] }
    func setPinned(id: UUID, isPinned: Bool) async throws {}
    func setPinboard(id: UUID, pinboard: String?) async throws {}
    func removePinboard(named name: String) async throws {}
    func delete(id: UUID) async throws {}
    func clearHistory() async throws {}
    func updateCreatedAt(id: UUID, date: Date) async throws {}

    func recentItems(limit: Int, filters: Set<HistoryFilter>) async throws -> [ClipboardItem] {
        try await recentItems(limit: limit)
    }

    func search(query: String, filters: Set<HistoryFilter>) async throws -> [ClipboardItem] {
        try await search(query: query)
    }
}

final class MockKeyboardPasteService: PasteService, @unchecked Sendable {
    func paste(_ item: ClipboardItem) async throws -> PasteResult { .copiedOnly }
    func pasteAsPlainText(_ item: ClipboardItem) async throws -> PasteResult { .copiedOnly }
    func copyAsPlainText(_ item: ClipboardItem) async throws {}
}

final class MockKeyboardPermissions: AccessibilityPermissionChecking, @unchecked Sendable {
    var isTrusted: Bool { true }
    func requestTrustIfNeeded() {}
    func openSystemSettings() {}
}

final class MockKeyboardTerminator: ApplicationTerminating, @unchecked Sendable {
    func terminate() {}
}
