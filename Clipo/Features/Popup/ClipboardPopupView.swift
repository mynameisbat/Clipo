import KeyboardShortcuts
import SwiftUI

struct ClipboardPopupView: View {
    @ObservedObject var viewModel: ClipboardPopupViewModel
    @State private var isShowingClearHistoryConfirmation = false
    @State private var showingSettings = false
    @FocusState private var isSearchFocused: Bool
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage(ClipboardSoundPreference.enabledStorageKey) private var clipboardSoundEnabled = true
    @AppStorage(ClipboardSoundPreference.nameStorageKey) private var clipboardSoundNameRawValue = ClipboardSoundName.glass.rawValue

    var body: some View {
        if showingSettings {
            settingsView
        } else {
            mainView
        }
    }

    private var mainView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                TextField("Search clipboard...", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                    .focused($isSearchFocused)
                    .onSubmit { Task { await viewModel.applySearch() } }
                    .onChange(of: viewModel.searchText) { _ in
                        Task { await viewModel.applySearch() }
                    }

                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if !viewModel.isAccessibilityTrusted {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Auto-paste needs Accessibility access")
                            .font(.subheadline.weight(.semibold))
                        Text("Enable to auto-paste items.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Enable") {
                        viewModel.openAccessibilitySettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(12)
                .background(Color.yellow.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(Array(viewModel.visibleItems.enumerated()), id: \.element.id) { index, item in
                        HStack(alignment: .top, spacing: 8) {
                            Button {
                                Task { await viewModel.activateItem(at: index) }
                            } label: {
                                ClipboardRowView(item: item, isSelected: index == viewModel.selectedIndex)
                            }
                            .buttonStyle(.plain)

                            Button {
                                Task { await viewModel.deleteItem(at: index) }
                            } label: {
                                Image(systemName: "trash")
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(.secondary)
                        }
                    }
                }
            }

            HStack {
                Button("Clear History") {
                    isShowingClearHistoryConfirmation = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button("Quit") {
                    viewModel.quitApp()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(16)
        .frame(width: 420, height: 500)
        .task { await viewModel.load() }
        .onAppear {
            Task { await viewModel.refresh() }
        }
        .alert("Clear non-pinned history?", isPresented: $isShowingClearHistoryConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                Task { await viewModel.clearHistory() }
            }
        } message: {
            Text("Pinned items will be kept.")
        }
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            isSearchFocused = true
        }
    }

    private var settingsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack {
                Text("Settings")
                    .font(.headline)

                HStack {
                    Button {
                        showingSettings = false
                    } label: {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .buttonStyle(.borderless)

                    Spacer()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("General")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Toggle("Launch at login", isOn: $launchAtLogin)
                            .onChange(of: launchAtLogin) { newValue in
                                AutoLaunchService.shared.setEnabled(newValue)
                            }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Permissions")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Label(
                            viewModel.isAccessibilityTrusted ? "Accessibility enabled" : "Accessibility disabled",
                            systemImage: viewModel.isAccessibilityTrusted ? "checkmark.shield" : "exclamationmark.triangle"
                        )
                        .foregroundColor(viewModel.isAccessibilityTrusted ? .green : .orange)

                        if !viewModel.isAccessibilityTrusted {
                            Button("Open Accessibility Settings") {
                                viewModel.openAccessibilitySettings()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Shortcuts")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        KeyboardShortcuts.Recorder("Toggle Clipo", name: ShortcutName.togglePopup)
                        KeyboardShortcuts.Recorder("Open paste picker", name: ShortcutName.openPastePicker)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("History")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Picker("Auto-delete after", selection: $viewModel.historyRetentionPolicy) {
                            ForEach(HistoryRetentionPolicy.allCases, id: \.rawValue) { policy in
                                Text(policy.title).tag(policy)
                            }
                        }
                        .pickerStyle(.menu)

                        Text("Pinned items are kept and are not auto-deleted.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Clipboard sound")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Toggle("Play sound on copy", isOn: $clipboardSoundEnabled)

                        Picker("Sound", selection: selectedClipboardSound) {
                            ForEach(ClipboardSoundName.allCases, id: \.rawValue) { sound in
                                Text(sound.title).tag(sound)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(!clipboardSoundEnabled)
                    }

                    HStack {
                        Spacer()
                        Text("Clipo v1.0.1")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 420, height: 500)
    }

    private var selectedClipboardSound: Binding<ClipboardSoundName> {
        Binding(
            get: { ClipboardSoundName(rawValue: clipboardSoundNameRawValue) ?? .glass },
            set: { clipboardSoundNameRawValue = $0.rawValue }
        )
    }
}
