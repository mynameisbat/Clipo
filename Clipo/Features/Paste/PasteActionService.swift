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
    func prepareForReturnToPreviousApp()
    func activatePreviousApp()
}

final class PasteActionService: PasteService, @unchecked Sendable {
    let clipboardWriter: ClipboardWriting
    let autoPasteDriver: AutoPasteDriving
    let permissions: AccessibilityPermissionChecking
    let targetApplicationActivator: TargetApplicationActivating

    init(
        clipboardWriter: ClipboardWriting,
        autoPasteDriver: AutoPasteDriving,
        permissions: AccessibilityPermissionChecking,
        targetApplicationActivator: TargetApplicationActivating
    ) {
        self.clipboardWriter = clipboardWriter
        self.autoPasteDriver = autoPasteDriver
        self.permissions = permissions
        self.targetApplicationActivator = targetApplicationActivator
    }

    func paste(_ item: ClipboardItem) async throws -> PasteResult {
        try clipboardWriter.write(item: item)
        guard permissions.isTrusted else { return .copiedOnly }
        await targetApplicationActivator.activatePreviousApp()
        // Give macOS a brief moment to return focus before sending Cmd+V.
        try? await Task.sleep(nanoseconds: 120_000_000)
        try autoPasteDriver.pasteCurrentClipboard()
        return .pasted
    }
}

@MainActor
final class PreviousApplicationActivator: TargetApplicationActivating {
    private let currentBundleIdentifier = Bundle.main.bundleIdentifier
    private var previousApplication: NSRunningApplication?

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
