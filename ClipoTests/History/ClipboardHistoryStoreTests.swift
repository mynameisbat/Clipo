import XCTest
@testable import Clipo

final class ClipboardHistoryStoreTests: XCTestCase {
    func testRecentItemsReturnNewestFirst() async throws {
        let store = try makeStore()

        try await store.insert(.stub(title: "Older", createdAt: .init(timeIntervalSince1970: 10)))
        try await store.insert(.stub(title: "Newer", createdAt: .init(timeIntervalSince1970: 20)))

        let items = try await store.recentItems(limit: 10)
        XCTAssertEqual(items.map(\.title), ["Newer", "Older"])
    }

    func testTogglePinnedUpdatesStoredValue() async throws {
        let store = try makeStore()
        let item = ClipboardItem.stub(title: "Pin me")

        try await store.insert(item)
        try await store.setPinned(id: item.id, isPinned: true)

        let items = try await store.recentItems(limit: 10)
        XCTAssertEqual(items.first?.isPinned, true)
    }

    func testSearchMatchesTitleAndContent() async throws {
        let store = try makeStore()

        try await store.insert(.stub(title: "Sprint summary", contentText: "macOS release train"))
        try await store.insert(.stub(title: "Another item", contentText: "nothing relevant"))

        let items = try await store.search(query: "release")
        XCTAssertEqual(items.map(\.title), ["Sprint summary"])
    }

    func testDeleteRemovesSingleItem() async throws {
        let store = try makeStore()
        let keep = ClipboardItem.stub(title: "Keep")
        let remove = ClipboardItem.stub(title: "Remove")

        try await store.insert(keep)
        try await store.insert(remove)

        try await store.delete(id: remove.id)

        let items = try await store.recentItems(limit: 10)
        XCTAssertEqual(items.map(\.title), ["Keep"])
    }

    func testClearHistoryKeepsPinnedItems() async throws {
        let store = try makeStore()
        let pinned = ClipboardItem.stub(title: "Pinned", isPinned: true)
        let regular = ClipboardItem.stub(title: "Regular")

        try await store.insert(pinned)
        try await store.insert(regular)

        try await store.clearHistory()

        let items = try await store.recentItems(limit: 10)
        XCTAssertEqual(items.map(\.title), ["Pinned"])
    }

    func testPurgeExpiredItemsRemovesOnlyOldUnpinnedItems() async throws {
        let store = try makeStore()
        let now = Date(timeIntervalSince1970: 1_000_000)
        let oldDate = now.addingTimeInterval(-(8 * 24 * 60 * 60))
        let recentDate = now.addingTimeInterval(-(2 * 24 * 60 * 60))

        try await store.insert(.stub(title: "Pinned old", createdAt: oldDate, isPinned: true))
        try await store.insert(.stub(title: "Recent", createdAt: recentDate))
        try await store.insert(.stub(title: "Expired", createdAt: oldDate))

        try await store.purgeExpiredItems(olderThanDays: 7, now: now)

        let items = try await store.recentItems(limit: 10)
        XCTAssertEqual(items.map(\.title), ["Pinned old", "Recent"])
    }

    func testSetPinboardUpdatesStoredValue() async throws {
        let store = try makeStore()
        let item = ClipboardItem.stub(title: "Classify me")

        try await store.insert(item)
        try await store.setPinboard(id: item.id, pinboard: "Templates")

        let items = try await store.recentItems(limit: 10)
        XCTAssertEqual(items.first?.pinboard, "Templates")
    }

    func testSearchWithPinboardFilter() async throws {
        let store = try makeStore()
        
        try await store.insert(.stub(title: "Template item", pinboard: "Templates"))
        try await store.insert(.stub(title: "Regular item", pinboard: nil))

        let filtered = try await store.recentItems(limit: 10, filters: [.pinboard("Templates")])
        XCTAssertEqual(filtered.map(\.title), ["Template item"])
    }

    func testSmartFilterGroupingORAndAND() async throws {
        let store = try makeStore()
        
        try await store.insert(.stub(kind: .text, title: "Template 1", pinboard: "Templates"))
        try await store.insert(.stub(kind: .text, title: "Email 1", pinboard: "Emails"))
        try await store.insert(.stub(kind: .text, title: "Code 1", pinboard: "Code"))
        try await store.insert(.stub(kind: .image, title: "Image 1", pinboard: "Code"))
        try await store.insert(.stub(kind: .text, title: "Regular Text", pinboard: nil))
        
        // 1. Multiple Pinboards: should OR them (Templates OR Emails)
        let pinboardsFilter = try await store.recentItems(limit: 10, filters: [.pinboard("Templates"), .pinboard("Emails")])
        XCTAssertEqual(Set(pinboardsFilter.map(\.title)), ["Template 1", "Email 1"])
        
        // 2. Pinboard and Kind: should AND them (Text AND (Code OR Templates))
        let kindAndPinboardFilter = try await store.recentItems(limit: 10, filters: [.kind(.text), .pinboard("Code"), .pinboard("Templates")])
        XCTAssertEqual(Set(kindAndPinboardFilter.map(\.title)), ["Template 1", "Code 1"])
        
        // 3. Kind OR kind AND pinboard ((Text OR Image) AND Code)
        let kindsAndPinboard = try await store.recentItems(limit: 10, filters: [.kind(.text), .kind(.image), .pinboard("Code")])
        XCTAssertEqual(Set(kindsAndPinboard.map(\.title)), ["Code 1", "Image 1"])
    }

    private func makeStore() throws -> ClipboardHistoryStore {
        let database = try AppDatabase.inMemory()
        return ClipboardHistoryStore(writer: database.writer, retentionDaysProvider: { nil })
    }
}
