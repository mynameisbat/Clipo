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
    private let toastManager: ToastManager
    var allItems: [ClipboardItem] = []
    weak var popupDismisser: ClipboardPopupDismissing?
    @Published var visibleItems: [ClipboardItem] = []
    @Published var searchText = ""
    @Published var selectedIndex = 0
    @Published var isAccessibilityTrusted = false
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

        // Start polling permission status every 2 seconds
        self.permissionCheckTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }
                let newStatus = self.permissions.isTrusted
                if self.isAccessibilityTrusted != newStatus {
                    self.isAccessibilityTrusted = newStatus
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
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

        // Force check permission status when popup loads
        isAccessibilityTrusted = permissions.isTrusted
    }

    func refresh() async {
        await load()
    }

    func applySearch() async {
        if searchText.isEmpty {
            allItems = (try? await historyStore.recentItems(limit: 100)) ?? []
        } else {
            allItems = (try? await historyStore.search(query: searchText)) ?? []

            if allItems.isEmpty {
                toastManager.show(.info("No results found"))
            }
        }
        applyVisibleItems()
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
