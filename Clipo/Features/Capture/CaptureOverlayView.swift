import SwiftUI
import AVFoundation

struct CaptureOverlayView: View {
    let screen: NSScreen
    let screenImage: NSImage
    let windows: [WindowInfo]
    let mode: CaptureMode
    let onCaptured: (NSImage) -> Void
    let onRecordStart: (CGRect, Bool, Bool) -> Void
    let onCancelled: () -> Void

    @State private var startPoint: CGPoint? = nil
    @State private var currentPoint: CGPoint? = nil
    @State private var hoveredWindow: WindowInfo? = nil
    @State private var mousePosition: CGPoint = .zero
    @State private var isSelected = false
    @State private var includeMic = false
    @State private var includeSystemAudio = false
    @State private var permissionDeniedMessage: String? = nil

    private var screenFrame: CGRect {
        screen.frame
    }

    private var currentSelectionRect: CGRect? {
        if let start = startPoint, let current = currentPoint {
            return CGRect(
                x: min(start.x, current.x),
                y: min(start.y, current.y),
                width: max(1, abs(start.x - current.x)),
                height: max(1, abs(start.y - current.y))
            )
        }
        if let hoveredWindow = hoveredWindow {
            // Convert CG coordinates (origin top-left) to AppKit coordinates (origin bottom-left)
            // relative to the current screen frame.
            let globalCGFrame = hoveredWindow.bounds
            // Convert CG global to CG local to this screen
            let localX = globalCGFrame.origin.x - screenFrame.origin.x
            let localY = globalCGFrame.origin.y - (NSScreen.screens.first?.frame.height ?? 0 - screenFrame.origin.y - screenFrame.height)
            
            return CGRect(
                x: localX,
                y: screenFrame.height - localY - globalCGFrame.height,
                width: globalCGFrame.width,
                height: globalCGFrame.height
            )
        }
        return nil
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Background screen screenshot
                Image(nsImage: screenImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)

                // Dimmed overlay with selection carved out
                Color.black.opacity(0.4)
                    .mask(
                        OverlayMaskShape(selectionRect: currentSelectionRect)
                            .fill(style: FillStyle(eoFill: true))
                    )

                // Draw border around the active selection
                if let selection = currentSelectionRect {
                    let isDragging = startPoint != nil
                    RoundedRectangle(cornerRadius: isDragging ? 0 : 4)
                        .stroke(DT.Color.accent, lineWidth: isDragging ? 1.5 : 2.5)
                        .frame(width: selection.width, height: selection.height)
                        .position(x: selection.midX, y: geometry.size.height - selection.midY)
                        .shadow(color: Color.black.opacity(0.3), radius: 4)

                    // Dimension label
                    Text("\(Int(selection.width)) × \(Int(selection.height))")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(DT.Color.accent)
                        .cornerRadius(4)
                        .position(
                            x: min(max(selection.midX, 50), geometry.size.width - 50),
                            y: geometry.size.height - (selection.maxY + 15) > 10 ?
                                geometry.size.height - (selection.maxY + 15) :
                                geometry.size.height - (selection.minY - 15)
                        )
                }

                // Window Owner Name Badge (when hovering over a window)
                if startPoint == nil, !isSelected, let window = hoveredWindow, let selection = currentSelectionRect {
                    HStack(spacing: 4) {
                        Image(systemName: "window.rectangle")
                            .font(.system(size: 10))
                        Text(window.ownerName)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(DT.Color.surface)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DT.Color.accent)
                    .cornerRadius(6)
                    .position(
                        x: min(max(selection.minX + 50, 60), geometry.size.width - 60),
                        y: geometry.size.height - selection.maxY + 15
                    )
                }

                // Help instructions pill at top center
                HStack(spacing: 8) {
                    let iconName: String = {
                        switch mode {
                        case .video: return "video.circle"
                        case .scrolling: return "arrow.up.and.down.circle"
                        default: return "camera.viewfinder"
                        }
                    }()
                    let helpText: String = {
                        switch mode {
                        case .video: return "Select video recording area. Esc to cancel."
                        case .scrolling: return "Select scrollable area to capture. Esc to cancel."
                        default: return "Click window or drag area to capture. Esc to cancel."
                        }
                    }()
                    Image(systemName: iconName)
                        .foregroundColor(DT.Color.accent)
                    Text(helpText)
                        .foregroundColor(DT.Color.textPrimary)
                }
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(DT.Color.surface.opacity(0.85))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(DT.Color.stroke, lineWidth: 1)
                )
                .position(x: geometry.size.width / 2, y: 40)

                // Magnifier Loupe near cursor
                if startPoint != nil {
                    MagnifierLoupeView(
                        image: screenImage,
                        mousePoint: mousePosition,
                        screenSize: geometry.size
                    )
                    .position(
                        x: mousePosition.x + 80 > geometry.size.width ? mousePosition.x - 80 : mousePosition.x + 80,
                        y: geometry.size.height - (mousePosition.y + 80 > geometry.size.height ? mousePosition.y - 80 : mousePosition.y + 80)
                    )
                }

                // Floating Recording HUD (Video Mode or Scrolling Mode)
                if isSelected, let selection = currentSelectionRect {
                    if mode == .scrolling {
                        HStack(spacing: 14) {
                            Button {
                                Task { @MainActor in
                                    onCancelled()
                                    await CaptureScrollingService.shared.startScrollingCapture(rect: selection, on: screen)
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.up.and.down.circle.fill")
                                        .font(.system(size: 12))
                                    Text("Chụp cuộn")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(DT.Color.accent)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)

                            Button {
                                isSelected = false
                                onCancelled()
                            } label: {
                                Text("Cancel")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(DT.Color.textPrimary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(DT.Color.surfaceElevated.opacity(0.95))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(DT.Color.stroke, lineWidth: 1)
                        )
                        .position(
                            x: min(max(selection.midX, 100), geometry.size.width - 100),
                            y: geometry.size.height - (selection.minY - 30) > 10 ?
                                geometry.size.height - (selection.minY - 30) :
                                geometry.size.height - (selection.maxY + 30)
                        )
                    } else {
                        HStack(spacing: 14) {
                            Button {
                                requestPermissionsThenRecord(selection: selection)
                            } label: {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 8, height: 8)
                                    Text("Record")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.25))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.red, lineWidth: 1))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            
                            Toggle(isOn: $includeMic) {
                                Image(systemName: includeMic ? "mic.fill" : "mic.slash.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(includeMic ? DT.Color.accent : DT.Color.textSecondary)
                            }
                            .toggleStyle(.button)
                            .buttonStyle(.plain)
                            .help("Record microphone input")
                            
                            Toggle(isOn: $includeSystemAudio) {
                                Image(systemName: includeSystemAudio ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(includeSystemAudio ? DT.Color.accent : DT.Color.textSecondary)
                            }
                            .toggleStyle(.button)
                            .buttonStyle(.plain)
                            .help("Record system audio")
                            
                            Button {
                                isSelected = false
                                onCancelled()
                            } label: {
                                Text("Cancel")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(DT.Color.textPrimary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(DT.Color.surfaceElevated.opacity(0.95))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(DT.Color.stroke, lineWidth: 1)
                        )
                        .position(
                            x: min(max(selection.midX, 100), geometry.size.width - 100),
                            y: geometry.size.height - (selection.minY - 30) > 10 ?
                                geometry.size.height - (selection.minY - 30) :
                                geometry.size.height - (selection.maxY + 30)
                        )
                    }
                }

                // Transparent mouse tracking overlay
                if !isSelected {
                    MouseTrackingView(
                        onMouseDown: { point in
                            startPoint = point
                            currentPoint = point
                            mousePosition = point
                        },
                        onMouseDragged: { point in
                            currentPoint = point
                            mousePosition = point
                        },
                        onMouseUp: { point in
                            mousePosition = point
                            
                            guard let rect = currentSelectionRect, rect.width > 2 && rect.height > 2 else {
                                if let window = hoveredWindow {
                                    let windowRect = convertCGToAppKit(rect: window.bounds)
                                    hoveredWindow = window
                                    startPoint = nil
                                    currentPoint = nil
                                    if mode == .video || mode == .scrolling {
                                        isSelected = true
                                    } else {
                                        if let cropped = crop(screenImage, rect: windowRect) {
                                            onCaptured(cropped)
                                        } else {
                                            onCancelled()
                                        }
                                    }
                                } else {
                                    onCancelled()
                                }
                                return
                            }
                            
                            if mode == .video || mode == .scrolling {
                                isSelected = true
                            } else {
                                if let cropped = crop(screenImage, rect: rect) {
                                    onCaptured(cropped)
                                } else {
                                    onCancelled()
                                }
                                startPoint = nil
                                currentPoint = nil
                            }
                        },
                        onMouseMoved: { point in
                            mousePosition = point
                            if startPoint == nil {
                                // Find window under mouse
                                // Convert mouse point from AppKit (origin bottom-left) to CG coordinates (origin top-left)
                                // CG coordinates are relative to the main display origin.
                                let cgPoint = CGPoint(
                                    x: screenFrame.origin.x + point.x,
                                    y: (NSScreen.screens.first?.frame.height ?? 0) - (screenFrame.origin.y + point.y)
                                )
                                hoveredWindow = WindowDetector.findWindow(at: cgPoint, in: windows)
                            }
                        }
                    )
                }
            }
        }
        .frame(width: screenFrame.width, height: screenFrame.height)
    }

    /// Crops the NSImage to the specified AppKit rect.
    private func crop(_ image: NSImage, rect: CGRect) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        let scaleX = imageWidth / screenFrame.width
        let scaleY = imageHeight / screenFrame.height

        // CG coordinates: origin top-left, y increases down
        let cropRect = CGRect(
            x: rect.origin.x * scaleX,
            y: (screenFrame.height - rect.origin.y - rect.size.height) * scaleY,
            width: rect.size.width * scaleX,
            height: rect.size.height * scaleY
        )

        guard let croppedCg = cgImage.cropping(to: cropRect) else { return nil }
        return NSImage(cgImage: croppedCg, size: rect.size)
    }

    private func convertCGToAppKit(rect: CGRect) -> NSRect {
        let rootScreenHeight = NSScreen.screens.first?.frame.height ?? 0
        let localX = rect.origin.x - screenFrame.origin.x
        let localY = rect.origin.y - (rootScreenHeight - screenFrame.origin.y - screenFrame.height)
        return NSRect(
            x: localX,
            y: screenFrame.height - localY - rect.size.height,
            width: rect.size.width,
            height: rect.size.height
        )
    }

    /// Requests microphone permission (if toggled on) then starts recording.
    /// This prevents TCC crashes from accessing AVCaptureDevice without authorization.
    private func requestPermissionsThenRecord(selection: CGRect) {
        guard includeMic else {
            // No mic needed — start immediately
            onRecordStart(selection, false, includeSystemAudio)
            return
        }

        let currentStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        switch currentStatus {
        case .authorized:
            onRecordStart(selection, true, includeSystemAudio)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    if granted {
                        onRecordStart(selection, true, includeSystemAudio)
                    } else {
                        permissionDeniedMessage = "Microphone access was denied. Recording without microphone."
                        onRecordStart(selection, false, includeSystemAudio)
                    }
                }
            }
        case .denied, .restricted:
            // Fall back gracefully — record without microphone
            permissionDeniedMessage = "Microphone access is denied in System Settings. Recording without microphone."
            onRecordStart(selection, false, includeSystemAudio)
        @unknown default:
            onRecordStart(selection, false, includeSystemAudio)
        }
    }
}


// MARK: - Masks and Shapes

struct OverlayMaskShape: Shape {
    let selectionRect: CGRect?

    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Entire display bounds
        path.addRect(rect)
        // Selection rect cut out
        if let sel = selectionRect {
            path.addRect(sel)
        }
        return path
    }
}

// MARK: - Magnifier Loupe

struct MagnifierLoupeView: View {
    let image: NSImage
    let mousePoint: CGPoint // AppKit coords (bottom-left relative to screen)
    let screenSize: CGSize

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: image)
                .resizable()
                .frame(width: screenSize.width, height: screenSize.height)
                // Offset the image so the mousePoint is centered in the magnifier
                .offset(
                    x: screenSize.width / 2 - mousePoint.x,
                    y: -(screenSize.height / 2 - mousePoint.y)
                )
                .scaleEffect(5.0) // 5x Zoom
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .overlay(Circle().stroke(DT.Color.accent, lineWidth: 2))
                .overlay(
                    // Crosshair lines
                    ZStack {
                        Path { path in
                            path.move(to: CGPoint(x: 60, y: 0))
                            path.addLine(to: CGPoint(x: 60, y: 120))
                            path.move(to: CGPoint(x: 0, y: 60))
                            path.addLine(to: CGPoint(x: 120, y: 60))
                        }
                        .stroke(Color.red.opacity(0.6), lineWidth: 1)
                        
                        Circle()
                            .stroke(Color.red.opacity(0.6), lineWidth: 1)
                            .frame(width: 8, height: 8)
                    }
                )
                .background(Circle().fill(Color.black.opacity(0.5)))
                .shadow(radius: 5)
        }
    }
}
