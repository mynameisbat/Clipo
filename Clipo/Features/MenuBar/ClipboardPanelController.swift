import AppKit
import KeyboardShortcuts
import SwiftUI

@MainActor
final class ClipboardPanelController: NSObject, ObservableObject, ClipboardPopupPresenting, ClipboardPopupDismissing {
    private enum Layout {
        static let panelSize = NSSize(width: 420, height: 500)
        static let anchorWidth: CGFloat = 28
    }

    enum PanelShortcutAction: Equatable {
        case toggle
        case present
    }

    private let popover: PopoverManaging
    private let outsideClickMonitor: OutsideClickMonitoring
    private let scheduleOutsideClickMonitoring: (@escaping @MainActor () -> Void) -> Void
    private let prepareForPresentation: @Sendable () async -> Void
    private var eventMonitor: Any?
    private var cursorAnchorWindow: NSWindow?
    private weak var viewModel: ClipboardPopupViewModel?

    init(
        viewModel: ClipboardPopupViewModel,
        prepareForPresentation: @escaping @Sendable () async -> Void = {},
        popover: PopoverManaging = PopoverAdapter(),
        outsideClickMonitor: OutsideClickMonitoring = OutsideClickMonitor(),
        scheduleOutsideClickMonitoring: @escaping (@escaping @MainActor () -> Void) -> Void = { action in
            DispatchQueue.main.async(execute: action)
        }
    ) {
        self.prepareForPresentation = prepareForPresentation
        self.popover = popover
        self.outsideClickMonitor = outsideClickMonitor
        self.scheduleOutsideClickMonitoring = scheduleOutsideClickMonitoring
        self.viewModel = viewModel
        super.init()
        let hostingController = NSHostingController(rootView: ClipboardPopupView(viewModel: viewModel))
        hostingController.view.frame = NSRect(origin: .zero, size: Layout.panelSize)
        popover.contentViewController = hostingController
        popover.contentSize = Layout.panelSize
        popover.behavior = .transient
        popover.animates = true
    }

    func toggle() async {
        await toggle(relativeTo: nil)
    }

    func toggle(relativeTo positioningView: NSView?) async {
        await handlePresentation(relativeTo: positioningView, closesWhenShown: true)
    }

    func present(relativeTo positioningView: NSView?) async {
        await handlePresentation(relativeTo: positioningView, closesWhenShown: false)
    }

    private func handlePresentation(relativeTo positioningView: NSView?, closesWhenShown: Bool) async {
        if popover.isShown {
            if closesWhenShown {
                closePopover()
            } else {
                await prepareForPresentation()
                activatePopoverWindow()
            }
            return
        }

        await prepareForPresentation()
        if let anchorView = positioningView {
            showPopover(relativeTo: anchorView)
        } else {
            showPopoverNearMouseCursor()
        }
    }

    func dismiss() async {
        closePopover()
    }

    private func showPopover(relativeTo positioningView: NSView?) {
        guard let positioningView else { return }

        NSApp.activate(ignoringOtherApps: true)
        cursorAnchorWindow?.orderOut(nil)
        cursorAnchorWindow = nil
        popover.show(relativeTo: anchorRect(for: positioningView), of: positioningView, preferredEdge: .minY)
        activatePopoverWindow()

        if let window = popover.contentViewController?.view.window {
            startKeyMonitoring(in: window)
        }

        scheduleOutsideClickMonitoring { [weak self] in
            guard let self, self.popover.isShown else { return }
            self.outsideClickMonitor.start { [weak self] location in
                self?.handlePotentialOutsideClick(at: location)
            }
        }
    }

    private func showPopoverNearMouseCursor() {
        guard let anchorView = makeCursorAnchorView() else { return }

        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .minY)
        activatePopoverWindow()

        if let window = popover.contentViewController?.view.window {
            startKeyMonitoring(in: window)
        }

        scheduleOutsideClickMonitoring { [weak self] in
            guard let self, self.popover.isShown else { return }
            self.outsideClickMonitor.start { [weak self] location in
                self?.handlePotentialOutsideClick(at: location)
            }
        }
    }

    private func activatePopoverWindow() {
        guard let window = popover.contentViewController?.view.window else { return }
        window.makeKey()
        window.makeKeyAndOrderFront(nil)
    }

    private func closePopover() {
        outsideClickMonitor.stop()
        stopKeyMonitoring()
        popover.close()
        cursorAnchorWindow?.orderOut(nil)
        cursorAnchorWindow = nil
    }

    private func anchorRect(for positioningView: NSView) -> NSRect {
        let bounds = positioningView.bounds
        let anchorWidth = min(Layout.anchorWidth, bounds.width)
        let originX = bounds.midX - (anchorWidth / 2)
        return NSRect(x: originX, y: bounds.minY, width: anchorWidth, height: bounds.height)
    }

    private func makeCursorAnchorView() -> NSView? {
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main else {
            return nil
        }

        let anchorRect = NSRect(x: mouseLocation.x - 1, y: mouseLocation.y - 1, width: 2, height: 2)
        let window = NSWindow(
            contentRect: anchorRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let anchorView = NSView(frame: NSRect(origin: .zero, size: anchorRect.size))
        window.contentView = anchorView
        window.orderFrontRegardless()
        cursorAnchorWindow = window
        return anchorView
    }

    // MARK: - Keyboard Monitoring

    private func startKeyMonitoring(in window: NSWindow) {
        stopKeyMonitoring()

        // Capture references for closure
        let viewModel = self.viewModel

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard window.isKeyWindow else { return event }

            if let shortcutAction = self.shortcutAction(for: event) {
                Task {
                    switch shortcutAction {
                    case .toggle:
                        await self.toggle(relativeTo: nil)
                    case .present:
                        await self.present(relativeTo: nil)
                    }
                }
                return nil
            }

            let keyCode = event.keyCode

            switch keyCode {
            case 53: // Escape
                Task { await self.dismiss() }
                return nil

            case 36: // Enter
                Task { await viewModel?.confirmSelection() }
                return nil

            case 51: // Backspace
                return event // Let search field handle it

            case 125: // Down
                viewModel?.moveSelection(delta: 1)
                return nil

            case 126: // Up
                viewModel?.moveSelection(delta: -1)
                return nil

            case 116: // Page Up
                viewModel?.moveSelection(delta: -10)
                return nil

            case 121: // Page Down
                viewModel?.moveSelection(delta: 10)
                return nil

            case 115: // Home
                viewModel?.moveToTop()
                return nil

            case 119: // End
                viewModel?.moveToBottom()
                return nil

            default:
                return event // Let all other keys pass through for search
            }
        }
    }

    func shortcutAction(for event: NSEvent) -> PanelShortcutAction? {
        guard let shortcut = KeyboardShortcuts.Shortcut(event: event) else {
            return nil
        }

        if shortcut == KeyboardShortcuts.Shortcut(name: ShortcutName.togglePopup) {
            return .toggle
        }

        if shortcut == KeyboardShortcuts.Shortcut(name: ShortcutName.openPastePicker) {
            return .present
        }

        return nil
    }

    private func stopKeyMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    func handlePotentialOutsideClick(at screenLocation: NSPoint) {
        guard popover.isShown else { return }
        guard let frame = popover.contentWindowFrame else {
            closePopover()
            return
        }

        guard !frame.contains(screenLocation) else { return }
        closePopover()
    }
}
