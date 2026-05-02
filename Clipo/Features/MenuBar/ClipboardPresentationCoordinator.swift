import Foundation

protocol ClipboardMonitoring: Sendable {
    func processCurrentPasteboard() async throws
    func notifyItemPasted(_ itemId: UUID)
}

@MainActor
protocol ClipboardPopupLoading: AnyObject {
    func load() async
}

@MainActor
struct ClipboardPresentationCoordinator {
    let monitor: ClipboardMonitoring
    let popupLoader: ClipboardPopupLoading

    func prepareForPresentation() async {
        try? await monitor.processCurrentPasteboard()
        await popupLoader.load()
    }
}
