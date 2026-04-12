import AppKit
import SwiftUI

struct DemoPanelView: View {
    let searchText: String
    let items: [ClipboardItem]
    let selectedIndex: Int
    let showAccessibilityBanner: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    Text(searchText.isEmpty ? "Search clipboard..." : searchText)
                        .foregroundColor(searchText.isEmpty ? .secondary : .primary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Image(systemName: "gearshape")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if showAccessibilityBanner {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Auto-paste needs Accessibility access")
                            .font(.subheadline.weight(.semibold))
                        Text("Enable to auto-paste items.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("Enable")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.yellow.opacity(0.18))
                        .clipShape(Capsule())
                }
                .padding(12)
                .background(Color.yellow.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        HStack(alignment: .top, spacing: 8) {
                            ClipboardRowView(item: item, isSelected: index == selectedIndex)
                            Image(systemName: "trash")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                                .frame(width: 28, height: 28)
                                .background(Color.white.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .padding(.top, 10)
                        }
                    }
                }
            }

            HStack {
                Text("Clear History")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())

                Spacer()

                Text("Quit")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
            }
        }
        .padding(16)
        .frame(width: 420, height: 500)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.11, blue: 0.15),
                    Color(red: 0.07, green: 0.08, blue: 0.10)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
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
        let searchItems = makeSearchItems(imageURL: generatedImageURL)

        try render(
            view: DemoPanelView(
                searchText: "",
                items: overviewItems,
                selectedIndex: 0,
                showAccessibilityBanner: false
            ),
            to: assetsDirectory.appendingPathComponent("clipo-overview.png")
        )

        try render(
            view: DemoPanelView(
                searchText: "fig",
                items: searchItems,
                selectedIndex: 1,
                showAccessibilityBanner: false
            ),
            to: assetsDirectory.appendingPathComponent("clipo-search.png")
        )

        let framesDirectory = temporaryDirectory.appendingPathComponent("gif-frames", isDirectory: true)
        try? FileManager.default.removeItem(at: framesDirectory)
        try FileManager.default.createDirectory(at: framesDirectory, withIntermediateDirectories: true)

        let frameStates: [(String, [ClipboardItem], Int)] = [
            ("", overviewItems, 0),
            ("f", searchItems, 0),
            ("fi", searchItems, 0),
            ("fig", searchItems, 1),
            ("figm", searchItems, 1)
        ]

        for (index, state) in frameStates.enumerated() {
            try render(
                view: DemoPanelView(
                    searchText: state.0,
                    items: state.1,
                    selectedIndex: state.2,
                    showAccessibilityBanner: false
                ),
                to: framesDirectory.appendingPathComponent(String(format: "frame-%02d.png", index))
            )
        }
    }

    private static func render<V: View>(view: V, to outputURL: URL) throws {
        let hostingView = NSHostingView(rootView: view.colorScheme(.dark))
        let size = NSSize(width: 420, height: 500)
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
            NSColor(calibratedRed: 0.15, green: 0.37, blue: 0.78, alpha: 1),
            NSColor(calibratedRed: 0.51, green: 0.24, blue: 0.87, alpha: 1),
            NSColor(calibratedRed: 0.93, green: 0.34, blue: 0.51, alpha: 1)
        ])!
        gradient.draw(in: bounds, angle: -28)

        let card = NSBezierPath(roundedRect: NSRect(x: 80, y: 110, width: 800, height: 320), xRadius: 32, yRadius: 32)
        NSColor(calibratedWhite: 0.98, alpha: 0.18).setFill()
        card.fill()

        let inner = NSBezierPath(roundedRect: NSRect(x: 120, y: 155, width: 420, height: 230), xRadius: 24, yRadius: 24)
        NSColor(calibratedWhite: 0.05, alpha: 0.68).setFill()
        inner.fill()

        let sidebar = NSBezierPath(roundedRect: NSRect(x: 575, y: 155, width: 265, height: 230), xRadius: 24, yRadius: 24)
        NSColor(calibratedWhite: 1, alpha: 0.18).setFill()
        sidebar.fill()

        let title = NSAttributedString(
            string: "Clipo Preview",
            attributes: [
                .font: NSFont.systemFont(ofSize: 34, weight: .bold),
                .foregroundColor: NSColor.white
            ]
        )
        title.draw(at: NSPoint(x: 130, y: 330))

        let subtitle = NSAttributedString(
            string: "Search, preview, and reuse clipboard history from the menu bar.",
            attributes: [
                .font: NSFont.systemFont(ofSize: 20, weight: .medium),
                .foregroundColor: NSColor(calibratedWhite: 1, alpha: 0.84)
            ]
        )
        subtitle.draw(at: NSPoint(x: 130, y: 288))

        let badge = NSBezierPath(roundedRect: NSRect(x: 130, y: 210, width: 170, height: 40), xRadius: 20, yRadius: 20)
        NSColor(calibratedWhite: 1, alpha: 0.20).setFill()
        badge.fill()

        let badgeText = NSAttributedString(
            string: "macOS Menu Bar App",
            attributes: [
                .font: NSFont.systemFont(ofSize: 16, weight: .semibold),
                .foregroundColor: NSColor.white
            ]
        )
        badgeText.draw(at: NSPoint(x: 155, y: 222))

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
                title: "Product announcement visual",
                resourcePath: imageURL.path,
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
                title: "Swift onboarding snippet",
                contentText: """
                let history = try await historyStore.recentItems(limit: 100)
                visibleItems = history.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
                """,
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
                title: "Release checklist",
                contentText: "https://github.com/bloodstalk1/Clipo/releases/tag/v1.0.0",
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

    private static func makeSearchItems(imageURL: URL) -> [ClipboardItem] {
        [
            .stub(
                kind: .text,
                title: "Figma frame notes",
                contentText: "Hero frame updated with the new Clipo launch copy and menu bar positioning notes.",
                metadata: ClipboardItemMetadata(
                    imageWidth: nil,
                    imageHeight: nil,
                    imageFileSize: nil,
                    faviconURL: nil,
                    detectedLanguage: nil,
                    lineCount: nil,
                    characterCount: 84,
                    wordCount: 14,
                    fileSize: nil,
                    fileExtension: nil
                )
            ),
            .stub(
                kind: .image,
                title: "Figma export preview",
                resourcePath: imageURL.path,
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
                title: "Figma component label",
                contentText: "Clipo / Search Panel / Selected Image",
                metadata: ClipboardItemMetadata(
                    imageWidth: nil,
                    imageHeight: nil,
                    imageFileSize: nil,
                    faviconURL: nil,
                    detectedLanguage: nil,
                    lineCount: nil,
                    characterCount: 39,
                    wordCount: 7,
                    fileSize: nil,
                    fileExtension: nil
                )
            )
        ]
    }
}
