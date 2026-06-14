import Cocoa
import SwiftUI

final class CaptureEditorWindow: NSWindow {
    init(image: NSImage, onCopy: @escaping (NSImage) -> Void, onSave: @escaping (NSImage) -> Void, onCancel: @escaping () -> Void) {
        let contentRect = NSRect(x: 0, y: 0, width: 900, height: 600)
        
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
            
            CaptureEditorView(
                image: image,
                onCopy: { [weak self] finalImage in
                    onCopy(finalImage)
                    self?.close()
                },
                onSave: { [weak self] finalImage in
                    onSave(finalImage)
                    self?.close()
                },
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
