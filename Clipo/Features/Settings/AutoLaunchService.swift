import Foundation
import ServiceManagement

final class AutoLaunchService: @unchecked Sendable {
    static let shared = AutoLaunchService()

    func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "launchAtLogin")
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("AutoLaunch: Failed to \(enabled ? "enable" : "disable") - \(error)")
            }
        } else {
            let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.bat.clipo"
            SMLoginItemSetEnabled(bundleIdentifier as CFString, enabled)
        }
    }

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "launchAtLogin")
    }
}
