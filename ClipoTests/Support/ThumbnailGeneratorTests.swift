import XCTest
import AppKit
@testable import Clipo

final class ThumbnailGeneratorTests: XCTestCase {
    var generator: ThumbnailGenerator!
    var tempDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()
        generator = ThumbnailGenerator()

        // Create temp directory for test images
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        generator = nil

        // Clean up temp directory
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        tempDirectory = nil

        try await super.tearDown()
    }

    // MARK: - Thumbnail Generation

    func testGenerateThumbnailFromValidImage() async throws {
        // Given: Valid image data
        let imageData = createTestImageData(size: CGSize(width: 800, height: 600))

        // When: Generate thumbnail
        let thumbnailData = try await generator.generateThumbnail(from: imageData)

        // Then: Should return valid thumbnail data
        XCTAssertNotNil(thumbnailData)
        XCTAssertGreaterThan(thumbnailData.count, 0)

        // Verify thumbnail dimensions
        guard let image = NSImage(data: thumbnailData) else {
            XCTFail("Failed to create NSImage from thumbnail data")
            return
        }

        let size = image.size
        XCTAssertLessThanOrEqual(size.width, 200)
        XCTAssertLessThanOrEqual(size.height, 200)
    }

    func testGenerateThumbnailMaintainsAspectRatio() async throws {
        // Given: Wide image (16:9 aspect ratio)
        let imageData = createTestImageData(size: CGSize(width: 1600, height: 900))

        // When: Generate thumbnail
        let thumbnailData = try await generator.generateThumbnail(from: imageData)

        // Then: Should maintain aspect ratio
        guard let image = NSImage(data: thumbnailData) else {
            XCTFail("Failed to create NSImage from thumbnail data")
            return
        }

        let size = image.size
        let aspectRatio = size.width / size.height
        XCTAssertEqual(aspectRatio, 16.0 / 9.0, accuracy: 0.1)
    }

    func testGenerateThumbnailFromSmallImage() async throws {
        // Given: Image smaller than target size
        let imageData = createTestImageData(size: CGSize(width: 100, height: 100))

        // When: Generate thumbnail
        let thumbnailData = try await generator.generateThumbnail(from: imageData)

        // Then: Should not upscale (keep original size or smaller)
        guard let image = NSImage(data: thumbnailData) else {
            XCTFail("Failed to create NSImage from thumbnail data")
            return
        }

        let size = image.size
        XCTAssertLessThanOrEqual(size.width, 100)
        XCTAssertLessThanOrEqual(size.height, 100)
    }

    func testGenerateThumbnailFromInvalidDataThrows() async {
        // Given: Invalid image data
        let invalidData = Data("not an image".utf8)

        // When/Then: Should throw error
        do {
            _ = try await generator.generateThumbnail(from: invalidData)
            XCTFail("Should throw error for invalid image data")
        } catch {
            // Expected error
            XCTAssertTrue(true)
        }
    }

    func testGenerateThumbnailFromEmptyDataThrows() async {
        // Given: Empty data
        let emptyData = Data()

        // When/Then: Should throw error
        do {
            _ = try await generator.generateThumbnail(from: emptyData)
            XCTFail("Should throw error for empty data")
        } catch {
            // Expected error
            XCTAssertTrue(true)
        }
    }

    // MARK: - Performance

    func testGenerateThumbnailPerformance() async throws {
        // Given: Large image
        let imageData = createTestImageData(size: CGSize(width: 4000, height: 3000))
        let generator = self.generator!

        // When/Then: Should complete in reasonable time
        measure {
            let expectation = XCTestExpectation(description: "Thumbnail generation")

            Task {
                _ = try? await generator.generateThumbnail(from: imageData)
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 1.0)
        }
    }

    // MARK: - Helper Methods

    private func createTestImageData(size: CGSize) -> Data {
        let image = NSImage(size: size)
        image.lockFocus()

        // Draw a simple colored rectangle
        NSColor.blue.setFill()
        NSRect(origin: .zero, size: size).fill()

        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return Data()
        }

        return pngData
    }
}
