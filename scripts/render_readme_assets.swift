import AppKit
import SwiftUI

enum ClipboardPopupStyle {
    case anchoredToMenuBar
    case nearCursor

    var cornerRadius: CGFloat {
        switch self {
        case .anchoredToMenuBar: return 12
        case .nearCursor: return 18
        }
    }
}

private struct DemoPanelView: View {
    let searchText: String
    let items: [ClipboardItem]
    let selectedIndex: Int
    let showAccessibilityBanner: Bool
    let isCompact: Bool
    let activeFilters: Set<HistoryFilter>
    let showFilters: Bool
    let isPaused: Bool

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            searchField

            if showFilters {
                FilterChipStrip(activeFilters: .constant(activeFilters))
                    .frame(height: 36)
                    .background(Color.white.opacity(0.04))
            }

            if showAccessibilityBanner {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(DT.Color.warning)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-paste needs Accessibility access")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(DT.Color.textPrimary)
                        Text("Enable to auto-paste items.")
                            .font(.system(size: 10))
                            .foregroundColor(DT.Color.textSecondary)
                    }
                    Spacer()
                    Text("Enable")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(DT.Color.warning.opacity(0.18))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(DT.Color.warning.opacity(0.10))
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    if items.isEmpty {
                        EmptyStateView(searchText: searchText)
                    } else {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            HStack(alignment: .top, spacing: 6) {
                                ClipboardRowView(
                                    item: item,
                                    isSelected: index == selectedIndex,
                                    isCompact: isCompact,
                                    style: .anchoredToMenuBar,
                                    quickPasteHint: index < 9 ? "⌘\(index + 1)" : nil,
                                    onTogglePin: {},
                                    onDelete: {},
                                    onCopyAsPlainText: {}
                                )

                                if !isCompact {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(DT.Color.textSecondary)
                                        .frame(width: 26, height: 26)
                                        .background(Color.white.opacity(0.04))
                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                        .padding(.top, 10)
                                }
                            }
                        }
                    }
                }
                .padding(12)
            }

            footerActions
        }
        .frame(width: 420, height: 520)
        .background(LiquidGlassMaterial(cornerRadius: 18))
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Clipo")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DT.Color.textPrimary)
                Text("\(items.count) items\(isPaused ? " · paused" : "")")
                    .font(.system(size: 10))
                    .foregroundColor(DT.Color.textSecondary)
            }

            Spacer()

            Text("⇧⌘V")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(DT.Color.textSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())

            Image(systemName: "rectangle.compress.vertical")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(DT.Color.textSecondary)
                .frame(width: 26, height: 26)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            Image(systemName: "gearshape")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(DT.Color.textSecondary)
                .frame(width: 26, height: 26)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundColor(DT.Color.textSecondary)

            Text(searchText.isEmpty ? "Search clipboard..." : searchText)
                .foregroundColor(searchText.isEmpty ? DT.Color.textSecondary : DT.Color.textPrimary)
                .font(.system(size: 13))

            Spacer()

            if !searchText.isEmpty {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(DT.Color.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(Color.white.opacity(0.04))
    }

    private var footerActions: some View {
        HStack(spacing: 8) {
            Image(systemName: isPaused ? "play.fill" : "pause.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isPaused ? DT.Color.warning : DT.Color.textSecondary)
                .frame(width: 26, height: 26)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    Circle()
                        .fill(isPaused ? DT.Color.warning : Color.clear)
                        .frame(width: 5, height: 5)
                        .offset(x: 7, y: -7)
                )

            Spacer()

            Image(systemName: "trash")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(DT.Color.textSecondary)
                .frame(width: 26, height: 26)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }
}

@main
struct ReadmeAssetRenderer {
    static func main() throws {
        let repositoryRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let assetsDirectory = repositoryRoot.appendingPathComponent("docs/assets", isDirectory: true)
        try FileManager.default.createDirectory(at: assetsDirectory, withIntermediateDirectories: true)

        let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("clipo-readme-assets", isDirectory: true)
        try? FileManager.default.removeItem(at: temporaryDirectory)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)

        let generatedImageURL = temporaryDirectory.appendingPathComponent("demo-image.png")
        try createDemoImage(at: generatedImageURL)

        let overviewItems = makeOverviewItems(imageURL: generatedImageURL)
        let compactItems = makeCompactItems()
        let filtersItems = makeFiltersItems(imageURL: generatedImageURL)

        try render(
            view: DemoPanelView(
                searchText: "",
                items: overviewItems,
                selectedIndex: 0,
                showAccessibilityBanner: false,
                isCompact: false,
                activeFilters: [],
                showFilters: false,
                isPaused: false
            ),
            to: assetsDirectory.appendingPathComponent("clipo-overview.png")
        )

        try render(
            view: DemoPanelView(
                searchText: "",
                items: compactItems,
                selectedIndex: 1,
                showAccessibilityBanner: false,
                isCompact: true,
                activeFilters: [],
                showFilters: false,
                isPaused: false
            ),
            to: assetsDirectory.appendingPathComponent("clipo-compact.png")
        )

        try render(
            view: DemoPanelView(
                searchText: "",
                items: filtersItems,
                selectedIndex: 1,
                showAccessibilityBanner: false,
                isCompact: false,
                activeFilters: [.kind(.image), .dateRange(.last7Days)],
                showFilters: true,
                isPaused: false
            ),
            to: assetsDirectory.appendingPathComponent("clipo-filters.png")
        )

        try render(
            view: DemoPanelView(
                searchText: "",
                items: overviewItems,
                selectedIndex: 0,
                showAccessibilityBanner: true,
                isCompact: false,
                activeFilters: [],
                showFilters: false,
                isPaused: false
            ),
            to: assetsDirectory.appendingPathComponent("clipo-banner.png")
        )

        let framesDirectory = temporaryDirectory.appendingPathComponent("gif-frames", isDirectory: true)
        try? FileManager.default.removeItem(at: framesDirectory)
        try FileManager.default.createDirectory(at: framesDirectory, withIntermediateDirectories: true)

        let frameStates: [(String, [ClipboardItem], Int, Bool, Bool, Set<HistoryFilter>, Bool, Bool)] = [
            ("", overviewItems, 0, false, false, [], false, false),
            ("f", overviewItems, 0, false, false, [], false, false),
            ("fi", overviewItems, 0, false, false, [], false, false),
            ("fig", filtersItems, 1, false, false, [], false, false),
            ("fig", filtersItems, 1, false, true, [.kind(.image)], true, false)
        ]

        for (index, state) in frameStates.enumerated() {
            try render(
                view: DemoPanelView(
                    searchText: state.0,
                    items: state.1,
                    selectedIndex: state.2,
                    showAccessibilityBanner: state.3,
                    isCompact: state.4,
                    activeFilters: state.5,
                    showFilters: state.6,
                    isPaused: state.7
                ),
                to: framesDirectory.appendingPathComponent(String(format: "frame-%02d.png", index))
            )
        }

        print("Generated README assets in \(assetsDirectory.path)")
    }

    private static func render<V: View>(view: V, to outputURL: URL) throws {
        let hostingView = NSHostingView(rootView: view.colorScheme(.dark))
        let size = NSSize(width: 420, height: 520)
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.layoutSubtreeIfNeeded()
        hostingView.appearance = NSAppearance(named: .darkAqua)

        guard let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            throw NSError(domain: "ReadmeAssetRenderer", code: 1)
        }

        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)

        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "ReadmeAssetRenderer", code: 2)
        }

        try data.write(to: outputURL)
    }

    private static func createDemoImage(at url: URL) throws {
        let size = NSSize(width: 960, height: 540)
        let image = NSImage(size: size)
        image.lockFocus()

        let bounds = NSRect(origin: .zero, size: size)
        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.08, green: 0.72, blue: 0.65, alpha: 1),
            NSColor(calibratedRed: 0.04, green: 0.40, blue: 0.50, alpha: 1),
            NSColor(calibratedRed: 0.06, green: 0.09, blue: 0.16, alpha: 1)
        ])!
        gradient.draw(in: bounds, angle: -135)

        let card = NSBezierPath(roundedRect: NSRect(x: 80, y: 110, width: 800, height: 320), xRadius: 32, yRadius: 32)
        NSColor(calibratedWhite: 1, alpha: 0.10).setFill()
        card.fill()

        let stack = NSBezierPath(roundedRect: NSRect(x: 145, y: 175, width: 240, height: 200), xRadius: 18, yRadius: 18)
        NSColor(calibratedWhite: 0.95, alpha: 0.92).setFill()
        stack.fill()

        let stack2 = NSBezierPath(roundedRect: NSRect(x: 165, y: 165, width: 240, height: 200), xRadius: 18, yRadius: 18)
        NSColor(calibratedWhite: 0.98, alpha: 0.92).setFill()
        stack2.fill()

        let stack3 = NSBezierPath(roundedRect: NSRect(x: 185, y: 155, width: 240, height: 200), xRadius: 18, yRadius: 18)
        NSColor.white.setFill()
        stack3.fill()

        NSColor(calibratedWhite: 0.85, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 210, y: 280, width: 140, height: 12), xRadius: 4, yRadius: 4).fill()
        NSBezierPath(roundedRect: NSRect(x: 210, y: 305, width: 180, height: 8), xRadius: 3, yRadius: 3).fill()
        NSBezierPath(roundedRect: NSRect(x: 210, y: 322, width: 150, height: 8), xRadius: 3, yRadius: 3).fill()

        let dot = NSBezierPath(ovalIn: NSRect(x: 360, y: 195, width: 38, height: 38))
        NSColor(calibratedRed: 0.08, green: 0.72, blue: 0.65, alpha: 1).setFill()
        dot.fill()

        let title = NSAttributedString(
            string: "Clipo",
            attributes: [
                .font: NSFont.systemFont(ofSize: 56, weight: .bold),
                .foregroundColor: NSColor.white
            ]
        )
        title.draw(at: NSPoint(x: 540, y: 270))

        let subtitle = NSAttributedString(
            string: "Your clipboard, supercharged",
            attributes: [
                .font: NSFont.systemFont(ofSize: 22, weight: .medium),
                .foregroundColor: NSColor(calibratedWhite: 1, alpha: 0.88)
            ]
        )
        subtitle.draw(at: NSPoint(x: 540, y: 220))

        let badge = NSBezierPath(roundedRect: NSRect(x: 540, y: 158, width: 200, height: 34), xRadius: 17, yRadius: 17)
        NSColor(calibratedWhite: 1, alpha: 0.20).setFill()
        badge.fill()

        let badgeText = NSAttributedString(
            string: "macOS menu bar · MIT",
            attributes: [
                .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: NSColor.white
            ]
        )
        badgeText.draw(at: NSPoint(x: 564, y: 168))

        image.unlockFocus()

        guard
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let png = bitmap.representation(using: .png, properties: [:])
        else {
            throw NSError(domain: "ReadmeAssetRenderer", code: 3)
        }

        try png.write(to: url)
    }

    private static func makeOverviewItems(imageURL: URL) -> [ClipboardItem] {
        [
            .stub(
                kind: .image,
                title: "Hero illustration",
                resourcePath: imageURL.path,
                sourceAppBundleId: "com.apple.Photos",
                isPinned: true,
                metadata: ClipboardItemMetadata(
                    imageWidth: 960,
                    imageHeight: 540,
                    imageFileSize: 180_000,
                    detectedLanguage: nil,
                    lineCount: nil,
                    characterCount: nil,
                    wordCount: nil,
                    fileSize: nil,
                    fileExtension: nil
                )
            ),
            .stub(
                kind: .text,
                title: "Swift snippet",
                contentText: """
                let history = try await historyStore.recentItems(limit: 100)
                visibleItems = history.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
                """,
                sourceAppBundleId: "com.apple.dt.Xcode",
                metadata: ClipboardItemMetadata(
                    imageWidth: nil,
                    imageHeight: nil,
                    imageFileSize: nil,
                    faviconURL: nil,
                    detectedLanguage: .swift,
                    lineCount: 2,
                    characterCount: 124,
                    wordCount: nil,
                    fileSize: nil,
                    fileExtension: nil
                )
            ),
            .stub(
                kind: .link,
                title: "Release notes",
                contentText: "https://github.com/bloodstalk1/Clipo/releases",
                sourceAppBundleId: "com.apple.Safari",
                metadata: ClipboardItemMetadata(
                    imageWidth: nil,
                    imageHeight: nil,
                    imageFileSize: nil,
                    faviconURL: nil,
                    detectedLanguage: nil,
                    lineCount: nil,
                    characterCount: 58,
                    wordCount: 5,
                    fileSize: nil,
                    fileExtension: nil
                )
            ),
            .stub(
                kind: .text,
                title: "Standup note",
                contentText: "Polished popup behavior, added retention policy, and packaged the first public DMG.",
                sourceAppBundleId: "com.apple.Notes",
                metadata: ClipboardItemMetadata(
                    imageWidth: nil,
                    imageHeight: nil,
                    imageFileSize: nil,
                    faviconURL: nil,
                    detectedLanguage: nil,
                    lineCount: nil,
                    characterCount: 89,
                    wordCount: 13,
                    fileSize: nil,
                    fileExtension: nil
                )
            )
        ]
    }

    private static func makeCompactItems() -> [ClipboardItem] {
        [
            .stub(
                kind: .text,
                title: "Quick command",
                contentText: "gh pr create --fill",
                sourceAppBundleId: "com.apple.Terminal",
                metadata: ClipboardItemMetadata(
                    detectedLanguage: .shell,
                    lineCount: 1,
                    characterCount: 19
                )
            ),
            .stub(
                kind: .text,
                title: "Hex color palette",
                contentText: "#14B8A6  #0EA5E9  #F59E0B  #EF4444",
                sourceAppBundleId: "com.apple.Notes",
                metadata: ClipboardItemMetadata(
                    detectedLanguage: .markdown,
                    lineCount: 1,
                    characterCount: 44
                )
            ),
            .stub(
                kind: .link,
                title: "Linear changelog",
                contentText: "https://linear.app/changelog/2024-12",
                sourceAppBundleId: "com.apple.Safari",
                metadata: ClipboardItemMetadata(
                    characterCount: 43,
                    wordCount: 2
                )
            ),
            .stub(
                kind: .text,
                title: "Email draft",
                contentText: "Following up on our conversation about the launch plan for next quarter.",
                sourceAppBundleId: "com.apple.mail",
                metadata: ClipboardItemMetadata(
                    characterCount: 84,
                    wordCount: 14
                )
            )
        ]
    }

    private static func makeFiltersItems(imageURL: URL) -> [ClipboardItem] {
        [
            .stub(
                kind: .text,
                title: "Image dimensions spec",
                contentText: "1920×1080 cover image, 2x retina export, 600 KB max",
                sourceAppBundleId: "com.apple.Notes",
                metadata: ClipboardItemMetadata(
                    characterCount: 60,
                    wordCount: 12
                )
            ),
            .stub(
                kind: .image,
                title: "Screenshot from today",
                resourcePath: imageURL.path,
                sourceAppBundleId: "com.apple.screencapture",
                metadata: ClipboardItemMetadata(
                    imageWidth: 960,
                    imageHeight: 540,
                    imageFileSize: 180_000
                )
            ),
            .stub(
                kind: .image,
                title: "Reference photo",
                resourcePath: imageURL.path,
                sourceAppBundleId: "com.apple.Photos",
                isPinned: true,
                metadata: ClipboardItemMetadata(
                    imageWidth: 960,
                    imageHeight: 540,
                    imageFileSize: 180_000
                )
            )
        ]
    }
}
