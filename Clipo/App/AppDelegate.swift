import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate?

    let environment = AppEnvironment()
    private var menuBarController: MenuBarController?
    private let hotkeyService = GlobalHotkeyService()
    private var panelController: ClipboardPanelController?
    private var viewModel: ClipboardPopupViewModel?

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AppEnvironment.shared = environment
        environment.startMonitoring()

        let viewModel = ClipboardPopupViewModel(
            historyStore: environment.historyStore,
            pasteService: environment.pasteService,
            permissions: environment.permissions
        )
        self.viewModel = viewModel
        let presentationCoordinator = ClipboardPresentationCoordinator(
            monitor: environment.monitor,
            popupLoader: viewModel
        )
        panelController = ClipboardPanelController(
            viewModel: viewModel,
            prepareForPresentation: presentationCoordinator.prepareForPresentation,
            onPopupStateChange: { [weak environment] isOpen in
                Task { @MainActor in
                    if isOpen {
                        environment?.notifyPopupOpened()
                    } else {
                        environment?.notifyPopupClosed()
                    }
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

        hotkeyService.registerPauseToggle { [weak self] in
            Task { @MainActor in
                self?.environment.toggleMonitoringPaused()
            }
        }

        for index in 1...9 {
            hotkeyService.registerQuickPaste(at: index) { [weak self] in
                Task { @MainActor in
                    await self?.environment.quickPaste(at: index)
                }
            }
        }

        hotkeyService.registerSequentialPaste { [weak self] in
            Task { @MainActor in
                guard let self = self, let viewModel = self.viewModel else { return }
                if viewModel.pasteStack.isEmpty {
                    NSSound.beep()
                    viewModel.toastManagerForView.show(.error("Paste Stack is empty"))
                } else {
                    await viewModel.popAndPasteStack()
                }
            }
        }
        
        hotkeyService.registerScreenCapture {
            Task { @MainActor in
                CaptureService.shared.startCaptureFlow(mode: .image)
            }
        }

        hotkeyService.registerScreenRecording {
            Task { @MainActor in
                if CaptureService.shared.isRecording {
                    CaptureService.shared.stopRecording()
                } else {
                    CaptureService.shared.startCaptureFlow(mode: .video)
                }
            }
        }
        
        hotkeyService.registerScreenScrollingCapture {
            Task { @MainActor in
                CaptureService.shared.startCaptureFlow(mode: .scrolling)
            }
        }
    }
}
