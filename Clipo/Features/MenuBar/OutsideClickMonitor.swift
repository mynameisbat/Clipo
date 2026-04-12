import AppKit

@MainActor
protocol OutsideClickMonitoring: AnyObject {
    func start(handler: @escaping (NSPoint) -> Void)
    func stop()
}

@MainActor
final class OutsideClickMonitor: OutsideClickMonitoring {
    private var globalMonitors: [Any] = []
    private var localMonitors: [Any] = []

    func start(handler: @escaping (NSPoint) -> Void) {
        stop()

        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]

        if let globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: mask,
            handler: { _ in
                Task { @MainActor in
                    handler(NSEvent.mouseLocation)
                }
            }
        ) {
            globalMonitors.append(globalMonitor)
        }

        if let localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: mask,
            handler: { event in
                let location = event.window?.convertPoint(toScreen: event.locationInWindow) ?? NSEvent.mouseLocation
                handler(location)
                return event
            }
        ) {
            localMonitors.append(localMonitor)
        }
    }

    func stop() {
        globalMonitors.forEach(NSEvent.removeMonitor)
        localMonitors.forEach(NSEvent.removeMonitor)
        globalMonitors.removeAll()
        localMonitors.removeAll()
    }
}
