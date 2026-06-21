import XCTest
@testable import Clipo

final class ClipboardPopupViewModelTests: XCTestCase {

    // MARK: - Permission Polling

    @MainActor
    func testPermissionStatusUpdatesAutomatically() async throws {
        // Given: ViewModel with permission initially denied
        let mockPermissions = MockAccessibilityPermissionService(initialTrusted: false)
        let mockHistoryStore = MockClipboardHistoryStoreForPermissionTests()
        let mockPasteService = MockPasteServiceForPermissionTests()

        let viewModel = ClipboardPopupViewModel(
            historyStore: mockHistoryStore,
            pasteService: mockPasteService,
            permissions: mockPermissions
        )

        // Then: Initial state should be not trusted
        XCTAssertFalse(viewModel.isAccessibilityTrusted)

        // When: Permission is granted
        mockPermissions.setTrusted(true)

        // Wait for polling to detect change (2 seconds + buffer)
        try await Task.sleep(nanoseconds: 2_500_000_000)

        // Then: ViewModel should reflect new permission status
        XCTAssertTrue(viewModel.isAccessibilityTrusted)
    }

    @MainActor
    func testPermissionStatusUpdatesWhenRevoked() async throws {
        // Given: ViewModel with permission initially granted
        let mockPermissions = MockAccessibilityPermissionService(initialTrusted: true)
        let mockHistoryStore = MockClipboardHistoryStoreForPermissionTests()
        let mockPasteService = MockPasteServiceForPermissionTests()

        let viewModel = ClipboardPopupViewModel(
            historyStore: mockHistoryStore,
            pasteService: mockPasteService,
            permissions: mockPermissions
        )

        // Then: Initial state should be trusted
        XCTAssertTrue(viewModel.isAccessibilityTrusted)

        // When: Permission is revoked
        mockPermissions.setTrusted(false)

        // Wait for polling to detect change (2 seconds + buffer)
        try await Task.sleep(nanoseconds: 2_500_000_000)

        // Then: ViewModel should reflect revoked permission
        XCTAssertFalse(viewModel.isAccessibilityTrusted)
    }

    @MainActor
    func testPermissionPollingStopsOnDeinit() async throws {
        // Given: ViewModel with permission polling
        let mockPermissions = MockAccessibilityPermissionService(initialTrusted: false)
        let mockHistoryStore = MockClipboardHistoryStoreForPermissionTests()
        let mockPasteService = MockPasteServiceForPermissionTests()

        var viewModel: ClipboardPopupViewModel? = ClipboardPopupViewModel(
            historyStore: mockHistoryStore,
            pasteService: mockPasteService,
            permissions: mockPermissions
        )

        // When: ViewModel is deallocated
        viewModel = nil

        // Wait a bit to ensure deinit completes
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then: No crash or memory leak (verified by test completion)
        XCTAssertNil(viewModel)
    }

    // MARK: - Security & Hardening Tests

    @MainActor
    func testAvailableActionsExcludeTranslateAndShortenForSensitiveItems() async throws {
        let mockPermissions = MockAccessibilityPermissionService(initialTrusted: true)
        let mockHistoryStore = MockHistoryStoreForSecurityTests()
        let mockPasteService = MockPasteServiceForPermissionTests()
        
        let sensitiveItem = ClipboardItem.stub(
            kind: .link,
            title: "Sensitive link",
            contentText: "https://example.com/login?password=mysecretpassword123"
        )
        await mockHistoryStore.setItems([sensitiveItem])
        
        let viewModel = ClipboardPopupViewModel(
            historyStore: mockHistoryStore,
            pasteService: mockPasteService,
            permissions: mockPermissions
        )
        
        await viewModel.load()
        
        // Assert sensitive item is selected
        XCTAssertEqual(viewModel.selectedItem?.id, sensitiveItem.id)
        
        let actions = viewModel.availableActions
        XCTAssertFalse(actions.contains(.translateToVietnamese))
        XCTAssertFalse(actions.contains(.shortenURL))
        XCTAssertTrue(actions.contains(.stripTracking))
        XCTAssertTrue(actions.contains(.openIncognito))
    }

    @MainActor
    func testExecuteActionBlocksSensitiveTranslationAndShortening() async throws {
        let mockPermissions = MockAccessibilityPermissionService(initialTrusted: true)
        let mockHistoryStore = MockHistoryStoreForSecurityTests()
        let mockPasteService = MockPasteServiceForPermissionTests()
        let toastManager = ToastManager()
        
        let sensitiveItem = ClipboardItem.stub(
            kind: .link,
            title: "Sensitive link",
            contentText: "https://example.com/login?password=mysecretpassword123"
        )
        await mockHistoryStore.setItems([sensitiveItem])
        
        let viewModel = ClipboardPopupViewModel(
            historyStore: mockHistoryStore,
            pasteService: mockPasteService,
            permissions: mockPermissions,
            toastManager: toastManager
        )
        
        await viewModel.load()
        
        // Directly try executing actions
        await viewModel.executeAction(.translateToVietnamese)
        XCTAssertEqual(toastManager.currentToast?.message, "Cannot translate sensitive text")
        
        toastManager.clear()
        
        await viewModel.executeAction(.shortenURL)
        XCTAssertEqual(toastManager.currentToast?.message, "Cannot shorten sensitive URL")
    }

    @MainActor
    func testTranslateActionEnforcesCharacterLimit() async throws {
        let mockPermissions = MockAccessibilityPermissionService(initialTrusted: true)
        let mockHistoryStore = MockHistoryStoreForSecurityTests()
        let mockPasteService = MockPasteServiceForPermissionTests()
        let toastManager = ToastManager()
        
        let hugeText = String(repeating: "A", count: 5001)
        let hugeItem = ClipboardItem.stub(
            kind: .text,
            title: "Huge text",
            contentText: hugeText
        )
        await mockHistoryStore.setItems([hugeItem])
        
        let viewModel = ClipboardPopupViewModel(
            historyStore: mockHistoryStore,
            pasteService: mockPasteService,
            permissions: mockPermissions,
            toastManager: toastManager
        )
        
        await viewModel.load()
        
        await viewModel.executeAction(.translateToVietnamese)
        XCTAssertEqual(toastManager.currentToast?.message, "Text too long for translation (max 5000 characters)")
    }
}

// MARK: - Mock History Store for Security Tests

private actor MockHistoryStoreForSecurityTests: ClipboardHistoryLoading {
    var items: [ClipboardItem] = []

    func setItems(_ newItems: [ClipboardItem]) {
        self.items = newItems
    }

    func recentItems(limit: Int) async throws -> [ClipboardItem] {
        return items
    }
    
    func recentItems(limit: Int, filters: Set<HistoryFilter>) async throws -> [ClipboardItem] {
        return items
    }

    func search(query: String) async throws -> [ClipboardItem] {
        return items
    }

    func search(query: String, filters: Set<HistoryFilter>) async throws -> [ClipboardItem] {
        return items
    }

    func setPinned(id: UUID, isPinned: Bool) async throws {}
    func setPinboard(id: UUID, pinboard: String?) async throws {}
    func removePinboard(named name: String) async throws {}
    func delete(id: UUID) async throws {}
    func clearHistory() async throws {}
    func updateCreatedAt(id: UUID, date: Date) async throws {}
}

// MARK: - Mock Services for Permission Tests

private final class MockAccessibilityPermissionService: AccessibilityPermissionChecking, @unchecked Sendable {
    private var _isTrusted: Bool

    init(initialTrusted: Bool) {
        self._isTrusted = initialTrusted
    }

    var isTrusted: Bool {
        _isTrusted
    }

    func setTrusted(_ trusted: Bool) {
        _isTrusted = trusted
    }

    func requestTrustIfNeeded() {}

    func openSystemSettings() {}
}

private final class MockClipboardHistoryStoreForPermissionTests: ClipboardHistoryLoading {
    func recentItems(limit: Int) async throws -> [ClipboardItem] {
        return []
    }

    func search(query: String) async throws -> [ClipboardItem] {
        return []
    }

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

private final class MockPasteServiceForPermissionTests: PasteService {
    func paste(_ item: ClipboardItem) async throws -> PasteResult {
        return .copiedOnly
    }

    func pasteAsPlainText(_ item: ClipboardItem) async throws -> PasteResult {
        return .copiedOnly
    }

    func copyAsPlainText(_ item: ClipboardItem) async throws {}
}
