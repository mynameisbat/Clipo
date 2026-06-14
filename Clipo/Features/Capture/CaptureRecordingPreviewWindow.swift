import Cocoa
import SwiftUI

final class CaptureRecordingPreviewWindow: NSWindow {
    init(videoURL: URL, onCancel: @escaping () -> Void) {
        let contentRect = NSRect(x: 0, y: 0, width: 800, height: 500)
        
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.isMovableByWindowBackground = true
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isReleasedWhenClosed = false
        
        // Wrap in GPU Glass material background to match Clipo aesthetic
        let glassView = ZStack {
            GPUAcceleratedGlassMaterial(cornerRadius: 18)
            
            CaptureRecordingPreviewView(
                videoURL: videoURL,
                onCancel: { [weak self] in
                    onCancel()
                    self?.close()
                }
            )
        }
        
        let hostingView = NSHostingView(rootView: glassView)
        hostingView.frame = contentRect
        hostingView.autoresizingMask = [.width, .height]
        
        self.contentView = hostingView
        self.center()
    }
    
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}
