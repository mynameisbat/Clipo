import AppKit
import Foundation

enum PasteResult: Equatable, Sendable {
    case pasted
    case copiedOnly
}

protocol ClipboardWriting {
    func write(item: ClipboardItem) throws
}

protocol AutoPasteDriving {
    func pasteCurrentClipboard() throws
}

@MainActor
protocol TargetApplicationActivating {
    var previousApplicationBundleIdentifier: String? { get }
    func prepareForReturnToPreviousApp()
    func activatePreviousApp()
}

final class PasteActionService: PasteService, @unchecked Sendable {
    private enum PasteTiming {
        static let defaultDelayNanoseconds: UInt64 = 120_000_000
        static let windowsAppDelayNanoseconds: UInt64 = 800_000_000
        static let windowsAppBundleIdentifier = "com.microsoft.rdc.macos"
    }

    let clipboardWriter: ClipboardWriting
    let autoPasteDriver: AutoPasteDriving
    let permissions: AccessibilityPermissionChecking
    let targetApplicationActivator: TargetApplicationActivating
    let monitor: ClipboardMonitoring
    private let sleep: @Sendable (UInt64) async -> Void

    init(
        clipboardWriter: ClipboardWriting,
        autoPasteDriver: AutoPasteDriving,
        permissions: AccessibilityPermissionChecking,
        targetApplicationActivator: TargetApplicationActivating,
        monitor: ClipboardMonitoring,
        sleep: @escaping @Sendable (UInt64) async -> Void = { nanoseconds in
            try? await Task.sleep(nanoseconds: nanoseconds)
        }
    ) {
        self.clipboardWriter = clipboardWriter
        self.autoPasteDriver = autoPasteDriver
        self.permissions = permissions
        self.targetApplicationActivator = targetApplicationActivator
        self.monitor = monitor
        self.sleep = sleep
    }

    func paste(_ item: ClipboardItem) async throws -> PasteResult {
        try clipboardWriter.write(item: item)
        monitor.notifyItemPasted(item.id)
        guard permissions.isTrusted else { return .copiedOnly }
        await targetApplicationActivator.activatePreviousApp()
        let previousApplicationBundleIdentifier = await MainActor.run {
            targetApplicationActivator.previousApplicationBundleIdentifier
        }
        await sleep(Self.pasteDelayNanoseconds(for: previousApplicationBundleIdentifier))
        try autoPasteDriver.pasteCurrentClipboard()
        return .pasted
    }

    func pasteAsPlainText(_ item: ClipboardItem) async throws -> PasteResult {
        try await copyAsPlainText(item)
        guard permissions.isTrusted else { return .copiedOnly }
        await targetApplicationActivator.activatePreviousApp()
        let previousApplicationBundleIdentifier = await MainActor.run {
            targetApplicationActivator.previousApplicationBundleIdentifier
        }
        await sleep(Self.pasteDelayNanoseconds(for: previousApplicationBundleIdentifier))
        try autoPasteDriver.pasteCurrentClipboard()
        return .pasted
    }

    func copyAsPlainText(_ item: ClipboardItem) async throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let plain = plainTextContent(of: item)
        pasteboard.setString(plain, forType: .string)
        monitor.notifyItemPasted(item.id)
    }

    private func plainTextContent(of item: ClipboardItem) -> String {
        switch item.kind {
        case .text, .link:
            return item.contentText ?? item.title
        case .file:
            if let path = item.resourcePath {
                return URL(fileURLWithPath: path).absoluteString
            }
            return item.title
        case .image:
            return item.title
        }
    }

    private static func pasteDelayNanoseconds(for bundleIdentifier: String?) -> UInt64 {
        switch bundleIdentifier {
        case PasteTiming.windowsAppBundleIdentifier:
            return PasteTiming.windowsAppDelayNanoseconds
        default:
            return PasteTiming.defaultDelayNanoseconds
        }
    }
}

@MainActor
final class PreviousApplicationActivator: TargetApplicationActivating {
    private let currentBundleIdentifier = Bundle.main.bundleIdentifier
    private var previousApplication: NSRunningApplication?
    nonisolated(unsafe) private var workspaceObserver: NSObjectProtocol?

    init() {
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            Task { @MainActor in
                self.handleAppActivation(app)
            }
        }
    }

    deinit {
        if let workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
        }
    }

    var previousApplicationBundleIdentifier: String? {
        previousApplication?.bundleIdentifier
    }

    func prepareForReturnToPreviousApp() {
        guard
            let frontmostApplication = NSWorkspace.shared.frontmostApplication,
            frontmostApplication.bundleIdentifier != currentBundleIdentifier
        else {
            return
        }

        previousApplication = frontmostApplication
    }

    func activatePreviousApp() {
        NSApp.hide(nil)
        previousApplication?.unhide()
        previousApplication?.activate(options: [.activateAllWindows])
    }

    private func handleAppActivation(_ app: NSRunningApplication) {
        guard app.bundleIdentifier != currentBundleIdentifier else { return }
        previousApplication = app
    }
}

struct SystemClipboardWriter: ClipboardWriting {
    func write(item: ClipboardItem) throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.kind {
        case .text, .link:
            pasteboard.setString(item.contentText ?? item.title, forType: .string)
        case .file:
            if let path = item.resourcePath {
                pasteboard.writeObjects([URL(fileURLWithPath: path) as NSURL])
            }
        case .image:
            if
                let path = item.resourcePath,
                let url = URL(string: path),
                url.scheme != nil,
                !url.isFileURL
            {
                pasteboard.writeObjects([url as NSURL])
                pasteboard.setString(url.absoluteString, forType: .string)
            } else if let path = item.resourcePath, let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                pasteboard.setData(data, forType: .tiff)
            }
        }
    }
}

struct SystemAutoPasteDriver: AutoPasteDriving {
    func pasteCurrentClipboard() throws {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)

        vDown?.flags = .maskCommand
        vUp?.flags = .maskCommand

        vDown?.post(tap: .cgAnnotatedSessionEventTap)
        vUp?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
