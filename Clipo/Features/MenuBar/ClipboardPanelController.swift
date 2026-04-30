import AppKit
import KeyboardShortcuts

@MainActor
final class ClipboardPanelController: NSObject, ObservableObject, ClipboardPopupPresenting, ClipboardPopupDismissing {
    enum PanelShortcutAction: Equatable {
        case toggle
        case present
    }

    private let panelWindow: any ClipboardPanelWindowManaging
    private let outsideClickMonitor: OutsideClickMonitoring
    private let scheduleOutsideClickMonitoring: (@escaping @MainActor () -> Void) -> Void
    private let prepareForPresentation: @Sendable () async -> Void
    private var eventMonitor: Any?
    private let viewModel: ClipboardPopupViewModel

    init(
        viewModel: ClipboardPopupViewModel,
        prepareForPresentation: @escaping @Sendable () async -> Void = {},
        panelWindow: any ClipboardPanelWindowManaging = FloatingClipboardPanelWindowManager(),
        outsideClickMonitor: OutsideClickMonitoring = OutsideClickMonitor(),
        scheduleOutsideClickMonitoring: @escaping (@escaping @MainActor () -> Void) -> Void = { action in
            DispatchQueue.main.async(execute: action)
        }
    ) {
        self.prepareForPresentation = prepareForPresentation
        self.panelWindow = panelWindow
        self.outsideClickMonitor = outsideClickMonitor
        self.scheduleOutsideClickMonitoring = scheduleOutsideClickMonitoring
        self.viewModel = viewModel
        super.init()
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
        if isPresentationShown {
            if closesWhenShown {
                closePresentation()
            } else {
                await prepareForPresentation()
                activatePresentationWindow()
            }
            return
        }

        await prepareForPresentation()
        if let anchorView = positioningView {
            showPanel(relativeTo: anchorView)
        } else {
            showPanelNearMouseCursor()
        }
    }

    func dismiss() async {
        closePresentation()
    }

    private func showPanel(relativeTo positioningView: NSView) {
        guard let presentation = anchoredPanelPresentation(relativeTo: positioningView) else {
            showPanelNearMouseCursor()
            return
        }

        showPanel(
            frame: presentation.frame,
            screen: presentation.screen,
            style: .anchoredToMenuBar
        )
    }

    private func showPanelNearMouseCursor() {
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main else {
            return
        }

        let frame = floatingPanelFrame(near: mouseLocation, visibleFrame: screen.visibleFrame)
        showPanel(frame: frame, screen: screen, style: .nearCursor)
    }

    private func showPanel(frame: NSRect, screen: NSScreen?, style: ClipboardPopupStyle) {
        NSApp.activate(ignoringOtherApps: true)
        panelWindow.show(viewModel: viewModel, frame: frame, screen: screen, style: style)
        panelWindow.activate()

        if let window = panelWindow.window {
            startKeyMonitoring(in: window)
        }
        startOutsideClickMonitoring()
    }

    func floatingPanelFrame(near mouseLocation: NSPoint, visibleFrame: NSRect) -> NSRect {
        ClipboardPanelLayout.panelFrame(near: mouseLocation, visibleFrame: visibleFrame)
    }

    func floatingPanelFrame(anchoredTo anchorScreenRect: NSRect, visibleFrame: NSRect) -> NSRect {
        ClipboardPanelLayout.panelFrame(anchoredTo: anchorScreenRect, visibleFrame: visibleFrame)
    }

    private var isPresentationShown: Bool {
        panelWindow.isVisible
    }

    private var currentPresentationFrame: NSRect? {
        panelWindow.frame
    }

    private func activatePresentationWindow() {
        panelWindow.activate()
    }

    private func startOutsideClickMonitoring() {
        scheduleOutsideClickMonitoring { [weak self] in
            guard let self, self.isPresentationShown else { return }
            self.outsideClickMonitor.start { [weak self] location in
                self?.handlePotentialOutsideClick(at: location)
            }
        }
    }

    private func closePresentation() {
        outsideClickMonitor.stop()
        stopKeyMonitoring()
        panelWindow.close()
    }

    private func anchorRect(for positioningView: NSView) -> NSRect {
        ClipboardPanelLayout.anchorRect(for: positioningView)
    }

    private func anchoredPanelPresentation(relativeTo positioningView: NSView) -> (frame: NSRect, screen: NSScreen)? {
        guard let window = positioningView.window else { return nil }
        guard let screen = window.screen
            ?? NSScreen.screens.first(where: { $0.frame.intersects(window.frame) })
            ?? NSScreen.main
        else {
            return nil
        }

        let anchorInWindow = positioningView.convert(anchorRect(for: positioningView), to: nil)
        let anchorOnScreen = window.convertToScreen(anchorInWindow)
        let frame = floatingPanelFrame(anchoredTo: anchorOnScreen, visibleFrame: screen.visibleFrame)

        return (frame, screen)
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
                Task { await viewModel.confirmSelection() }
                return nil

            case 51: // Backspace
                return event // Let search field handle it

            case 125: // Down
                viewModel.moveSelection(delta: 1)
                return nil

            case 126: // Up
                viewModel.moveSelection(delta: -1)
                return nil

            case 116: // Page Up
                viewModel.moveSelection(delta: -10)
                return nil

            case 121: // Page Down
                viewModel.moveSelection(delta: 10)
                return nil

            case 115: // Home
                viewModel.moveToTop()
                return nil

            case 119: // End
                viewModel.moveToBottom()
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

        if shortcut == KeyboardShortcuts.Shortcut(name: ShortcutName.screenExtensionTogglePopup) {
            return .toggle
        }

        if shortcut == KeyboardShortcuts.Shortcut(name: ShortcutName.openPastePicker) {
            return .present
        }

        if shortcut == KeyboardShortcuts.Shortcut(name: ShortcutName.screenExtensionOpenPastePicker) {
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
        guard isPresentationShown else { return }
        guard let frame = currentPresentationFrame else {
            closePresentation()
            return
        }

        guard !frame.contains(screenLocation) else { return }
        closePresentation()
    }
}
