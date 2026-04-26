import XCTest
@testable import Clipo

final class ClipboardItemTests: XCTestCase {
    func testPreviewContentReturnsImageURLForImageItems() {
        let item = ClipboardItem.stub(
            kind: .image,
            title: "Screenshot",
            resourcePath: "/tmp/example.tiff"
        )

        XCTAssertEqual(item.previewContent, .image(URL(fileURLWithPath: "/tmp/example.tiff")))
    }

    func testImageItemsShowInlinePreviewByDefault() {
        XCTAssertTrue(ClipboardItem.stub(kind: .image, title: "Image").showsInlinePreviewByDefault)
        XCTAssertFalse(ClipboardItem.stub(kind: .text, title: "Text").showsInlinePreviewByDefault)
    }

    func testOnlyCodeAndImagesShowExpandedPreviewWhenSelected() {
        let plainTextItem = ClipboardItem.stub(
            kind: .text,
            title: "Hello world",
            contentText: "Hello world",
            metadata: .empty()
        )
        let codeItem = ClipboardItem.stub(
            kind: .text,
            title: "print(\"Hello\")",
            contentText: "print(\"Hello\")",
            metadata: ClipboardItemMetadata(detectedLanguage: .swift, lineCount: 1)
        )

        XCTAssertFalse(plainTextItem.showsExpandedPreviewWhenSelected)
        XCTAssertTrue(codeItem.showsExpandedPreviewWhenSelected)
        XCTAssertTrue(ClipboardItem.stub(kind: .image, title: "Image").showsExpandedPreviewWhenSelected)
    }

    func testPreviewContentReturnsRemoteImageURLForWebImageItems() {
        let item = ClipboardItem.stub(
            kind: .image,
            title: "Web image",
            resourcePath: "https://images.example.com/photo.jpeg"
        )

        XCTAssertEqual(item.previewContent, .image(URL(string: "https://images.example.com/photo.jpeg")!))
    }

    func testTextItemsWithEmptyTitleShowAsTextKind() {
        let item = ClipboardItem.stub(
            kind: .text,
            title: "",
            contentText: "Some content"
        )

        XCTAssertEqual(item.kind, .text)
        XCTAssertEqual(item.previewContent, .text("Some content"))
    }
}
