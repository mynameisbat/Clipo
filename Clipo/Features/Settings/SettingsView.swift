import KeyboardShortcuts
import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case shortcuts
    case history
    case privacy
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .shortcuts: return "Shortcuts"
        case .history: return "History"
        case .privacy: return "Privacy"
        case .about: return "About"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .shortcuts: return "keyboard"
        case .history: return "clock.arrow.circlepath"
        case .privacy: return "lock.shield"
        case .about: return "info.circle"
        }
    }
}

struct SettingsView: View {
    let viewModel: ClipboardPopupViewModel?

    @AppStorage("clipo.settingsTab") private var selectedTabRaw: String = SettingsTab.general.rawValue
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage(ClipboardSoundPreference.enabledStorageKey) private var clipboardSoundEnabled = true
    @AppStorage(ClipboardSoundPreference.nameStorageKey) private var clipboardSoundNameRawValue = ClipboardSoundName.glass.rawValue
    @AppStorage("clipo.paused") private var isPausedFromStorage = false
    @AppStorage(HistoryRetentionPolicy.storageKey) private var retentionPolicyFromStorage: HistoryRetentionPolicy = .defaultPolicy

    private enum Appearance {
        static let tabBarHeight: CGFloat = 44
        static let panelWidth: CGFloat = 420
        static let panelHeight: CGFloat = 520
    }

    private var selectedTab: SettingsTab {
        SettingsTab(rawValue: selectedTabRaw) ?? .general
    }

    private var isPaused: Bool {
        get { isPausedFromStorage }
        nonmutating set {
            isPausedFromStorage = newValue
            AppEnvironment.shared?.setMonitoringPaused(newValue)
        }
    }

    private var retentionPolicyBinding: Binding<HistoryRetentionPolicy> {
        Binding(
            get: { viewModel?.historyRetentionPolicy ?? retentionPolicyFromStorage },
            set: { newValue in
                retentionPolicyFromStorage = newValue
                viewModel?.historyRetentionPolicy = newValue
            }
        )
    }

    private var isAccessibilityTrusted: Bool {
        viewModel?.isAccessibilityTrusted ?? false
    }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Rectangle()
                .fill(DT.Color.stroke)
                .frame(height: 1)
            tabContent
        }
        .frame(width: Appearance.panelWidth, height: Appearance.panelHeight)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(SettingsTab.allCases) { tab in
                Button {
                    selectedTabRaw = tab.rawValue
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 13, weight: .medium))
                        Text(tab.title)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(selectedTab == tab ? DT.Color.accent : DT.Color.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: Appearance.tabBarHeight)
                    .background(
                        selectedTab == tab
                            ? DT.Color.accentMuted
                            : Color.clear
                    )
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(selectedTab == tab ? DT.Color.accent : Color.clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DT.Spacing.xs)
        .padding(.top, DT.Spacing.s)
    }

    @ViewBuilder
    private var tabContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DT.Spacing.l) {
                switch selectedTab {
                case .general: generalTab
                case .shortcuts: shortcutsTab
                case .history: historyTab
                case .privacy: privacyTab
                case .about: aboutTab
                }
            }
            .padding(DT.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var generalTab: some View {
        section("Startup") {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { newValue in
                    AutoLaunchService.shared.setEnabled(newValue)
                }
        }

        section("Clipboard sound") {
            Toggle("Play sound on copy", isOn: $clipboardSoundEnabled)

            Picker("Sound", selection: selectedClipboardSound) {
                ForEach(ClipboardSoundName.allCases, id: \.rawValue) { sound in
                    Text(sound.title).tag(sound)
                }
            }
            .pickerStyle(.menu)
            .disabled(!clipboardSoundEnabled)
        }
    }

    @ViewBuilder
    private var shortcutsTab: some View {
        section("Hotkeys") {
            KeyboardShortcuts.Recorder("Toggle Clipo", name: ShortcutName.togglePopup)
            KeyboardShortcuts.Recorder("Open paste picker", name: ShortcutName.openPastePicker)
            KeyboardShortcuts.Recorder("Screen extension toggle", name: ShortcutName.screenExtensionTogglePopup)
            KeyboardShortcuts.Recorder("Screen extension paste picker", name: ShortcutName.screenExtensionOpenPastePicker)
            KeyboardShortcuts.Recorder("Pause / resume history", name: ShortcutName.pauseToggle)
        }

        section("Quick paste") {
            KeyboardShortcuts.Recorder("Paste item 1", name: ShortcutName.quickPaste1)
            KeyboardShortcuts.Recorder("Paste item 2", name: ShortcutName.quickPaste2)
            KeyboardShortcuts.Recorder("Paste item 3", name: ShortcutName.quickPaste3)
            KeyboardShortcuts.Recorder("Paste item 4", name: ShortcutName.quickPaste4)
            KeyboardShortcuts.Recorder("Paste item 5", name: ShortcutName.quickPaste5)
            KeyboardShortcuts.Recorder("Paste item 6", name: ShortcutName.quickPaste6)
            KeyboardShortcuts.Recorder("Paste item 7", name: ShortcutName.quickPaste7)
            KeyboardShortcuts.Recorder("Paste item 8", name: ShortcutName.quickPaste8)
            KeyboardShortcuts.Recorder("Paste item 9", name: ShortcutName.quickPaste9)

            Text("Quick paste copies the Nth most recent item to your clipboard. Paste manually with ⌘V.")
                .font(.system(size: 11))
                .foregroundColor(DT.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var historyTab: some View {
        section("Monitoring") {
            Toggle("Pause history collection", isOn: Binding(
                get: { isPaused },
                set: { isPaused = $0 }
            ))

            Text("When paused, anything you copy stays on the system clipboard but is not added to Clipo history.")
                .font(.system(size: 11))
                .foregroundColor(DT.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }

        section("Auto-delete") {
            Picker("Auto-delete after", selection: retentionPolicyBinding) {
                ForEach(HistoryRetentionPolicy.allCases, id: \.rawValue) { policy in
                    Text(policy.title).tag(policy)
                }
            }
            .pickerStyle(.menu)

            Text("Pinned items are kept and are not auto-deleted.")
                .font(.system(size: 11))
                .foregroundColor(DT.Color.textSecondary)
        }
    }

    @ViewBuilder
    private var privacyTab: some View {
        section("Accessibility") {
            Label(
                isAccessibilityTrusted ? "Enabled" : "Not enabled",
                systemImage: isAccessibilityTrusted ? "checkmark.shield.fill" : "exclamationmark.triangle.fill"
            )
            .foregroundColor(isAccessibilityTrusted ? DT.Color.accent : DT.Color.warning)

            Text("Required to auto-paste into other apps. Without it, Clipo copies the item to your clipboard so you can paste manually.")
                .font(.system(size: 11))
                .foregroundColor(DT.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if !isAccessibilityTrusted {
                Button("Open Accessibility Settings") {
                    if let viewModel {
                        viewModel.openAccessibilitySettings()
                    } else {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    @ViewBuilder
    private var aboutTab: some View {
        section("Clipo") {
            row("Version", "v2.0.0 (build 3)")
            row("License", "MIT")
        }

        section("Resources") {
            linkRow("Releases", url: "https://github.com/bloodstalk1/Clipo/releases", icon: "arrow.up.forward.app")
            linkRow("Source on GitHub", url: "https://github.com/bloodstalk1/Clipo", icon: "chevron.left.forwardslash.chevron.right")
        }
    }

    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: DT.Spacing.s) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(DT.Color.textSecondary)
                .textCase(.uppercase)
            content()
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(DT.Color.textSecondary)
            Spacer()
            Text(value)
                .foregroundColor(DT.Color.textPrimary)
        }
    }

    private func linkRow(_ label: String, url: String, icon: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack {
                Label(label, systemImage: icon)
                    .foregroundColor(DT.Color.textPrimary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(DT.Color.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var selectedClipboardSound: Binding<ClipboardSoundName> {
        Binding(
            get: { ClipboardSoundName(rawValue: clipboardSoundNameRawValue) ?? .glass },
            set: { clipboardSoundNameRawValue = $0.rawValue }
        )
    }
}
