import SwiftUI

struct ClipboardRowView: View {
    private enum Appearance {
        static let radius: CGFloat = 14
        static let selectedAccentWidth: CGFloat = 2
        static let kindBadgeSize: CGFloat = 22
    }

    let item: ClipboardItem
    let isSelected: Bool
    let isCompact: Bool
    let style: ClipboardPopupStyle
    let quickPasteHint: String?
    let onTogglePin: () -> Void
    let onDelete: () -> Void
    let onCopyAsPlainText: () -> Void

    @State private var isHovered = false
    @State private var sourceAppIcon: NSImage?

    private var shouldShowPreview: Bool {
        guard !isCompact else { return false }
        return item.showsInlinePreviewByDefault || (isSelected && item.showsExpandedPreviewWhenSelected)
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(isSelected ? DT.Color.accent : Color.clear)
                .frame(width: Appearance.selectedAccentWidth)

            VStack(alignment: .leading, spacing: DT.Spacing.s) {
                headerRow

                if !isCompact {
                    metadataRow
                }

                if shouldShowPreview {
                    previewBody
                        .padding(.top, DT.Spacing.xxs)
                }
            }
            .padding(DT.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: isCompact ? 48 : 60, alignment: .leading)
        .background(rowBackground)
        .overlay(
            RoundedRectangle(cornerRadius: Appearance.radius, style: .continuous)
                .stroke(rowBorderColor, lineWidth: 1)
        )
        .overlay(alignment: .top) {
            if item.isPinned {
                Rectangle()
                    .fill(DT.Color.accent)
                    .frame(height: 1)
                    .clipShape(RoundedRectangle(cornerRadius: Appearance.radius, style: .continuous))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Appearance.radius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Appearance.radius, style: .continuous))
        .scaleEffect(isHovered ? 1.005 : 1.0)
        .animation(.hoverHighlight, value: isHovered)
        .animation(.selection, value: isSelected)
        .onHover { hovering in
            isHovered = hovering
        }
        .task {
            await loadSourceAppIcon()
        }
        .contextMenu {
            contextMenuItems
        }
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: DT.Spacing.s) {
            kindBadge

            Text(item.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(DT.Color.textPrimary)
                .lineLimit(1)

            Spacer(minLength: DT.Spacing.s)

            if let quickPasteHint {
                Text(quickPasteHint)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(isSelected ? DT.Color.accent : DT.Color.textSecondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.10) : Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: DT.Radius.xs, style: .continuous))
            }

            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(DT.Color.accent)
            }
        }
    }

    private var metadataRow: some View {
        HStack(spacing: DT.Spacing.xs) {
            if let sourceAppIcon {
                Image(nsImage: sourceAppIcon)
                    .resizable()
                    .frame(width: 12, height: 12)
                    .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                    .accessibilityLabel("Source app: \(item.sourceAppBundleId ?? "Unknown")")
            }

            Text(relativeTimeText)
                .font(.system(size: 10))
                .foregroundColor(DT.Color.textSecondary)

            if let language = item.metadata.detectedLanguage, language != .unknown {
                metaSeparator
                Text(language.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(DT.Color.textSecondary)
            }

            if let wordCount = item.metadata.wordCount, wordCount > 0 {
                metaSeparator
                Text("\(wordCount) words")
                    .font(.system(size: 10))
                    .foregroundColor(DT.Color.textSecondary)
            }

            if item.kind == .image, let width = item.metadata.imageWidth, let height = item.metadata.imageHeight {
                metaSeparator
                Text("\(width)×\(height)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(DT.Color.textSecondary)
            }

            if let ext = item.metadata.fileExtension, !ext.isEmpty {
                metaSeparator
                Text(ext.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(DT.Color.textSecondary)
            }
        }
    }

    private var metaSeparator: some View {
        Text("\u{00B7}")
            .font(.system(size: 10))
            .foregroundColor(DT.Color.textSecondary.opacity(0.6))
    }

    private var kindBadge: some View {
        kindIcon
            .font(.system(size: 11, weight: .semibold))
            .frame(width: Appearance.kindBadgeSize, height: Appearance.kindBadgeSize)
            .background(kindTint.opacity(0.16))
            .clipShape(RoundedRectangle(cornerRadius: DT.Radius.s, style: .continuous))
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        Button {
            onTogglePin()
        } label: {
            Label(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash" : "pin")
        }

        Button {
            onCopyAsPlainText()
        } label: {
            Label("Copy as Plain Text", systemImage: "doc.on.doc")
        }

        Divider()

        Button(role: .destructive) {
            onDelete()
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func loadSourceAppIcon() async {
        guard let bundleId = item.sourceAppBundleId else { return }
        let provider = AppIconProvider()
        sourceAppIcon = await provider.icon(for: bundleId)
    }

    private var relativeTimeText: String {
        Self.relativeTimeFormatter.localizedString(for: item.createdAt, relativeTo: Date())
    }

    private static let relativeTimeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

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
        if let language = item.metadata.detectedLanguage, language != .unknown {
            codePreview(text, language: language)
        } else {
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(DT.Color.textSecondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func codePreview(_ text: String, language: CodeLanguage) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(text.prefix(500) + (text.count > 500 ? "..." : ""))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(DT.Color.textPrimary)
                .padding(DT.Spacing.s)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: DT.Radius.s, style: .continuous))
        .frame(maxWidth: .infinity)
        .frame(height: isSelected ? 100 : 56)
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
                .clipShape(RoundedRectangle(cornerRadius: DT.Radius.s, style: .continuous))
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
                        .clipShape(RoundedRectangle(cornerRadius: DT.Radius.s, style: .continuous))
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
                        .font(.system(size: 12))
                        .foregroundColor(DT.Color.textSecondary)
                        .accessibilityLabel("Image preview unavailable for \(item.title)")
                @unknown default:
                    EmptyView()
                }
            }
        }
    }

    private var kindTint: Color {
        switch item.kind {
        case .image: return DT.Color.accent
        case .text:
            return item.metadata.detectedLanguage != .unknown ? Color.purple : DT.Color.textSecondary
        case .link: return Color.cyan
        case .file: return Color.green
        }
    }

    @ViewBuilder
    private var kindIcon: some View {
        switch item.kind {
        case .image:
            Image(systemName: "photo").foregroundColor(DT.Color.accent)
        case .text:
            Image(systemName: "doc.text").foregroundColor(DT.Color.textSecondary)
        case .link:
            Image(systemName: "link").foregroundColor(Color.cyan)
        case .file:
            Image(systemName: "doc").foregroundColor(Color.green)
        }
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: Appearance.radius, style: .continuous)
            .fill(isSelected ? selectedFill : normalFill)
    }

    private var rowBorderColor: Color {
        isSelected ? selectedStroke : normalStroke
    }

    private var normalFill: Color {
        isHovered
            ? Color.white.opacity(0.08)
            : (style == .anchoredToMenuBar ? Color.black.opacity(0.025) : Color.white.opacity(0.04))
    }

    private var selectedFill: Color {
        DT.Color.accentMuted
    }

    private var normalStroke: Color {
        isHovered ? Color.white.opacity(0.10) : DT.Color.stroke
    }

    private var selectedStroke: Color {
        DT.Color.accent.opacity(0.32)
    }
}

struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, DT.Spacing.xs)
            .padding(.vertical, 2)
            .background(color.opacity(0.14))
            .clipShape(Capsule())
    }
}
