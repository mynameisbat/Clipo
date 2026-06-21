import AppKit

@MainActor
final class MenuBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var panelController: ClipboardPopupPresenting?
    private let targetApplicationActivator: TargetApplicationActivating

    init(
        panelController: ClipboardPopupPresenting,
        targetApplicationActivator: TargetApplicationActivating = PreviousApplicationActivator()
    ) {
        self.panelController = panelController
        self.targetApplicationActivator = targetApplicationActivator
        super.init()
        setupButton()
    }

    private func setupButton() {
        if let button = statusItem.button {
            button.image = NSImage(named: "MenuBarIcon")
            button.image?.isTemplate = true
            button.image?.accessibilityDescription = "Clipo"
            button.target = self
            button.action = #selector(togglePanel)
        }
        statusItem.menu = buildMenu()
        statusItem.isVisible = true
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let openItem = NSMenuItem(
            title: "Open Clipo",
            action: #selector(togglePanel),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)

        let captureItem = NSMenuItem(
            title: "Capture Screen",
            action: #selector(captureScreen),
            keyEquivalent: "s"
        )
        captureItem.keyEquivalentModifierMask = [.command, .option]
        captureItem.target = self
        menu.addItem(captureItem)

        let recordItem = NSMenuItem(
            title: "Record Screen",
            action: #selector(recordScreen),
            keyEquivalent: "r"
        )
        recordItem.keyEquivalentModifierMask = [.command, .option]
        recordItem.target = self
        menu.addItem(recordItem)

        let scrollingCaptureItem = NSMenuItem(
            title: "Scrolling Screenshot",
            action: #selector(scrollingCaptureScreen),
            keyEquivalent: "p"
        )
        scrollingCaptureItem.keyEquivalentModifierMask = [.command, .option]
        scrollingCaptureItem.target = self
        menu.addItem(scrollingCaptureItem)

        menu.addItem(.separator())

        let aboutItem = NSMenuItem(
            title: "About Clipo",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        aboutItem.target = NSApp
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Clipo",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp
        menu.addItem(quitItem)

        return menu
    }

    @objc private func captureScreen() {
        Task { @MainActor in
            CaptureService.shared.startCaptureFlow(mode: .image)
        }
    }

    @objc private func recordScreen() {
        Task { @MainActor in
            if CaptureService.shared.isRecording {
                CaptureService.shared.stopRecording()
            } else {
                CaptureService.shared.startCaptureFlow(mode: .video)
            }
        }
    }

    @objc private func scrollingCaptureScreen() {
        Task { @MainActor in
            CaptureService.shared.startCaptureFlow(mode: .scrolling)
        }
    }

    func togglePopover() async {
        targetApplicationActivator.prepareForReturnToPreviousApp()
        await panelController?.toggle(relativeTo: statusItem.button)
    }

    func showPastePicker() async {
        targetApplicationActivator.prepareForReturnToPreviousApp()
        await panelController?.present(relativeTo: statusItem.button)
    }

    func togglePopoverNearCursor() async {
        targetApplicationActivator.prepareForReturnToPreviousApp()
        await panelController?.toggle()
    }

    func showPastePickerNearCursor() async {
        targetApplicationActivator.prepareForReturnToPreviousApp()
        await panelController?.present(relativeTo: nil)
    }

    @objc private func togglePanel() {
        Task { @MainActor in
            await togglePopover()
        }
    }
}
