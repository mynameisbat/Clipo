import Foundation

struct ImageAssetStore {
    let baseURL: URL
    private let thumbnailGenerator: ThumbnailGenerator

    init(baseURL: URL, thumbnailGenerator: ThumbnailGenerator = ThumbnailGenerator()) {
        self.baseURL = baseURL
        self.thumbnailGenerator = thumbnailGenerator
    }

    // Synchronous version for backward compatibility (no thumbnail)
    func storeImage(data: Data, fileExtension: String = "tiff") throws -> URL {
        try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true, attributes: nil)
        let url = baseURL.appendingPathComponent(UUID().uuidString).appendingPathExtension(fileExtension)
        try data.write(to: url)
        return url
    }

    // Async version with thumbnail generation
    func storeImageWithThumbnail(data: Data, fileExtension: String = "tiff") async throws -> (fullImageURL: URL, thumbnailURL: URL?) {
        try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true, attributes: nil)

        let uuid = UUID().uuidString
        let fullImageURL = baseURL.appendingPathComponent(uuid).appendingPathExtension(fileExtension)

        // Store full image
        try data.write(to: fullImageURL)

        // Generate and store thumbnail
        let thumbnailURL: URL?
        do {
            let thumbnailData = try await thumbnailGenerator.generateThumbnail(from: data)
            let thumbURL = baseURL.appendingPathComponent("\(uuid)_thumb").appendingPathExtension("png")
            try thumbnailData.write(to: thumbURL)
            thumbnailURL = thumbURL
        } catch {
            // If thumbnail generation fails, continue without thumbnail
            thumbnailURL = nil
        }

        return (fullImageURL, thumbnailURL)
    }
}

