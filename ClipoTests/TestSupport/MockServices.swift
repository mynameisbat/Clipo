import Foundation
@testable import Clipo

// MARK: - Shared Mock Services for Tests

final class InMemoryClipboardHistoryStore: ClipboardHistoryLoading, @unchecked Sendable {
    private var items: [ClipboardItem]

    init(items: [ClipboardItem]) {
        self.items = items
    }

    func recentItems(limit: Int) async throws -> [ClipboardItem] {
        return Array(items.prefix(limit))
    }

    func search(query: String) async throws -> [ClipboardItem] {
        return items.filter { item in
            item.title.localizedCaseInsensitiveContains(query) ||
            (item.contentText?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    func setPinned(id: UUID, isPinned: Bool) async throws {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index] = ClipboardItem(
                id: items[index].id,
                kind: items[index].kind,
                title: items[index].title,
                contentText: items[index].contentText,
                resourcePath: items[index].resourcePath,
                sourceAppBundleId: items[index].sourceAppBundleId,
                createdAt: items[index].createdAt,
                isPinned: isPinned,
                metadata: items[index].metadata
            )
        }
    }

    func delete(id: UUID) async throws {
        items.removeAll { $0.id == id }
    }

    func clearHistory() async throws {
        items.removeAll { !$0.isPinned }
    }
}

final class MockPasteService: PasteService, @unchecked Sendable {
    private var _pasteCallCount = 0
    private var _lastPastedItem: ClipboardItem?
    var resultToReturn: PasteResult = .pasted

    var pasteCallCount: Int {
        _pasteCallCount
    }

    var lastPastedItem: ClipboardItem? {
        _lastPastedItem
    }

    func paste(_ item: ClipboardItem) async throws -> PasteResult {
        _pasteCallCount += 1
        _lastPastedItem = item
        return resultToReturn
    }
}
