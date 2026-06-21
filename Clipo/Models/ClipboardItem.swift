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
    var pinboard: String?
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
        pinboard: String? = nil,
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
        self.pinboard = pinboard
        self.metadata = metadata
    }
}

extension ClipboardItem {
    var showsInlinePreviewByDefault: Bool {
        kind == .image
    }

    var showsExpandedPreviewWhenSelected: Bool {
        kind == .image || (metadata.detectedLanguage ?? .unknown) != .unknown
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
        pinboard: String? = nil,
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
            pinboard: pinboard,
            metadata: metadata
        )
    }

    var isSensitive: Bool {
        guard let text = contentText else { return false }
        
        let creditCardRegex = try? NSRegularExpression(pattern: "\\b(?:\\d[ -]?){13,16}\\b", options: [])
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        if let cardMatch = creditCardRegex?.firstMatch(in: text, options: [], range: range), cardMatch.range.length > 0 {
            return true
        }
        
        let sensitiveKeywordsRegex = try? NSRegularExpression(
            pattern: "(?i)(password|passwd|passcode|secret|api_key|apikey|private_key|token|auth_token)\\s*[:=]\\s*[\"']?[a-zA-Z0-9_\\-\\.+=]{6,}[\"']?",
            options: []
        )
        if let keywordMatch = sensitiveKeywordsRegex?.firstMatch(in: text, options: [], range: range), keywordMatch.range.length > 0 {
            return true
        }
        
        return false
    }
    
    var maskedText: String? {
        guard let text = contentText else { return nil }
        guard isSensitive else { return text }
        
        var masked = text
        
        if let creditCardRegex = try? NSRegularExpression(pattern: "\\b(?:\\d[ -]?){13,16}\\b", options: []) {
            let matches = creditCardRegex.matches(in: masked, options: [], range: NSRange(masked.startIndex..<masked.endIndex, in: masked))
            for match in matches.reversed() {
                if let r = Range(match.range, in: masked) {
                    let rawCard = String(masked[r])
                    let digitsOnly = rawCard.filter { $0.isNumber }
                    let last4 = String(digitsOnly.suffix(4))
                    let maskedCard = "•••• •••• •••• " + last4
                    masked.replaceSubrange(r, with: maskedCard)
                }
            }
        }
        
        if let sensitiveKeywordsRegex = try? NSRegularExpression(
            pattern: "(?i)(password|passwd|passcode|secret|api_key|apikey|private_key|token|auth_token)\\s*([:=])\\s*([\"']?)([a-zA-Z0-9_\\-\\.+=]{6,})([\"']?)",
            options: []
        ) {
            let matches = sensitiveKeywordsRegex.matches(in: masked, options: [], range: NSRange(masked.startIndex..<masked.endIndex, in: masked))
            for match in matches.reversed() {
                if match.numberOfRanges >= 5 {
                    let valRange = match.range(at: 4)
                    if let r = Range(valRange, in: masked) {
                        let len = valRange.length
                        let maskStr = String(repeating: "•", count: min(16, len))
                        masked.replaceSubrange(r, with: maskStr)
                    }
                }
            }
        }
        
        return masked
    }
    
    var maskedTitle: String {
        if isSensitive, let masked = maskedText {
            return String(masked.prefix(80))
        }
        return title
    }
}
