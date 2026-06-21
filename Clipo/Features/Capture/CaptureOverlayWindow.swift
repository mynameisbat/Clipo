import Cocoa
import SwiftUI

final class CaptureOverlayWindow: NSWindow {
    var onCancel: (() -> Void)?

    init(
        screen: NSScreen,
        screenImage: NSImage,
        windows: [WindowInfo],
        mode: CaptureMode,
        onCaptured: @escaping (NSImage) -> Void,
        onRecordStart: @escaping (CGRect, Bool, Bool) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onCancel = onCancel
        
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // BUG-10 fix: use maximum window level to ensure overlay stays above all other windows
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.hidesOnDeactivate = false
        self.isReleasedWhenClosed = false
        
        let overlayView = CaptureOverlayView(
            screen: screen,
            screenImage: screenImage,
            windows: windows,
            mode: mode,
            onCaptured: { [weak self] croppedImage in
                self?.orderOut(nil)
                onCaptured(croppedImage)
            },
            onRecordStart: { [weak self] rect, includeMic, includeSystemAudio in
                self?.orderOut(nil)
                onRecordStart(rect, includeMic, includeSystemAudio)
            },
            onCancelled: { [weak self] in
                self?.orderOut(nil)
                onCancel()
            }
        )
        
        let hostingView = NSHostingView(rootView: overlayView)
        hostingView.frame = NSRect(origin: .zero, size: screen.frame.size)
        hostingView.autoresizingMask = [.width, .height]
        
        self.contentView = hostingView
    }

    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            orderOut(nil)
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }
}
