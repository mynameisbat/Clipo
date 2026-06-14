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
                pinboard: items[index].pinboard,
                metadata: items[index].metadata
            )
        }
    }

    func setPinboard(id: UUID, pinboard: String?) async throws {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index] = ClipboardItem(
                id: items[index].id,
                kind: items[index].kind,
                title: items[index].title,
                contentText: items[index].contentText,
                resourcePath: items[index].resourcePath,
                sourceAppBundleId: items[index].sourceAppBundleId,
                createdAt: items[index].createdAt,
                isPinned: items[index].isPinned,
                pinboard: pinboard,
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

    func recentItems(limit: Int, filters: Set<HistoryFilter>) async throws -> [ClipboardItem] {
        return try await recentItems(limit: limit) // Simple fallback for mock
    }

    func search(query: String, filters: Set<HistoryFilter>) async throws -> [ClipboardItem] {
        return try await search(query: query) // Simple fallback for mock
    }

    func removePinboard(named name: String) async throws {
        for index in items.indices {
            if items[index].pinboard == name {
                items[index] = ClipboardItem(
                    id: items[index].id,
                    kind: items[index].kind,
                    title: items[index].title,
                    contentText: items[index].contentText,
                    resourcePath: items[index].resourcePath,
                    sourceAppBundleId: items[index].sourceAppBundleId,
                    createdAt: items[index].createdAt,
                    isPinned: items[index].isPinned,
                    pinboard: nil,
                    metadata: items[index].metadata
                )
            }
        }
    }

    func updateCreatedAt(id: UUID, date: Date) async throws {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index] = ClipboardItem(
                id: items[index].id,
                kind: items[index].kind,
                title: items[index].title,
                contentText: items[index].contentText,
                resourcePath: items[index].resourcePath,
                sourceAppBundleId: items[index].sourceAppBundleId,
                createdAt: date,
                isPinned: items[index].isPinned,
                pinboard: items[index].pinboard,
                metadata: items[index].metadata
            )
        }
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

    func pasteAsPlainText(_ item: ClipboardItem) async throws -> PasteResult {
        _pasteCallCount += 1
        _lastPastedItem = item
        return resultToReturn
    }

    func copyAsPlainText(_ item: ClipboardItem) async throws {}
}
