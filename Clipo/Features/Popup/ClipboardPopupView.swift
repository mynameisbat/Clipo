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
        ZStack {
            Group {
                if showingSettings {
                    SettingsView(viewModel: viewModel)
                        .transition(.opacity)
                } else {
                    mainViewWithToast
                        .transition(.opacity)
                }
            }
            
            if viewModel.isQuickLookVisible, let selectedItem = viewModel.selectedItem {
                QuickLookPreviewView(item: selectedItem) {
                    viewModel.isQuickLookVisible = false
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal: .opacity.combined(with: .scale(scale: 0.95))
                ))
                .zIndex(2)
            }

            if viewModel.isActionMenuVisible, let selectedItem = viewModel.selectedItem {
                ActionMenuView(
                    title: selectedItem.title,
                    actions: viewModel.availableActions,
                    selectedIndex: viewModel.selectedActionIndex,
                    onSelect: { action in
                        Task { await viewModel.executeAction(action) }
                    },
                    onDismiss: {
                        viewModel.isActionMenuVisible = false
                    }
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal: .opacity.combined(with: .scale(scale: 0.95))
                ))
                .zIndex(3)
            }
        }
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous))
        .scaleEffect(isVisible ? 1.0 : 0.95)
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(.popupEntrance, value: isVisible)
        .animation(.quickFeedback, value: viewModel.isQuickLookVisible)
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
                FilterChipStrip(activeFilters: $viewModel.activeFilters, pinboards: viewModel.availablePinboards)
                    .frame(height: Appearance.filterStripHeight)
                    .background(DT.Color.stroke.opacity(0.20))

                if !viewModel.isAccessibilityTrusted {
                    permissionBanner
                }

                if viewModel.updateAvailable {
                    updateBanner
                }

                list

                if !viewModel.pasteStack.isEmpty {
                    pasteStackBar
                }

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
            VStack(alignment: .leading, spacing: 1) {
                Text("Clipo")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(DT.Color.textPrimary)

                Text(summaryText)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(DT.Color.textSecondary)
            }

            Spacer(minLength: DT.Spacing.xs)

            if let shortcut = ShortcutName.togglePopup.shortcut {
                Text(shortcutLabel(for: shortcut))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(DT.Color.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(DT.Color.stroke)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }

            captureButton

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

    private var captureButton: some View {
        Button {
            Task {
                await viewModel.popupDismisser?.dismiss()
                try? await Task.sleep(nanoseconds: 150_000_000) // 150ms
                CaptureService.shared.startCaptureFlow()
            }
        } label: {
            Image(systemName: "camera")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DT.Color.textSecondary)
                .frame(width: Appearance.controlSize, height: Appearance.controlSize)
                .background(controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: DT.Radius.s, style: .continuous))
        }
        .buttonStyle(.plain)
        .help("Capture screen (⌘⌥S)")
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
                .font(.system(size: 13, weight: .medium, design: .rounded))
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
        .frame(height: 32)
        .background(DT.Color.surfaceElevated.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: DT.Radius.s, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DT.Radius.s, style: .continuous)
                .stroke(isSearchFocused ? DT.Color.accent.opacity(0.3) : DT.Color.stroke, lineWidth: 1)
        )
        .padding(.horizontal, DT.Spacing.m)
        .padding(.vertical, DT.Spacing.s)
        .background(DT.Color.surface.opacity(0.2))
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

    private var updateBanner: some View {
        HStack(alignment: .top, spacing: DT.Spacing.s) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(DT.Color.accent)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text("New version available!")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DT.Color.textPrimary)
                if let version = viewModel.latestVersion {
                    Text("Version \(version) is ready to download.")
                        .font(.system(size: 11))
                        .foregroundColor(DT.Color.textSecondary)
                }
            }

            Spacer()

            HStack(spacing: DT.Spacing.xs) {
                Button("Dismiss") {
                    viewModel.dismissUpdateBanner()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(DT.Color.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(DT.Color.stroke)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                if let updateURL = viewModel.updateURL {
                    Button("Update") {
                        NSWorkspace.shared.open(updateURL)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(DT.Color.surface)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DT.Color.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
        }
        .padding(.horizontal, DT.Spacing.m)
        .padding(.vertical, DT.Spacing.s)
        .background(DT.Color.accent.opacity(0.10))
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
                                        searchText: viewModel.searchText,
                                        quickPasteHint: quickPasteHint(for: index),
                                        onTogglePin: { Task { await viewModel.togglePinned(at: index) } },
                                        onDelete: { Task { await viewModel.deleteItem(at: index) } },
                                        onCopyAsPlainText: { Task { await viewModel.copyAsPlainText(at: index) } },
                                        onEditImage: { Task { await viewModel.editImage(item) } },
                                        onExtractTextOCR: { Task { await viewModel.performOCR(on: item) } }
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
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isPaused ? DT.Color.warning : DT.Color.textSecondary)
                    .frame(width: Appearance.controlSize, height: Appearance.controlSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isPaused ? "Resume history (⌘T)" : "Pause history (⌘T)")

            Spacer()

            Button {
                isShowingClearHistoryConfirmation = true
            } label: {
                Image(systemName: "clock.badge.xmark")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DT.Color.textSecondary)
                    .frame(width: Appearance.controlSize, height: Appearance.controlSize)
                    .contentShape(Rectangle())
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
            .fill(DT.Color.surfaceElevated.opacity(0.8))
    }

    private var pasteStackBar: some View {
        HStack(spacing: DT.Spacing.s) {
            Image(systemName: "square.stack.3d.down.right.fill")
                .font(.system(size: 11))
                .foregroundColor(DT.Color.accent)
            
            Text("Paste Stack:")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(DT.Color.textPrimary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(viewModel.pasteStack.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 4) {
                            Text(item.title)
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundColor(DT.Color.textPrimary)
                                .lineLimit(1)
                                .frame(maxWidth: 80)
                            
                            Button {
                                viewModel.removeFromStack(at: index)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(DT.Color.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(DT.Color.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(DT.Color.stroke, lineWidth: 1)
                        )
                    }
                }
            }
            
            Spacer()
            
            Button {
                viewModel.clearStack()
            } label: {
                Text("Clear")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(DT.Color.danger)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DT.Spacing.m)
        .frame(height: 36)
        .background(DT.Color.surfaceElevated.opacity(0.4))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(DT.Color.stroke)
                .frame(height: 1)
        }
    }
}

struct QuickLookPreviewView: View {
    let item: ClipboardItem
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // Dark glass backdrop
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            VStack(spacing: 0) {
                // Header bar
                HStack {
                    Image(systemName: "eye.fill")
                        .foregroundColor(DT.Color.accent)
                        .font(.system(size: 11, weight: .semibold))
                    Text("Quick Look")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(DT.Color.textSecondary)
                    
                    Spacer()
                    
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(DT.Color.textSecondary)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, DT.Spacing.m)
                .frame(height: 36)
                .background(DT.Color.surfaceElevated)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(DT.Color.stroke)
                        .frame(height: 1)
                }
                
                // Content area
                ZStack {
                    DT.Color.surfaceElevated
                        .ignoresSafeArea()
                    
                    Group {
                        switch item.previewContent {
                        case let .text(text):
                            if let language = item.metadata.detectedLanguage, language != .unknown {
                                codePreview(text, language: language)
                            } else {
                                textPreview(text)
                            }
                        case let .image(url):
                            imagePreview(url)
                        case .none:
                            filePreview
                        }
                    }
                    .padding(DT.Spacing.m)
                }
            }
            .frame(width: 380, height: 420)
            .clipShape(RoundedRectangle(cornerRadius: DT.Radius.l, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DT.Radius.l, style: .continuous)
                    .stroke(DT.Color.stroke, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 16, x: 0, y: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func textPreview(_ text: String) -> some View {
        ScrollView {
            Text(text)
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(DT.Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
    }
    
    @ViewBuilder
    private func codePreview(_ text: String, language: CodeLanguage) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DT.Spacing.s) {
                HStack {
                    Text(language.displayName)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.indigo)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.indigo.opacity(0.12))
                        .clipShape(Capsule())
                    
                    Spacer()
                }
                
                Text(text)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(DT.Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    @ViewBuilder
    private func imagePreview(_ url: URL) -> some View {
        if url.isFileURL, let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: DT.Radius.s, style: .continuous))
        } else {
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: DT.Radius.s, style: .continuous))
                case .empty:
                    ProgressView()
                case .failure:
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundColor(DT.Color.textSecondary)
                @unknown default:
                    EmptyView()
                }
            }
        }
    }
    
    private var filePreview: some View {
        VStack(spacing: DT.Spacing.m) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 64, height: 64)
                
                Image(systemName: "doc.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Color.orange)
            }
            
            VStack(spacing: DT.Spacing.xxs) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(DT.Color.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                if let ext = item.metadata.fileExtension {
                    Text(ext.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(DT.Color.textSecondary)
                }
            }
        }
    }
}

struct ActionMenuView: View {
    let title: String
    let actions: [ClipboardAction]
    let selectedIndex: Int
    let onSelect: (ClipboardAction) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // Dark backdrop
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            VStack(spacing: 0) {
                // Header (title of the item we are performing actions on)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Actions")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(DT.Color.accent)
                        .textCase(.uppercase)
                    
                    Text(title)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(DT.Color.textPrimary)
                        .lineLimit(1)
                }
                .padding(.horizontal, DT.Spacing.m)
                .padding(.vertical, DT.Spacing.s)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DT.Color.surfaceElevated)
                
                Rectangle()
                    .fill(DT.Color.stroke)
                    .frame(height: 1)
                
                // Actions List
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                                actionRow(action: action, isSelected: index == selectedIndex)
                                    .id(action.id)
                                    .onTapGesture {
                                        onSelect(action)
                                    }
                            }
                        }
                        .padding(DT.Spacing.s)
                    }
                    .frame(maxHeight: 260)
                    .onChange(of: selectedIndex) { newIndex in
                        guard actions.indices.contains(newIndex) else { return }
                        withAnimation(.quickFeedback) {
                            proxy.scrollTo(actions[newIndex].id, anchor: .center)
                        }
                    }
                }
                
                Rectangle()
                    .fill(DT.Color.stroke)
                    .frame(height: 1)
                
                // Footer (hints)
                HStack {
                    Text("↑↓ to navigate")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(DT.Color.textSecondary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text("⏎")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(DT.Color.textSecondary)
                        Text("to execute")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundColor(DT.Color.textSecondary)
                    }
                }
                .padding(.horizontal, DT.Spacing.m)
                .frame(height: 28)
                .background(DT.Color.surfaceElevated)
            }
            .frame(width: 320)
            .background(DT.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: DT.Radius.l, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DT.Radius.l, style: .continuous)
                    .stroke(DT.Color.stroke, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.4), radius: 24, x: 0, y: 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func actionRow(action: ClipboardAction, isSelected: Bool) -> some View {
        HStack(spacing: DT.Spacing.s) {
            Image(systemName: action.icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isSelected ? DT.Color.accent : DT.Color.textSecondary)
                .frame(width: 16)
            
            Text(action.rawValue)
                .font(.system(size: 12, weight: isSelected ? .semibold : .medium, design: .rounded))
                .foregroundColor(isSelected ? DT.Color.textPrimary : DT.Color.textPrimary.opacity(0.8))
            
            Spacer()
            
            if let hint = action.shortcutHint {
                Text(hint)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(isSelected ? DT.Color.accent : DT.Color.textSecondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(isSelected ? DT.Color.accentMuted : Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            } else if isSelected {
                Text("⏎")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(DT.Color.accent)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(DT.Color.accentMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            }
        }
        .padding(.horizontal, DT.Spacing.s)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: DT.Radius.s, style: .continuous)
                .fill(isSelected ? DT.Color.accentMuted : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DT.Radius.s, style: .continuous)
                .stroke(isSelected ? DT.Color.accent.opacity(0.2) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}
