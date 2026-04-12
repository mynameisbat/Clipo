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
        statusItem.isVisible = true
    }

    func togglePopover() async {
        targetApplicationActivator.prepareForReturnToPreviousApp()
        await panelController?.toggle(relativeTo: statusItem.button)
    }

    @objc private func togglePanel() {
        Task { @MainActor in
            await togglePopover()
        }
    }
}
