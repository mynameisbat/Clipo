import SwiftUI

@main
struct ClipoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(viewModel: nil)
                .frame(width: 420, height: 360)
        }
    }
}
