import AppKit

enum ClipboardPanelLayout {
    static let panelSize = NSSize(width: 420, height: 500)

    private static let anchorWidth: CGFloat = 28
    private static let anchorOffset: CGFloat = 8
    private static let cursorOffset: CGFloat = 12
    private static let screenPadding: CGFloat = 8

    static func panelFrame(near mouseLocation: NSPoint, visibleFrame: NSRect) -> NSRect {
        let size = panelSize
        let horizontalOrigin = clampedOrigin(
            preferred: mouseLocation.x - (size.width / 2),
            length: size.width,
            containerMin: visibleFrame.minX,
            containerMax: visibleFrame.maxX
        )

        let minY = visibleFrame.minY + screenPadding
        let belowCursorY = mouseLocation.y - size.height - cursorOffset
        let aboveCursorY = mouseLocation.y + cursorOffset
        let preferredY = belowCursorY >= minY ? belowCursorY : aboveCursorY
        let verticalOrigin = clampedOrigin(
            preferred: preferredY,
            length: size.height,
            containerMin: visibleFrame.minY,
            containerMax: visibleFrame.maxY
        )

        return NSRect(origin: NSPoint(x: horizontalOrigin, y: verticalOrigin), size: size)
    }

    static func panelFrame(anchoredTo anchorScreenRect: NSRect, visibleFrame: NSRect) -> NSRect {
        let size = panelSize
        let horizontalOrigin = clampedOrigin(
            preferred: anchorScreenRect.midX - (size.width / 2),
            length: size.width,
            containerMin: visibleFrame.minX,
            containerMax: visibleFrame.maxX
        )

        let minY = visibleFrame.minY + screenPadding
        let belowAnchorY = anchorScreenRect.minY - size.height - anchorOffset
        let aboveAnchorY = anchorScreenRect.maxY + anchorOffset
        let preferredY = belowAnchorY >= minY ? belowAnchorY : aboveAnchorY
        let verticalOrigin = clampedOrigin(
            preferred: preferredY,
            length: size.height,
            containerMin: visibleFrame.minY,
            containerMax: visibleFrame.maxY
        )

        return NSRect(origin: NSPoint(x: horizontalOrigin, y: verticalOrigin), size: size)
    }

    @MainActor
    static func anchorRect(for positioningView: NSView) -> NSRect {
        let bounds = positioningView.bounds
        let width = min(anchorWidth, bounds.width)
        let originX = bounds.midX - (width / 2)
        return NSRect(x: originX, y: bounds.minY, width: width, height: bounds.height)
    }

    private static func clampedOrigin(
        preferred: CGFloat,
        length: CGFloat,
        containerMin: CGFloat,
        containerMax: CGFloat
    ) -> CGFloat {
        let minOrigin = containerMin + screenPadding
        let maxOrigin = containerMax - length - screenPadding

        guard maxOrigin >= minOrigin else {
            return ((containerMin + containerMax) / 2) - (length / 2)
        }

        return min(max(preferred, minOrigin), maxOrigin)
    }
}
