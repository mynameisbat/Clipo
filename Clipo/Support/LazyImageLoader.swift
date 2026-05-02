import Foundation
import AppKit

actor LazyImageLoader {
    private var loadingTasks: [UUID: Task<NSImage?, Never>] = [:]
    private var imageCache: [UUID: NSImage] = [:]

    /// Load image for a clipboard item, with caching and deduplication
    /// - Parameters:
    ///   - itemId: Unique identifier for the clipboard item
    ///   - path: File path to the image
    /// - Returns: Loaded image, or nil if loading fails
    func loadImage(for itemId: UUID, path: String) async -> NSImage? {
        // Check cache first
        if let cached = imageCache[itemId] {
            return cached
        }

        // Check if already loading
        if let existingTask = loadingTasks[itemId] {
            return await existingTask.value
        }

        // Start new load task
        let task = Task<NSImage?, Never> {
            guard let image = NSImage(contentsOfFile: path) else {
                return nil as NSImage?
            }
            return image
        }

        loadingTasks[itemId] = task
        let image = await task.value
        loadingTasks.removeValue(forKey: itemId)

        // Cache successful loads
        if let image = image {
            imageCache[itemId] = image
        }

        return image
    }

    /// Preload multiple images in parallel
    /// - Parameters:
    ///   - itemIds: Array of clipboard item IDs
    ///   - paths: Array of file paths (must match itemIds length)
    func preloadImages(for itemIds: [UUID], paths: [String]) async {
        guard itemIds.count == paths.count else {
            return
        }

        await withTaskGroup(of: Void.self) { group in
            for (id, path) in zip(itemIds, paths) {
                group.addTask {
                    _ = await self.loadImage(for: id, path: path)
                }
            }
        }
    }

    /// Clear image cache to free memory
    func clearCache() {
        imageCache.removeAll()
    }

    /// Remove specific image from cache
    /// - Parameter itemId: Clipboard item ID to remove
    func removeFromCache(itemId: UUID) {
        imageCache.removeValue(forKey: itemId)
    }

    /// Get current cache size (number of cached images)
    var cacheSize: Int {
        imageCache.count
    }

    /// Get memory usage estimate in bytes
    var estimatedMemoryUsage: Int64 {
        var totalBytes: Int64 = 0
        for image in imageCache.values {
            if let tiffData = image.tiffRepresentation {
                totalBytes += Int64(tiffData.count)
            }
        }
        return totalBytes
    }
}
