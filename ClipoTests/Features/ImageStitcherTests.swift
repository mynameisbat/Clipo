import XCTest
import CoreGraphics
import UniformTypeIdentifiers
@testable import Clipo

final class ImageStitcherTests: XCTestCase {
    
    private var tempURLs: [URL] = []
    
    override func tearDown() {
        for url in tempURLs {
            try? FileManager.default.removeItem(at: url)
        }
        tempURLs.removeAll()
        super.tearDown()
    }
    
    func testImageStitcherCorrectlyAlignsAndStitchesOverlappingImages() async throws {
        // Given: Two mock images with a 100px vertical overlap.
        // Image A: Width 100, Height 150, rendering lines 0 to 149.
        // Image B: Width 100, Height 150, rendering lines 50 to 199.
        // Overlap height: 100 pixels (Lines 50 to 149 of A match Lines 0 to 99 of B).
        // Stitched height should be: 150 + 150 - 100 = 200 pixels.
        
        let width = 100
        let height = 150
        
        guard let imgA = createPatternImage(width: width, height: height, startY: 0),
              let imgB = createPatternImage(width: width, height: height, startY: 50) else {
            XCTFail("Failed to create mock CGImages")
            return
        }
        
        guard let urlA = saveCGImageToTempURL(imgA),
              let urlB = saveCGImageToTempURL(imgB) else {
            XCTFail("Failed to write mock CGImages to disk")
            return
        }
        
        tempURLs.append(urlA)
        tempURLs.append(urlB)
        
        let stitcher = ImageStitcher()
        
        // When
        let resultImage = try await stitcher.stitch(frameURLs: [urlA, urlB])
        
        // Then
        XCTAssertNotNil(resultImage, "Stitcher should return a stitched image")
        if let stitched = resultImage {
            XCTAssertEqual(stitched.width, width, "Width should remain constant")
            XCTAssertEqual(stitched.height, 200, "Stitched height should equal combined height minus overlap")
        }
    }
    
    func testImageStitcherFailsGracefullyWhenNoOverlapExits() async throws {
        // Given: Two images with completely different patterns (no overlap)
        let width = 100
        let height = 100
        
        guard let imgA = createPatternImage(width: width, height: height, startY: 0),
              let imgB = createPatternImage(width: width, height: height, startY: 1000) else { // starts at 1000, different colors
            XCTFail("Failed to create mock CGImages")
            return
        }
        
        guard let urlA = saveCGImageToTempURL(imgA),
              let urlB = saveCGImageToTempURL(imgB) else {
            XCTFail("Failed to write mock CGImages to disk")
            return
        }
        
        tempURLs.append(urlA)
        tempURLs.append(urlB)
        
        let stitcher = ImageStitcher()
        
        // When
        let resultImage = try await stitcher.stitch(frameURLs: [urlA, urlB])
        
        // Then: Stitcher should stop at the point of failure and return the first image
        XCTAssertNotNil(resultImage, "Stitcher should return the first image as fallback rather than failing")
        if let stitched = resultImage {
            XCTAssertEqual(stitched.width, width)
            XCTAssertEqual(stitched.height, height, "Should fallback to imgA height since stitching failed")
        }
    }
    
    // MARK: - Helpers
    
    private func createPatternImage(width: Int, height: Int, startY: Int) -> CGImage? {
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        for y in 0..<height {
            let actualY = startY + y
            let r = UInt8((actualY * 7) % 256)
            let g = UInt8((actualY * 13) % 256)
            let b = UInt8((actualY * 17) % 256)
            let a: UInt8 = 255
            
            for x in 0..<width {
                let offset = (y * width + x) * bytesPerPixel
                pixels[offset] = r
                pixels[offset + 1] = g
                pixels[offset + 2] = b
                pixels[offset + 3] = a
            }
        }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }
        
        return context.makeImage()
    }
    
    private func saveCGImageToTempURL(_ image: CGImage) -> URL? {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        guard let destination = CGImageDestinationCreateWithURL(tempURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return tempURL
    }
}
