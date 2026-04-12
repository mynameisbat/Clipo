import Foundation
import GRDB

struct AppDatabase {
    let writer: any DatabaseWriter

    static func live(at url: URL) throws -> AppDatabase {
        let queue = try DatabaseQueue(path: url.path)
        try DatabaseMigratorFactory.make().migrate(queue)
        return AppDatabase(writer: queue)
    }

    static func inMemory() throws -> AppDatabase {
        let queue = try DatabaseQueue()
        try DatabaseMigratorFactory.make().migrate(queue)
        return AppDatabase(writer: queue)
    }
}
