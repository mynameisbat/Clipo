import Foundation
import GRDB

protocol ClipboardHistoryLoading: Sendable {
    func recentItems(limit: Int) async throws -> [ClipboardItem]
    func search(query: String) async throws -> [ClipboardItem]
    func setPinned(id: UUID, isPinned: Bool) async throws
    func delete(id: UUID) async throws
    func clearHistory() async throws
}

protocol ClipboardItemSink: Sendable {
    func store(_ item: ClipboardItem) async throws
}

actor ClipboardHistoryStore: ClipboardHistoryLoading, ClipboardItemSink {
    private let writer: any DatabaseWriter
    private let retentionDaysProvider: @Sendable () -> Int?
    private let resourceCleaner: @Sendable ([String]) -> Void

    init(
        writer: any DatabaseWriter,
        retentionDaysProvider: @escaping @Sendable () -> Int? = { HistoryRetentionPolicy.current().days },
        resourceCleaner: @escaping @Sendable ([String]) -> Void = ClipboardHistoryStore.cleanResources
    ) {
        self.writer = writer
        self.retentionDaysProvider = retentionDaysProvider
        self.resourceCleaner = resourceCleaner
    }

    func insert(_ item: ClipboardItem) async throws {
        try await purgeExpiredItemsUsingConfiguredPolicy(now: Date())
        try await writer.write { db in
            var record = ClipboardItemRecord(item: item)
            try record.insert(db)
        }
    }

    func recentItems(limit: Int) async throws -> [ClipboardItem] {
        try await purgeExpiredItemsUsingConfiguredPolicy(now: Date())
        return try await writer.read { db in
            try ClipboardItemRecord
                .order(Column("isPinned").desc, Column("createdAt").desc)
                .limit(limit)
                .fetchAll(db)
                .map(\.domain)
        }
    }

    func setPinned(id: UUID, isPinned: Bool) async throws {
        try await writer.write { db in
            try db.execute(
                sql: "UPDATE clipboard_items SET isPinned = ? WHERE id = ?",
                arguments: [isPinned, id]
            )
        }
    }

    func search(query: String) async throws -> [ClipboardItem] {
        try await purgeExpiredItemsUsingConfiguredPolicy(now: Date())
        let pattern = "%\(query)%"
        return try await writer.read { db in
            try ClipboardItemRecord
                .filter(sql: "title LIKE ? OR contentText LIKE ?", arguments: [pattern, pattern])
                .order(Column("isPinned").desc, Column("createdAt").desc)
                .fetchAll(db)
                .map(\.domain)
        }
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
    }

    func purgeExpiredItemsUsingConfiguredPolicy(now: Date) async throws {
        guard let retentionDays = retentionDaysProvider() else { return }
        try await purgeExpiredItems(olderThanDays: retentionDays, now: now)
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
}
