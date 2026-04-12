import Foundation
import SwiftUI

protocol PasteService: AnyObject, Sendable {
    func paste(_ item: ClipboardItem) async throws -> PasteResult
}

@MainActor
final class ClipboardPopupViewModel: ObservableObject, ClipboardPopupLoading {
    private let historyStore: ClipboardHistoryLoading
    private let pasteService: PasteService
    private let permissions: AccessibilityPermissionChecking
    private let applicationTerminator: ApplicationTerminating
    var allItems: [ClipboardItem] = []
    weak var popupDismisser: ClipboardPopupDismissing?
    @Published var visibleItems: [ClipboardItem] = []
    @Published var searchText = ""
    @Published var selectedIndex = 0
    @AppStorage(HistoryRetentionPolicy.storageKey) var historyRetentionPolicy: HistoryRetentionPolicy = .defaultPolicy

    init(
        historyStore: ClipboardHistoryLoading,
        pasteService: PasteService,
        permissions: AccessibilityPermissionChecking,
        applicationTerminator: ApplicationTerminating = ApplicationTerminator()
    ) {
        self.historyStore = historyStore
        self.pasteService = pasteService
        self.permissions = permissions
        self.applicationTerminator = applicationTerminator
    }

    var selectedItem: ClipboardItem? {
        guard visibleItems.indices.contains(selectedIndex) else { return nil }
        return visibleItems[selectedIndex]
    }

    var isAccessibilityTrusted: Bool {
        permissions.isTrusted
    }

    func load() async {
        allItems = (try? await historyStore.recentItems(limit: 100)) ?? []
        applyVisibleItems()
    }

    func refresh() async {
        await load()
    }

    func applySearch() async {
        if searchText.isEmpty {
            allItems = (try? await historyStore.recentItems(limit: 100)) ?? []
        } else {
            allItems = (try? await historyStore.search(query: searchText)) ?? []
        }
        applyVisibleItems()
    }

    func confirmSelection() async {
        guard let selectedItem else { return }
        await popupDismisser?.dismiss()
        try? await Task.sleep(nanoseconds: 120_000_000)
        _ = try? await pasteService.paste(selectedItem)
    }

    func togglePinnedSelection() async {
        guard let selectedItem else { return }
        try? await historyStore.setPinned(id: selectedItem.id, isPinned: !selectedItem.isPinned)
        await load()
    }

    func deleteSelectedItem() async {
        guard let selectedItem else { return }
        try? await historyStore.delete(id: selectedItem.id)
        await applySearch()
    }

    func deleteItem(at index: Int) async {
        guard visibleItems.indices.contains(index) else { return }
        selectedIndex = index
        await deleteSelectedItem()
    }

    func clearHistory() async {
        try? await historyStore.clearHistory()
        await applySearch()
    }

    func moveSelection(delta: Int) {
        selectedIndex = max(0, min(selectedIndex + delta, max(visibleItems.count - 1, 0)))
    }

    func moveToTop() {
        selectedIndex = 0
    }

    func moveToBottom() {
        selectedIndex = max(visibleItems.count - 1, 0)
    }

    func quitApp() {
        applicationTerminator.terminate()
    }

    func openAccessibilitySettings() {
        permissions.openSystemSettings()
    }

    func activateItem(at index: Int) async {
        guard visibleItems.indices.contains(index) else { return }
        selectedIndex = index
        await confirmSelection()
    }

    private func applyVisibleItems() {
        visibleItems = allItems
        selectedIndex = min(selectedIndex, max(visibleItems.count - 1, 0))
    }
}
