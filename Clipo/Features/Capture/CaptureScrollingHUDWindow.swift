import Cocoa
import SwiftUI

final class CaptureScrollingHUDWindow: NSPanel {
    fileprivate class HUDViewModel: ObservableObject {
        @Published var capturedCount = 0
    }
    
    private let viewModel = HUDViewModel()
    private let onStop: () -> Void
    private let onCancel: () -> Void
    
    init(onStop: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.onStop = onStop
        self.onCancel = onCancel
        
        let contentRect = NSRect(x: 0, y: 0, width: 320, height: 44)
        
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.level = .statusBar
        self.isMovableByWindowBackground = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        setupContentView()
    }
    
    private func setupContentView() {
        let view = HUDViewWrapper(viewModel: viewModel, onStop: onStop, onCancel: onCancel)
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 44)
        hostingView.autoresizingMask = [.width, .height]
        self.contentView = hostingView
    }
    
    func updateProgress(captured: Int) {
        viewModel.capturedCount = captured
    }
    
    func showNear(rect: CGRect, on screen: NSScreen) {
        let screenFrame = screen.frame
        var x = rect.midX - 160
        var y = rect.minY - 60
        
        if x < screenFrame.minX { x = screenFrame.minX + 20 }
        if x + 320 > screenFrame.maxX { x = screenFrame.maxX - 340 }
        if y < screenFrame.minY { y = rect.maxY + 20 }
        
        let globalRect = NSRect(x: screenFrame.origin.x + x, y: screenFrame.origin.y + y, width: 320, height: 44)
        self.setFrame(globalRect, display: true)
        self.makeKeyAndOrderFront(nil)
    }
}

private struct HUDViewWrapper: View {
    @ObservedObject var viewModel: CaptureScrollingHUDWindow.HUDViewModel
    let onStop: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            GPUAcceleratedGlassMaterial(cornerRadius: 12)
            CaptureScrollingHUDView(
                capturedCount: viewModel.capturedCount,
                onStop: onStop,
                onCancel: onCancel
            )
        }
    }
}
