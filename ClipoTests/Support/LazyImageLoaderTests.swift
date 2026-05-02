import XCTest
import AppKit
@testable import Clipo

final class LazyImageLoaderTests: XCTestCase {

    // MARK: - Test Setup

    var tempDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        try await super.tearDown()
    }

    private func createTestImage(at path: URL) throws {
        let image = NSImage(size: NSSize(width: 100, height: 100))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 100, height: 100).fill()
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create test image"])
        }

        try pngData.write(to: path)
    }

    // MARK: - Image Loading

    func testLoadImageFromValidPath() async throws {
        // Given: LazyImageLoader and valid image file
        let loader = LazyImageLoader()
        let imagePath = tempDirectory.appendingPathComponent("test.png")
        try createTestImage(at: imagePath)
        let itemId = UUID()

        // When: Loading image
        let image = await loader.loadImage(for: itemId, path: imagePath.path)

        // Then: Should return image
        XCTAssertNotNil(image)
    }

    func testLoadImageFromInvalidPath() async {
        // Given: LazyImageLoader and invalid path
        let loader = LazyImageLoader()
        let itemId = UUID()
        let invalidPath = "/nonexistent/path/image.png"

        // When: Loading image
        let image = await loader.loadImage(for: itemId, path: invalidPath)

        // Then: Should return nil
        XCTAssertNil(image)
    }

    // MARK: - Caching

    func testImageCaching() async throws {
        // Given: LazyImageLoader and valid image
        let loader = LazyImageLoader()
        let imagePath = tempDirectory.appendingPathComponent("test.png")
        try createTestImage(at: imagePath)
        let itemId = UUID()

        // When: Loading same image twice
        let image1 = await loader.loadImage(for: itemId, path: imagePath.path)
        let image2 = await loader.loadImage(for: itemId, path: imagePath.path)

        // Then: Should return same cached image
        XCTAssertNotNil(image1)
        XCTAssertNotNil(image2)
        XCTAssertTrue(image1 === image2) // Same object reference
    }

    func testCacheSizeIncreases() async throws {
        // Given: LazyImageLoader
        let loader = LazyImageLoader()
        let imagePath1 = tempDirectory.appendingPathComponent("test1.png")
        let imagePath2 = tempDirectory.appendingPathComponent("test2.png")
        try createTestImage(at: imagePath1)
        try createTestImage(at: imagePath2)

        // When: Loading multiple images
        _ = await loader.loadImage(for: UUID(), path: imagePath1.path)
        let sizeAfterFirst = await loader.cacheSize

        _ = await loader.loadImage(for: UUID(), path: imagePath2.path)
        let sizeAfterSecond = await loader.cacheSize

        // Then: Cache size should increase
        XCTAssertEqual(sizeAfterFirst, 1)
        XCTAssertEqual(sizeAfterSecond, 2)
    }

    func testClearCache() async throws {
        // Given: LazyImageLoader with cached images
        let loader = LazyImageLoader()
        let imagePath = tempDirectory.appendingPathComponent("test.png")
        try createTestImage(at: imagePath)

        _ = await loader.loadImage(for: UUID(), path: imagePath.path)
        _ = await loader.loadImage(for: UUID(), path: imagePath.path)

        let sizeBeforeClear = await loader.cacheSize
        XCTAssertEqual(sizeBeforeClear, 2)

        // When: Clearing cache
        await loader.clearCache()

        // Then: Cache should be empty
        let sizeAfterClear = await loader.cacheSize
        XCTAssertEqual(sizeAfterClear, 0)
    }

    func testRemoveFromCache() async throws {
        // Given: LazyImageLoader with cached image
        let loader = LazyImageLoader()
        let imagePath = tempDirectory.appendingPathComponent("test.png")
        try createTestImage(at: imagePath)
        let itemId = UUID()

        _ = await loader.loadImage(for: itemId, path: imagePath.path)
        let sizeBeforeRemove = await loader.cacheSize
        XCTAssertEqual(sizeBeforeRemove, 1)

        // When: Removing specific item from cache
        await loader.removeFromCache(itemId: itemId)

        // Then: Cache size should decrease
        let sizeAfterRemove = await loader.cacheSize
        XCTAssertEqual(sizeAfterRemove, 0)
    }

    // MARK: - Task Deduplication

    func testConcurrentLoadsSameImage() async throws {
        // Given: LazyImageLoader and valid image
        let loader = LazyImageLoader()
        let imagePath = tempDirectory.appendingPathComponent("test.png")
        try createTestImage(at: imagePath)
        let itemId = UUID()

        // When: Loading same image concurrently
        async let image1 = loader.loadImage(for: itemId, path: imagePath.path)
        async let image2 = loader.loadImage(for: itemId, path: imagePath.path)
        async let image3 = loader.loadImage(for: itemId, path: imagePath.path)

        let results = await [image1, image2, image3]

        // Then: All should return same cached image
        XCTAssertTrue(results.allSatisfy { $0 != nil })
        XCTAssertTrue(results[0] === results[1])
        XCTAssertTrue(results[1] === results[2])
    }

    // MARK: - Preloading

    func testPreloadImages() async throws {
        // Given: LazyImageLoader and multiple images
        let loader = LazyImageLoader()
        let imagePath1 = tempDirectory.appendingPathComponent("test1.png")
        let imagePath2 = tempDirectory.appendingPathComponent("test2.png")
        let imagePath3 = tempDirectory.appendingPathComponent("test3.png")

        try createTestImage(at: imagePath1)
        try createTestImage(at: imagePath2)
        try createTestImage(at: imagePath3)

        let itemIds = [UUID(), UUID(), UUID()]
        let paths = [imagePath1.path, imagePath2.path, imagePath3.path]

        // When: Preloading images
        await loader.preloadImages(for: itemIds, paths: paths)

        // Then: All images should be cached
        let cacheSize = await loader.cacheSize
        XCTAssertEqual(cacheSize, 3)
    }

    func testPreloadImagesWithMismatchedArrays() async throws {
        // Given: LazyImageLoader with mismatched arrays
        let loader = LazyImageLoader()
        let imagePath = tempDirectory.appendingPathComponent("test.png")
        try createTestImage(at: imagePath)

        let itemIds = [UUID(), UUID()]
        let paths = [imagePath.path] // Only 1 path for 2 IDs

        // When: Preloading with mismatched arrays
        await loader.preloadImages(for: itemIds, paths: paths)

        // Then: Should handle gracefully (no crash)
        let cacheSize = await loader.cacheSize
        XCTAssertEqual(cacheSize, 0) // No images loaded due to mismatch
    }

    // MARK: - Memory Usage

    func testEstimatedMemoryUsage() async throws {
        // Given: LazyImageLoader with cached images
        let loader = LazyImageLoader()
        let imagePath = tempDirectory.appendingPathComponent("test.png")
        try createTestImage(at: imagePath)

        // When: Loading image
        _ = await loader.loadImage(for: UUID(), path: imagePath.path)

        // Then: Should report memory usage
        let memoryUsage = await loader.estimatedMemoryUsage
        XCTAssertGreaterThan(memoryUsage, 0)
    }

    func testMemoryUsageIncreasesWithMoreImages() async throws {
        // Given: LazyImageLoader
        let loader = LazyImageLoader()
        let imagePath1 = tempDirectory.appendingPathComponent("test1.png")
        let imagePath2 = tempDirectory.appendingPathComponent("test2.png")
        try createTestImage(at: imagePath1)
        try createTestImage(at: imagePath2)

        // When: Loading multiple images
        _ = await loader.loadImage(for: UUID(), path: imagePath1.path)
        let memoryAfterFirst = await loader.estimatedMemoryUsage

        _ = await loader.loadImage(for: UUID(), path: imagePath2.path)
        let memoryAfterSecond = await loader.estimatedMemoryUsage

        // Then: Memory usage should increase
        XCTAssertGreaterThan(memoryAfterSecond, memoryAfterFirst)
    }

    // MARK: - Multiple Items

    func testLoadMultipleDifferentImages() async throws {
        // Given: LazyImageLoader and multiple images
        let loader = LazyImageLoader()
        let imagePath1 = tempDirectory.appendingPathComponent("test1.png")
        let imagePath2 = tempDirectory.appendingPathComponent("test2.png")
        try createTestImage(at: imagePath1)
        try createTestImage(at: imagePath2)

        // When: Loading different images
        let image1 = await loader.loadImage(for: UUID(), path: imagePath1.path)
        let image2 = await loader.loadImage(for: UUID(), path: imagePath2.path)

        // Then: Should return different images
        XCTAssertNotNil(image1)
        XCTAssertNotNil(image2)
        XCTAssertFalse(image1 === image2) // Different objects
    }
}
