import Foundation
import GRDB

struct ClipboardItemRecord: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "clipboard_items"

    var id: UUID
    var kind: String
    var title: String
    var contentText: String?
    var resourcePath: String?
    var sourceAppBundleId: String?
    var createdAt: Date
    var isPinned: Bool
    var pinboard: String?

    init(item: ClipboardItem) {
        id = item.id
        kind = item.kind.rawValue
        title = item.title
        contentText = item.contentText
        resourcePath = item.resourcePath
        sourceAppBundleId = item.sourceAppBundleId
        createdAt = item.createdAt
        isPinned = item.isPinned
        pinboard = item.pinboard
    }

    var domain: ClipboardItem {
        ClipboardItem(
            id: id,
            kind: ClipboardItemKind(rawValue: kind) ?? .text,
            title: title,
            contentText: contentText,
            resourcePath: resourcePath,
            sourceAppBundleId: sourceAppBundleId,
            createdAt: createdAt,
            isPinned: isPinned,
            pinboard: pinboard
        )
    }
}
