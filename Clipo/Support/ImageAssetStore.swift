import Foundation

struct ImageAssetStore {
    let baseURL: URL

    func storeImage(data: Data, fileExtension: String = "tiff") throws -> URL {
        try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true, attributes: nil)
        let url = baseURL.appendingPathComponent(UUID().uuidString).appendingPathExtension(fileExtension)
        try data.write(to: url)
        return url
    }
}
