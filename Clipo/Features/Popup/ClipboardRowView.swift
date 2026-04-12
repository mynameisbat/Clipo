import SwiftUI

struct ClipboardRowView: View {
    let item: ClipboardItem
    let isSelected: Bool

    private var shouldShowPreview: Bool {
        item.showsInlinePreviewByDefault || isSelected
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with title and metadata
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        // Kind icon
                        kindIcon
                        Text(item.title)
                            .font(.headline)
                            .lineLimit(1)
                    }

                    // Metadata badges
                    metadataBadges
                }

                Spacer()

                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .foregroundColor(.orange)
                        .padding(.top, 2)
                }
            }

            // Preview body
            if shouldShowPreview {
                previewBody
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 50)
        .background(isSelected ? Color.accentColor.opacity(0.18) : Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Kind Icon

    @ViewBuilder
    private var kindIcon: some View {
        switch item.kind {
        case .image:
            Image(systemName: "photo")
                .foregroundColor(.blue)
        case .text:
            if item.metadata.detectedLanguage != .unknown {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .foregroundColor(.purple)
            } else {
                Image(systemName: "doc.text")
                    .foregroundColor(.secondary)
            }
        case .link:
            Image(systemName: "link")
                .foregroundColor(.cyan)
        case .file:
            Image(systemName: "doc")
                .foregroundColor(.green)
        }
    }

    // MARK: - Metadata Badges

    @ViewBuilder
    private var metadataBadges: some View {
        HStack(spacing: 6) {
            // Image metadata
            if item.kind == .image {
                if let width = item.metadata.imageWidth, let height = item.metadata.imageHeight {
                    Badge(text: "\(width)×\(height)", color: .blue)
                }
                if let size = item.metadata.imageFileSize {
                    Badge(text: formatFileSize(size), color: .gray)
                }
            }

            // Code metadata
            if let language = item.metadata.detectedLanguage, language != .unknown {
                Badge(text: language.displayName, color: languageColor(for: language))
                if let lineCount = item.metadata.lineCount {
                    Badge(text: "\(lineCount) lines", color: .gray)
                }
            }

            // Text metadata
            if item.kind == .text && item.metadata.detectedLanguage == .unknown {
                if let wordCount = item.metadata.wordCount {
                    Badge(text: "\(wordCount) words", color: .gray)
                }
                if let charCount = item.metadata.characterCount, charCount > 100 {
                    Badge(text: "\(charCount) chars", color: .gray)
                }
            }

            // File metadata
            if item.kind == .file {
                if let ext = item.metadata.fileExtension, !ext.isEmpty {
                    Badge(text: ext.uppercased(), color: .green)
                }
                if let size = item.metadata.fileSize {
                    Badge(text: formatFileSize(size), color: .gray)
                }
            }
        }
    }

    private func languageColor(for language: CodeLanguage) -> Color {
        switch language {
        case .swift: return .orange
        case .javascript, .typescript: return .yellow
        case .python: return .blue
        case .json: return .gray
        case .html: return .red
        case .css: return .purple
        case .sql: return .green
        case .shell: return .mint
        case .markdown: return .pink
        case .unknown: return .gray
        }
    }

    // MARK: - Preview Body

    @ViewBuilder
    private var previewBody: some View {
        switch item.previewContent {
        case let .text(contentText):
            textPreview(contentText)
        case let .image(url):
            imagePreview(url)
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private func textPreview(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let language = item.metadata.detectedLanguage, language != .unknown {
                // Code preview with syntax highlighting placeholder
                codePreview(text, language: language)
            } else {
                // Plain text preview
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(4)
            }
        }
    }

    @ViewBuilder
    private func codePreview(_ text: String, language: CodeLanguage) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(text.prefix(500) + (text.count > 500 ? "..." : ""))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.primary)
                .padding(8)
                .background(Color.black.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .frame(maxWidth: .infinity)
        .frame(height: isSelected ? 120 : 60)
    }

    @ViewBuilder
    private func imagePreview(_ url: URL) -> some View {
        if url.isFileURL, let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: isSelected ? 160 : 96)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(height: isSelected ? 160 : 96)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: isSelected ? 160 : 96)
                case .failure:
                    Label("Image preview unavailable", systemImage: "photo")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                @unknown default:
                    EmptyView()
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Badge Component

struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
