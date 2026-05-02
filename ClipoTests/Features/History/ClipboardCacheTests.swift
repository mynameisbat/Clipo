import XCTest
@testable import Clipo

final class ClipboardCacheTests: XCTestCase {
    var cache: ClipboardCache!

    override func setUp() {
        super.setUp()
        cache = ClipboardCache()
    }

    override func tearDown() {
        cache = nil
        super.tearDown()
    }

    // MARK: - Recent Items Cache

    func testGetRecentReturnsNilWhenCacheEmpty() async {
        // Given: Empty cache

        // When: Get recent items
        let items = await cache.getRecent(limit: 10)

        // Then: Should return nil
        XCTAssertNil(items)
    }

    func testCacheRecentStoresItems() async {
        // Given: Sample items
        let items = createSampleItems(count: 5)

        // When: Cache items
        await cache.cacheRecent(items)

        // Then: Should retrieve cached items
        let cached = await cache.getRecent(limit: 10)
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.count, 5)
    }

    func testGetRecentRespectsLimit() async {
        // Given: 10 cached items
        let items = createSampleItems(count: 10)
        await cache.cacheRecent(items)

        // When: Get with limit 5
        let cached = await cache.getRecent(limit: 5)

        // Then: Should return only 5 items
        XCTAssertEqual(cached?.count, 5)
    }

    func testCacheExpiresAfterTTL() async {
        // Given: Cached items with short TTL
        let items = createSampleItems(count: 3)
        let shortTTLCache = ClipboardCache(cacheTTL: 0.5) // 0.5 seconds
        await shortTTLCache.cacheRecent(items)

        // When: Wait for TTL to expire
        try? await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds

        // Then: Cache should be expired
        let cached = await shortTTLCache.getRecent(limit: 10)
        XCTAssertNil(cached)
    }

    func testCacheDoesNotExpireBeforeTTL() async {
        // Given: Cached items
        let items = createSampleItems(count: 3)
        await cache.cacheRecent(items)

        // When: Wait less than TTL (default 120s, wait 1s)
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        // Then: Cache should still be valid
        let cached = await cache.getRecent(limit: 10)
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.count, 3)
    }

    // MARK: - Query Cache

    func testGetQueryReturnsNilWhenCacheEmpty() async {
        // Given: Empty cache

        // When: Get query result
        let items = await cache.getQuery("test")

        // Then: Should return nil
        XCTAssertNil(items)
    }

    func testCacheQueryStoresResults() async {
        // Given: Sample items
        let items = createSampleItems(count: 3)

        // When: Cache query result
        await cache.cacheQuery("test", items: items)

        // Then: Should retrieve cached result
        let cached = await cache.getQuery("test")
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.count, 3)
    }

    func testQueryCacheExpiresAfterTTL() async {
        // Given: Cached query with short TTL
        let items = createSampleItems(count: 2)
        let shortTTLCache = ClipboardCache(cacheTTL: 0.5)
        await shortTTLCache.cacheQuery("test", items: items)

        // When: Wait for TTL to expire
        try? await Task.sleep(nanoseconds: 600_000_000)

        // Then: Cache should be expired
        let cached = await shortTTLCache.getQuery("test")
        XCTAssertNil(cached)
    }

    func testDifferentQueriesHaveSeparateCaches() async {
        // Given: Two different queries
        let items1 = createSampleItems(count: 2)
        let items2 = createSampleItems(count: 3)

        await cache.cacheQuery("query1", items: items1)
        await cache.cacheQuery("query2", items: items2)

        // When: Retrieve each query
        let cached1 = await cache.getQuery("query1")
        let cached2 = await cache.getQuery("query2")

        // Then: Should return correct results
        XCTAssertEqual(cached1?.count, 2)
        XCTAssertEqual(cached2?.count, 3)
    }

    // MARK: - Cache Invalidation

    func testInvalidateClearsRecentCache() async {
        // Given: Cached recent items
        let items = createSampleItems(count: 5)
        await cache.cacheRecent(items)

        // When: Invalidate cache
        await cache.invalidate()

        // Then: Recent cache should be cleared
        let cached = await cache.getRecent(limit: 10)
        XCTAssertNil(cached)
    }

    func testInvalidateClearsQueryCache() async {
        // Given: Cached query results
        let items = createSampleItems(count: 3)
        await cache.cacheQuery("test", items: items)

        // When: Invalidate cache
        await cache.invalidate()

        // Then: Query cache should be cleared
        let cached = await cache.getQuery("test")
        XCTAssertNil(cached)
    }

    func testInvalidateClearsAllCaches() async {
        // Given: Both recent and query caches populated
        let recentItems = createSampleItems(count: 5)
        let queryItems = createSampleItems(count: 3)

        await cache.cacheRecent(recentItems)
        await cache.cacheQuery("test", items: queryItems)

        // When: Invalidate cache
        await cache.invalidate()

        // Then: All caches should be cleared
        let cachedRecent = await cache.getRecent(limit: 10)
        let cachedQuery = await cache.getQuery("test")

        XCTAssertNil(cachedRecent)
        XCTAssertNil(cachedQuery)
    }

    // MARK: - Helper Methods

    private func createSampleItems(count: Int) -> [ClipboardItem] {
        (0..<count).map { index in
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
}
