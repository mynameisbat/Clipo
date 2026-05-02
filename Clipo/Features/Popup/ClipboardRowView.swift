import SwiftUI

struct ClipboardRowView: View {
    private enum Appearance {
        static let cornerRadius: CGFloat = 14
    }

    let item: ClipboardItem
    let isSelected: Bool
    let style: ClipboardPopupStyle
    @State private var isHovered = false
    @State private var sourceAppIcon: NSImage?

    private var shouldShowPreview: Bool {
        item.showsInlinePreviewByDefault || (isSelected && item.showsExpandedPreviewWhenSelected)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        iconBadge
                        Text(item.title)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                    }

                    metadataBadges
                }

                Spacer()

                HStack(spacing: 8) {
                    if let sourceAppIcon {
                        Image(nsImage: sourceAppIcon)
                            .resizable()
                            .frame(width: 16, height: 16)
                            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                            .accessibilityLabel("Source app: \(item.sourceAppBundleId ?? "Unknown")")
                    }

                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .foregroundColor(.orange)
                            .padding(.top, 2)
                    }
                }
            }

            if shouldShowPreview {
                previewBody
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 50)
        .background(rowBackground)
        .overlay(
            RoundedRectangle(cornerRadius: Appearance.cornerRadius, style: .continuous)
                .stroke(rowBorderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Appearance.cornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Appearance.cornerRadius, style: .continuous))
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.hoverHighlight, value: isHovered)
        .animation(.selection, value: isSelected)
        .onHover { hovering in
            isHovered = hovering
        }
        .task {
            await loadSourceAppIcon()
        }
    }

    private func loadSourceAppIcon() async {
        guard let bundleId = item.sourceAppBundleId else { return }
        let provider = AppIconProvider()
        sourceAppIcon = await provider.icon(for: bundleId)
    }

    @ViewBuilder
    private var iconBadge: some View {
        kindIcon
            .font(.system(size: 12, weight: .semibold))
            .frame(width: 22, height: 22)
            .background(kindTint.opacity(0.16))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    @ViewBuilder
    private var metadataBadges: some View {
        HStack(spacing: 6) {
            if item.kind == .image {
                if let width = item.metadata.imageWidth, let height = item.metadata.imageHeight {
                    Badge(text: "\(width)×\(height)", color: .blue)
                }
                if let size = item.metadata.imageFileSize {
                    Badge(text: formatFileSize(size), color: .gray)
                }
            }

            if let language = item.metadata.detectedLanguage, language != .unknown {
                Badge(text: language.displayName, color: languageColor(for: language))
                if let lineCount = item.metadata.lineCount {
                    Badge(text: "\(lineCount) lines", color: .gray)
                }
            }

            if item.kind == .text && item.metadata.detectedLanguage == .unknown {
                if let wordCount = item.metadata.wordCount {
                    Badge(text: "\(wordCount) words", color: .gray)
                }
                if let charCount = item.metadata.characterCount, charCount > 100 {
                    Badge(text: "\(charCount) chars", color: .gray)
                }
            }

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
                codePreview(text, language: language)
            } else {
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
                .background(Color.black.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .frame(maxWidth: .infinity)
        .frame(height: isSelected ? 120 : 60)
        .animation(.smoothSlide, value: isSelected)
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
                .animation(.smoothSlide, value: isSelected)
                .accessibilityLabel("Image preview: \(item.title)")
                .accessibilityHint("Press Enter to paste this image")
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
                        .animation(.smoothSlide, value: isSelected)
                        .accessibilityLabel("Image preview: \(item.title)")
                        .accessibilityHint("Press Enter to paste this image")
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: isSelected ? 160 : 96)
                        .accessibilityLabel("Loading image preview")
                case .failure:
                    Label("Image preview unavailable", systemImage: "photo")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .accessibilityLabel("Image preview unavailable for \(item.title)")
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

    private var kindTint: Color {
        switch item.kind {
        case .image:
            return .blue
        case .text:
            return item.metadata.detectedLanguage != .unknown ? .purple : .secondary
        case .link:
            return .cyan
        case .file:
            return .green
        }
    }

    @ViewBuilder
    private var kindIcon: some View {
        switch item.kind {
        case .image:
            Image(systemName: "photo")
                .foregroundColor(.blue)
        case .text:
            Image(systemName: "doc.text")
                .foregroundColor(.secondary)
        case .link:
            Image(systemName: "link")
                .foregroundColor(.cyan)
        case .file:
            Image(systemName: "doc")
                .foregroundColor(.green)
        }
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: Appearance.cornerRadius, style: .continuous)
            .fill(isSelected ? selectedBackgroundColor : normalBackgroundColor)
    }

    private var rowBorderColor: Color {
        isSelected ? selectedBorderColor : normalBorderColor
    }

    private var normalBackgroundColor: Color {
        style == .anchoredToMenuBar ? Color.black.opacity(0.025) : Color.white.opacity(0.055)
    }

    private var selectedBackgroundColor: Color {
        style == .anchoredToMenuBar ? Color.accentColor.opacity(0.12) : Color.accentColor.opacity(0.18)
    }

    private var normalBorderColor: Color {
        style == .anchoredToMenuBar ? Color.black.opacity(0.05) : Color.white.opacity(0.07)
    }

    private var selectedBorderColor: Color {
        style == .anchoredToMenuBar ? Color.accentColor.opacity(0.18) : Color.accentColor.opacity(0.28)
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
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.14))
            .clipShape(Capsule())
    }
}
