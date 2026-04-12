import XCTest
@testable import Clipo

final class ClipboardMonitorTests: XCTestCase {
    func testMonitorIgnoresImmediateDuplicateFingerprint() async throws {
        let sink = RecordingClipboardSink()
        let monitor = ClipboardMonitor(
            reader: { _ in ClipboardItem.stub(title: "Same", contentText: "Same") },
            snapshotProvider: { PasteboardSnapshot(strings: ["Same"], fileURLs: [], imageData: nil, imageFileExtension: nil, sourceAppBundleId: nil) },
            sink: sink
        )

        try await monitor.processCurrentPasteboard()
        try await monitor.processCurrentPasteboard()

        let count = await sink.items.count
        XCTAssertEqual(count, 1)
    }

    func testMonitorSkipsDuplicateImageSnapshotBeforeCreatingNewAssetItem() async throws {
        let sink = RecordingClipboardSink()
        let counter = InvocationCounter()
        let snapshot = PasteboardSnapshot(
            strings: [],
            fileURLs: [],
            imageData: Data([1, 2, 3, 4]),
            imageFileExtension: "tiff",
            sourceAppBundleId: nil
        )
        let monitor = ClipboardMonitor(
            reader: { _ in
                let invocation = counter.incrementAndGet()
                return ClipboardItem.stub(
                    kind: .image,
                    title: "image-\(invocation).tiff",
                    resourcePath: "/tmp/image-\(invocation).tiff"
                )
            },
            snapshotProvider: { snapshot },
            sink: sink
        )

        try await monitor.processCurrentPasteboard()
        try await monitor.processCurrentPasteboard()

        let count = await sink.items.count
        let invocations = counter.value
        XCTAssertEqual(count, 1)
        XCTAssertEqual(invocations, 1)
    }

    func testMonitorRestoresLastFingerprintAcrossRelaunches() async throws {
        let persistence = FingerprintPersistenceRecorder()
        let snapshot = PasteboardSnapshot(
            strings: ["Persist me"],
            fileURLs: [],
            imageData: nil,
            imageFileExtension: nil,
            sourceAppBundleId: nil
        )

        let firstSink = RecordingClipboardSink()
        let firstMonitor = ClipboardMonitor(
            reader: { _ in ClipboardItem.stub(title: "Persist me", contentText: "Persist me") },
            snapshotProvider: { snapshot },
            sink: firstSink,
            initialFingerprint: nil,
            persistLastFingerprint: { fingerprint in persistence.save(fingerprint) }
        )

        try await firstMonitor.processCurrentPasteboard()

        let secondSink = RecordingClipboardSink()
        let secondMonitor = ClipboardMonitor(
            reader: { _ in ClipboardItem.stub(title: "Persist me", contentText: "Persist me") },
            snapshotProvider: { snapshot },
            sink: secondSink,
            initialFingerprint: persistence.value,
            persistLastFingerprint: { fingerprint in persistence.save(fingerprint) }
        )

        try await secondMonitor.processCurrentPasteboard()

        let firstCount = await firstSink.items.count
        let secondCount = await secondSink.items.count
        XCTAssertEqual(firstCount, 1)
        XCTAssertEqual(secondCount, 0)
        XCTAssertEqual(persistence.value, snapshot.fingerprint)
    }

    func testMonitorProcessesHTMLImageSnapshotEvenWhenTextFingerprintMatchesOldClipboard() async throws {
        let sink = RecordingClipboardSink()
        let html = "<img src=\"https://scontent.xx.fbcdn.net/v/t39.30808-6/12345_n.jpg?stp=dst-jpg\">"
        let snapshot = PasteboardSnapshot(
            strings: ["https://www.facebook.com/photo/?fbid=123"],
            fileURLs: [],
            imageData: nil,
            imageFileExtension: nil,
            htmlData: html.data(using: .utf8),
            sourceAppBundleId: "com.google.Chrome"
        )

        let monitor = ClipboardMonitor(
            reader: { _ in
                ClipboardItem.stub(
                    kind: .image,
                    title: "12345_n.jpg",
                    resourcePath: "https://scontent.xx.fbcdn.net/v/t39.30808-6/12345_n.jpg?stp=dst-jpg"
                )
            },
            snapshotProvider: { snapshot },
            sink: sink,
            initialFingerprint: "text::https://www.facebook.com/photo/?fbid=123"
        )

        try await monitor.processCurrentPasteboard()

        let items = await sink.items
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.kind, .image)
    }
}

actor RecordingClipboardSink: ClipboardItemSink {
    private(set) var items: [ClipboardItem] = []

    func store(_ item: ClipboardItem) async throws {
        items.append(item)
    }
}

final class InvocationCounter: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var value = 0

    func incrementAndGet() -> Int {
        lock.lock()
        defer { lock.unlock() }
        value += 1
        return value
    }
}

final class FingerprintPersistenceRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: String?

    var value: String? {
        lock.lock()
        defer { lock.unlock() }
        return storedValue
    }

    func save(_ fingerprint: String?) {
        lock.lock()
        storedValue = fingerprint
        lock.unlock()
    }
}
