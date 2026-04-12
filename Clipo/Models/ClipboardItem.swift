import Foundation

enum ClipboardItemKind: String, Codable, CaseIterable, Sendable {
    case text
    case image
    case file
    case link
}

enum CodeLanguage: String, Codable, Sendable {
    case swift
    case javascript
    case python
    case typescript
    case json
    case html
    case css
    case sql
    case shell
    case markdown
    case unknown

    var displayName: String {
        switch self {
        case .swift: return "Swift"
        case .javascript: return "JavaScript"
        case .python: return "Python"
        case .typescript: return "TypeScript"
        case .json: return "JSON"
        case .html: return "HTML"
        case .css: return "CSS"
        case .sql: return "SQL"
        case .shell: return "Shell"
        case .markdown: return "Markdown"
        case .unknown: return "Code"
        }
    }

    var color: String {
        switch self {
        case .swift: return "orange"
        case .javascript, .typescript: return "yellow"
        case .python: return "blue"
        case .json: return "gray"
        case .html: return "red"
        case .css: return "purple"
        case .sql: return "green"
        case .shell: return "mint"
        case .markdown: return "pink"
        case .unknown: return "gray"
        }
    }
}

struct ClipboardItemMetadata: Equatable, Sendable {
    // Image metadata
    var imageWidth: Int?
    var imageHeight: Int?
    var imageFileSize: Int64?

    // URL metadata
    var faviconURL: URL?

    // Code metadata
    var detectedLanguage: CodeLanguage?
    var lineCount: Int?
    var characterCount: Int?

    // Text metadata
    var wordCount: Int?

    // File metadata
    var fileSize: Int64?
    var fileExtension: String?

    static func empty() -> ClipboardItemMetadata {
        ClipboardItemMetadata()
    }
}

enum ClipboardPreviewContent: Equatable, Sendable {
    case text(String)
    case image(URL)
    case none
}

struct ClipboardItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let kind: ClipboardItemKind
    let title: String
    let contentText: String?
    let resourcePath: String?
    let sourceAppBundleId: String?
    let createdAt: Date
    var isPinned: Bool
    var metadata: ClipboardItemMetadata

    init(
        id: UUID = UUID(),
        kind: ClipboardItemKind,
        title: String,
        contentText: String? = nil,
        resourcePath: String? = nil,
        sourceAppBundleId: String? = nil,
        createdAt: Date = Date(),
        isPinned: Bool = false,
        metadata: ClipboardItemMetadata = .empty()
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.contentText = contentText
        self.resourcePath = resourcePath
        self.sourceAppBundleId = sourceAppBundleId
        self.createdAt = createdAt
        self.isPinned = isPinned
        self.metadata = metadata
    }
}

extension ClipboardItem {
    var showsInlinePreviewByDefault: Bool {
        kind == .image
    }

    var previewContent: ClipboardPreviewContent {
        switch kind {
        case .text, .link:
            if let contentText, !contentText.isEmpty {
                return .text(contentText)
            }
            return .none
        case .image:
            guard let resourcePath else { return .none }
            if let remoteURL = URL(string: resourcePath), remoteURL.scheme != nil {
                return .image(remoteURL)
            }
            return .image(URL(fileURLWithPath: resourcePath))
        case .file:
            return .none
        }
    }

    static func stub(
        id: UUID = UUID(),
        kind: ClipboardItemKind = .text,
        title: String,
        contentText: String? = nil,
        resourcePath: String? = nil,
        sourceAppBundleId: String? = nil,
        createdAt: Date = Date(),
        isPinned: Bool = false,
        metadata: ClipboardItemMetadata = .empty()
    ) -> ClipboardItem {
        ClipboardItem(
            id: id,
            kind: kind,
            title: title,
            contentText: contentText,
            resourcePath: resourcePath,
            sourceAppBundleId: sourceAppBundleId,
            createdAt: createdAt,
            isPinned: isPinned,
            metadata: metadata
        )
    }
}
