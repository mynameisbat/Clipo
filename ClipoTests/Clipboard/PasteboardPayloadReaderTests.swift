import XCTest
@testable import Clipo

final class PasteboardPayloadReaderTests: XCTestCase {
    func testTextSnapshotBecomesTextItem() throws {
        let store = ImageAssetStore(baseURL: FileManager.default.temporaryDirectory)
        let reader = PasteboardPayloadReader(assetStore: store)
        let snapshot = PasteboardSnapshot(strings: ["Hello world"], fileURLs: [], imageData: nil, imageFileExtension: nil, sourceAppBundleId: "com.apple.TextEdit")

        let item = try reader.read(snapshot: snapshot)
        XCTAssertEqual(item?.kind, .text)
        XCTAssertEqual(item?.title, "Hello world")
    }

    func testFileURLSnapshotBecomesFileItem() throws {
        let store = ImageAssetStore(baseURL: FileManager.default.temporaryDirectory)
        let reader = PasteboardPayloadReader(assetStore: store)
        let snapshot = PasteboardSnapshot(strings: [], fileURLs: [URL(fileURLWithPath: "/tmp/mock.pdf")], imageData: nil, imageFileExtension: nil, sourceAppBundleId: nil)

        let item = try reader.read(snapshot: snapshot)
        XCTAssertEqual(item?.kind, .file)
        XCTAssertEqual(item?.resourcePath, "/tmp/mock.pdf")
    }

    func testImageSnapshotBecomesImageItem() throws {
        let store = ImageAssetStore(baseURL: FileManager.default.temporaryDirectory)
        let reader = PasteboardPayloadReader(assetStore: store)
        let snapshot = PasteboardSnapshot(
            strings: [],
            fileURLs: [],
            imageData: Data([0x89, 0x50, 0x4E, 0x47]),
            imageFileExtension: "png",
            sourceAppBundleId: nil
        )

        let item = try reader.read(snapshot: snapshot)

        XCTAssertEqual(item?.kind, .image)
        XCTAssertEqual(URL(fileURLWithPath: item?.resourcePath ?? "").pathExtension, "png")
    }

    func testImageSnapshotIsPreferredOverTextWhenBothExist() throws {
        let store = ImageAssetStore(baseURL: FileManager.default.temporaryDirectory)
        let reader = PasteboardPayloadReader(assetStore: store)
        let snapshot = PasteboardSnapshot(
            strings: ["https://example.com/image"],
            fileURLs: [],
            imageData: Data([0x89, 0x50, 0x4E, 0x47]),
            imageFileExtension: "png",
            sourceAppBundleId: nil
        )

        let item = try reader.read(snapshot: snapshot)

        XCTAssertEqual(item?.kind, .image)
    }

    // MARK: - HTML Parsing Tests (Disabled - HTML parsing removed)

    /*
    func testHTMLImageStringBecomesImageItem() throws {
        let store = ImageAssetStore(baseURL: FileManager.default.temporaryDirectory)
        let reader = PasteboardPayloadReader(assetStore: store)
        let snapshot = PasteboardSnapshot(
            strings: ["<img src=\"https://cdn.example.com/media/photo?id=123\">"],
            fileURLs: [],
            imageData: nil,
            imageFileExtension: nil,
            sourceAppBundleId: "com.google.Chrome"
        )

        let item = try reader.read(snapshot: snapshot)

        XCTAssertEqual(item?.kind, .image)
        XCTAssertEqual(item?.resourcePath, "https://cdn.example.com/media/photo?id=123")
    }
    */

    func testDirectRemoteImageURLBecomesImageItem() throws {
        let store = ImageAssetStore(baseURL: FileManager.default.temporaryDirectory)
        let reader = PasteboardPayloadReader(assetStore: store)
        let snapshot = PasteboardSnapshot(
            strings: ["https://images.example.com/photo.jpeg"],
            fileURLs: [],
            imageData: nil,
            imageFileExtension: nil,
            sourceAppBundleId: "com.apple.Safari"
        )

        let item = try reader.read(snapshot: snapshot)

        XCTAssertEqual(item?.kind, .image)
        XCTAssertEqual(item?.resourcePath, "https://images.example.com/photo.jpeg")
    }

    /*
    func testXPhotoTweetHTMLSrcsetBecomesImageItem() throws {
        let store = ImageAssetStore(baseURL: FileManager.default.temporaryDirectory)
        let reader = PasteboardPayloadReader(assetStore: store)
        let html = """
        <a href="https://x.com/DnewHome/status/2049693209409048876/photo/1">
          <img alt="" srcset="https://pbs.twimg.com/media/Gw-example?format=jpg&amp;name=small 680w, https://pbs.twimg.com/media/Gw-example?format=jpg&amp;name=large 1200w">
        </a>
        """
        let snapshot = PasteboardSnapshot(
            strings: ["https://x.com/DnewHome/status/2049693209409048876/photo/1"],
            fileURLs: [],
            imageData: nil,
            imageFileExtension: nil,
            htmlData: html.data(using: .utf8),
            sourceAppBundleId: "com.google.Chrome"
        )

        let item = try reader.read(snapshot: snapshot)

        XCTAssertEqual(item?.kind, .image)
        XCTAssertEqual(item?.resourcePath, "https://pbs.twimg.com/media/Gw-example?format=jpg&name=small")
    }
    */

    func testWebArchiveImageDataBecomesImageItem() throws {
        let store = ImageAssetStore(baseURL: FileManager.default.temporaryDirectory)
        let reader = PasteboardPayloadReader(assetStore: store)
        let archive = try makeWebArchive(
            mimeType: "image/jpeg",
            resourceURL: "https://scontent.xx.fbcdn.net/photo.jpg",
            data: Data([0xFF, 0xD8, 0xFF, 0xE0])
        )
        let snapshot = PasteboardSnapshot(
            strings: [],
            fileURLs: [],
            imageData: nil,
            imageFileExtension: nil,
            webArchiveData: archive,
            sourceAppBundleId: "com.google.Chrome"
        )

        let item = try reader.read(snapshot: snapshot)

        XCTAssertEqual(item?.kind, .image)
        XCTAssertEqual(URL(fileURLWithPath: item?.resourcePath ?? "").pathExtension, "jpeg")
    }

    func testNestedWebArchiveImageDataBecomesImageItem() throws {
        let store = ImageAssetStore(baseURL: FileManager.default.temporaryDirectory)
        let reader = PasteboardPayloadReader(assetStore: store)
        let archive = try makeNestedWebArchive(
            mimeType: "image/webp",
            resourceURL: "https://scontent.xx.fbcdn.net/photo.webp",
            data: Data([0x52, 0x49, 0x46, 0x46])
        )
        let snapshot = PasteboardSnapshot(
            strings: [],
            fileURLs: [],
            imageData: nil,
            imageFileExtension: nil,
            webArchiveData: archive,
            sourceAppBundleId: "com.google.Chrome"
        )

        let item = try reader.read(snapshot: snapshot)

        XCTAssertEqual(item?.kind, .image)
        XCTAssertEqual(URL(fileURLWithPath: item?.resourcePath ?? "").pathExtension, "webp")
    }

    /*
    func testUTF16HTMLDataImageBecomesImageItem() throws {
        let store = ImageAssetStore(baseURL: FileManager.default.temporaryDirectory)
        let reader = PasteboardPayloadReader(assetStore: store)
        let html = "<img src=\"https://scontent.xx.fbcdn.net/v/t39.30808-6/12345_n.jpg?stp=dst-jpg\">"
        let snapshot = PasteboardSnapshot(
            strings: [],
            fileURLs: [],
            imageData: nil,
            imageFileExtension: nil,
            htmlData: html.data(using: .utf16LittleEndian),
            sourceAppBundleId: "com.google.Chrome"
        )

        let item = try reader.read(snapshot: snapshot)

        XCTAssertEqual(item?.kind, .image)
        XCTAssertEqual(item?.resourcePath, "https://scontent.xx.fbcdn.net/v/t39.30808-6/12345_n.jpg?stp=dst-jpg")
    }

    func testFigmaHTMLWithoutImageFallsBackToReadableTextItem() throws {
        let store = ImageAssetStore(baseURL: FileManager.default.temporaryDirectory)
        let reader = PasteboardPayloadReader(assetStore: store)
        let snapshot = PasteboardSnapshot(
            strings: [],
            fileURLs: [],
            imageData: nil,
            imageFileExtension: nil,
            htmlData: "<div data-testid=\"selection\">Figma Selection</div>".data(using: .utf8),
            sourceAppBundleId: "com.figma.Desktop"
        )

        let item = try reader.read(snapshot: snapshot)

        XCTAssertEqual(item?.kind, .text)
        XCTAssertEqual(item?.title, "Figma Selection")
    }

    func testEmptyHTMLFallbackUsesFigmaSelectionTitle() throws {
        let store = ImageAssetStore(baseURL: FileManager.default.temporaryDirectory)
        let reader = PasteboardPayloadReader(assetStore: store)
        // HTML with only whitespace, no actual readable text
        let snapshot = PasteboardSnapshot(
            strings: [],
            fileURLs: [],
            imageData: nil,
            imageFileExtension: nil,
            htmlData: "   ".data(using: .utf8),
            sourceAppBundleId: "com.figma.Desktop"
        )

        let item = try reader.read(snapshot: snapshot)

        XCTAssertEqual(item?.kind, .text)
        XCTAssertEqual(item?.title, "Figma Selection")
    }
    */

    private func makeWebArchive(mimeType: String, resourceURL: String, data: Data) throws -> Data {
        let archive: [String: Any] = [
            "WebMainResource": [
                "WebResourceData": data,
                "WebResourceMIMEType": mimeType,
                "WebResourceURL": resourceURL
            ]
        ]

        return try PropertyListSerialization.data(fromPropertyList: archive, format: .binary, options: 0)
    }

    private func makeNestedWebArchive(mimeType: String, resourceURL: String, data: Data) throws -> Data {
        let archive: [String: Any] = [
            "WebSubframeArchives": [
                [
                    "WebSubresources": [
                        [
                            "WebResourceData": data,
                            "WebResourceMIMEType": mimeType,
                            "WebResourceURL": resourceURL
                        ]
                    ]
                ]
            ]
        ]

        return try PropertyListSerialization.data(fromPropertyList: archive, format: .binary, options: 0)
    }
}
