import KeyboardShortcuts
import SwiftUI

struct ClipboardPopupView: View {
    private enum Appearance {
        static let sectionCornerRadius: CGFloat = 14
        static let rowCornerRadius: CGFloat = 16
    }

    @ObservedObject var viewModel: ClipboardPopupViewModel
    let style: ClipboardPopupStyle
    @State private var isShowingClearHistoryConfirmation = false
    @State private var showingSettings = false
    @FocusState private var isSearchFocused: Bool
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage(ClipboardSoundPreference.enabledStorageKey) private var clipboardSoundEnabled = true
    @AppStorage(ClipboardSoundPreference.nameStorageKey) private var clipboardSoundNameRawValue = ClipboardSoundName.glass.rawValue
    @State private var isVisible = false

    var body: some View {
        Group {
            if showingSettings {
                settingsView
            } else {
                mainViewWithToast
            }
        }
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous))
        .scaleEffect(isVisible ? 1.0 : 0.95)
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(.popupEntrance, value: isVisible)
        .onAppear {
            isVisible = true
        }
    }

    private var mainViewWithToast: some View {
        ZStack(alignment: .top) {
            mainView

            if let toast = viewModel.toastManagerForView.currentToast {
                ToastView(toast: toast)
                    .padding(.top, 16)
                    .transition(ToastView.slideInTransition)
                    .zIndex(1)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(toast.message)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.toastManagerForView.currentToast?.id)
    }

    private var mainView: some View {
        ZStack {
            VStack(spacing: 14) {
                headerView

                if !viewModel.isAccessibilityTrusted {
                    permissionBanner
                }

                listContainer

                footerActions
            }
            .padding(14)
            .frame(width: 420, height: 500)

            KeyboardEventHandlingView { eventData async in
                let shouldFocusSearch = await KeyboardNavigationHandler.handleKeyEvent(
                    eventData,
                    viewModel: viewModel,
                    currentSearchFocused: isSearchFocused,
                    popupDismisser: viewModel.popupDismisser
                )
                if let newFocusState = shouldFocusSearch {
                    isSearchFocused = newFocusState
                }
                return true
            }
            .frame(width: 0, height: 0)
        }
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

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Clipo")
                        .font(.system(size: 15, weight: .semibold))

                    Text(summaryText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .background(controlBackgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Search clipboard...", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                        .focused($isSearchFocused)
                        .onSubmit { Task { await viewModel.applySearch() } }
                        .onChange(of: viewModel.searchText) { _ in
                            Task { await viewModel.applySearch() }
                        }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(searchBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(searchBorderColor, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                if let shortcut = ShortcutName.togglePopup.shortcut {
                    Text(shortcutLabel(for: shortcut))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .background(controlBackgroundColor)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(12)
        .background(headerBackgroundColor)
        .overlay(headerOverlay)
        .clipShape(RoundedRectangle(cornerRadius: Appearance.sectionCornerRadius, style: .continuous))
    }

    private var permissionBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text("Auto-paste needs Accessibility access")
                    .font(.subheadline.weight(.semibold))
                Text("Enable to paste back into other apps.")
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
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.yellow.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var listContainer: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if viewModel.visibleItems.isEmpty {
                    emptyState
                } else {
                    ForEach(Array(viewModel.visibleItems.enumerated()), id: \.element.id) { index, item in
                        HStack(alignment: .top, spacing: 8) {
                            Button {
                                Task { await viewModel.activateItem(at: index) }
                            } label: {
                                ClipboardRowView(
                                    item: item,
                                    isSelected: index == viewModel.selectedIndex,
                                    style: style
                                )
                            }
                            .buttonStyle(.plain)

                            Button {
                                Task { await viewModel.deleteItem(at: index) }
                            } label: {
                                Image(systemName: "trash")
                                    .frame(width: 30, height: 30)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.secondary)
                            .background(Color.primary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }
            }
            .padding(12)
        }
        .background(listBackgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: Appearance.rowCornerRadius, style: .continuous)
                .stroke(listBorderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Appearance.rowCornerRadius, style: .continuous))
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.secondary)

            Text(viewModel.searchText.isEmpty ? "Clipboard history is empty" : "No results found")
                .font(.subheadline.weight(.medium))

            Text(viewModel.searchText.isEmpty ? "Copy something to see it here." : "Try a different keyword.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private var footerActions: some View {
        HStack(spacing: 10) {
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
        .padding(.horizontal, 4)
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
                        KeyboardShortcuts.Recorder("Screen extension toggle", name: ShortcutName.screenExtensionTogglePopup)
                        KeyboardShortcuts.Recorder("Screen extension paste picker", name: ShortcutName.screenExtensionOpenPastePicker)
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
                        Text("Clipo v2.0.0")
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

    private var summaryText: String {
        "\(viewModel.visibleItems.count) item\(viewModel.visibleItems.count == 1 ? "" : "s") ready"
    }

    private func shortcutLabel(for shortcut: KeyboardShortcuts.Shortcut) -> String {
        shortcut.description
    }

    @ViewBuilder
    private var panelBackground: some View {
        if style.usesNativePopoverBackground {
            NativePopoverBackgroundView()
        } else {
            LiquidGlassMaterial(cornerRadius: style.cornerRadius)
        }
    }

    private var headerBackgroundColor: Color {
        style == .anchoredToMenuBar ? Color.clear : Color.white.opacity(0.08)
    }

    @ViewBuilder
    private var headerOverlay: some View {
        if style == .anchoredToMenuBar {
            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(height: 1)
                .frame(maxHeight: .infinity, alignment: .bottom)
        } else {
            RoundedRectangle(cornerRadius: Appearance.sectionCornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var controlBackgroundColor: Color {
        style == .anchoredToMenuBar ? Color.black.opacity(0.06) : Color.primary.opacity(0.06)
    }

    private var searchBackgroundColor: Color {
        style == .anchoredToMenuBar ? Color.black.opacity(0.05) : Color.primary.opacity(0.05)
    }

    private var searchBorderColor: Color {
        style == .anchoredToMenuBar ? Color.black.opacity(0.08) : Color.white.opacity(0.08)
    }

    private var listBackgroundColor: Color {
        style == .anchoredToMenuBar ? Color.black.opacity(0.04) : Color.black.opacity(0.08)
    }

    private var listBorderColor: Color {
        style == .anchoredToMenuBar ? Color.black.opacity(0.08) : Color.white.opacity(0.06)
    }
}
