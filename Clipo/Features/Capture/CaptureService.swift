import Cocoa
import SwiftUI
import CoreGraphics

enum CaptureMode: Sendable {
    case image
    case video
}

@MainActor
final class CaptureService: NSObject {
    static let shared = CaptureService()
    
    private var overlayWindows: [CaptureOverlayWindow] = []
    private var editorWindow: CaptureEditorWindow?
    private var previewWindow: CaptureRecordingPreviewWindow?
    
    private let recorder = ScreenRecorder()
    private var recordingStatusItem: NSStatusItem?
    
    var isRecording: Bool {
        recorder.isRecording
    }
    
    private override init() {
        super.init()
    }
    
    /// Starts the screen capture workflow.
    func startCaptureFlow(mode: CaptureMode = .image) {
        // 1. Check/request screen recording permissions
        guard checkScreenCapturePermission() else {
            requestScreenCapturePermission()
            return
        }
        
        // 2. Dismiss any current captures
        closeActiveWindows()
        
        // 3. Get window boundaries for auto-snapping (excluding overlay windows)
        let excludingIDs = Set(overlayWindows.map { CGWindowID($0.windowNumber) })
        let visibleWindows = WindowDetector.getVisibleWindows(excludingWindowIDs: excludingIDs)
        
        // 4. Capture all screens and instantiate overlays
        let screens = NSScreen.screens
        for screen in screens {
            guard let screenImage = captureDisplayImage(screen: screen) else {
                continue
            }
            
            let overlayWindow = CaptureOverlayWindow(
                screen: screen,
                screenImage: screenImage,
                windows: visibleWindows,
                mode: mode,
                onCaptured: { [weak self] croppedImage in
                    self?.handleCapturedImage(croppedImage)
                },
                onRecordStart: { [weak self] rect, includeMic, includeSystemAudio in
                    self?.startRecording(rect: rect, screen: screen, includeMic: includeMic, recordSystemAudio: includeSystemAudio)
                },
                onCancel: { [weak self] in
                    self?.closeActiveWindows()
                }
            )
            
            overlayWindows.append(overlayWindow)
            overlayWindow.makeKeyAndOrderFront(nil)
            
            // Focus the overlay window so it receives keys
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func stopRecording() {
        recorder.stopRecording()
    }
    
    private func startRecording(rect: CGRect, screen: NSScreen, includeMic: Bool, recordSystemAudio: Bool) {
        closeActiveWindows()
        recorder.delegate = self
        recorder.startRecording(cropRect: rect, on: screen, includeMic: includeMic, recordSystemAudio: recordSystemAudio)
    }
    
    private func handleCapturedImage(_ image: NSImage) {
        closeActiveWindows()
        
        // Create the editor window
        let editor = CaptureEditorWindow(
            image: image,
            onCopy: { finalImage in
                let pb = NSPasteboard.general
                pb.clearContents()
                if let tiffData = finalImage.tiffRepresentation {
                    pb.setData(tiffData, forType: .tiff)
                }
            },
            onSave: { finalImage in
                let savePanel = NSSavePanel()
                savePanel.allowedContentTypes = [.png]
                savePanel.nameFieldStringValue = "Screenshot_\(Int(Date().timeIntervalSince1970)).png"
                
                savePanel.begin { response in
                    if response == .OK, let url = savePanel.url {
                        if let tiffData = finalImage.tiffRepresentation,
                           let bitmap = NSBitmapImageRep(data: tiffData),
                           let pngData = bitmap.representation(using: .png, properties: [:]) {
                            try? pngData.write(to: url)
                        }
                    }
                }
            },
            onCancel: {}
        )
        
        self.editorWindow = editor
        editor.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func closeActiveWindows() {
        for window in overlayWindows {
            window.orderOut(nil)
            window.close()
        }
        overlayWindows.removeAll()
    }
    
    private func checkScreenCapturePermission() -> Bool {
        if #available(macOS 10.15, *) {
            return CGPreflightScreenCaptureAccess()
        }
        return true
    }
    
    private func requestScreenCapturePermission() {
        if #available(macOS 10.15, *) {
            // This triggers the macOS system dialog if not already granted
            _ = CGRequestScreenCaptureAccess()
        }
    }
    
    private func captureDisplayImage(screen: NSScreen) -> NSImage? {
        guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return nil
        }
        
        guard let cgImage = CGDisplayCreateImage(displayID) else {
            return nil
        }
        
        return NSImage(cgImage: cgImage, size: screen.frame.size)
    }
    
    private func showRecordingStatusItem() {
        guard recordingStatusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            let config = NSImage.SymbolConfiguration(paletteColors: [.systemRed])
            button.image = NSImage(systemSymbolName: "stop.circle.fill", accessibilityDescription: "Stop Recording")?
                .withSymbolConfiguration(config)
            button.target = self
            button.action = #selector(stopRecordingClicked)
        }
        recordingStatusItem = item
    }
    
    private func hideRecordingStatusItem() {
        if let item = recordingStatusItem {
            NSStatusBar.system.removeStatusItem(item)
            recordingStatusItem = nil
        }
    }
    
    @objc private func stopRecordingClicked() {
        stopRecording()
    }
    
    private func presentPreviewWindow(videoURL: URL) {
        let preview = CaptureRecordingPreviewWindow(
            videoURL: videoURL,
            onCancel: { [weak self] in
                self?.previewWindow = nil
                // Clean up temp file
                try? FileManager.default.removeItem(at: videoURL)
            }
        )
        self.previewWindow = preview
        preview.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - ScreenRecorderDelegate

extension CaptureService: ScreenRecorderDelegate {
    func screenRecorderDidStart() {
        showRecordingStatusItem()
    }
    
    func screenRecorderDidFinish(outputURL: URL?, error: Error?) {
        hideRecordingStatusItem()
        
        if let error = error {
            let alert = NSAlert()
            alert.messageText = "Recording Error"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        
        guard let outputURL = outputURL else { return }
        
        presentPreviewWindow(videoURL: outputURL)
    }
}
