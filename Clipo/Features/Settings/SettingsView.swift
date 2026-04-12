import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @AppStorage(HistoryRetentionPolicy.storageKey) private var historyRetentionPolicyRawValue = HistoryRetentionPolicy.defaultPolicy.rawValue
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    private var selectedHistoryRetentionPolicy: Binding<HistoryRetentionPolicy> {
        Binding(
            get: { HistoryRetentionPolicy(rawValue: historyRetentionPolicyRawValue) ?? .defaultPolicy },
            set: { historyRetentionPolicyRawValue = $0.rawValue }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Clipo")
                .font(.title2.weight(.semibold))

            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { newValue in
                    AutoLaunchService.shared.setEnabled(newValue)
                }

            Label(
                environment.permissions.isTrusted ? "Accessibility enabled" : "Accessibility required for auto-paste",
                systemImage: environment.permissions.isTrusted ? "checkmark.shield" : "exclamationmark.triangle"
            )

            Button("Open Accessibility Settings") {
                environment.permissions.openSystemSettings()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Global shortcut")
                    .font(.headline)
                KeyboardShortcuts.Recorder("Toggle Clipo", name: ShortcutName.togglePopup)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("History retention")
                    .font(.headline)
                Picker("History retention", selection: selectedHistoryRetentionPolicy) {
                    ForEach(HistoryRetentionPolicy.allCases, id: \.rawValue) { policy in
                        Text(policy.title).tag(policy)
                    }
                }
                .pickerStyle(.menu)

                Text("Pinned items are kept and are not auto-deleted.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(24)
    }
}
