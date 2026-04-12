import AppKit

@MainActor
protocol PopoverManaging: AnyObject {
    var isShown: Bool { get }
    var contentWindowFrame: NSRect? { get }
    var contentViewController: NSViewController? { get set }
    var contentSize: NSSize { get set }
    var behavior: NSPopover.Behavior { get set }
    var animates: Bool { get set }

    func show(relativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge)
    func close()
}

@MainActor
final class PopoverAdapter: PopoverManaging {
    private let popover = NSPopover()

    var isShown: Bool {
        popover.isShown
    }

    var contentWindowFrame: NSRect? {
        popover.contentViewController?.view.window?.frame
    }

    var contentViewController: NSViewController? {
        get { popover.contentViewController }
        set { popover.contentViewController = newValue }
    }

    var contentSize: NSSize {
        get { popover.contentSize }
        set { popover.contentSize = newValue }
    }

    var behavior: NSPopover.Behavior {
        get { popover.behavior }
        set { popover.behavior = newValue }
    }

    var animates: Bool {
        get { popover.animates }
        set { popover.animates = newValue }
    }

    func show(relativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge) {
        popover.show(relativeTo: positioningRect, of: positioningView, preferredEdge: preferredEdge)
    }

    func close() {
        popover.performClose(nil)
    }
}
