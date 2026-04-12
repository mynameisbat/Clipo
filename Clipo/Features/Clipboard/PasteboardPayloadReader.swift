import AppKit
import Foundation

struct PasteboardPayloadReader {
    let assetStore: ImageAssetStore

    func read(snapshot: PasteboardSnapshot) throws -> ClipboardItem? {
        if let imageData = snapshot.imageData {
            let assetURL = try assetStore.storeImage(
                data: imageData,
                fileExtension: snapshot.imageFileExtension ?? "png"
            )
            let dimensions = extractImageDimensions(from: imageData)
            var metadata = ClipboardItemMetadata()
            metadata.imageWidth = dimensions.width
            metadata.imageHeight = dimensions.height
            metadata.imageFileSize = Int64(imageData.count)
            return ClipboardItem(
                id: UUID(),
                kind: .image,
                title: assetURL.lastPathComponent,
                contentText: nil,
                resourcePath: assetURL.path,
                sourceAppBundleId: snapshot.sourceAppBundleId,
                createdAt: Date(),
                isPinned: false,
                metadata: metadata
            )
        }

        if let webArchiveCandidate = try readWebArchiveImage(snapshot.webArchiveData) {
            return webArchiveCandidate
        }

        if let htmlData = snapshot.htmlData,
           let htmlImageURL = extractImageURL(fromHTMLData: htmlData) {
            return makeRemoteImageItem(from: htmlImageURL, sourceAppBundleId: snapshot.sourceAppBundleId)
        }

        // Fallback: extract readable text from HTML when no image URL is found
        // If no readable text found, use "Figma Selection" as title
        if let htmlData = snapshot.htmlData {
            let fallbackText = extractReadableHTMLText(from: htmlData)
            let fallbackTitle = fallbackText.map { String($0.prefix(80)) } ?? "Figma Selection"
            let textMetadata = extractTextMetadata(from: fallbackText)
            return ClipboardItem(
                id: UUID(),
                kind: .text,
                title: fallbackTitle,
                contentText: fallbackText,
                resourcePath: nil,
                sourceAppBundleId: snapshot.sourceAppBundleId,
                createdAt: Date(),
                isPinned: false,
                metadata: textMetadata
            )
        }

        if let rtfImageItem = try readRichTextImage(snapshot.rtfData, sourceAppBundleId: snapshot.sourceAppBundleId) {
            return rtfImageItem
        }

        if let webImageURL = snapshot.strings.lazy.compactMap(extractWebImageURL(from:)).first {
            return makeRemoteImageItem(from: webImageURL, sourceAppBundleId: snapshot.sourceAppBundleId)
        }

        if let text = snapshot.strings.first, !text.isEmpty {
            let kind: ClipboardItemKind = text.hasPrefix("http://") || text.hasPrefix("https://") ? .link : .text
            let textMetadata = extractTextMetadata(from: text)
            return ClipboardItem(
                id: UUID(),
                kind: kind,
                title: String(text.prefix(80)),
                contentText: text,
                resourcePath: nil,
                sourceAppBundleId: snapshot.sourceAppBundleId,
                createdAt: Date(),
                isPinned: false,
                metadata: textMetadata
            )
        }

        if let fileURL = snapshot.fileURLs.first {
            let fileMetadata = extractFileMetadata(from: fileURL)
            return ClipboardItem(
                id: UUID(),
                kind: .file,
                title: fileURL.lastPathComponent,
                contentText: nil,
                resourcePath: fileURL.path,
                sourceAppBundleId: snapshot.sourceAppBundleId,
                createdAt: Date(),
                isPinned: false,
                metadata: fileMetadata
            )
        }

        return nil
    }

    private func readWebArchiveImage(_ data: Data?) throws -> ClipboardItem? {
        guard
            let data,
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        else {
            return nil
        }

        for resource in extractWebArchiveResources(from: plist) {
            guard
                let mimeType = resource["WebResourceMIMEType"] as? String,
                mimeType.lowercased().hasPrefix("image/")
            else {
                continue
            }

            if let resourceData = resource["WebResourceData"] as? Data, !resourceData.isEmpty {
                let fileExtension = fileExtension(forMimeType: mimeType, fallbackURLString: resource["WebResourceURL"] as? String)
                let assetURL = try assetStore.storeImage(data: resourceData, fileExtension: fileExtension)
                let dimensions = extractImageDimensions(from: resourceData)
                var metadata = ClipboardItemMetadata()
                metadata.imageWidth = dimensions.width
                metadata.imageHeight = dimensions.height
                metadata.imageFileSize = Int64(resourceData.count)
                return ClipboardItem(
                    id: UUID(),
                    kind: .image,
                    title: assetURL.lastPathComponent,
                    contentText: nil,
                    resourcePath: assetURL.path,
                    sourceAppBundleId: nil,
                    createdAt: Date(),
                    isPinned: false,
                    metadata: metadata
                )
            }

            if let urlString = resource["WebResourceURL"] as? String, let url = URL(string: urlString) {
                return makeRemoteImageItem(from: url, sourceAppBundleId: nil)
            }
        }

        return nil
    }

    private func extractWebArchiveResources(from value: Any) -> [[String: Any]] {
        if let dictionary = value as? [String: Any] {
            var resources: [[String: Any]] = []
            if dictionary["WebResourceMIMEType"] != nil {
                resources.append(dictionary)
            }

            for nestedValue in dictionary.values {
                resources.append(contentsOf: extractWebArchiveResources(from: nestedValue))
            }

            return resources
        }

        if let array = value as? [Any] {
            return array.flatMap(extractWebArchiveResources(from:))
        }

        return []
    }

    private func readRichTextImage(_ data: Data?, sourceAppBundleId: String?) throws -> ClipboardItem? {
        guard let data else { return nil }

        let attributedString = try NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        )

        var foundItem: ClipboardItem?
        let range = NSRange(location: 0, length: attributedString.length)
        attributedString.enumerateAttributes(in: range, options: []) { attributes, _, stop in
            if
                let attachment = attributes[.attachment] as? NSTextAttachment,
                let data = attachment.fileWrapper?.regularFileContents ?? attachment.image?.tiffRepresentation
            {
                let assetURL = try? assetStore.storeImage(data: data, fileExtension: "tiff")
                if let assetURL {
                    let dimensions = extractImageDimensions(from: data)
                    var metadata = ClipboardItemMetadata()
                    metadata.imageWidth = dimensions.width
                    metadata.imageHeight = dimensions.height
                    metadata.imageFileSize = Int64(data.count)
                    foundItem = ClipboardItem(
                        id: UUID(),
                        kind: .image,
                        title: assetURL.lastPathComponent,
                        contentText: nil,
                        resourcePath: assetURL.path,
                        sourceAppBundleId: sourceAppBundleId,
                        createdAt: Date(),
                        isPinned: false,
                        metadata: metadata
                    )
                    stop.pointee = true
                    return
                }
            }

            if
                let link = attributes[.link] as? URL,
                looksLikeImageURL(link)
            {
                foundItem = makeRemoteImageItem(from: link, sourceAppBundleId: sourceAppBundleId)
                stop.pointee = true
            }
        }

        return foundItem
    }

    private func makeRemoteImageItem(from rawValue: String, sourceAppBundleId: String?) -> ClipboardItem? {
        guard let url = extractWebImageURL(from: rawValue) else { return nil }
        return makeRemoteImageItem(from: url, sourceAppBundleId: sourceAppBundleId)
    }

    private func makeRemoteImageItem(from url: URL, sourceAppBundleId: String?) -> ClipboardItem {
        var metadata = ClipboardItemMetadata()
        metadata.faviconURL = URL(string: "\(url.scheme ?? "https")://\(url.host ?? "")/favicon.ico")
        return ClipboardItem(
            id: UUID(),
            kind: .image,
            title: url.lastPathComponent.isEmpty ? url.host ?? url.absoluteString : url.lastPathComponent,
            contentText: nil,
            resourcePath: url.absoluteString,
            sourceAppBundleId: sourceAppBundleId,
            createdAt: Date(),
            isPinned: false,
            metadata: metadata
        )
    }

    private func extractWebImageURL(from rawValue: String) -> URL? {
        if let htmlImageURL = extractImageURL(fromHTML: rawValue) {
            return htmlImageURL
        }

        guard let url = URL(string: rawValue.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }

        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return nil
        }

        if looksLikeImageURL(url) {
            return url
        }

        return nil
    }

    private func extractImageURL(fromHTML html: String) -> URL? {
        let patterns = [
            #"<img[^>]+src=["']([^"']+)["']"#,
            #"<source[^>]+srcset=["']([^"']+)["']"#,
            #"property=["']og:image["'][^>]+content=["']([^"']+)["']"#,
            #"content=["']([^"']+)["'][^>]+property=["']og:image["']"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }

            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            guard
                let match = regex.firstMatch(in: html, options: [], range: range),
                match.numberOfRanges > 1,
                let captureRange = Range(match.range(at: 1), in: html)
            else {
                continue
            }

            let candidate = String(html[captureRange])
                .split(separator: ",")
                .first
                .map(String.init)?
                .split(separator: " ")
                .first
                .map(String.init)

            if let candidate, let url = URL(string: candidate), let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
                return url
            }
        }

        return nil
    }

    private func extractImageURL(fromHTMLData data: Data) -> URL? {
        for candidate in decodeHTMLCandidates(from: data) {
            if let url = extractImageURL(fromHTML: candidate) {
                return url
            }
        }

        return nil
    }

    private func extractReadableHTMLText(from data: Data) -> String? {
        for candidate in decodeHTMLCandidates(from: data) {
            let stripped = candidate
                .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            // Require minimum 2 characters to be considered readable content
            if stripped.count >= 2 {
                return stripped
            }
        }
        return nil
    }

    private func looksLikeImageURL(_ url: URL) -> Bool {
        let imageExtensions = ["png", "jpg", "jpeg", "gif", "webp", "heic", "tif", "tiff", "bmp", "avif"]
        if imageExtensions.contains(url.pathExtension.lowercased()) {
            return true
        }

        let lowercasedPath = url.path.lowercased()
        return lowercasedPath.contains("/photo") || lowercasedPath.contains("/image") || lowercasedPath.contains("/media")
    }

    private func fileExtension(forMimeType mimeType: String, fallbackURLString: String?) -> String {
        let normalized = mimeType.lowercased()
        if normalized.contains("png") { return "png" }
        if normalized.contains("jpeg") || normalized.contains("jpg") { return "jpeg" }
        if normalized.contains("gif") { return "gif" }
        if normalized.contains("webp") { return "webp" }
        if normalized.contains("heic") { return "heic" }
        if normalized.contains("tiff") || normalized.contains("tif") { return "tiff" }
        if let fallbackURLString, let url = URL(string: fallbackURLString), !url.pathExtension.isEmpty {
            return url.pathExtension
        }
        return "png"
    }

    private func decodeHTMLCandidates(from data: Data) -> [String] {
        let encodings: [String.Encoding] = [.utf8, .utf16, .utf16LittleEndian, .utf16BigEndian, .unicode, .isoLatin1]
        var candidates: [String] = []
        for encoding in encodings {
            if let string = String(data: data, encoding: encoding), !string.isEmpty {
                candidates.append(string)
            }
        }

        if let attributedString = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.html],
            documentAttributes: nil
        ) {
            candidates.append(attributedString.string)
        }

        if let string = NSString(data: data, encoding: String.Encoding.utf8.rawValue) as String? {
            candidates.append(string)
        }

        // Preserve order while removing duplicate decode attempts.
        var seen = Set<String>()
        return candidates.filter { seen.insert($0).inserted }
    }

    // MARK: - Metadata Extraction

    private func extractImageDimensions(from data: Data) -> (width: Int?, height: Int?) {
        guard let image = NSImage(data: data) else { return (nil, nil) }
        let size = image.size
        if size.width > 0 && size.height > 0 {
            return (Int(size.width), Int(size.height))
        }
        return (nil, nil)
    }

    private func extractTextMetadata(from text: String?) -> ClipboardItemMetadata {
        var metadata = ClipboardItemMetadata()
        guard let text else { return metadata }

        // Detect language for code snippets
        metadata.detectedLanguage = detectCodeLanguage(from: text)

        // Word count
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        metadata.wordCount = words.count

        // Character count
        metadata.characterCount = text.count

        // Line count
        metadata.lineCount = text.components(separatedBy: .newlines).count

        return metadata
    }

    private func extractFileMetadata(from url: URL) -> ClipboardItemMetadata {
        var metadata = ClipboardItemMetadata()
        metadata.fileExtension = url.pathExtension

        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let fileSize = attributes[.size] as? Int64 {
            metadata.fileSize = fileSize
        }

        return metadata
    }

    private func detectCodeLanguage(from text: String) -> CodeLanguage {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Swift
        if trimmed.contains("func ") && (trimmed.contains("let ") || trimmed.contains("var ")) {
            return .swift
        }

        // Python
        if trimmed.hasPrefix("def ") || trimmed.hasPrefix("import ") || trimmed.hasPrefix("from ") {
            return .python
        }

        // JavaScript/TypeScript
        if trimmed.contains("function ") || trimmed.contains("const ") || trimmed.contains("=> ") {
            if trimmed.contains(": string") || trimmed.contains(": number") || trimmed.contains("interface ") {
                return .typescript
            }
            return .javascript
        }

        // JSON
        if (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) || (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) {
            if trimmed.contains(":") && !trimmed.contains(";") {
                return .json
            }
        }

        // HTML
        if trimmed.contains("<html") || trimmed.contains("<div") || trimmed.contains("<!DOCTYPE") {
            return .html
        }

        // SQL
        if trimmed.contains("SELECT ") || trimmed.contains("INSERT ") || trimmed.contains("UPDATE ") || trimmed.contains("DELETE ") {
            return .sql
        }

        // Shell
        if trimmed.hasPrefix("#!/") || trimmed.hasPrefix("sudo ") || trimmed.hasPrefix("chmod ") {
            return .shell
        }

        // Markdown
        if trimmed.hasPrefix("#") || trimmed.hasPrefix("- ") || trimmed.contains("```") {
            return .markdown
        }

        // CSS
        if trimmed.contains("{") && (trimmed.contains("color:") || trimmed.contains("margin:") || trimmed.contains("padding:")) {
            return .css
        }

        return .unknown
    }
}
