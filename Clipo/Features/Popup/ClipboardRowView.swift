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
    let searchText: String
    let quickPasteHint: String?
    let onTogglePin: () -> Void
    let onDelete: () -> Void
    let onCopyAsPlainText: () -> Void
    var onEditImage: (() -> Void)? = nil
    var onExtractTextOCR: (() -> Void)? = nil

    @State private var isHovered = false
    @State private var sourceAppIcon: NSImage?
    @State private var revealSensitive = false

    private var displayTitle: String {
        if item.isSensitive && !revealSensitive {
            return item.maskedTitle
        }
        return item.title
    }

    private var shouldShowPreview: Bool {
        guard !isCompact else { return false }
        return item.showsInlinePreviewByDefault || (isSelected && item.showsExpandedPreviewWhenSelected)
    }

    var body: some View {
        HStack(spacing: 0) {
            Capsule()
                .fill(isSelected ? DT.Color.accent : Color.clear)
                .frame(width: Appearance.selectedAccentWidth, height: 20)
                .padding(.leading, 6)

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
        .animation(.selection, value: isSelected)
        .onHover { hovering in
            withAnimation(.hoverHighlight) {
                isHovered = hovering
            }
        }
        .task {
            await loadSourceAppIcon()
        }
        .contextMenu {
            contextMenuItems
        }
    }

    private var sourceAppOrKindBadge: some View {
        Group {
            if let sourceAppIcon {
                Image(nsImage: sourceAppIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Appearance.kindBadgeSize, height: Appearance.kindBadgeSize)
                    .clipShape(RoundedRectangle(cornerRadius: DT.Radius.s, style: .continuous))
            } else {
                kindBadge
            }
        }
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: DT.Spacing.s) {
            sourceAppOrKindBadge

            highlightedText(displayTitle, query: searchText)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(DT.Color.textPrimary)
                .lineLimit(1)

            if item.isSensitive {
                Button {
                    revealSensitive.toggle()
                } label: {
                    Image(systemName: revealSensitive ? "eye.fill" : "eye.slash.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(DT.Color.accent)
                }
                .buttonStyle(.plain)
                .help(revealSensitive ? "Hide sensitive info" : "Reveal sensitive info")
            }

            if let badgeColor = parseColor(item.title) {
                RoundedRectangle(cornerRadius: 3.5)
                    .fill(badgeColor)
                    .frame(width: 13, height: 13)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3.5)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
            }

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
        HStack(spacing: DT.Spacing.s) {
            Text(relativeTimeText)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(DT.Color.textSecondary)

            Spacer(minLength: 0)

            HStack(spacing: DT.Spacing.xxs) {
                if let pinboard = item.pinboard, !pinboard.isEmpty {
                    pillBadge(text: pinboard, color: Color.teal)
                }

                if let language = item.metadata.detectedLanguage, language != .unknown {
                    pillBadge(text: language.displayName, color: Color.indigo)
                }

                if let wordCount = item.metadata.wordCount, wordCount > 0 {
                    pillBadge(text: "\(wordCount) words", color: DT.Color.textSecondary)
                }

                if item.kind == .image, let width = item.metadata.imageWidth, let height = item.metadata.imageHeight {
                    pillBadge(text: "\(width)×\(height)", color: DT.Color.accent, design: .monospaced)
                }

                if let ext = item.metadata.fileExtension, !ext.isEmpty {
                    pillBadge(text: ext.uppercased(), color: Color.orange, design: .monospaced)
                }
            }
        }
    }

    @ViewBuilder
    private func pillBadge(text: String, color: Color, design: Font.Design = .default) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold, design: design))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.08))
            .overlay(
                Capsule().stroke(color.opacity(0.18), lineWidth: 1)
            )
            .clipShape(Capsule())
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

        if item.kind == .image {
            if let onEditImage {
                Button {
                    onEditImage()
                } label: {
                    Label("Edit Image", systemImage: "pencil.and.outline")
                }
            }
            if let onExtractTextOCR {
                Button {
                    onExtractTextOCR()
                } label: {
                    Label("Extract Text from Image (OCR)", systemImage: "text.viewfinder")
                }
            }
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
            let textToUse = (item.isSensitive && !revealSensitive) ? (item.maskedText ?? "") : contentText
            textPreview(textToUse)
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
            highlightedText(text, query: searchText)
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
            return item.metadata.detectedLanguage != .unknown ? Color.indigo : DT.Color.textSecondary
        case .link: return Color.blue
        case .file: return Color.orange
        }
    }

    @ViewBuilder
    private var kindIcon: some View {
        switch item.kind {
        case .image:
            Image(systemName: "photo.fill").foregroundColor(DT.Color.accent)
        case .text:
            if item.metadata.detectedLanguage != .unknown {
                Image(systemName: "terminal.fill").foregroundColor(Color.indigo)
            } else {
                Image(systemName: "text.alignleft").foregroundColor(DT.Color.textSecondary)
            }
        case .link:
            Image(systemName: "link").foregroundColor(Color.blue)
        case .file:
            Image(systemName: "doc.fill").foregroundColor(Color.orange)
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

    private func parseColor(_ text: String) -> Color? {
        if let hexColor = parseHexColor(text) {
            return hexColor
        }
        if let rgbColor = parseRgbColor(text) {
            return rgbColor
        }
        return nil
    }

    private func parseHexColor(_ text: String) -> Color? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.hasPrefix("#") || cleaned.count == 3 || cleaned.count == 6 || cleaned.count == 8 else { return nil }
        
        var hex = cleaned
        if hex.hasPrefix("#") {
            hex.removeFirst()
        }
        
        let characterSet = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
        guard CharacterSet(charactersIn: hex).isSubset(of: characterSet) else { return nil }
        guard hex.count == 3 || hex.count == 6 || hex.count == 8 else { return nil }
        
        var rgbValue: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgbValue)
        
        let r, g, b, a: Double
        if hex.count == 3 {
            r = Double((rgbValue & 0xF00) >> 8) / 15.0
            g = Double((rgbValue & 0x0F0) >> 4) / 15.0
            b = Double(rgbValue & 0x00F) / 15.0
            a = 1.0
        } else if hex.count == 6 {
            r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
            g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
            b = Double(rgbValue & 0x0000FF) / 255.0
            a = 1.0
        } else if hex.count == 8 {
            r = Double((rgbValue & 0xFF000000) >> 24) / 255.0
            g = Double((rgbValue & 0x00FF0000) >> 16) / 255.0
            b = Double((rgbValue & 0x0000FF00) >> 8) / 255.0
            a = Double(rgbValue & 0x000000FF) / 255.0
        } else {
            return nil
        }
        
        return Color(red: r, green: g, blue: b, opacity: a)
    }

    private func parseRgbColor(_ text: String) -> Color? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard cleaned.hasPrefix("rgb") else { return nil }
        
        guard let openParen = cleaned.firstIndex(of: "("),
              let closeParen = cleaned.firstIndex(of: ")"),
              openParen < closeParen else { return nil }
              
        let contentStart = cleaned.index(after: openParen)
        let content = String(cleaned[contentStart..<closeParen])
        
        let parts = content.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard parts.count == 3 || parts.count == 4 else { return nil }
        
        func parseComponent(_ part: String, maxVal: Double) -> Double? {
            if part.hasSuffix("%") {
                guard let val = Double(part.dropLast()) else { return nil }
                return (val / 100.0) * maxVal
            }
            return Double(part)
        }
        
        guard let r = parseComponent(parts[0], maxVal: 255.0),
              let g = parseComponent(parts[1], maxVal: 255.0),
              let b = parseComponent(parts[2], maxVal: 255.0) else { return nil }
              
        var alpha: Double = 1.0
        if parts.count == 4 {
            if parts[3].hasSuffix("%") {
                if let val = Double(parts[3].dropLast()) {
                    alpha = val / 100.0
                } else {
                    return nil
                }
            } else {
                guard let val = Double(parts[3]) else { return nil }
                alpha = val
            }
        }
        
        return Color(
            red: max(0.0, min(1.0, r / 255.0)),
            green: max(0.0, min(1.0, g / 255.0)),
            blue: max(0.0, min(1.0, b / 255.0)),
            opacity: max(0.0, min(1.0, alpha))
        )
    }

    private func highlightedText(_ text: String, query: String) -> Text {
        guard !query.isEmpty else { return Text(text) }
        
        var result = Text("")
        let lowercasedText = text.lowercased()
        let lowercasedQuery = query.lowercased()
        
        var currentIndex = text.startIndex
        while let range = lowercasedText.range(of: lowercasedQuery, range: currentIndex..<text.endIndex) {
            let prefix = String(text[currentIndex..<range.lowerBound])
            let match = String(text[range])
            
            result = result + Text(prefix)
            result = result + Text(match)
                .bold()
                .foregroundColor(DT.Color.accent)
            
            currentIndex = range.upperBound
        }
        
        let suffix = String(text[currentIndex..<text.endIndex])
        result = result + Text(suffix)
        
        return result
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
