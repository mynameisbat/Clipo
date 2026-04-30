import AppKit
import SwiftUI

private final class FloatingClipboardPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
protocol ClipboardPanelWindowManaging: AnyObject {
    var isVisible: Bool { get }
    var frame: NSRect? { get }
    var window: NSWindow? { get }

    func show(
        viewModel: ClipboardPopupViewModel,
        frame: NSRect,
        screen: NSScreen?,
        style: ClipboardPopupStyle
    )
    func activate()
    func close()
}

enum ClipboardPopupStyle {
    case anchoredToMenuBar
    case nearCursor

    var cornerRadius: CGFloat {
        switch self {
        case .anchoredToMenuBar:
            return 12
        case .nearCursor:
            return 18
        }
    }

    var usesNativePopoverBackground: Bool {
        self == .anchoredToMenuBar
    }
}

@MainActor
final class FloatingClipboardPanelWindowManager: ClipboardPanelWindowManaging {
    private var panel: NSWindow?

    var isVisible: Bool {
        panel?.isVisible == true
    }

    var frame: NSRect? {
        guard isVisible else { return nil }
        return panel?.frame
    }

    var window: NSWindow? {
        panel
    }

    func show(
        viewModel: ClipboardPopupViewModel,
        frame: NSRect,
        screen: NSScreen?,
        style: ClipboardPopupStyle
    ) {
        close()

        let hostingController = NSHostingController(
            rootView: ClipboardPopupView(viewModel: viewModel, style: style)
        )
        hostingController.view.frame = NSRect(origin: .zero, size: frame.size)

        let panel = FloatingClipboardPanel(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        panel.contentViewController = hostingController
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.isReleasedWhenClosed = false
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = style.cornerRadius
        panel.contentView?.layer?.masksToBounds = true
        panel.setFrame(frame, display: true)
        self.panel = panel
    }

    func activate() {
        panel?.makeKey()
        panel?.makeKeyAndOrderFront(nil)
    }

    func close() {
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
    }
}
