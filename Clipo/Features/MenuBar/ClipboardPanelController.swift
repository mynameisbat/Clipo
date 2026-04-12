import AppKit
import SwiftUI

@MainActor
final class ClipboardPanelController: NSObject, ObservableObject, ClipboardPopupPresenting, ClipboardPopupDismissing {
    private let popover: PopoverManaging
    private let outsideClickMonitor: OutsideClickMonitoring
    private let scheduleOutsideClickMonitoring: (@escaping @MainActor () -> Void) -> Void
    private weak var lastPositioningView: NSView?
    private let prepareForPresentation: @Sendable () async -> Void
    private var eventMonitor: Any?
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
        hostingController.view.frame = NSRect(x: 0, y: 0, width: 420, height: 520)
        popover.contentViewController = hostingController
        popover.contentSize = NSSize(width: 420, height: 520)
        popover.behavior = .transient
        popover.animates = true
    }

    func toggle() async {
        await toggle(relativeTo: nil)
    }

    func toggle(relativeTo positioningView: NSView?) async {
        if let positioningView {
            lastPositioningView = positioningView
        }

        if popover.isShown {
            closePopover()
            return
        }

        await prepareForPresentation()
        showPopover(relativeTo: positioningView ?? lastPositioningView)
    }

    func dismiss() async {
        closePopover()
    }

    private func showPopover(relativeTo positioningView: NSView?) {
        guard let positioningView else { return }

        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: positioningView.bounds, of: positioningView, preferredEdge: .minY)

        guard let window = popover.contentViewController?.view.window else { return }
        window.makeKey()
        startKeyMonitoring(in: window)

        scheduleOutsideClickMonitoring { [weak self] in
            guard let self, self.popover.isShown else { return }
            self.outsideClickMonitor.start { [weak self] location in
                self?.handlePotentialOutsideClick(at: location)
            }
        }
    }

    private func closePopover() {
        outsideClickMonitor.stop()
        stopKeyMonitoring()
        popover.close()
    }

    // MARK: - Keyboard Monitoring

    private func startKeyMonitoring(in window: NSWindow) {
        stopKeyMonitoring()

        // Capture references for closure
        let viewModel = self.viewModel
        let dismissAction: () -> Void = { [weak self] in
            _ = Task { await self?.dismiss() }
        }

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard window.isKeyWindow else { return event }

            let keyCode = event.keyCode

            switch keyCode {
            case 53: // Escape
                dismissAction()
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
