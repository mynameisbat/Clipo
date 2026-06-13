import Foundation
import AppKit

actor LazyImageLoader {
    private var loadingTasks: [UUID: Task<Void, Never>] = [:]
    private var imageCache: [UUID: NSImage] = [:]

    func loadImage(for itemId: UUID, path: String) async -> NSImage? {
        if let cached = imageCache[itemId] {
            return cached
        }

        if let existingTask = loadingTasks[itemId] {
            _ = await existingTask.value
            return imageCache[itemId]
        }

        let task = Task {
            guard let image = NSImage(contentsOfFile: path) else { return }
            imageCache[itemId] = image
        }

        loadingTasks[itemId] = task
        _ = await task.value
        loadingTasks.removeValue(forKey: itemId)
        return imageCache[itemId]
    }

    func preloadImages(for itemIds: [UUID], paths: [String]) async {
        guard itemIds.count == paths.count else { return }

        await withTaskGroup(of: Void.self) { group in
            for (id, path) in zip(itemIds, paths) {
                group.addTask {
                    _ = await self.loadImage(for: id, path: path)
                }
            }
        }
    }

    func clearCache() {
        imageCache.removeAll()
    }

    func removeFromCache(itemId: UUID) {
        imageCache.removeValue(forKey: itemId)
    }

    var cacheSize: Int {
        imageCache.count
    }

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
