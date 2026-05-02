import Foundation

/// Smart caching layer for clipboard items to reduce database queries
actor ClipboardCache {
    struct CacheEntry {
        let items: [ClipboardItem]
        let timestamp: Date
    }

    private var recentItemsCache: CacheEntry?
    private var queryCache: [String: CacheEntry] = [:]
    private let cacheTTL: TimeInterval

    init(cacheTTL: TimeInterval = 120) { // Default 2 minutes
        self.cacheTTL = cacheTTL
    }

    // MARK: - Recent Items Cache

    func getRecent(limit: Int) -> [ClipboardItem]? {
        guard let cache = recentItemsCache,
              Date().timeIntervalSince(cache.timestamp) < cacheTTL else {
            return nil
        }
        return Array(cache.items.prefix(limit))
    }

    func cacheRecent(_ items: [ClipboardItem]) {
        recentItemsCache = CacheEntry(items: items, timestamp: Date())
    }

    // MARK: - Query Cache

    func getQuery(_ query: String) -> [ClipboardItem]? {
        guard let cache = queryCache[query],
              Date().timeIntervalSince(cache.timestamp) < cacheTTL else {
            return nil
        }
        return cache.items
    }

    func cacheQuery(_ query: String, items: [ClipboardItem]) {
        queryCache[query] = CacheEntry(items: items, timestamp: Date())
    }

    // MARK: - Cache Invalidation

    func invalidate() {
        recentItemsCache = nil
        queryCache.removeAll()
    }

    func invalidateRecent() {
        recentItemsCache = nil
    }

    func invalidateQuery(_ query: String) {
        queryCache.removeValue(forKey: query)
    }
}
