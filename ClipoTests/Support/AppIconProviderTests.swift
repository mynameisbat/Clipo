import XCTest
import AppKit
@testable import Clipo

final class AppIconProviderTests: XCTestCase {

    // MARK: - Icon Retrieval

    func testIconForValidBundleId() async {
        // Given: AppIconProvider and valid bundle ID (Finder)
        let provider = AppIconProvider()
        let bundleId = "com.apple.finder"

        // When: Request icon
        let icon = await provider.icon(for: bundleId)

        // Then: Should return an icon
        XCTAssertNotNil(icon)
    }

    func testIconForInvalidBundleId() async {
        // Given: AppIconProvider and invalid bundle ID
        let provider = AppIconProvider()
        let bundleId = "com.invalid.nonexistent.app"

        // When: Request icon
        let icon = await provider.icon(for: bundleId)

        // Then: Should return nil
        XCTAssertNil(icon)
    }

    func testIconForEmptyBundleId() async {
        // Given: AppIconProvider and empty bundle ID
        let provider = AppIconProvider()
        let bundleId = ""

        // When: Request icon
        let icon = await provider.icon(for: bundleId)

        // Then: Should return nil
        XCTAssertNil(icon)
    }

    // MARK: - Caching

    func testIconCaching() async {
        // Given: AppIconProvider and valid bundle ID
        let provider = AppIconProvider()
        let bundleId = "com.apple.finder"

        // When: Request icon twice
        let icon1 = await provider.icon(for: bundleId)
        let icon2 = await provider.icon(for: bundleId)

        // Then: Both should return the same cached icon
        XCTAssertNotNil(icon1)
        XCTAssertNotNil(icon2)
        XCTAssertTrue(icon1 === icon2) // Same object reference
    }

    func testCacheSizeIncreases() async {
        // Given: AppIconProvider
        let provider = AppIconProvider()

        // When: Request icons for multiple apps
        _ = await provider.icon(for: "com.apple.finder")
        let sizeAfterFirst = await provider.cacheSize

        _ = await provider.icon(for: "com.apple.Safari")
        let sizeAfterSecond = await provider.cacheSize

        // Then: Cache size should increase
        XCTAssertEqual(sizeAfterFirst, 1)
        XCTAssertEqual(sizeAfterSecond, 2)
    }

    func testCacheSizeDoesNotIncreaseForSameBundleId() async {
        // Given: AppIconProvider
        let provider = AppIconProvider()

        // When: Request same icon twice
        _ = await provider.icon(for: "com.apple.finder")
        let sizeAfterFirst = await provider.cacheSize

        _ = await provider.icon(for: "com.apple.finder")
        let sizeAfterSecond = await provider.cacheSize

        // Then: Cache size should remain the same
        XCTAssertEqual(sizeAfterFirst, 1)
        XCTAssertEqual(sizeAfterSecond, 1)
    }

    // MARK: - Cache Management

    func testClearCache() async {
        // Given: AppIconProvider with cached icons
        let provider = AppIconProvider()
        _ = await provider.icon(for: "com.apple.finder")
        _ = await provider.icon(for: "com.apple.Safari")

        let sizeBeforeClear = await provider.cacheSize
        XCTAssertEqual(sizeBeforeClear, 2)

        // When: Clear cache
        await provider.clearCache()

        // Then: Cache should be empty
        let sizeAfterClear = await provider.cacheSize
        XCTAssertEqual(sizeAfterClear, 0)
    }

    func testIconRetrievalAfterCacheClear() async {
        // Given: AppIconProvider with cached icon
        let provider = AppIconProvider()
        let bundleId = "com.apple.finder"

        let icon1 = await provider.icon(for: bundleId)
        XCTAssertNotNil(icon1)

        // When: Clear cache and request again
        await provider.clearCache()
        let icon2 = await provider.icon(for: bundleId)

        // Then: Should retrieve icon again (different object)
        XCTAssertNotNil(icon2)
        XCTAssertFalse(icon1 === icon2) // Different object reference
    }

    // MARK: - Multiple Bundle IDs

    func testMultipleBundleIds() async {
        // Given: AppIconProvider and multiple bundle IDs
        let provider = AppIconProvider()
        let bundleIds = [
            "com.apple.finder",
            "com.apple.Safari",
            "com.apple.TextEdit"
        ]

        // When: Request icons for all bundle IDs
        var icons: [NSImage?] = []
        for bundleId in bundleIds {
            let icon = await provider.icon(for: bundleId)
            icons.append(icon)
        }

        // Then: Should retrieve all icons
        XCTAssertEqual(icons.count, 3)
        XCTAssertTrue(icons.allSatisfy { $0 != nil })

        // And: Cache should contain all icons
        let cacheSize = await provider.cacheSize
        XCTAssertEqual(cacheSize, 3)
    }
}
