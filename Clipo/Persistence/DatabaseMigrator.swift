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
        return migrator
    }
}
