import SwiftUI
import AppKit

struct KeyEventData: Sendable {
    let keyCode: UInt16
    let modifiers: NSEvent.ModifierFlags
    let characters: String
}

struct KeyboardEventHandlingView: NSViewRepresentable {
    let onKeyEvent: @MainActor (KeyEventData) async -> Bool

    func makeNSView(context: Context) -> NSView {
        let view = KeyEventView()
        view.keyEventHandler = onKeyEvent
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let keyEventView = nsView as? KeyEventView {
            keyEventView.keyEventHandler = onKeyEvent
        }
    }

    class KeyEventView: NSView {
        var keyEventHandler: (@MainActor (KeyEventData) async -> Bool)?

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            // Extract event data synchronously
            let eventData = KeyEventData(
                keyCode: event.keyCode,
                modifiers: event.modifierFlags,
                characters: event.charactersIgnoringModifiers ?? ""
            )

            Task { @MainActor in
                _ = await keyEventHandler?(eventData) ?? false
            }
        }
    }
}
