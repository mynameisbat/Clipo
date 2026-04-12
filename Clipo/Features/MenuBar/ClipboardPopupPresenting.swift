import AppKit

@MainActor
protocol ClipboardPopupDismissing: AnyObject {
    func dismiss() async
}

@MainActor
protocol ClipboardPopupPresenting: AnyObject {
    func toggle() async
    func toggle(relativeTo positioningView: NSView?) async
}
