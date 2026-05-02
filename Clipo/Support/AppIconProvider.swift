import Foundation
import AppKit

actor AppIconProvider {
    private var iconCache: [String: NSImage] = [:]

    /// Retrieves the app icon for a given bundle identifier
    /// - Parameter bundleId: The bundle identifier of the application
    /// - Returns: The app icon, or nil if not found
    func icon(for bundleId: String) async -> NSImage? {
        // Check cache first
        if let cached = iconCache[bundleId] {
            return cached
        }

        // Get app URL from bundle identifier
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return nil
        }

        // Get icon from app URL
        let icon = NSWorkspace.shared.icon(forFile: appURL.path)

        // Cache the icon
        iconCache[bundleId] = icon

        return icon
    }

    /// Clears the icon cache
    func clearCache() {
        iconCache.removeAll()
    }

    /// Returns the number of cached icons
    var cacheSize: Int {
        iconCache.count
    }
}
