import Foundation
import AppKit
import CoreImage

enum ThumbnailError: Error {
    case invalidImageData
    case failedToCreateThumbnail
    case failedToConvertToData
}

/// Generates thumbnails for images using CoreImage for performance
actor ThumbnailGenerator {
    private let targetSize: CGSize
    private let context: CIContext

    init(targetSize: CGSize = CGSize(width: 200, height: 200)) {
        self.targetSize = targetSize
        self.context = CIContext(options: [.useSoftwareRenderer: false])
    }

    func generateThumbnail(from imageData: Data) async throws -> Data {
        guard !imageData.isEmpty else {
            throw ThumbnailError.invalidImageData
        }

        // Create NSImage from data
        guard let image = NSImage(data: imageData) else {
            throw ThumbnailError.invalidImageData
        }

        // Calculate scaled size maintaining aspect ratio
        let scaledSize = calculateScaledSize(originalSize: image.size, targetSize: targetSize)

        // Don't upscale small images
        let finalSize: CGSize
        if image.size.width <= targetSize.width && image.size.height <= targetSize.height {
            finalSize = image.size
        } else {
            finalSize = scaledSize
        }

        // Create thumbnail using CoreImage for better performance
        guard let ciImage = CIImage(data: imageData) else {
            throw ThumbnailError.invalidImageData
        }

        // Calculate scale factor
        let scaleX = finalSize.width / ciImage.extent.width
        let scaleY = finalSize.height / ciImage.extent.height
        let scale = min(scaleX, scaleY)

        // Apply scale transform
        let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        // Render to CGImage
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            throw ThumbnailError.failedToCreateThumbnail
        }

        // Convert to NSImage and then to PNG data
        let thumbnailImage = NSImage(cgImage: cgImage, size: finalSize)
        guard let tiffData = thumbnailImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw ThumbnailError.failedToConvertToData
        }

        return pngData
    }

    private func calculateScaledSize(originalSize: CGSize, targetSize: CGSize) -> CGSize {
        let widthRatio = targetSize.width / originalSize.width
        let heightRatio = targetSize.height / originalSize.height
        let scale = min(widthRatio, heightRatio)

        return CGSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )
    }
}
