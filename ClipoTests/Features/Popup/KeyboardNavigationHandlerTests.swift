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
    func delete(id: UUID) async throws {}
    func clearHistory() async throws {}

    func recentItems(limit: Int, filters: Set<HistoryFilter>) async throws -> [ClipboardItem] {
        try await recentItems(limit: limit)
    }

    func search(query: String, filters: Set<HistoryFilter>) async throws -> [ClipboardItem] {
        try await search(query: query)
    }
}

final class MockKeyboardPasteService: PasteService, @unchecked Sendable {
    func paste(_ item: ClipboardItem) async throws -> PasteResult { .copiedOnly }
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
