import AVFoundation
import ImageIO
import UniformTypeIdentifiers
import CoreGraphics
import CoreImage

enum GIFConverter {
    /// Natively converts an MP4 video file to an animated GIF.
    /// - Parameters:
    ///   - videoURL: URL of the source MP4 video
    ///   - outputURL: Target file URL for the GIF
    ///   - frameRate: Desired output frame rate (default 12fps for reasonable size/quality)
    static func convertVideoToGIF(videoURL: URL, outputURL: URL, frameRate: Int = 12) async throws {
        let savedFps = UserDefaults.standard.integer(forKey: "clipo.recording.gifFps")
        let activeFrameRate = savedFps > 0 ? savedFps : frameRate
        
        let savedScale = UserDefaults.standard.double(forKey: "clipo.recording.gifScale")
        let scale = savedScale > 0.01 ? savedScale : 1.0

        let asset = AVAsset(url: videoURL)
        let reader = try AVAssetReader(asset: asset)
        
        // Load the video track asynchronously (macOS 13+ compatible)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw NSError(domain: "GIFConverter", code: 1, userInfo: [NSLocalizedDescriptionKey: "No video track found"])
        }
        
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        let trackOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: outputSettings)
        reader.add(trackOutput)
        reader.startReading()
        
        var images: [CGImage] = []
        var lastFrameTime: CMTime = .zero
        let frameInterval = CMTime(value: 1, timescale: CMTimeScale(activeFrameRate))
        
        let context = CIContext(options: [
            .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            .useSoftwareRenderer: false
        ])
        
        while let sampleBuffer = trackOutput.copyNextSampleBuffer() {
            let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            
            // Decimate frames to match desired target framerate
            if !images.isEmpty && (pts - lastFrameTime) < frameInterval {
                continue
            }
            lastFrameTime = pts
            
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                continue
            }
            
            var ciImage = CIImage(cvImageBuffer: imageBuffer)
            if scale < 0.99 {
                ciImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            }
            
            if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                images.append(cgImage)
            }
        }
        
        guard !images.isEmpty else {
            throw NSError(domain: "GIFConverter", code: 2, userInfo: [NSLocalizedDescriptionKey: "No video frames could be read"])
        }
        
        // Create the GIF destination using the precise frame count
        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.gif.identifier as CFString,
            images.count,
            nil
        ) else {
            throw NSError(domain: "GIFConverter", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create GIF image destination"])
        }
        
        let delayTime = 1.0 / Double(activeFrameRate)
        let frameProperties = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFDelayTime as String: delayTime
            ]
        ] as CFDictionary
        
        let gifProperties = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFLoopCount as String: 0 // Infinite loops
            ]
        ] as CFDictionary
        
        CGImageDestinationSetProperties(destination, gifProperties)
        
        for image in images {
            CGImageDestinationAddImage(destination, image, frameProperties)
        }
        
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "GIFConverter", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to finalize GIF creation"])
        }
    }
}
