import AppKit

@MainActor
protocol ApplicationTerminating: AnyObject {
    func terminate()
}

@MainActor
final class ApplicationTerminator: ApplicationTerminating {
    func terminate() {
        NSApp.terminate(nil)
    }
}
