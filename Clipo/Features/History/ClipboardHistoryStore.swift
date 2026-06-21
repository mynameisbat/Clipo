import Foundation
import GRDB

protocol ClipboardHistoryLoading: Sendable {
    func recentItems(limit: Int) async throws -> [ClipboardItem]
    func recentItems(limit: Int, filters: Set<HistoryFilter>) async throws -> [ClipboardItem]
    func search(query: String) async throws -> [ClipboardItem]
    func search(query: String, filters: Set<HistoryFilter>) async throws -> [ClipboardItem]
    func setPinned(id: UUID, isPinned: Bool) async throws
    func setPinboard(id: UUID, pinboard: String?) async throws
    func removePinboard(named name: String) async throws
    func delete(id: UUID) async throws
    func clearHistory() async throws
    func updateCreatedAt(id: UUID, date: Date) async throws
}

protocol ClipboardItemSink: Sendable {
    func store(_ item: ClipboardItem) async throws
}

actor ClipboardHistoryStore: ClipboardHistoryLoading, ClipboardItemSink {
    private let writer: any DatabaseWriter
    private let retentionDaysProvider: @Sendable () -> Int?
    private let resourceCleaner: @Sendable ([String]) -> Void
    private let cache: ClipboardCache
    private let purgeScheduler: PurgeScheduler

    init(
        writer: any DatabaseWriter,
        retentionDaysProvider: @escaping @Sendable () -> Int? = { HistoryRetentionPolicy.current().days },
        resourceCleaner: @escaping @Sendable ([String]) -> Void = ClipboardHistoryStore.cleanResources,
        cache: ClipboardCache = ClipboardCache(),
        purgeScheduler: PurgeScheduler = PurgeScheduler()
    ) {
        self.writer = writer
        self.retentionDaysProvider = retentionDaysProvider
        self.resourceCleaner = resourceCleaner
        self.cache = cache
        self.purgeScheduler = purgeScheduler
    }

    func insert(_ item: ClipboardItem) async throws {
        try await purgeExpiredItemsUsingConfiguredPolicy(now: Date())
        try await writer.write { db in
            var duplicateId: UUID?
            
            if item.kind == .text || item.kind == .link {
                if let contentText = item.contentText {
                    let dup = try ClipboardItemRecord
                        .filter(Column("kind") == item.kind.rawValue && Column("contentText") == contentText)
                        .fetchOne(db)
                    duplicateId = dup?.id
                }
            } else if item.kind == .file {
                if let resourcePath = item.resourcePath {
                    let dup = try ClipboardItemRecord
                        .filter(Column("kind") == item.kind.rawValue && Column("resourcePath") == resourcePath)
                        .fetchOne(db)
                    duplicateId = dup?.id
                }
            } else if item.kind == .image {
                if let resourcePath = item.resourcePath,
                   let newAttrs = try? FileManager.default.attributesOfItem(atPath: resourcePath),
                   let newSize = newAttrs[.size] as? Int64 {
                    
                    let imageRecords = try ClipboardItemRecord
                        .filter(Column("kind") == ClipboardItemKind.image.rawValue)
                        .fetchAll(db)
                        
                    for rec in imageRecords {
                        if let recPath = rec.resourcePath,
                           let attrs = try? FileManager.default.attributesOfItem(atPath: recPath),
                           let size = attrs[.size] as? Int64,
                           size == newSize {
                            let newURL = URL(fileURLWithPath: resourcePath)
                            let recURL = URL(fileURLWithPath: recPath)
                            if let newData = try? Data(contentsOf: newURL, options: .mappedIfSafe),
                               let recData = try? Data(contentsOf: recURL, options: .mappedIfSafe),
                               newData == recData {
                                duplicateId = rec.id
                                break
                            }
                        }
                    }
                }
            }
            
            if let duplicateId {
                let paths = try String.fetchAll(
                    db,
                    sql: "SELECT resourcePath FROM clipboard_items WHERE id = ? AND resourcePath IS NOT NULL",
                    arguments: [duplicateId]
                )
                try db.execute(
                    sql: "DELETE FROM clipboard_items WHERE id = ?",
                    arguments: [duplicateId]
                )
                for path in paths {
                    if path != item.resourcePath {
                        if let url = URL(string: path), url.scheme != nil, !url.isFileURL {
                            continue
                        }
                        try? FileManager.default.removeItem(atPath: path)
                    }
                }
            }
            
            var record = ClipboardItemRecord(item: item)
            try record.insert(db)
        }

        await cache.invalidate()
    }

    func recentItems(limit: Int) async throws -> [ClipboardItem] {
        if let cached = await cache.getRecent(limit: limit) {
            return cached
        }

        try await purgeExpiredItemsUsingConfiguredPolicy(now: Date())
        let items = try await writer.read { db in
            try ClipboardItemRecord
                .order(Column("isPinned").desc, Column("createdAt").desc)
                .limit(limit)
                .fetchAll(db)
                .map(\.domain)
        }

        await cache.cacheRecent(items)
        return items
    }

    func recentItems(limit: Int, filters: Set<HistoryFilter>) async throws -> [ClipboardItem] {
        let items = try await recentItems(limit: limit)
        return Self.applyFilters(filters, to: items)
    }

    func setPinned(id: UUID, isPinned: Bool) async throws {
        try await writer.write { db in
            try db.execute(
                sql: "UPDATE clipboard_items SET isPinned = ? WHERE id = ?",
                arguments: [isPinned, id]
            )
        }

        await cache.invalidate()
    }

    func setPinboard(id: UUID, pinboard: String?) async throws {
        try await writer.write { db in
            try db.execute(
                sql: "UPDATE clipboard_items SET pinboard = ? WHERE id = ?",
                arguments: [pinboard, id]
            )
        }

        await cache.invalidate()
    }

    func removePinboard(named name: String) async throws {
        try await writer.write { db in
            try db.execute(
                sql: "UPDATE clipboard_items SET pinboard = NULL WHERE pinboard = ?",
                arguments: [name]
            )
        }

        await cache.invalidate()
    }

    func updateCreatedAt(id: UUID, date: Date) async throws {
        try await writer.write { db in
            try db.execute(
                sql: "UPDATE clipboard_items SET createdAt = ? WHERE id = ?",
                arguments: [date, id]
            )
        }

        await cache.invalidate()
    }

    func search(query: String) async throws -> [ClipboardItem] {
        if let cached = await cache.getQuery(query) {
            return cached
        }

        try await purgeExpiredItemsUsingConfiguredPolicy(now: Date())

        let items = try await writer.read { db in
            let sql = """
                SELECT c.*
                FROM clipboard_items c
                WHERE c.id IN (SELECT id FROM clipboard_items_fts WHERE clipboard_items_fts MATCH ?)
                   OR (c.sourceAppBundleId LIKE ?)
                ORDER BY c.isPinned DESC, c.createdAt DESC
                """

            let likeQuery = "%\(query)%"
            return try ClipboardItemRecord
                .fetchAll(db, sql: sql, arguments: [query, likeQuery])
                .map(\.domain)
        }

        await cache.cacheQuery(query, items: items)
        return items
    }

    func search(query: String, filters: Set<HistoryFilter>) async throws -> [ClipboardItem] {
        let items = try await search(query: query)
        return Self.applyFilters(filters, to: items)
    }

    func store(_ item: ClipboardItem) async throws {
        try await insert(item)
    }

    func delete(id: UUID) async throws {
        let resourcePaths = try await writer.write { db in
            let paths = try String.fetchAll(
                db,
                sql: "SELECT resourcePath FROM clipboard_items WHERE id = ? AND resourcePath IS NOT NULL",
                arguments: [id]
            )
            try db.execute(
                sql: "DELETE FROM clipboard_items WHERE id = ?",
                arguments: [id]
            )
            return paths
        }

        resourceCleaner(resourcePaths)

        await cache.invalidate()
    }

    func clearHistory() async throws {
        let resourcePaths = try await writer.write { db in
            let paths = try String.fetchAll(
                db,
                sql: "SELECT resourcePath FROM clipboard_items WHERE isPinned = 0 AND resourcePath IS NOT NULL"
            )
            try db.execute(sql: "DELETE FROM clipboard_items WHERE isPinned = 0")
            return paths
        }

        resourceCleaner(resourcePaths)

        await cache.invalidate()
    }

    func purgeExpiredItemsUsingConfiguredPolicy(now: Date) async throws {
        guard await purgeScheduler.shouldPurge() else { return }

        if let retentionDays = retentionDaysProvider() {
            try await purgeExpiredItems(olderThanDays: retentionDays, now: now)
        }
        
        try? await enforceStorageLimits()

        await purgeScheduler.markPurged()
    }

    func enforceStorageLimits() async throws {
        let maxItemsSetting = UserDefaults.standard.integer(forKey: "clipo.settings.maxItems")
        let maxItems = maxItemsSetting > 0 ? maxItemsSetting : (maxItemsSetting == 0 ? 0 : 1000)
        
        // 1. Enforce item count limit (if not set to 0/Unlimited)
        if maxItems > 0 {
            let resourcePaths = try await writer.write { db in
                let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM clipboard_items") ?? 0
                if count > maxItems {
                    let excess = count - maxItems
                    let paths = try String.fetchAll(
                        db,
                        sql: """
                        SELECT resourcePath FROM clipboard_items
                        WHERE isPinned = 0 AND resourcePath IS NOT NULL
                        ORDER BY createdAt ASC
                        LIMIT ?
                        """,
                        arguments: [excess]
                    )
                    try db.execute(
                        sql: """
                        DELETE FROM clipboard_items
                        WHERE id IN (
                            SELECT id FROM clipboard_items
                            WHERE isPinned = 0
                            ORDER BY createdAt ASC
                            LIMIT ?
                        )
                        """,
                        arguments: [excess]
                    )
                    return paths
                }
                return [String]()
            }
            if !resourcePaths.isEmpty {
                Self.cleanResources(at: resourcePaths)
            }
        }
        
        // 2. Enforce image cache directory size limit
        let maxCacheSizeSetting = UserDefaults.standard.integer(forKey: "clipo.settings.maxCacheSizeMB")
        let maxCacheSizeMB = maxCacheSizeSetting > 0 ? maxCacheSizeSetting : (maxCacheSizeSetting == 0 ? 0 : 1000)
        if maxCacheSizeMB > 0 {
            guard let supportRoot = try? ApplicationPaths.applicationSupportRoot() else { return }
            let imagesDir = supportRoot.appendingPathComponent("images", isDirectory: true)
            
            var totalSize: Int64 = 0
            let fileManager = FileManager.default
            guard let enumerator = fileManager.enumerator(at: imagesDir, includingPropertiesForKeys: [.fileSizeKey], options: []) else { return }
            
            while let fileURL = enumerator.nextObject() as? URL {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = resourceValues.fileSize {
                    totalSize += Int64(fileSize)
                }
            }
            
            let limitBytes = Int64(maxCacheSizeMB) * 1024 * 1024
            if totalSize > limitBytes {
                let sizeToFreeLimit = totalSize - limitBytes
                let imagesToPurge = try await writer.write { db -> [String] in
                    let records = try ClipboardItemRecord
                        .filter(Column("kind") == ClipboardItemKind.image.rawValue && Column("isPinned") == false)
                        .order(Column("createdAt").asc)
                        .fetchAll(db)
                    
                    var purgedPaths: [String] = []
                    var sizeToFree = sizeToFreeLimit
                    
                    for rec in records {
                        guard sizeToFree > 0 else { break }
                        if let path = rec.resourcePath {
                            let fileURL = URL(fileURLWithPath: path)
                            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                               let fileSize = resourceValues.fileSize {
                                sizeToFree -= Int64(fileSize)
                            }
                            purgedPaths.append(path)
                            try db.execute(sql: "DELETE FROM clipboard_items WHERE id = ?", arguments: [rec.id])
                        }
                    }
                    return purgedPaths
                }
                
                if !imagesToPurge.isEmpty {
                    Self.cleanResources(at: imagesToPurge)
                }
            }
        }
    }

    func purgeExpiredItems(olderThanDays: Int, now: Date) async throws {
        let cutoff = now.addingTimeInterval(TimeInterval(-olderThanDays * 24 * 60 * 60))
        let resourcePaths = try await writer.write { db in
            let paths = try String.fetchAll(
                db,
                sql: """
                SELECT resourcePath
                FROM clipboard_items
                WHERE isPinned = 0 AND createdAt < ? AND resourcePath IS NOT NULL
                """,
                arguments: [cutoff]
            )
            try db.execute(
                sql: """
                DELETE FROM clipboard_items
                WHERE isPinned = 0 AND createdAt < ?
                """,
                arguments: [cutoff]
            )
            return paths
        }

        resourceCleaner(resourcePaths)
    }

    private static func cleanResources(at paths: [String]) {
        let fileManager = FileManager.default
        for path in paths {
            if let url = URL(string: path), url.scheme != nil, !url.isFileURL {
                continue
            }
            try? fileManager.removeItem(atPath: path)
        }
    }

    private static func applyFilters(_ filters: Set<HistoryFilter>, to items: [ClipboardItem]) -> [ClipboardItem] {
        guard !filters.isEmpty else { return items }
        
        var kinds = Set<ClipboardItemKind>()
        var pinboards = Set<String>()
        var dateRanges = Set<HistoryFilter.DateRange>()
        var sourceApps = Set<String>()
        var requirePinned = false
        
        for filter in filters {
            switch filter {
            case .kind(let k):
                kinds.insert(k)
            case .pinboard(let name):
                pinboards.insert(name)
            case .dateRange(let range):
                dateRanges.insert(range)
            case .sourceApp(let app):
                sourceApps.insert(app)
            case .pinned:
                requirePinned = true
            }
        }
        
        return items.filter { item in
            // 1. Kind: OR within group
            if !kinds.isEmpty {
                if !kinds.contains(item.kind) { return false }
            }
            
            // 2. Pinboard: OR within group
            if !pinboards.isEmpty {
                guard let p = item.pinboard, pinboards.contains(p) else { return false }
            }
            
            // 3. Date range: OR within group
            if !dateRanges.isEmpty {
                let matchesDate = dateRanges.contains { range in
                    Self.isInRange(item.createdAt, range: range)
                }
                if !matchesDate { return false }
            }
            
            // 4. Source app: OR within group
            if !sourceApps.isEmpty {
                let matchesApp = sourceApps.contains { appQuery in
                    guard let bundleId = item.sourceAppBundleId else { return false }
                    let query = appQuery.lowercased()
                    if bundleId.lowercased().contains(query) { return true }
                    return getAppName(from: bundleId).lowercased().contains(query)
                }
                if !matchesApp { return false }
            }
            
            // 5. Pinned
            if requirePinned {
                if !item.isPinned { return false }
            }
            
            return true
        }
    }

    private static func matches(filter: HistoryFilter, item: ClipboardItem) -> Bool {
        switch filter {
        case .kind(let k):
            return item.kind == k
        case .pinned:
            return item.isPinned
        case .dateRange(let range):
            return Self.isInRange(item.createdAt, range: range)
        case .pinboard(let name):
            return item.pinboard == name
        case .sourceApp(let appQuery):
            guard let bundleId = item.sourceAppBundleId else { return false }
            let query = appQuery.lowercased()
            if bundleId.lowercased().contains(query) {
                return true
            }
            let appName = getAppName(from: bundleId).lowercased()
            return appName.contains(query)
        }
    }

    private static func getAppName(from bundleId: String) -> String {
        let lower = bundleId.lowercased()
        if lower.contains("slack") { return "Slack" }
        if lower.contains("safari") { return "Safari" }
        if lower.contains("chrome") { return "Google Chrome" }
        if lower.contains("vscode") || lower.contains("visualstudio") { return "VS Code" }
        if lower.contains("xcode") { return "Xcode" }
        if lower.contains("finder") { return "Finder" }
        if lower.contains("terminal") { return "Terminal" }
        if lower.contains("iterm") { return "iTerm" }
        
        let components = bundleId.split(separator: ".")
        if let last = components.last {
            return String(last).capitalized
        }
        return bundleId
    }

    private static func isInRange(_ date: Date, range: HistoryFilter.DateRange) -> Bool {
        let cal = Calendar.current
        let now = Date()
        switch range {
        case .today:
            return cal.isDateInToday(date)
        case .yesterday:
            let yesterday = cal.date(byAdding: .day, value: -1, to: now) ?? now
            return cal.isDate(date, inSameDayAs: yesterday)
        case .last7Days:
            guard let sevenDaysAgo = cal.date(byAdding: .day, value: -7, to: now) else { return false }
            return date >= sevenDaysAgo
        }
    }
}
