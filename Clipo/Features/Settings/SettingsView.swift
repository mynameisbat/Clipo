import KeyboardShortcuts
import SwiftUI
import UniformTypeIdentifiers

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case shortcuts
    case history
    case pinboards
    case privacy
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .shortcuts: return "Shortcuts"
        case .history: return "History"
        case .pinboards: return "Pinboards"
        case .privacy: return "Privacy"
        case .about: return "About"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .shortcuts: return "keyboard"
        case .history: return "clock.arrow.circlepath"
        case .pinboards: return "folder"
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
    @AppStorage("clipo.pinboards") private var pinboardsStorage: String = "Templates,Emails,Code"

    // Recording Preferences
    @AppStorage("clipo.recording.videoFps") private var videoFps = 30
    @AppStorage("clipo.recording.gifFps") private var gifFps = 12
    @AppStorage("clipo.recording.gifScale") private var gifScale = 1.0

    @State private var ignoredBundleIds: [String] = []
    @State private var newIgnoredBundleId: String = ""
    @State private var runningApps: [RunningAppInfo] = []
    @State private var newPinboardName: String = ""

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
        HStack(spacing: DT.Spacing.xxs) {
            ForEach(SettingsTab.allCases) { tab in
                Button {
                    withAnimation(.quickFeedback) {
                        selectedTabRaw = tab.rawValue
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .medium))
                        Text(tab.title)
                            .font(.system(size: 10, weight: selectedTab == tab ? .semibold : .medium, design: .rounded))
                    }
                    .foregroundColor(selectedTab == tab ? DT.Color.accent : DT.Color.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: Appearance.tabBarHeight - 4)
                    .background(
                        RoundedRectangle(cornerRadius: DT.Radius.s, style: .continuous)
                            .fill(selectedTab == tab ? DT.Color.accentMuted : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DT.Radius.s, style: .continuous)
                            .stroke(selectedTab == tab ? DT.Color.accent.opacity(0.18) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DT.Spacing.s)
        .padding(.vertical, DT.Spacing.xs)
        .background(DT.Color.surface.opacity(0.3))
    }

    @ViewBuilder
    private var tabContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DT.Spacing.l) {
                switch selectedTab {
                case .general: generalTab
                case .shortcuts: shortcutsTab
                case .history: historyTab
                case .pinboards: pinboardsTab
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

        section("Screen Recording") {
            Picker("Video Capture Frame Rate", selection: $videoFps) {
                Text("24 fps").tag(24)
                Text("30 fps (Default)").tag(30)
                Text("60 fps (High)").tag(60)
            }
            .pickerStyle(.menu)
            
            Picker("GIF Export Frame Rate", selection: $gifFps) {
                Text("10 fps").tag(10)
                Text("12 fps (Default)").tag(12)
                Text("15 fps").tag(15)
                Text("20 fps").tag(20)
            }
            .pickerStyle(.menu)
            
            Picker("GIF Resolution Scale", selection: $gifScale) {
                Text("50% (Compact size)").tag(0.5)
                Text("75% (Medium size)").tag(0.75)
                Text("100% (Full size)").tag(1.0)
            }
            .pickerStyle(.menu)
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
            KeyboardShortcuts.Recorder("Sequential Paste (Paste Stack)", name: ShortcutName.sequentialPaste)
            KeyboardShortcuts.Recorder("Capture screen", name: ShortcutName.screenCapture)
            KeyboardShortcuts.Recorder("Record screen", name: ShortcutName.screenRecording)
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
        VStack(alignment: .leading, spacing: DT.Spacing.l) {
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

            section("Backup & Restore") {
                Text("Export all your clipboard history (including pinned items, collections, and image assets) to a single '.clipobackup' archive, or restore from a previous backup.")
                    .font(.system(size: 11))
                    .foregroundColor(DT.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: DT.Spacing.m) {
                    Button(action: exportBackupData) {
                        Label("Export Backup...", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: importBackupData) {
                        Label("Restore Backup...", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                }
            }

            section("Ignored Applications") {
                Text("Clipo will not monitor the clipboard when copying from these applications (e.g. password managers).")
                    .font(.system(size: 11))
                    .foregroundColor(DT.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if ignoredBundleIds.isEmpty {
                    Text("No applications ignored.")
                        .font(.system(size: 11).italic())
                        .foregroundColor(DT.Color.textSecondary)
                        .padding(.vertical, 2)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(ignoredBundleIds, id: \.self) { bundleId in
                                    HStack {
                                        Text(bundleId)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(DT.Color.textPrimary)
                                        Spacer()
                                        Button {
                                            removeIgnoredApp(bundleId)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(DT.Color.textSecondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                        .frame(height: 80)
                    }
                }

                HStack {
                    TextField("Add bundle ID (e.g. com.agilebits.onepassword)", text: $newIgnoredBundleId)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                    Button("Add") {
                        addIgnoredApp()
                    }
                    .controlSize(.small)
                    .disabled(newIgnoredBundleId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            if !runningApps.isEmpty {
                section("Running Applications (Suggestions)") {
                    Text("Click '+' next to a running application to ignore it.")
                        .font(.system(size: 11))
                        .foregroundColor(DT.Color.textSecondary)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(runningApps) { app in
                                HStack(spacing: 8) {
                                    if let icon = app.icon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .frame(width: 14, height: 14)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(app.name)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(DT.Color.textPrimary)
                                        Text(app.id)
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundColor(DT.Color.textSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Button {
                                        ignoreApp(app.id)
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(DT.Color.accent)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .frame(height: 100)
                }
            }
        }
        .onAppear {
            ignoredBundleIds = IgnoredAppsManager.shared.getIgnoredBundleIds()
            loadRunningApps()
        }
    }

    private var currentVersionString: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return "v\(version) (build \(build))"
        }
        return "v2.0.0 (build 3)"
    }

    @ViewBuilder
    private var aboutTab: some View {
        section("Clipo") {
            row("Version", currentVersionString)
            row("License", "MIT")
        }

        if let viewModel = viewModel {
            SoftwareUpdateSection(viewModel: viewModel)
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

    private func removeIgnoredApp(_ bundleId: String) {
        IgnoredAppsManager.shared.removeIgnoredBundleId(bundleId)
        ignoredBundleIds = IgnoredAppsManager.shared.getIgnoredBundleIds()
        loadRunningApps()
    }

    private func addIgnoredApp() {
        let cleaned = newIgnoredBundleId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        IgnoredAppsManager.shared.addIgnoredBundleId(cleaned)
        ignoredBundleIds = IgnoredAppsManager.shared.getIgnoredBundleIds()
        newIgnoredBundleId = ""
        loadRunningApps()
    }

    private func ignoreApp(_ bundleId: String) {
        IgnoredAppsManager.shared.addIgnoredBundleId(bundleId)
        ignoredBundleIds = IgnoredAppsManager.shared.getIgnoredBundleIds()
        loadRunningApps()
    }

    private func loadRunningApps() {
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> RunningAppInfo? in
                guard let bundleId = app.bundleIdentifier,
                      let name = app.localizedName else { return nil }
                return RunningAppInfo(id: bundleId, name: name, icon: app.icon)
            }
        
        let uniqueApps = Array(Set(apps)).sorted(by: { $0.name.lowercased() < $1.name.lowercased() })
        let currentIgnored = IgnoredAppsManager.shared.getIgnoredBundleIds()
        self.runningApps = uniqueApps.filter { !currentIgnored.contains($0.id) }
    }

    private var selectedClipboardSound: Binding<ClipboardSoundName> {
        Binding(
            get: { ClipboardSoundName(rawValue: clipboardSoundNameRawValue) ?? .glass },
            set: { clipboardSoundNameRawValue = $0.rawValue }
        )
    }

    @ViewBuilder
    private var pinboardsTab: some View {
        section("Manage Pinboards") {
            Text("Create custom collections to categorize your pinned clipboard items. These will show up in the inline filters and Action Menu (⌘K).")
                .font(.system(size: 11))
                .foregroundColor(DT.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            let pinboards = pinboardsStorage
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            if pinboards.isEmpty {
                Text("No custom pinboards created yet.")
                    .font(.system(size: 11).italic())
                    .foregroundColor(DT.Color.textSecondary)
                    .padding(.vertical, 2)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(pinboards, id: \.self) { name in
                                HStack {
                                    Label(name, systemImage: "folder.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(DT.Color.textPrimary)
                                    Spacer()
                                    Button {
                                        deletePinboard(name)
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundColor(DT.Color.textSecondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .frame(height: 140)
                    .padding(8)
                    .background(DT.Color.surfaceElevated.opacity(0.4))
                    .cornerRadius(DT.Radius.s)
                }
            }

            HStack {
                TextField("Add pinboard name (e.g. Snippets)", text: $newPinboardName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
                Button("Add") {
                    addPinboard()
                }
                .controlSize(.small)
                .disabled(newPinboardName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func addPinboard() {
        let cleaned = newPinboardName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        guard !cleaned.contains(",") else { return }
        
        var pinboards = pinboardsStorage
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            
        guard !pinboards.contains(cleaned) else { return }
        pinboards.append(cleaned)
        pinboardsStorage = pinboards.joined(separator: ",")
        newPinboardName = ""
        
        if let viewModel = viewModel {
            Task {
                await viewModel.load()
            }
        }
    }

    private func deletePinboard(_ name: String) {
        var pinboards = pinboardsStorage
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            
        pinboards.removeAll(where: { $0 == name })
        pinboardsStorage = pinboards.joined(separator: ",")
        
        if let appEnv = AppEnvironment.shared {
            Task {
                try? await appEnv.historyStore.removePinboard(named: name)
                if let viewModel = viewModel {
                    await viewModel.load()
                }
            }
        }
    }

    private func exportBackupData() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType(filenameExtension: "clipobackup")].compactMap { $0 }
        savePanel.nameFieldStringValue = "clipo_backup_\(dateStringForBackup())"
        savePanel.title = "Export Clipo Backup"
        
        savePanel.begin { response in
            if response == .OK, let destinationURL = savePanel.url {
                Task {
                    do {
                        try await BackupService.exportBackup(to: destinationURL)
                        if let viewModel = viewModel {
                            viewModel.toastManagerForView.show(.success("Backup exported successfully"))
                        }
                    } catch {
                        if let viewModel = viewModel {
                            viewModel.toastManagerForView.show(.error("Export failed: \(error.localizedDescription)"))
                        }
                    }
                }
            }
        }
    }

    private func importBackupData() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [UTType(filenameExtension: "clipobackup")].compactMap { $0 }
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.title = "Restore Clipo Backup"
        
        openPanel.begin { response in
            if response == .OK, let sourceURL = openPanel.url {
                Task {
                    do {
                        try await BackupService.importBackup(from: sourceURL)
                        
                        let alert = NSAlert()
                        alert.messageText = "Restore Successful"
                        alert.informativeText = "Your clipboard history and assets have been restored. Clipo will now close to reload the database."
                        alert.alertStyle = .informational
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                        
                        NSApplication.shared.terminate(nil)
                    } catch {
                        if let viewModel = viewModel {
                            viewModel.toastManagerForView.show(.error("Restore failed: \(error.localizedDescription)"))
                        }
                    }
                }
            }
        }
    }

    private func dateStringForBackup() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

struct RunningAppInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: NSImage?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: RunningAppInfo, rhs: RunningAppInfo) -> Bool {
        lhs.id == rhs.id
    }
}

struct SoftwareUpdateSection: View {
    @ObservedObject var viewModel: ClipboardPopupViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: DT.Spacing.s) {
            Text("Software Update")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(DT.Color.textSecondary)
                .textCase(.uppercase)
            
            HStack(spacing: DT.Spacing.m) {
                SoftwareUpdateButton(
                    action: {
                        Task {
                            await viewModel.checkForUpdatesManually()
                        }
                    },
                    isChecking: viewModel.isCheckingForUpdates
                )

                if viewModel.updateAvailable {
                    if let updateURL = viewModel.updateURL {
                        Button(action: {
                            NSWorkspace.shared.open(updateURL)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 12))
                                Text("Download new update")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(DT.Color.accent)
                            .underline()
                        }
                        .buttonStyle(.plain)
                    }
                } else if !viewModel.isCheckingForUpdates {
                    Text("Clipo is up to date.")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(DT.Color.textSecondary)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

struct SoftwareUpdateButton: View {
    let action: () -> Void
    let isChecking: Bool
    
    @State private var isHovered = false
    @State private var rotationDegrees: Double = 0
    
    var body: some View {
        Button(action: {
            if !isChecking {
                withAnimation(.linear(duration: 1).repeatCount(1, autoreverses: false)) {
                    rotationDegrees += 360
                }
                action()
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .bold))
                    .rotationEffect(.degrees(rotationDegrees))
                    .animation(isChecking ? .linear(duration: 1.2).repeatForever(autoreverses: false) : .default, value: rotationDegrees)
                
                Text(isChecking ? "Checking..." : "Check for Updates")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .foregroundColor(isHovered ? DT.Color.surface : DT.Color.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isHovered ? DT.Color.accent : DT.Color.accentMuted)
                    
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(DT.Color.accent.opacity(0.35), lineWidth: 1.5)
                }
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .shadow(color: DT.Color.accent.opacity(isHovered ? 0.25 : 0.0), radius: 6, x: 0, y: 2)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .disabled(isChecking)
    }
}
