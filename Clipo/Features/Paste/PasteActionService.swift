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
    private let sleep: @Sendable (UInt64) async -> Void

    init(
        clipboardWriter: ClipboardWriting,
        autoPasteDriver: AutoPasteDriving,
        permissions: AccessibilityPermissionChecking,
        targetApplicationActivator: TargetApplicationActivating,
        sleep: @escaping @Sendable (UInt64) async -> Void = { nanoseconds in
            try? await Task.sleep(nanoseconds: nanoseconds)
        }
    ) {
        self.clipboardWriter = clipboardWriter
        self.autoPasteDriver = autoPasteDriver
        self.permissions = permissions
        self.targetApplicationActivator = targetApplicationActivator
        self.sleep = sleep
    }

    func paste(_ item: ClipboardItem) async throws -> PasteResult {
        try clipboardWriter.write(item: item)
        guard permissions.isTrusted else { return .copiedOnly }
        await targetApplicationActivator.activatePreviousApp()
        let previousApplicationBundleIdentifier = await MainActor.run {
            targetApplicationActivator.previousApplicationBundleIdentifier
        }
        await sleep(Self.pasteDelayNanoseconds(for: previousApplicationBundleIdentifier))
        try autoPasteDriver.pasteCurrentClipboard()
        return .pasted
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
