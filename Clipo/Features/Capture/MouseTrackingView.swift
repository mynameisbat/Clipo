import SwiftUI
import AppKit

struct MouseTrackingView: NSViewRepresentable {
    var onMouseDown: (CGPoint) -> Void
    var onMouseDragged: (CGPoint) -> Void
    var onMouseUp: (CGPoint) -> Void
    var onMouseMoved: (CGPoint) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = TrackingNSView()
        view.onMouseDown = onMouseDown
        view.onMouseDragged = onMouseDragged
        view.onMouseUp = onMouseUp
        view.onMouseMoved = onMouseMoved
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? TrackingNSView {
            view.onMouseDown = onMouseDown
            view.onMouseDragged = onMouseDragged
            view.onMouseUp = onMouseUp
            view.onMouseMoved = onMouseMoved
        }
    }
    
    class TrackingNSView: NSView {
        var onMouseDown: ((CGPoint) -> Void)?
        var onMouseDragged: ((CGPoint) -> Void)?
        var onMouseUp: ((CGPoint) -> Void)?
        var onMouseMoved: ((CGPoint) -> Void)?
        
        private var trackingArea: NSTrackingArea?
        
        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let trackingArea = trackingArea {
                removeTrackingArea(trackingArea)
            }
            
            let options: NSTrackingArea.Options = [.activeAlways, .mouseMoved, .enabledDuringMouseDrag]
            trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
            addTrackingArea(trackingArea!)
        }
        
        override func mouseDown(with event: NSEvent) {
            let point = convert(event.locationInWindow, from: nil)
            onMouseDown?(point)
        }
        
        override func mouseDragged(with event: NSEvent) {
            let point = convert(event.locationInWindow, from: nil)
            onMouseDragged?(point)
        }
        
        override func mouseUp(with event: NSEvent) {
            let point = convert(event.locationInWindow, from: nil)
            onMouseUp?(point)
        }
        
        override func mouseMoved(with event: NSEvent) {
            let point = convert(event.locationInWindow, from: nil)
            onMouseMoved?(point)
        }
        
        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .crosshair)
        }
    }
}
