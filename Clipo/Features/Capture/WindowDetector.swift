import Cocoa
import CoreGraphics

struct WindowInfo: Identifiable, Equatable {
    let id: CGWindowID
    let bounds: CGRect // CG coordinate system (origin top-left)
    let ownerName: String
    let name: String
}

enum WindowDetector {
    /// Returns a list of all visible normal windows on screen.
    static func getVisibleWindows(excludingWindowIDs: Set<CGWindowID> = []) -> [WindowInfo] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        
        let ourPid = ProcessInfo.processInfo.processIdentifier
        var windows: [WindowInfo] = []
        
        for dict in list {
            guard let id = dict[kCGWindowNumber as String] as? CGWindowID else {
                continue
            }
            
            if excludingWindowIDs.contains(id) {
                continue
            }
            
            // Filter out our own app windows by PID
            if let pid = dict[kCGWindowOwnerPID as String] as? Int32, pid == ourPid {
                continue
            }
            
            // Filter out window layers that aren't the standard window layer (0)
            guard let layer = dict[kCGWindowLayer as String] as? Int, layer == 0 else {
                continue
            }
            
            guard let boundsDict = dict[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else {
                continue
            }
            
            // Skip extremely small windows
            if bounds.width < 100 || bounds.height < 100 {
                continue
            }
            
            let ownerName = dict[kCGWindowOwnerName as String] as? String ?? ""
            let name = dict[kCGWindowName as String] as? String ?? ""
            
            windows.append(WindowInfo(id: id, bounds: bounds, ownerName: ownerName, name: name))
        }
        
        return windows
    }
    
    /// Finds the topmost window that contains the given point (in CG coordinates).
    static func findWindow(at point: CGPoint, in windows: [WindowInfo]) -> WindowInfo? {
        // Since window list is returned in front-to-back order,
        // the first one containing the point is the window we hover over.
        return windows.first { $0.bounds.contains(point) }
    }
}
