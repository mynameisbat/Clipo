import AppKit
import Foundation
import UniformTypeIdentifiers

struct SystemPasteboardSnapshotProvider {
    func snapshot() -> PasteboardSnapshot {
        let pasteboard = NSPasteboard.general
        let stringObjects = pasteboard.readObjects(forClasses: [NSString.self]) as? [String] ?? []
        let allURLs = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: false]
        ) as? [URL] ?? []
        let fileURLs = allURLs.filter(\.isFileURL)
        let remoteURLStrings = allURLs.filter { !$0.isFileURL }.map(\.absoluteString)
        let htmlString = pasteboard.string(forType: .html)
        let htmlData = pasteboard.data(forType: .html)
        let rtfData = pasteboard.data(forType: .rtf) ?? pasteboard.data(forType: .rtfd)
        let webArchiveData = pasteboard.data(forType: NSPasteboard.PasteboardType("Apple Web Archive pasteboard type"))
            ?? pasteboard.data(forType: NSPasteboard.PasteboardType("com.apple.webarchive"))
        let strings = Array(
            NSOrderedSet(array: stringObjects + remoteURLStrings + [htmlString].compactMap { $0 })
        ) as? [String] ?? []
        let imagePayload = resolveImagePayload(from: pasteboard)
        let sourceAppBundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        return PasteboardSnapshot(
            strings: strings,
            fileURLs: fileURLs,
            imageData: imagePayload.data,
            imageFileExtension: imagePayload.fileExtension,
            htmlData: htmlData,
            rtfData: rtfData,
            webArchiveData: webArchiveData,
            sourceAppBundleId: sourceAppBundleId
        )
    }

    private func resolveImagePayload(from pasteboard: NSPasteboard) -> (data: Data?, fileExtension: String?) {
        let supportedImageTypes: [(NSPasteboard.PasteboardType, String)] = [
            (.tiff, "tiff"),
            (.png, "png"),
            (NSPasteboard.PasteboardType(UTType.jpeg.identifier), "jpeg"),
            (NSPasteboard.PasteboardType(UTType.gif.identifier), "gif"),
            (NSPasteboard.PasteboardType(UTType.webP.identifier), "webp"),
            (NSPasteboard.PasteboardType(UTType.heic.identifier), "heic")
        ]

        for (type, fileExtension) in supportedImageTypes {
            if let data = pasteboard.data(forType: type) {
                return (data, fileExtension)
            }
        }

        if
            let images = pasteboard.readObjects(forClasses: [NSImage.self]) as? [NSImage],
            let image = images.first,
            let tiffData = image.tiffRepresentation
        {
            return (tiffData, "tiff")
        }

        return (nil, nil)
    }
}

actor ClipboardMonitor: ClipboardMonitoring {
    private let reader: @Sendable (PasteboardSnapshot) throws -> ClipboardItem?
    private let snapshotProvider: @Sendable () -> PasteboardSnapshot
    private let changeCountProvider: @Sendable () -> Int
    private let sink: ClipboardItemSink
    private let persistLastFingerprint: @Sendable (String?) -> Void
    private let onNewItemStored: @Sendable (ClipboardItem) async -> Void
    private var lastFingerprint: String?
    private var lastPastedFingerprint: String?
    private var lastChangeCount: Int = -1

    init(
        reader: @escaping @Sendable (PasteboardSnapshot) throws -> ClipboardItem?,
        snapshotProvider: @escaping @Sendable () -> PasteboardSnapshot,
        changeCountProvider: @escaping @Sendable () -> Int = { NSPasteboard.general.changeCount },
        sink: ClipboardItemSink,
        initialFingerprint: String? = nil,
        persistLastFingerprint: @escaping @Sendable (String?) -> Void = { _ in },
        onNewItemStored: @escaping @Sendable (ClipboardItem) async -> Void = { _ in }
    ) {
        self.reader = reader
        self.snapshotProvider = snapshotProvider
        self.changeCountProvider = changeCountProvider
        self.sink = sink
        self.lastFingerprint = initialFingerprint
        self.persistLastFingerprint = persistLastFingerprint
        self.onNewItemStored = onNewItemStored
    }

    func processCurrentPasteboard() async throws {
        // Fast path: skip expensive snapshot read if pasteboard hasn't changed
        let currentChangeCount = changeCountProvider()
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        let snapshot = snapshotProvider()
        let fingerprint = snapshot.fingerprint
        guard fingerprint != lastFingerprint else { return }

        // Skip storing if this is the item we just pasted
        if let lastPastedFp = lastPastedFingerprint, fingerprint == lastPastedFp {
            lastFingerprint = fingerprint
            persistLastFingerprint(fingerprint)
            lastPastedFingerprint = nil
            return
        }

        guard let item = try reader(snapshot) else { return }
        lastFingerprint = fingerprint
        persistLastFingerprint(fingerprint)
        try await sink.store(item)
        await onNewItemStored(item)
    }

    nonisolated func notifyItemPasted(_ itemId: UUID) {
        Task {
            await setLastPastedFingerprint()
        }
    }

    private func setLastPastedFingerprint() {
        let snapshot = snapshotProvider()
        lastPastedFingerprint = snapshot.fingerprint
    }
}
