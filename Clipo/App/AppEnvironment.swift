import Foundation
import SwiftUI

final class AppEnvironment: ObservableObject {
    private static let clipboardFingerprintStore = ClipboardFingerprintStore()
    let historyStore: ClipboardHistoryStore
    let payloadReader: PasteboardPayloadReader
    let permissions: AccessibilityPermissionService
    let pasteService: PasteActionService
    let targetApplicationActivator: PreviousApplicationActivator
    let monitor: ClipboardMonitor
    private var monitorTimer: Timer?

    init() {
        let supportRoot = try! ApplicationPaths.applicationSupportRoot()
        let databaseURL = supportRoot.appendingPathComponent("clipboard.sqlite")
        let database = try! AppDatabase.live(at: databaseURL)
        let historyStore = ClipboardHistoryStore(writer: database.writer)
        let permissions = AccessibilityPermissionService()
        let targetApplicationActivator = PreviousApplicationActivator()
        let payloadReader = PasteboardPayloadReader(assetStore: ImageAssetStore(baseURL: supportRoot.appendingPathComponent("images", isDirectory: true)))
        let snapshotProvider = SystemPasteboardSnapshotProvider()

        self.historyStore = historyStore
        self.payloadReader = payloadReader
        self.permissions = permissions
        self.targetApplicationActivator = targetApplicationActivator
        self.pasteService = PasteActionService(
            clipboardWriter: SystemClipboardWriter(),
            autoPasteDriver: SystemAutoPasteDriver(),
            permissions: permissions,
            targetApplicationActivator: targetApplicationActivator
        )
        self.monitor = ClipboardMonitor(
            reader: { snapshot in try payloadReader.read(snapshot: snapshot) },
            snapshotProvider: { snapshotProvider.snapshot() },
            sink: historyStore,
            initialFingerprint: Self.clipboardFingerprintStore.load(),
            persistLastFingerprint: { fingerprint in
                Self.clipboardFingerprintStore.save(fingerprint)
            }
        )
    }

    func startMonitoring() {
        let monitorRef = monitor
        let historyStoreRef = historyStore
        Task {
            try? await historyStoreRef.purgeExpiredItemsUsingConfiguredPolicy(now: Date())
        }
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { _ in
            Task {
                try? await monitorRef.processCurrentPasteboard()
            }
        }
    }
}

private final class ClipboardFingerprintStore: @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let key = "clipo.lastClipboardFingerprint"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load() -> String? {
        userDefaults.string(forKey: key)
    }

    func save(_ fingerprint: String?) {
        userDefaults.set(fingerprint, forKey: key)
    }
}
