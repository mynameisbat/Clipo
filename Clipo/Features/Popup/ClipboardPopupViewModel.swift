import Foundation
import SwiftUI

protocol PasteService: AnyObject, Sendable {
    func paste(_ item: ClipboardItem) async throws -> PasteResult
    func copyAsPlainText(_ item: ClipboardItem) async throws
}

@MainActor
final class ClipboardPopupViewModel: ObservableObject, ClipboardPopupLoading {
    private let historyStore: ClipboardHistoryLoading
    private let pasteService: PasteService
    private let permissions: AccessibilityPermissionChecking
    private let applicationTerminator: ApplicationTerminating
    private let toastManager: ToastManager
    var allItems: [ClipboardItem] = []
    weak var popupDismisser: ClipboardPopupDismissing?
    @Published var visibleItems: [ClipboardItem] = []
    @Published var searchText = ""
    @Published var selectedIndex = 0
    @Published var isAccessibilityTrusted = false
    @Published var activeFilters: Set<HistoryFilter> = []
    @AppStorage(HistoryRetentionPolicy.storageKey) var historyRetentionPolicy: HistoryRetentionPolicy = .defaultPolicy
    private var permissionCheckTask: Task<Void, Never>?

    init(
        historyStore: ClipboardHistoryLoading,
        pasteService: PasteService,
        permissions: AccessibilityPermissionChecking,
        applicationTerminator: ApplicationTerminating = ApplicationTerminator(),
        toastManager: ToastManager = ToastManager()
    ) {
        self.historyStore = historyStore
        self.pasteService = pasteService
        self.permissions = permissions
        self.applicationTerminator = applicationTerminator
        self.toastManager = toastManager
        self.isAccessibilityTrusted = permissions.isTrusted

        self.permissionCheckTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                let newStatus = self.permissions.isTrusted
                if self.isAccessibilityTrusted != newStatus {
                    self.isAccessibilityTrusted = newStatus
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    deinit {
        permissionCheckTask?.cancel()
    }

    var toastManagerForView: ToastManager {
        toastManager
    }

    var selectedItem: ClipboardItem? {
        guard visibleItems.indices.contains(selectedIndex) else { return nil }
        return visibleItems[selectedIndex]
    }

    func load() async {
        allItems = (try? await historyStore.recentItems(limit: 100)) ?? []
        applyVisibleItems()

        isAccessibilityTrusted = permissions.isTrusted
    }

    func refresh() async {
        await load()
    }

    func applySearch() async {
        let query = searchText
        let filters = activeFilters
        do {
            if query.isEmpty {
                if filters.isEmpty {
                    allItems = try await historyStore.recentItems(limit: 100)
                } else {
                    allItems = try await historyStore.recentItems(limit: 100, filters: filters)
                }
            } else {
                if filters.isEmpty {
                    allItems = try await historyStore.search(query: query)
                } else {
                    allItems = try await historyStore.search(query: query, filters: filters)
                }
                if allItems.isEmpty {
                    toastManager.show(.info("No results found"))
                }
            }
        } catch {
            allItems = []
        }
        applyVisibleItems()
    }

    func toggleFilter(_ filter: HistoryFilter) {
        if activeFilters.contains(filter) {
            activeFilters.remove(filter)
        } else {
            activeFilters.insert(filter)
        }
        Task { await applySearch() }
    }

    func clearFilters() {
        guard !activeFilters.isEmpty else { return }
        activeFilters.removeAll()
        Task { await applySearch() }
    }

    func confirmSelection() async {
        guard let selectedItem else { return }
        await popupDismisser?.dismiss()
        try? await Task.sleep(nanoseconds: 120_000_000)

        let result = try? await pasteService.paste(selectedItem)

        if result == .pasted {
            toastManager.show(.success("Pasted successfully"))
        } else if result == .copiedOnly {
            toastManager.show(.info("Copied to clipboard"))
        } else {
            toastManager.show(.error("Failed to paste"))
        }
    }

    func togglePinnedSelection() async {
        guard let selectedItem else { return }
        let wasPinned = selectedItem.isPinned
        try? await historyStore.setPinned(id: selectedItem.id, isPinned: !wasPinned)
        await load()

        if wasPinned {
            toastManager.show(.success("Item unpinned"))
        } else {
            toastManager.show(.success("Item pinned"))
        }
    }

    func togglePinned(at index: Int) async {
        guard visibleItems.indices.contains(index) else { return }
        let item = visibleItems[index]
        let newPinned = !item.isPinned
        try? await historyStore.setPinned(id: item.id, isPinned: newPinned)
        await load()
        toastManager.show(.success(newPinned ? "Item pinned" : "Item unpinned"))
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
        toastManager.show(.success("Item deleted"))
    }

    func copyAsPlainText(at index: Int) async {
        guard visibleItems.indices.contains(index) else { return }
        let item = visibleItems[index]
        do {
            try await pasteService.copyAsPlainText(item)
            toastManager.show(.success("Copied as plain text"))
        } catch {
            toastManager.show(.error("Copy failed"))
        }
    }

    func clearHistory() async {
        try? await historyStore.clearHistory()
        await applySearch()
        toastManager.show(.success("History cleared"))
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
