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
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipo")
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
