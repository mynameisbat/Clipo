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
