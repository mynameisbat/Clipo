import Foundation
import GRDB

enum DatabaseMigratorFactory {
    static func make() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createClipboardItems") { db in
            try db.create(table: "clipboard_items") { table in
                table.column("id", .text).primaryKey()
                table.column("kind", .text).notNull()
                table.column("title", .text).notNull()
                table.column("contentText", .text)
                table.column("resourcePath", .text)
                table.column("sourceAppBundleId", .text)
                table.column("createdAt", .datetime).notNull().indexed()
                table.column("isPinned", .boolean).notNull().defaults(to: false)
            }
        }

        migrator.registerMigration("addFTS5SearchIndex") { db in
            // Create FTS5 virtual table for full-text search
            try db.execute(sql: """
                CREATE VIRTUAL TABLE clipboard_items_fts USING fts5(
                    id UNINDEXED,
                    title,
                    contentText,
                    content='clipboard_items',
                    content_rowid='rowid'
                )
                """)

            // Populate FTS table with existing data
            try db.execute(sql: """
                INSERT INTO clipboard_items_fts(rowid, id, title, contentText)
                SELECT rowid, id, title, contentText FROM clipboard_items
                """)

            // Trigger to keep FTS in sync on INSERT
            try db.execute(sql: """
                CREATE TRIGGER clipboard_items_ai AFTER INSERT ON clipboard_items BEGIN
                    INSERT INTO clipboard_items_fts(rowid, id, title, contentText)
                    VALUES (new.rowid, new.id, new.title, new.contentText);
                END
                """)

            // Trigger to keep FTS in sync on DELETE
            try db.execute(sql: """
                CREATE TRIGGER clipboard_items_ad AFTER DELETE ON clipboard_items BEGIN
                    DELETE FROM clipboard_items_fts WHERE rowid = old.rowid;
                END
                """)

            // Trigger to keep FTS in sync on UPDATE
            try db.execute(sql: """
                CREATE TRIGGER clipboard_items_au AFTER UPDATE ON clipboard_items BEGIN
                    UPDATE clipboard_items_fts
                    SET title = new.title, contentText = new.contentText
                    WHERE rowid = new.rowid;
                END
                """)
        }

        migrator.registerMigration("addPinboardColumn") { db in
            try db.execute(sql: "ALTER TABLE clipboard_items ADD COLUMN pinboard TEXT")
        }

        return migrator
    }
}
