import KeyboardShortcuts
import SwiftUI

struct ClipboardPopupView: View {
    private enum Appearance {
        static let panelWidth: CGFloat = 420
        static let panelHeight: CGFloat = 520
        static let toolbarHeight: CGFloat = 40
        static let searchHeight: CGFloat = 44
        static let filterStripHeight: CGFloat = 36
        static let footerHeight: CGFloat = 32
        static let controlSize: CGFloat = 28
    }

    @ObservedObject var viewModel: ClipboardPopupViewModel
    let style: ClipboardPopupStyle
    @State private var isShowingClearHistoryConfirmation = false
    @State private var showingSettings = false
    @State private var isVisible = false
    @AppStorage("clipo.compactMode") private var isCompactMode = false
    @AppStorage("clipo.paused") private var isPaused = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        Group {
            if showingSettings {
                SettingsView(viewModel: viewModel)
                    .transition(.opacity)
            } else {
                mainViewWithToast
                    .transition(.opacity)
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
        .onChange(of: isPaused) { newValue in
            AppEnvironment.shared?.setMonitoringPaused(newValue)
        }
    }

    private var mainViewWithToast: some View {
        ZStack(alignment: .top) {
            mainView

            if let toast = viewModel.toastManagerForView.currentToast {
                ToastView(toast: toast)
                    .padding(.top, 12)
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
            VStack(spacing: 0) {
                toolbar
                searchField
                FilterChipStrip(activeFilters: $viewModel.activeFilters)
                    .frame(height: Appearance.filterStripHeight)
                    .background(DT.Color.stroke.opacity(0.20))

                if !viewModel.isAccessibilityTrusted {
                    permissionBanner
                }

                list

                footerActions
            }
            .frame(width: Appearance.panelWidth, height: Appearance.panelHeight)

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

    private var toolbar: some View {
        HStack(spacing: DT.Spacing.s) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Clipo")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DT.Color.textPrimary)

                Text(summaryText)
                    .font(.system(size: 10))
                    .foregroundColor(DT.Color.textSecondary)
            }

            Spacer(minLength: DT.Spacing.xs)

            if let shortcut = ShortcutName.togglePopup.shortcut {
                Text(shortcutLabel(for: shortcut))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(DT.Color.textSecondary)
                    .padding(.horizontal, DT.Spacing.xs)
                    .padding(.vertical, 4)
                    .background(controlBackground)
                    .clipShape(Capsule())
            }

            compactToggle

            settingsButton
        }
        .padding(.horizontal, DT.Spacing.m)
        .frame(height: Appearance.toolbarHeight)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DT.Color.stroke)
                .frame(height: 1)
        }
    }

    private var compactToggle: some View {
        Button {
            isCompactMode.toggle()
        } label: {
            Image(systemName: isCompactMode ? "rectangle.expand.vertical" : "rectangle.compress.vertical")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DT.Color.textSecondary)
                .frame(width: Appearance.controlSize, height: Appearance.controlSize)
                .background(controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: DT.Radius.s, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(isCompactMode ? "Show previews" : "Hide previews")
    }

    private var settingsButton: some View {
        Button {
            withAnimation(.quickFeedback) {
                showingSettings = true
            }
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DT.Color.textSecondary)
                .frame(width: Appearance.controlSize, height: Appearance.controlSize)
                .background(controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: DT.Radius.s, style: .continuous))
        }
        .buttonStyle(.plain)
        .help("Settings")
    }

    private var searchField: some View {
        HStack(spacing: DT.Spacing.s) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DT.Color.textSecondary)

            TextField("Search clipboard...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(DT.Color.textPrimary)
                .focused($isSearchFocused)
                .onSubmit { Task { await viewModel.applySearch() } }
                .onChange(of: viewModel.searchText) { _ in
                    Task { await viewModel.applySearch() }
                }

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(DT.Color.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DT.Spacing.m)
        .frame(height: Appearance.searchHeight)
        .background(DT.Color.stroke.opacity(0.4))
    }

    private var permissionBanner: some View {
        HStack(alignment: .top, spacing: DT.Spacing.s) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundColor(DT.Color.warning)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text("Auto-paste needs Accessibility access")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DT.Color.textPrimary)
                Text("Enable to paste back into other apps.")
                    .font(.system(size: 11))
                    .foregroundColor(DT.Color.textSecondary)
            }

            Spacer()

            Button("Enable") {
                viewModel.openAccessibilitySettings()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, DT.Spacing.m)
        .padding(.vertical, DT.Spacing.s)
        .background(DT.Color.warning.opacity(0.10))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DT.Color.stroke)
                .frame(height: 1)
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: DT.Spacing.s) {
                    if viewModel.visibleItems.isEmpty {
                        EmptyStateView(searchText: viewModel.searchText)
                    } else {
                        ForEach(Array(viewModel.visibleItems.enumerated()), id: \.element.id) { index, item in
                            HStack(alignment: .top, spacing: DT.Spacing.xs) {
                                Button {
                                    Task { await viewModel.activateItem(at: index) }
                                } label: {
                                    ClipboardRowView(
                                        item: item,
                                        isSelected: index == viewModel.selectedIndex,
                                        isCompact: isCompactMode,
                                        style: style,
                                        quickPasteHint: quickPasteHint(for: index),
                                        onTogglePin: { Task { await viewModel.togglePinned(at: index) } },
                                        onDelete: { Task { await viewModel.deleteItem(at: index) } },
                                        onCopyAsPlainText: { Task { await viewModel.copyAsPlainText(at: index) } }
                                    )
                                }
                                .buttonStyle(.plain)

                                if !isCompactMode {
                                    Button {
                                        Task { await viewModel.deleteItem(at: index) }
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(DT.Color.textSecondary)
                                            .frame(width: Appearance.controlSize, height: Appearance.controlSize)
                                            .background(controlBackground)
                                            .clipShape(RoundedRectangle(cornerRadius: DT.Radius.s, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Delete")
                                }
                            }
                            .id(item.id)
                        }
                    }
                }
                .padding(DT.Spacing.m)
            }
            .onChange(of: viewModel.selectedIndex) { newIndex in
                guard viewModel.visibleItems.indices.contains(newIndex) else { return }
                withAnimation(.smoothSlide) {
                    proxy.scrollTo(viewModel.visibleItems[newIndex].id, anchor: .center)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footerActions: some View {
        HStack(spacing: DT.Spacing.s) {
            Button {
                isPaused.toggle()
            } label: {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isPaused ? DT.Color.warning : DT.Color.textSecondary)
                    .frame(width: Appearance.controlSize, height: Appearance.controlSize)
                    .background(controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: DT.Radius.s, style: .continuous))
                    .overlay(
                        Circle()
                            .fill(isPaused ? DT.Color.warning : Color.clear)
                            .frame(width: 6, height: 6)
                            .offset(x: 8, y: -8)
                    )
            }
            .buttonStyle(.plain)
            .help(isPaused ? "Resume history (⌘T)" : "Pause history (⌘T)")

            Spacer()

            Button {
                isShowingClearHistoryConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DT.Color.textSecondary)
                    .frame(width: Appearance.controlSize, height: Appearance.controlSize)
                    .background(controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: DT.Radius.s, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Clear non-pinned history")
        }
        .padding(.horizontal, DT.Spacing.m)
        .frame(height: Appearance.footerHeight)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(DT.Color.stroke)
                .frame(height: 1)
        }
    }

    private func quickPasteHint(for index: Int) -> String? {
        guard index < 9 else { return nil }
        return "⌘\(index + 1)"
    }

    private var summaryText: String {
        let count = viewModel.visibleItems.count
        let pausedSuffix = isPaused ? " · paused" : ""
        return "\(count) item\(count == 1 ? "" : "s")\(pausedSuffix)"
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

    private var controlBackground: some View {
        RoundedRectangle(cornerRadius: DT.Radius.s, style: .continuous)
            .fill(style == .anchoredToMenuBar ? Color.black.opacity(0.06) : Color.primary.opacity(0.06))
    }
}
