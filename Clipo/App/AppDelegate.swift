import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate?

    let environment = AppEnvironment()
    private var menuBarController: MenuBarController?
    private let hotkeyService = GlobalHotkeyService()
    private var panelController: ClipboardPanelController?

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        environment.startMonitoring()

        let viewModel = ClipboardPopupViewModel(
            historyStore: environment.historyStore,
            pasteService: environment.pasteService,
            permissions: environment.permissions
        )
        let presentationCoordinator = ClipboardPresentationCoordinator(
            monitor: environment.monitor,
            popupLoader: viewModel
        )
        panelController = ClipboardPanelController(
            viewModel: viewModel,
            prepareForPresentation: presentationCoordinator.prepareForPresentation,
            onPopupStateChange: { [weak environment] isOpen in
                if isOpen {
                    environment?.notifyPopupOpened()
                } else {
                    environment?.notifyPopupClosed()
                }
            }
        )
        viewModel.popupDismisser = panelController
        menuBarController = MenuBarController(
            panelController: panelController!,
            targetApplicationActivator: environment.targetApplicationActivator
        )

        hotkeyService.restoreDefaultsIfNeeded()

        hotkeyService.registerTogglePopup { [weak self] in
            Task { @MainActor in
                await self?.menuBarController?.togglePopoverNearCursor()
            }
        }

        hotkeyService.registerOpenPastePicker { [weak self] in
            Task { @MainActor in
                await self?.menuBarController?.showPastePickerNearCursor()
            }
        }
    }
}
