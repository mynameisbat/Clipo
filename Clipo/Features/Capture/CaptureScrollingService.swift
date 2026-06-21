import Cocoa
import SwiftUI
import CoreGraphics
import UniformTypeIdentifiers

@MainActor
final class CaptureScrollingService: NSObject {
    static let shared = CaptureScrollingService()
    
    enum CaptureError: Error {
        case captureFailed
        case saveFailed
        case permissionsDenied
    }
    
    private var hudWindow: CaptureScrollingHUDWindow?
    private var temporaryFrameURLs: [URL] = []
    private var isCapturing = false
    private var originalCursorPosition: CGPoint?
    
    private override init() {
        super.init()
    }
    
    /// Starts the automated scrolling capture process for a given rect and screen.
    func startScrollingCapture(rect: CGRect, on screen: NSScreen) async {
        guard !isCapturing else { return }
        
        // 1. Check for Accessibility permission required for event generation
        guard checkAccessibilityPermission() else {
            promptForAccessibilityPermission()
            return
        }
        
        isCapturing = true
        temporaryFrameURLs.removeAll()
        
        // 2. Focus target window and warp cursor
        let screenFrame = screen.frame
        let globalRectX = screenFrame.origin.x + rect.origin.x
        let globalRectY = screenFrame.origin.y + rect.origin.y
        let globalCenter = CGPoint(x: globalRectX + rect.width / 2, y: globalRectY + rect.height / 2)
        
        saveAndWarpCursor(to: globalCenter)
        
        // Focus/Click the target window under the center to activate it
        sendClickEvent(at: globalCenter)
        
        showHUD(for: rect, on: screen)
        
        // Settle window focus for 200ms
        try? await Task.sleep(for: .milliseconds(200))
        
        do {
            try await captureLoop(rect: rect, screen: screen)
            await stopAndStitch()
        } catch {
            print("Capture failed: \(error.localizedDescription)")
            cleanup()
        }
    }
    
    private func captureLoop(rect: CGRect, screen: NSScreen) async throws {
        let maxPages = 15
        var previousImageHash: Int?
        
        for pageIndex in 0..<maxPages {
            guard isCapturing else { break }
            
            // Capture current frame
            guard let frameImage = captureFrame(rect: rect, screen: screen) else {
                throw CaptureError.captureFailed
            }
            
            // Check for duplicate frame (scrolling finished or stuck)
            let currentHash = calculateImageHash(frameImage)
            if let prevHash = previousImageHash, currentHash == prevHash {
                print("Duplicate frame detected. Scroll complete.")
                break
            }
            previousImageHash = currentHash
            
            // Save to disk cache (PNG)
            let tempURL = try saveToTemporaryFile(frameImage)
            temporaryFrameURLs.append(tempURL)
            
            // Update HUD progress
            hudWindow?.updateProgress(captured: pageIndex + 1)
            
            // Send scroll event
            sendScrollEvent()
            
            // Settle time for rendering
            try await Task.sleep(for: .milliseconds(250))
        }
    }
    
    func stopAndStitch() async {
        guard isCapturing else { return }
        isCapturing = false
        hudWindow?.close()
        restoreCursor()
        
        let stitcher = ImageStitcher()
        let urls = temporaryFrameURLs
        
        if !urls.isEmpty {
            do {
                if let stitchedCGImage = try await stitcher.stitch(frameURLs: urls) {
                    let stitchedNSImage = NSImage(cgImage: stitchedCGImage, size: .zero)
                    CaptureService.shared.openEditor(with: stitchedNSImage)
                }
            } catch {
                print("Stitching failed: \(error.localizedDescription)")
            }
        }
        cleanup()
    }
    
    func cancel() {
        cleanup()
    }
    
    private func cleanup() {
        isCapturing = false
        hudWindow?.close()
        hudWindow = nil
        restoreCursor()
        
        // Clean up files
        for url in temporaryFrameURLs {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFrameURLs.removeAll()
    }
    
    private func showHUD(for rect: CGRect, on screen: NSScreen) {
        hudWindow = CaptureScrollingHUDWindow(
            onStop: { [weak self] in
                Task { @MainActor in
                    await self?.stopAndStitch()
                }
            },
            onCancel: { [weak self] in
                self?.cleanup()
            }
        )
        hudWindow?.showNear(rect: rect, on: screen)
    }
    
    // MARK: - CoreGraphics Helper functions
    
    private func checkAccessibilityPermission() -> Bool {
        let options = ["axTrustedCheckOptionPrompt" as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    private func promptForAccessibilityPermission() {
        let alert = NSAlert()
        alert.messageText = "Quyền Trợ năng (Accessibility) bắt buộc"
        alert.informativeText = "Clipo cần quyền Trợ năng để gửi sự kiện cuộn tự động đến các ứng dụng khác. Vui lòng cho phép Clipo trong System Settings."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Mở System Settings")
        alert.addButton(withTitle: "Hủy")
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    private func saveAndWarpCursor(to point: CGPoint) {
        let currentMouseLocation = NSEvent.mouseLocation
        let rootScreenHeight = NSScreen.screens.first?.frame.height ?? 0
        
        self.originalCursorPosition = CGPoint(
            x: currentMouseLocation.x,
            y: rootScreenHeight - currentMouseLocation.y
        )
        
        let targetCGPoint = CGPoint(
            x: point.x,
            y: rootScreenHeight - point.y
        )
        
        CGWarpMouseCursorPosition(targetCGPoint)
    }
    
    private func restoreCursor() {
        if let original = originalCursorPosition {
            CGWarpMouseCursorPosition(original)
            originalCursorPosition = nil
        }
    }
    
    private func sendClickEvent(at point: CGPoint) {
        let rootScreenHeight = NSScreen.screens.first?.frame.height ?? 0
        let cgPoint = CGPoint(x: point.x, y: rootScreenHeight - point.y)
        
        guard let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: cgPoint, mouseButton: .left),
              let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: cgPoint, mouseButton: .left) else {
            return
        }
        
        mouseDown.post(tap: CGEventTapLocation.cghidEventTap)
        Thread.sleep(forTimeInterval: 0.05)
        mouseUp.post(tap: CGEventTapLocation.cghidEventTap)
    }
    
    private func sendScrollEvent() {
        guard let scrollEvent = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 1,
            wheel1: -50,
            wheel2: 0,
            wheel3: 0
        ) else { return }
        
        scrollEvent.post(tap: CGEventTapLocation.cghidEventTap)
    }
    
    private func captureFrame(rect: CGRect, screen: NSScreen) -> CGImage? {
        guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return nil
        }
        
        guard let fullDisplayCGImage = CGDisplayCreateImage(displayID) else {
            return nil
        }
        
        let screenFrame = screen.frame
        let backingScale = screen.backingScaleFactor
        
        let cropRect = CGRect(
            x: rect.origin.x * backingScale,
            y: (screenFrame.height - rect.origin.y - rect.size.height) * backingScale,
            width: rect.size.width * backingScale,
            height: rect.size.height * backingScale
        )
        
        return fullDisplayCGImage.cropping(to: cropRect)
    }
    
    private func calculateImageHash(_ image: CGImage) -> Int {
        guard let pixelData = image.dataProvider?.data,
              let ptr = CFDataGetBytePtr(pixelData) else {
            return 0
        }
        
        let length = CFDataGetLength(pixelData)
        var hasher = Hasher()
        let step = max(1, length / 1000)
        for i in stride(from: 0, to: length, by: step) {
            hasher.combine(ptr[i])
        }
        return hasher.finalize()
    }
    
    private func saveToTemporaryFile(_ cgImage: CGImage) throws -> URL {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".png")
        
        guard let destination = CGImageDestinationCreateWithURL(
            tempURL as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw CaptureError.saveFailed
        }
        
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw CaptureError.saveFailed
        }
        
        return tempURL
    }
}
