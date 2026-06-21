import CoreGraphics
import ImageIO
import Foundation

/// Background actor responsible for heavy image stitching tasks.
actor ImageStitcher {
    enum StitcherError: Error {
        case invalidImage
        case noOverlap
        case emptyFrames
    }
    
    /// Stitches a series of frame image files into a single vertical CGImage.
    func stitch(frameURLs: [URL]) async throws -> CGImage? {
        guard !frameURLs.isEmpty else { return nil }
        if frameURLs.count == 1 {
            return CGImage.load(from: frameURLs[0])
        }
        
        var compositeImage: CGImage? = CGImage.load(from: frameURLs[0])
        
        for i in 1..<frameURLs.count {
            let nextFrame = autoreleasepool { () -> CGImage? in
                CGImage.load(from: frameURLs[i])
            }
            guard let currentComposite = compositeImage,
                  let next = nextFrame else {
                throw StitcherError.invalidImage
            }
            
            let merged = autoreleasepool { () -> CGImage? in
                stitchTwoImages(imgA: currentComposite, imgB: next)
            }
            
            if let merged = merged {
                compositeImage = merged
            } else {
                // Stitch failure recovery: stop and return what we have so far
                print("Stitching failed at frame \(i), returning composite up to this point.")
                break
            }
        }
        
        return compositeImage
    }
    
    private func stitchTwoImages(imgA: CGImage, imgB: CGImage) -> CGImage? {
        let width = imgA.width
        let heightA = imgA.height
        let heightB = imgB.height
        
        guard width == imgB.width else { return nil }
        
        // Extract pixel row signatures to find overlap quickly.
        // Since we scroll down, the overlap is usually at least 5% and at most 95% of the height.
        let minOverlap = Int(Double(heightB) * 0.05)
        let maxOverlap = Int(Double(heightB) * 0.95)
        
        guard let pixelDataA = imgA.dataProvider?.data,
              let pixelDataB = imgB.dataProvider?.data,
              let ptrA = CFDataGetBytePtr(pixelDataA),
              let ptrB = CFDataGetBytePtr(pixelDataB) else {
            return nil
        }
        
        let lengthA = CFDataGetLength(pixelDataA)
        let lengthB = CFDataGetLength(pixelDataB)
        
        let bytesPerPixelA = imgA.bitsPerPixel / 8
        let bytesPerRowA = imgA.bytesPerRow
        let bytesPerPixelB = imgB.bitsPerPixel / 8
        let bytesPerRowB = imgB.bytesPerRow
        
        // Sample columns across the image width to speed up calculation
        let numSampleColumns = 40
        let stepX = max(1, width / numSampleColumns)
        var sampleXCoords: [Int] = []
        for x in stride(from: 0, to: width, by: stepX) {
            sampleXCoords.append(x)
        }
        
        // We check every single possible overlap height (step = 1) to guarantee we do not miss
        // the correct match (especially on high-frequency patterns). To keep it extremely fast,
        // we only sample a fixed number of rows (e.g., 30) for each height.
        var bestOverlapHeight = minOverlap
        var minDiff = Double.infinity
        let numSampleRows = 30
        
        for oh in minOverlap...maxOverlap {
            guard heightA >= oh else { continue }
            var totalDiff: Double = 0
            let startRowA = heightA - oh
            
            let rowStep = max(1, oh / numSampleRows)
            var comparedRowsCount = 0
            
            for row in stride(from: 0, to: oh, by: rowStep) {
                let yA = startRowA + row
                let yB = row
                
                let rowOffsetA = yA * bytesPerRowA
                let rowOffsetB = yB * bytesPerRowB
                
                for x in sampleXCoords {
                    let pixelOffsetA = rowOffsetA + x * bytesPerPixelA
                    let pixelOffsetB = rowOffsetB + x * bytesPerPixelB
                    
                    guard pixelOffsetA >= 0 && pixelOffsetA + 2 < lengthA,
                          pixelOffsetB >= 0 && pixelOffsetB + 2 < lengthB else {
                        continue
                    }
                    
                    let rDiff = abs(Int(ptrA[pixelOffsetA]) - Int(ptrB[pixelOffsetB]))
                    let gDiff = abs(Int(ptrA[pixelOffsetA + 1]) - Int(ptrB[pixelOffsetB + 1]))
                    let bDiff = abs(Int(ptrA[pixelOffsetA + 2]) - Int(ptrB[pixelOffsetB + 2]))
                    
                    totalDiff += Double(rDiff + gDiff + bDiff)
                }
                comparedRowsCount += 1
            }
            
            let avgDiff = totalDiff / Double(max(1, comparedRowsCount) * sampleXCoords.count)
            if avgDiff < minDiff {
                minDiff = avgDiff
                bestOverlapHeight = oh
            }
        }
        
        // Accept matching if the average difference is within threshold (25 per channel)
        let threshold: Double = 25.0 * 3.0
        if minDiff > threshold {
            print("Best overlap difference \(minDiff) exceeds threshold \(threshold). Stitching aborted.")
            return nil
        }
        
        print("Found overlap height: \(bestOverlapHeight) with average pixel diff: \(minDiff)")
        
        let finalHeight = heightA + heightB - bestOverlapHeight
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: finalHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }
        
        // Render imgA on top (y increases up in default CGContext coordinates)
        context.draw(imgA, in: CGRect(x: 0, y: heightB - bestOverlapHeight, width: width, height: heightA))
        // Render imgB at the bottom
        context.draw(imgB, in: CGRect(x: 0, y: 0, width: width, height: heightB))
        
        return context.makeImage()
    }
}

extension CGImage {
    static func load(from url: URL) -> CGImage? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
    }
}
