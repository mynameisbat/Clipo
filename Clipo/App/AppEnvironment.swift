import AppKit
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
    let activityDetector: ActivityLevelDetector
    let adaptiveMonitor: AdaptiveClipboardMonitor
    private var monitorTimer: Timer? // Deprecated: Replaced by adaptiveMonitor

    init() {
        let supportRoot = try! ApplicationPaths.applicationSupportRoot()
        let databaseURL = supportRoot.appendingPathComponent("clipboard.sqlite")
        let database = try! AppDatabase.live(at: databaseURL)
        let historyStore = ClipboardHistoryStore(writer: database.writer)
        let permissions = AccessibilityPermissionService()
        let targetApplicationActivator = PreviousApplicationActivator()
        let payloadReader = PasteboardPayloadReader(assetStore: ImageAssetStore(baseURL: supportRoot.appendingPathComponent("images", isDirectory: true)))
        let snapshotProvider = SystemPasteboardSnapshotProvider()
        let clipboardSoundPlayer = SystemClipboardSoundPlayer()

        self.historyStore = historyStore
        self.payloadReader = payloadReader
        self.permissions = permissions
        self.targetApplicationActivator = targetApplicationActivator
        self.monitor = ClipboardMonitor(
            reader: { snapshot in try payloadReader.read(snapshot: snapshot) },
            snapshotProvider: { snapshotProvider.snapshot() },
            sink: historyStore,
            initialFingerprint: Self.clipboardFingerprintStore.load(),
            persistLastFingerprint: { fingerprint in
                Self.clipboardFingerprintStore.save(fingerprint)
            },
            onNewItemStored: { item in
                await clipboardSoundPlayer.playIfNeeded(for: item)
            }
        )
        self.pasteService = PasteActionService(
            clipboardWriter: SystemClipboardWriter(),
            autoPasteDriver: SystemAutoPasteDriver(),
            permissions: permissions,
            targetApplicationActivator: targetApplicationActivator,
            monitor: monitor
        )

        // Initialize adaptive monitoring
        self.activityDetector = ActivityLevelDetector()
        self.adaptiveMonitor = AdaptiveClipboardMonitor(
            clipboardMonitor: monitor,
            activityDetector: activityDetector
        )
    }

    func startMonitoring() {
        let historyStoreRef = historyStore
        let adaptiveMonitorRef = adaptiveMonitor

        Task {
            // Purge expired items on startup
            try? await historyStoreRef.purgeExpiredItemsUsingConfiguredPolicy(now: Date())

            // Start adaptive monitoring
            await adaptiveMonitorRef.startMonitoring()
        }
    }

    func notifyPopupOpened() {
        let adaptiveMonitorRef = adaptiveMonitor
        Task {
            await adaptiveMonitorRef.notifyPopupOpened()
        }
    }

    func notifyPopupClosed() {
        let adaptiveMonitorRef = adaptiveMonitor
        Task {
            await adaptiveMonitorRef.notifyPopupClosed()
        }
    }
}

actor SystemClipboardSoundPlayer {
    private let currentBundleIdentifier = Bundle.main.bundleIdentifier
    private let currentBundleIdentifierOverride: String?
    private let isSoundEnabled: @Sendable () -> Bool
    private let selectedSound: @Sendable () -> ClipboardSoundName
    private let playNamedSoundOverride: (@Sendable (String) async -> Bool)?
    private let beep: @Sendable () async -> Void
    private var activeSound: NSSound?

    init(
        currentBundleIdentifier: String? = nil,
        isSoundEnabled: @escaping @Sendable () -> Bool = {
            ClipboardSoundPreference.isEnabled(userDefaults: .standard)
        },
        selectedSound: @escaping @Sendable () -> ClipboardSoundName = {
            ClipboardSoundPreference.selectedSound(userDefaults: .standard)
        },
        playNamedSound: (@Sendable (String) async -> Bool)? = nil,
        beep: @escaping @Sendable () async -> Void = {
            NSSound.beep()
        }
    ) {
        self.currentBundleIdentifierOverride = currentBundleIdentifier
        self.isSoundEnabled = isSoundEnabled
        self.selectedSound = selectedSound
        self.playNamedSoundOverride = playNamedSound
        self.beep = beep
    }

    func playIfNeeded(for item: ClipboardItem) async {
        guard isSoundEnabled() else { return }
        guard item.sourceAppBundleId != resolvedBundleIdentifier else { return }

        let sound = selectedSound()
        let didPlay: Bool
        if let playNamedSoundOverride {
            didPlay = await playNamedSoundOverride(sound.rawValue)
        } else {
            didPlay = playSystemSound(named: sound.rawValue)
        }

        if !didPlay {
            await beep()
        }
    }

    private func playSystemSound(named name: String) -> Bool {
        guard let sound = NSSound(named: NSSound.Name(name)) else { return false }
        activeSound = sound
        return sound.play()
    }

    private var resolvedBundleIdentifier: String? {
        currentBundleIdentifierOverride ?? currentBundleIdentifier
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
