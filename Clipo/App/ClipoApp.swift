import SwiftUI

@main
struct ClipoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.environment)
                .frame(width: 420, height: 240)
        }
    }
}
