import XCTest
@testable import Clipo

@MainActor
final class ClipboardPopupViewModelTests: XCTestCase {
    func testSearchFiltersVisibleItems() async throws {
        let store = InMemoryClipboardHistoryStore(items: [
            .stub(title: "Release note", contentText: "Ship Friday"),
            .stub(title: "Random", contentText: "Nothing here")
        ])
        let viewModel = ClipboardPopupViewModel(
            historyStore: store,
            pasteService: MockPasteService(),
            permissions: StubAccessibilityPermissionService(isTrusted: true)
        )

        await viewModel.load()
        viewModel.searchText = "Ship"
        await viewModel.applySearch()

        XCTAssertEqual(viewModel.visibleItems.map(\.title), ["Release note"])
    }

    func testMoveSelectionClampsInsideBounds() async throws {
        let store = InMemoryClipboardHistoryStore(items: [.stub(title: "A"), .stub(title: "B")])
        let viewModel = ClipboardPopupViewModel(
            historyStore: store,
            pasteService: MockPasteService(),
            permissions: StubAccessibilityPermissionService(isTrusted: true)
        )

        await viewModel.load()
        viewModel.moveSelection(delta: 1)
        viewModel.moveSelection(delta: 10)

        XCTAssertEqual(viewModel.selectedItem?.title, "B")
    }

    func testQuitAppDelegatesToApplicationTerminator() async throws {
        let terminator = MockApplicationTerminator()
        let viewModel = ClipboardPopupViewModel(
            historyStore: InMemoryClipboardHistoryStore(items: []),
            pasteService: MockPasteService(),
            permissions: StubAccessibilityPermissionService(isTrusted: true),
            applicationTerminator: terminator
        )

        viewModel.quitApp()

        XCTAssertEqual(terminator.terminateCalls, 1)
    }

    func testActivateItemSelectsAndPastesChosenRow() async throws {
        let pasteService = MockPasteService()
        let eventRecorder = PopupEventRecorder()
        pasteService.eventRecorder = eventRecorder
        let dismissController = RecordingPopupDismissController(eventRecorder: eventRecorder)
        let viewModel = ClipboardPopupViewModel(
            historyStore: InMemoryClipboardHistoryStore(items: [.stub(title: "A"), .stub(title: "B")]),
            pasteService: pasteService,
            permissions: StubAccessibilityPermissionService(isTrusted: true),
            applicationTerminator: MockApplicationTerminator()
        )
        viewModel.popupDismisser = dismissController

        await viewModel.load()
        await viewModel.activateItem(at: 1)

        XCTAssertEqual(viewModel.selectedItem?.title, "B")
        XCTAssertEqual(pasteService.pastedTitles, ["B"])
        XCTAssertEqual(dismissController.dismissCalls, 1)
        XCTAssertEqual(eventRecorder.events, ["dismiss", "paste"])
    }

    func testOpenAccessibilitySettingsDelegatesToPermissionService() {
        let permissions = StubAccessibilityPermissionService(isTrusted: false)
        let viewModel = ClipboardPopupViewModel(
            historyStore: InMemoryClipboardHistoryStore(items: []),
            pasteService: MockPasteService(),
            permissions: permissions,
            applicationTerminator: MockApplicationTerminator()
        )

        viewModel.openAccessibilitySettings()

        XCTAssertEqual(permissions.openSystemSettingsCalls, 1)
        XCTAssertFalse(viewModel.isAccessibilityTrusted)
    }

    func testDeleteSelectedItemRemovesItFromVisibleItems() async throws {
        let store = InMemoryClipboardHistoryStore(items: [.stub(title: "A"), .stub(title: "B")])
        let viewModel = ClipboardPopupViewModel(
            historyStore: store,
            pasteService: MockPasteService(),
            permissions: StubAccessibilityPermissionService(isTrusted: true)
        )

        await viewModel.load()
        viewModel.moveSelection(delta: 1)
        await viewModel.deleteSelectedItem()

        XCTAssertEqual(viewModel.visibleItems.map(\.title), ["A"])
    }

    func testClearHistoryKeepsPinnedItemsVisible() async throws {
        let store = InMemoryClipboardHistoryStore(items: [
            .stub(title: "Pinned", isPinned: true),
            .stub(title: "Regular")
        ])
        let viewModel = ClipboardPopupViewModel(
            historyStore: store,
            pasteService: MockPasteService(),
            permissions: StubAccessibilityPermissionService(isTrusted: true)
        )

        await viewModel.load()
        await viewModel.clearHistory()

        XCTAssertEqual(viewModel.visibleItems.map(\.title), ["Pinned"])
    }
}

final class MockPasteService: PasteService, @unchecked Sendable {
    private(set) var pastedTitles: [String] = []
    var eventRecorder: PopupEventRecorder?

    func paste(_ item: ClipboardItem) async throws -> PasteResult {
        eventRecorder?.events.append("paste")
        pastedTitles.append(item.title)
        return .copiedOnly
    }
}

@MainActor
final class RecordingPopupDismissController: ClipboardPopupDismissing {
    private(set) var dismissCalls = 0
    private let eventRecorder: PopupEventRecorder

    init(eventRecorder: PopupEventRecorder) {
        self.eventRecorder = eventRecorder
    }

    func dismiss() async {
        dismissCalls += 1
        eventRecorder.events.append("dismiss")
    }
}

final class PopupEventRecorder {
    var events: [String] = []
}

final class MockClipboardWriter: ClipboardWriting {
    func write(item: ClipboardItem) throws {}
}

final class MockAutoPasteDriver: AutoPasteDriving {
    func pasteCurrentClipboard() throws {}
}

struct MockPermissions: AccessibilityPermissionChecking {
    var isTrusted: Bool { true }
    func requestTrustIfNeeded() {}
    func openSystemSettings() {}
}

final class MockApplicationTerminator: ApplicationTerminating {
    private(set) var terminateCalls = 0

    func terminate() {
        terminateCalls += 1
    }
}

actor InMemoryClipboardHistoryStore: ClipboardHistoryLoading {
    private var items: [ClipboardItem]

    init(items: [ClipboardItem]) {
        self.items = items
    }

    func recentItems(limit: Int) async throws -> [ClipboardItem] {
        Array(items.prefix(limit))
    }

    func search(query: String) async throws -> [ClipboardItem] {
        items.filter { item in
            item.title.localizedCaseInsensitiveContains(query) ||
            (item.contentText?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    func setPinned(id: UUID, isPinned: Bool) async throws {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isPinned = isPinned
    }

    func delete(id: UUID) async throws {
        items.removeAll { $0.id == id }
    }

    func clearHistory() async throws {
        items.removeAll { !$0.isPinned }
    }

    func purgeExpiredItems(olderThanDays: Int, now: Date) async throws {}
}
