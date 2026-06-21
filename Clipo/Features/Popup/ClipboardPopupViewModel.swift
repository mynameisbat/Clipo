import Foundation
import SwiftUI
import Vision
import AppKit
import Combine

enum ClipboardAction: Identifiable, Sendable, Hashable, Equatable {
    case paste
    case copyPlainText
    case addToStack
    case uppercase
    case lowercase
    case titleCase
    case camelCase
    case snakeCase
    case kebabCase
    case mergeLines
    case trim
    case formatJSON
    case extractTextOCR
    case editImage
    case base64Encode
    case base64Decode
    case urlEncode
    case urlDecode
    case togglePin
    case moveToPinboard(String)
    case removeFromPinboard
    case delete
    case mergeStack
    case translateToVietnamese
    case shortenURL
    case stripTracking
    case openIncognito
    
    var id: String {
        switch self {
        case .moveToPinboard(let name): return "moveToPinboard:\(name)"
        default: return String(describing: self)
        }
    }
    
    var rawValue: String {
        switch self {
        case .paste: return "Paste & Paste back"
        case .copyPlainText: return "Copy as Plain Text"
        case .addToStack: return "Add to Paste Stack"
        case .uppercase: return "Convert to UPPERCASE"
        case .lowercase: return "convert to lowercase"
        case .titleCase: return "Convert to Title Case"
        case .camelCase: return "Convert to camelCase"
        case .snakeCase: return "Convert to snake_case"
        case .kebabCase: return "Convert to kebab-case"
        case .mergeLines: return "Merge Lines (Single Paragraph)"
        case .trim: return "Trim Whitespace"
        case .formatJSON: return "Format JSON"
        case .extractTextOCR: return "Extract Text from Image (OCR)"
        case .editImage: return "Edit Image"
        case .base64Encode: return "Base64 Encode"
        case .base64Decode: return "Base64 Decode"
        case .urlEncode: return "URL Encode"
        case .urlDecode: return "URL Decode"
        case .togglePin: return "Toggle Pin"
        case .moveToPinboard(let name): return "Move to '\(name)'"
        case .removeFromPinboard: return "Remove from Pinboard"
        case .delete: return "Delete"
        case .mergeStack: return "Merge Paste Stack Items"
        case .translateToVietnamese: return "Translate to Vietnamese"
        case .shortenURL: return "Shorten URL (TinyURL)"
        case .stripTracking: return "Strip URL Tracking Parameters"
        case .openIncognito: return "Open in Incognito Mode"
        }
    }
    
    var icon: String {
        switch self {
        case .paste: return "doc.on.clipboard.fill"
        case .copyPlainText: return "doc.on.doc"
        case .addToStack: return "square.stack.3d.down.right"
        case .uppercase: return "textformat.size.larger"
        case .lowercase: return "textformat.size.smaller"
        case .titleCase: return "textformat.size"
        case .camelCase: return "textformat.alt"
        case .snakeCase: return "textformat.subscript"
        case .kebabCase: return "textformat.superscript"
        case .mergeLines: return "text.alignleft"
        case .trim: return "scissors"
        case .formatJSON: return "braces"
        case .extractTextOCR: return "text.viewfinder"
        case .editImage: return "pencil.and.outline"
        case .base64Encode: return "lock.fill"
        case .base64Decode: return "lock.open.fill"
        case .urlEncode: return "link.badge.plus"
        case .urlDecode: return "link"
        case .togglePin: return "pin"
        case .moveToPinboard: return "folder.badge.plus"
        case .removeFromPinboard: return "folder.badge.minus"
        case .delete: return "trash"
        case .mergeStack: return "square.stack.3d.up.fill"
        case .translateToVietnamese: return "character.book.closed.fill"
        case .shortenURL: return "link.badge.minus"
        case .stripTracking: return "wand.and.stars"
        case .openIncognito: return "eye.slash.circle.fill"
        }
    }

    var shortcutHint: String? {
        switch self {
        case .paste: return "⏎"
        case .copyPlainText: return "⌘C"
        case .addToStack: return "⌘⇧C"
        case .togglePin: return "⌘P"
        case .delete: return "⌘⌫"
        default: return nil
        }
    }
}

protocol PasteService: AnyObject, Sendable {
    func paste(_ item: ClipboardItem) async throws -> PasteResult
    func pasteAsPlainText(_ item: ClipboardItem) async throws -> PasteResult
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
    @Published var isQuickLookVisible = false
    @Published var isActionMenuVisible = false
    @Published var selectedActionIndex = 0
    @Published var pasteStack: [ClipboardItem] = []
    @AppStorage(HistoryRetentionPolicy.storageKey) var historyRetentionPolicy: HistoryRetentionPolicy = .defaultPolicy
    @AppStorage("clipo.pinboards") private var pinboardsStorage: String = "Templates,Emails,Code"

    var availablePinboards: [String] {
        pinboardsStorage.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
    @Published var updateAvailable = false
    @Published var latestVersion: String?
    @Published var updateURL: URL?
    @Published var isCheckingForUpdates = false
    private var updateChecker: UpdateChecker?
    private var permissionCheckTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var pendingImageEdits: [UUID: (path: String, openedAt: Date)] = [:]

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
        self.updateChecker = AppEnvironment.shared?.updateChecker

        if let checker = updateChecker {
            checker.$updateAvailable
                .sink { [weak self] in self?.updateAvailable = $0 }
                .store(in: &cancellables)
            checker.$latestVersion
                .sink { [weak self] in self?.latestVersion = $0 }
                .store(in: &cancellables)
            checker.$updateURL
                .sink { [weak self] in self?.updateURL = $0 }
                .store(in: &cancellables)
            checker.$isChecking
                .sink { [weak self] in self?.isCheckingForUpdates = $0 }
                .store(in: &cancellables)
        }

        self.permissionCheckTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }
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
        
        if let checker = updateChecker {
            self.updateAvailable = checker.updateAvailable
            self.latestVersion = checker.latestVersion
            self.updateURL = checker.updateURL
            self.isCheckingForUpdates = checker.isChecking
        }
    }

    func refresh() async {
        await checkPendingImageEdits()
        await load()
    }

    func applySearch() async {
        let (query, parsedFilters) = parseSearchText(searchText)
        let filters = activeFilters.union(parsedFilters)
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

    private func parseSearchText(_ text: String) -> (query: String, extraFilters: Set<HistoryFilter>) {
        var extraFilters = Set<HistoryFilter>()
        let tokens = text.components(separatedBy: .whitespaces)
        var remainingTokens: [String] = []
        
        for token in tokens {
            if token.hasPrefix("app:") {
                let val = String(token.dropFirst(4))
                if !val.isEmpty {
                    extraFilters.insert(.sourceApp(val))
                }
            } else if token.hasPrefix("kind:") {
                let val = String(token.dropFirst(5)).lowercased()
                if val == "text" {
                    extraFilters.insert(.kind(.text))
                } else if val == "image" || val == "images" {
                    extraFilters.insert(.kind(.image))
                } else if val == "link" || val == "links" {
                    extraFilters.insert(.kind(.link))
                } else if val == "file" || val == "files" {
                    extraFilters.insert(.kind(.file))
                }
            } else if token == "is:pinned" {
                extraFilters.insert(.pinned)
            } else {
                remainingTokens.append(token)
            }
        }
        
        let remainingQuery = remainingTokens.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return (remainingQuery, extraFilters)
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

    func pasteAsPlainText(at index: Int) async {
        guard visibleItems.indices.contains(index) else { return }
        let item = visibleItems[index]
        await popupDismisser?.dismiss()
        try? await Task.sleep(nanoseconds: 120_000_000)

        do {
            let result = try await pasteService.pasteAsPlainText(item)
            if result == .pasted {
                toastManager.show(.success("Pasted as plain text"))
            } else {
                toastManager.show(.info("Copied as plain text"))
            }
        } catch {
            toastManager.show(.error("Failed to paste"))
        }
    }

    func pasteSelectedAsPlainText() async {
        guard let selectedItem, let index = visibleItems.firstIndex(where: { $0.id == selectedItem.id }) else { return }
        await pasteAsPlainText(at: index)
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

    func checkForUpdatesManually() async {
        guard let checker = updateChecker else { return }
        isCheckingForUpdates = true
        let found = await checker.checkForUpdates(silent: false)
        self.updateAvailable = checker.updateAvailable
        self.latestVersion = checker.latestVersion
        self.updateURL = checker.updateURL
        isCheckingForUpdates = false
        
        if found {
            toastManager.show(.success("New version \(checker.latestVersion ?? "") available!"))
        } else {
            toastManager.show(.info("Clipo is up to date"))
        }
    }
    
    func dismissUpdateBanner() {
        self.updateAvailable = false
    }

    func activateItem(at index: Int) async {
        guard visibleItems.indices.contains(index) else { return }
        selectedIndex = index
        await confirmSelection()
    }

    func toggleQuickLook() {
        if selectedItem != nil {
            isQuickLookVisible.toggle()
        } else {
            isQuickLookVisible = false
        }
    }

    private func isValidURL(_ string: String?) -> Bool {
        guard let string = string?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        guard let url = URL(string: string), url.scheme != nil else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }

    var availableActions: [ClipboardAction] {
        guard let item = selectedItem else { return [] }
        var actions: [ClipboardAction] = []
        
        actions.append(.addToStack)
        actions.append(.togglePin)
        
        if item.pinboard != nil {
            actions.append(.removeFromPinboard)
        }
        
        for name in availablePinboards {
            if item.pinboard != name {
                actions.append(.moveToPinboard(name))
            }
        }
        
        if item.kind == .text || item.kind == .link {
            actions.insert(.paste, at: 0)
            actions.insert(.copyPlainText, at: 1)
            
            // Premium Quick Actions (disabled for sensitive content to prevent data leakage)
            if !item.isSensitive {
                actions.append(.translateToVietnamese)
            }
            
            let contentText = item.contentText ?? ""
            if item.kind == .link || isValidURL(contentText) {
                if !item.isSensitive {
                    actions.append(.shortenURL)
                }
                actions.append(.stripTracking)
                actions.append(.openIncognito)
            }
            
            actions.append(.uppercase)
            actions.append(.lowercase)
            actions.append(.titleCase)
            actions.append(.camelCase)
            actions.append(.snakeCase)
            actions.append(.kebabCase)
            actions.append(.mergeLines)
            actions.append(.trim)
            actions.append(.urlEncode)
            actions.append(.urlDecode)
            actions.append(.base64Encode)
            actions.append(.base64Decode)
            
            if let content = item.contentText,
               (content.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{") ||
                content.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("[")) {
                actions.append(.formatJSON)
            }
        } else if item.kind == .image {
            actions.insert(.paste, at: 0)
            actions.append(.editImage)
            actions.append(.extractTextOCR)
        } else if item.kind == .file {
            actions.insert(.paste, at: 0)
        }
        
        if pasteStack.count >= 2 {
            actions.append(.mergeStack)
        }
        
        actions.append(.delete)
        return actions
    }

    func executeAction(_ action: ClipboardAction) async {
        guard let item = selectedItem else { return }
        isActionMenuVisible = false
        
        switch action {
        case .moveToPinboard(let name):
            await setPinboardForSelected(name)
        case .removeFromPinboard:
            await setPinboardForSelected(nil)
        case .paste:
            await confirmSelection()
        case .copyPlainText:
            try? await pasteService.copyAsPlainText(item)
            toastManager.show(.success("Copied as plain text"))
        case .addToStack:
            addToStack(item)
        case .uppercase:
            if let text = item.contentText {
                let upper = text.uppercased()
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(upper, forType: .string)
                toastManager.show(.success("Copied uppercase text"))
            }
        case .lowercase:
            if let text = item.contentText {
                let lower = text.lowercased()
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(lower, forType: .string)
                toastManager.show(.success("Copied lowercase text"))
            }
        case .titleCase:
            if let text = item.contentText {
                let titleCased = text.capitalized
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(titleCased, forType: .string)
                toastManager.show(.success("Copied Title Case text"))
            }
        case .camelCase:
            if let text = item.contentText {
                let res = toCamelCase(text)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(res, forType: .string)
                toastManager.show(.success("Copied camelCase text"))
            }
        case .snakeCase:
            if let text = item.contentText {
                let res = toSnakeCase(text)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(res, forType: .string)
                toastManager.show(.success("Copied snake_case text"))
            }
        case .kebabCase:
            if let text = item.contentText {
                let res = toKebabCase(text)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(res, forType: .string)
                toastManager.show(.success("Copied kebab-case text"))
            }
        case .mergeLines:
            if let text = item.contentText {
                let res = mergeLines(text)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(res, forType: .string)
                toastManager.show(.success("Copied single line text"))
            }
        case .trim:
            if let text = item.contentText {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(trimmed, forType: .string)
                toastManager.show(.success("Copied trimmed text"))
            }
        case .formatJSON:
            if let text = item.contentText,
               let data = text.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data, options: []),
               let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]),
               let prettyString = String(data: prettyData, encoding: .utf8) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(prettyString, forType: .string)
                toastManager.show(.success("Copied formatted JSON"))
            } else {
                toastManager.show(.error("Invalid JSON"))
            }
        case .extractTextOCR:
            await performOCR(on: item)
        case .editImage:
            await editImage(item)
        case .base64Encode:
            if let text = item.contentText, let data = text.data(using: .utf8) {
                let encoded = data.base64EncodedString()
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(encoded, forType: .string)
                toastManager.show(.success("Copied Base64 encoded text"))
            }
        case .base64Decode:
            if let text = item.contentText,
               let data = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines)),
               let decoded = String(data: data, encoding: .utf8) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(decoded, forType: .string)
                toastManager.show(.success("Copied Base64 decoded text"))
            } else {
                toastManager.show(.error("Invalid Base64 string"))
            }
        case .urlEncode:
            if let text = item.contentText,
               let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(encoded, forType: .string)
                toastManager.show(.success("Copied URL encoded text"))
            }
        case .urlDecode:
            if let text = item.contentText,
               let decoded = text.removingPercentEncoding {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(decoded, forType: .string)
                toastManager.show(.success("Copied URL decoded text"))
            }
        case .togglePin:
            if let index = visibleItems.firstIndex(where: { $0.id == item.id }) {
                await togglePinned(at: index)
            }
        case .delete:
            if let index = visibleItems.firstIndex(where: { $0.id == item.id }) {
                await deleteItem(at: index)
            }
        case .mergeStack:
            await mergeStackItems()
        case .translateToVietnamese:
            if let text = item.contentText {
                if item.isSensitive {
                    toastManager.show(.error("Cannot translate sensitive text"))
                    return
                }
                if text.count > 5000 {
                    toastManager.show(.error("Text too long for translation (max 5000 characters)"))
                    return
                }
                toastManager.show(.info("Translating..."))
                do {
                    let translated = try await translateText(text, to: "vi")
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(translated, forType: .string)
                    toastManager.show(.success("Translated & copied to clipboard"))
                } catch {
                    toastManager.show(.error("Translation failed: \(error.localizedDescription)"))
                }
            }
        case .shortenURL:
            if let urlString = item.contentText {
                if item.isSensitive {
                    toastManager.show(.error("Cannot shorten sensitive URL"))
                    return
                }
                toastManager.show(.info("Shortening URL..."))
                do {
                    let shortened = try await shortenURL(urlString)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(shortened, forType: .string)
                    toastManager.show(.success("Shortened URL copied to clipboard"))
                } catch {
                    toastManager.show(.error("Shortening failed: \(error.localizedDescription)"))
                }
            }
        case .stripTracking:
            if let urlString = item.contentText {
                let stripped = stripTrackingParameters(from: urlString)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(stripped, forType: .string)
                toastManager.show(.success("Clean URL copied to clipboard"))
            }
        case .openIncognito:
            if let urlString = item.contentText,
               let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) {
                openURLInIncognito(url)
            }
        }
    }

    func mergeStackItems() async {
        guard pasteStack.count >= 2 else { return }
        let mergedText = pasteStack.compactMap { item in
            if item.kind == .text || item.kind == .link {
                return item.contentText
            }
            return item.title
        }.joined(separator: "\n")
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(mergedText, forType: .string)
        
        // Clear stack
        pasteStack.removeAll()
        toastManager.show(.success("Merged stack items & copied to clipboard"))
    }

    func addToStack(_ item: ClipboardItem) {
        pasteStack.append(item)
        toastManager.show(.success("Added to Paste Stack (\(pasteStack.count) items)"))
    }

    func clearStack() {
        pasteStack.removeAll()
        toastManager.show(.info("Paste Stack cleared"))
    }

    func removeFromStack(at index: Int) {
        guard pasteStack.indices.contains(index) else { return }
        pasteStack.remove(at: index)
    }

    func popAndPasteStack() async {
        guard !pasteStack.isEmpty else {
            toastManager.show(.info("Paste Stack is empty"))
            return
        }
        let item = pasteStack.removeFirst()
        await popupDismisser?.dismiss()
        try? await Task.sleep(nanoseconds: 120_000_000)
        
        let result = try? await pasteService.paste(item)
        if result == .pasted {
            toastManager.show(.success("Pasted from stack"))
        } else if result == .copiedOnly {
            toastManager.show(.info("Copied from stack"))
        }
    }

    func editImage(_ item: ClipboardItem) async {
        guard let path = item.resourcePath else { return }
        let fileURL = URL(fileURLWithPath: path)
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        let modDate = attrs?[.modificationDate] as? Date ?? Date()
        
        pendingImageEdits[item.id] = (path, modDate)
        NSWorkspace.shared.open(fileURL)
        toastManager.show(.info("Opening image in Preview..."))
    }

    private func checkPendingImageEdits() async {
        var idsToRemove: [UUID] = []
        
        for (id, editInfo) in pendingImageEdits {
            let path = editInfo.path
            let fileURL = URL(fileURLWithPath: path)
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                  let currentModDate = attrs[.modificationDate] as? Date else { continue }
            
            if currentModDate > editInfo.openedAt {
                await regenerateThumbnail(for: fileURL)
                do {
                    try await historyStore.updateCreatedAt(id: id, date: Date())
                    toastManager.show(.success("Image updated"))
                } catch {
                    toastManager.show(.error("Failed to update edited image"))
                }
                idsToRemove.append(id)
            }
        }
        
        for id in idsToRemove {
            pendingImageEdits.removeValue(forKey: id)
        }
    }

    private func regenerateThumbnail(for fileURL: URL) async {
        let directory = fileURL.deletingLastPathComponent()
        let uuid = fileURL.deletingPathExtension().lastPathComponent
        let thumbURL = directory.appendingPathComponent("\(uuid)_thumb.png")
        
        guard let data = try? Data(contentsOf: fileURL) else { return }
        
        let generator = ThumbnailGenerator()
        if let thumbnailData = try? await generator.generateThumbnail(from: data) {
            try? thumbnailData.write(to: thumbURL)
        }
    }

    func performOCR(on item: ClipboardItem) async {
        guard let path = item.resourcePath else { return }
        let url = URL(fileURLWithPath: path)
        guard let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            toastManager.show(.error("Failed to load image"))
            return
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self else { return }
            if let error {
                Task { @MainActor in
                    self.toastManager.show(.error("OCR error: \(error.localizedDescription)"))
                }
                return
            }
            
            guard let results = request.results as? [VNRecognizedTextObservation] else { return }
            let recognizedStrings = results.compactMap { $0.topCandidates(1).first?.string }
            let fullText = recognizedStrings.joined(separator: "\n")
            
            Task { @MainActor in
                if fullText.isEmpty {
                    self.toastManager.show(.info("No text detected in image"))
                } else {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(fullText, forType: .string)
                    self.toastManager.show(.success("Text extracted & copied"))
                }
            }
        }
        
        request.recognitionLevel = .accurate
        try? requestHandler.perform([request])
    }

    private func toCamelCase(_ text: String) -> String {
        let words = text.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        guard !words.isEmpty else { return text }
        let first = words[0].lowercased()
        let rest = words.dropFirst().map { $0.capitalized }
        return ([first] + rest).joined()
    }

    private func toSnakeCase(_ text: String) -> String {
        let words = text.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        return words.map { $0.lowercased() }.joined(separator: "_")
    }

    private func toKebabCase(_ text: String) -> String {
        let words = text.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        return words.map { $0.lowercased() }.joined(separator: "-")
    }

    private func mergeLines(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines.joined(separator: " ")
    }
 
    func setPinboard(for item: ClipboardItem, pinboard: String?) async {
        try? await historyStore.setPinboard(id: item.id, pinboard: pinboard)
        await load()
        if let pinboard = pinboard {
            toastManager.show(.success("Moved to '\(pinboard)'"))
        } else {
            toastManager.show(.success("Removed from Pinboard"))
        }
    }

    private func setPinboardForSelected(_ name: String?) async {
        guard let item = selectedItem else { return }
        await setPinboard(for: item, pinboard: name)
    }
 
    private func applyVisibleItems() {
        visibleItems = allItems
        selectedIndex = min(selectedIndex, max(visibleItems.count - 1, 0))
        if visibleItems.isEmpty {
            isQuickLookVisible = false
            isActionMenuVisible = false
        }
    }

    private func translateText(_ text: String, to language: String) async throws -> String {
        var components = URLComponents(string: "https://translate.googleapis.com/translate_a/single")!
        components.queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "sl", value: "auto"),
            URLQueryItem(name: "tl", value: language),
            URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "q", value: text)
        ]
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 6.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [Any],
              let sentences = json.first as? [Any] else {
            throw URLError(.cannotParseResponse)
        }
        
        var result = ""
        for sentence in sentences {
            if let sentenceArray = sentence as? [Any],
               let translatedPart = sentenceArray.first as? String {
                result += translatedPart
            }
        }
        
        if result.isEmpty {
            throw URLError(.cannotParseResponse)
        }
        return result
    }

    private func shortenURL(_ originalURL: String) async throws -> String {
        var components = URLComponents(string: "https://tinyurl.com/api-create.php")!
        components.queryItems = [URLQueryItem(name: "url", value: originalURL)]
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 6.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        guard let result = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !result.isEmpty else {
            throw URLError(.cannotParseResponse)
        }
        
        if result.lowercased().hasPrefix("error") {
            throw URLError(.badServerResponse)
        }
        return result
    }

    private func stripTrackingParameters(from urlString: String) -> String {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return urlString
        }
        
        guard let queryItems = components.queryItems else {
            return urlString
        }
        
        let trackingKeys = ["utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content", "si", "fbclid", "gclid", "ref", "referrer"]
        let cleanedItems = queryItems.filter { item in
            !trackingKeys.contains(item.name.lowercased()) && !item.name.lowercased().hasPrefix("utm_")
        }
        
        components.queryItems = cleanedItems.isEmpty ? nil : cleanedItems
        return components.url?.absoluteString ?? urlString
    }

    private func openURLInIncognito(_ url: URL) {
        guard url.scheme == "http" || url.scheme == "https" else {
            toastManager.show(.error("Only HTTP/HTTPS URLs are supported for Incognito Mode"))
            return
        }
        
        guard let defaultBrowserURL = NSWorkspace.shared.urlForApplication(toOpen: url) else {
            NSWorkspace.shared.open(url)
            return
        }
        
        let bundleId = Bundle(url: defaultBrowserURL)?.bundleIdentifier ?? ""
        
        if bundleId.contains("safari") {
            toastManager.show(.warning("Safari does not support direct incognito. Opened in normal tab."))
            NSWorkspace.shared.open(url)
            return
        }
        
        let config = NSWorkspace.OpenConfiguration()
        
        if bundleId.contains("chrome") {
            config.arguments = ["--incognito"]
        } else if bundleId.contains("firefox") {
            config.arguments = ["--private-window"]
        } else if bundleId.contains("msedge") {
            config.arguments = ["-inprivate"]
        }
        
        NSWorkspace.shared.open([url], withApplicationAt: defaultBrowserURL, configuration: config) { _, error in
            if let error = error {
                print("Failed to open incognito: \(error.localizedDescription)")
                Task { @MainActor in
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}
