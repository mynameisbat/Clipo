import SwiftUI
import AppKit

enum CanvasBackgroundPreset: String, CaseIterable, Identifiable {
    case none = "None"
    case sunrise = "Sunrise"
    case sunset = "Sunset"
    case aurora = "Aurora"
    case ocean = "Ocean"
    case glass = "Glass"
    
    var id: String { rawValue }
    
    var gradient: LinearGradient? {
        switch self {
        case .none:
            return nil
        case .sunrise:
            return LinearGradient(
                colors: [Color(red: 1.0, green: 0.38, blue: 0.22), Color(red: 1.0, green: 0.18, blue: 0.45)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .sunset:
            return LinearGradient(
                colors: [Color(red: 0.18, green: 0.12, blue: 0.35), Color(red: 0.95, green: 0.43, blue: 0.46)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .aurora:
            return LinearGradient(
                colors: [Color(red: 0.05, green: 0.75, blue: 0.55), Color(red: 0.45, green: 0.15, blue: 0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .ocean:
            return LinearGradient(
                colors: [Color(red: 0.02, green: 0.08, blue: 0.22), Color(red: 0.08, green: 0.55, blue: 0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .glass:
            return LinearGradient(
                colors: [Color.white.opacity(0.12), Color.white.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct AnnotationElement: Identifiable, Equatable {
    let id = UUID()
    var tool: AnnotationTool
    var start: CGPoint
    var end: CGPoint
    var points: [CGPoint] = []
    var color: Color
    var lineWidth: CGFloat = 3
    var text: String = ""
    var fontSize: CGFloat = 16
}

struct CaptureEditorView: View {
    let image: NSImage
    let onCopy: (NSImage) -> Void
    let onSave: (NSImage) -> Void
    let onCancel: () -> Void
    
    @State private var selectedBackground: CanvasBackgroundPreset = .none
    @State private var padding: CGFloat = 32
    @State private var cornerRadius: CGFloat = 12
    @State private var shadowRadius: CGFloat = 15
    
    // Annotation states
    @State private var activeTool: AnnotationTool = .none
    @State private var strokeColor: Color = .red
    @State private var annotations: [AnnotationElement] = []
    @State private var currentPoints: [CGPoint] = []
    @State private var dragStartPoint: CGPoint? = nil
    @State private var dragEndPoint: CGPoint? = nil
    
    // Text editing states
    @State private var textEditingPosition: CGPoint? = nil
    @State private var textInput: String = ""
    @State private var selectedFontSize: CGFloat = 18
    @FocusState private var isTextFieldFocused: Bool
    
    // OCR states
    @State private var isExtractingText = false
    @State private var ocrText: String = ""
    @State private var showOcrPopover = false
    
    private let availableColors: [Color] = [.red, .yellow, .blue, .green, .orange, .white, .black]
    
    var body: some View {
        HStack(spacing: 0) {
            // Preview Canvas (Left)
            previewCanvas
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.85))
            
            // Sidebar Controls (Right)
            sidebarControls
                .frame(width: 280)
                .background(DT.Color.surfaceElevated)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(DT.Color.stroke)
                        .frame(width: 1)
                }
        }
        .frame(width: 900, height: 600)
    }
    
    private var previewCanvas: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    
                    // The actual composite workspace
                    ZStack {
                        // Gradient Background
                        if let gradient = selectedBackground.gradient {
                            gradient
                                .frame(
                                    width: image.size.width + padding * 2,
                                    height: image.size.height + padding * 2
                                )
                                .cornerRadius(8)
                        }
                        
                        // Screenshot + Drawings ZStack
                        ZStack(alignment: .topLeading) {
                            Image(nsImage: image)
                                .resizable()
                                .frame(width: image.size.width, height: image.size.height)
                            
                            // Render Redactions (Blur and Blackout) below vector markups
                            ForEach(annotations) { element in
                                if element.tool == .blur {
                                    Image(nsImage: image)
                                        .resizable()
                                        .frame(width: image.size.width, height: image.size.height)
                                        .blur(radius: 16)
                                        .mask(
                                            Rectangle()
                                                .frame(width: abs(element.end.x - element.start.x), height: abs(element.end.y - element.start.y))
                                                .position(x: (element.start.x + element.end.x) / 2, y: (element.start.y + element.end.y) / 2)
                                        )
                                } else if element.tool == .blackout {
                                    Rectangle()
                                        .fill(Color(red: 0.05, green: 0.05, blue: 0.07))
                                        .frame(width: abs(element.end.x - element.start.x), height: abs(element.end.y - element.start.y))
                                        .position(x: (element.start.x + element.end.x) / 2, y: (element.start.y + element.end.y) / 2)
                                }
                            }
                            
                            // Live dragging blur/blackout preview
                            if let start = dragStartPoint, let end = dragEndPoint {
                                if activeTool == .blur {
                                    Image(nsImage: image)
                                        .resizable()
                                        .frame(width: image.size.width, height: image.size.height)
                                        .blur(radius: 16)
                                        .mask(
                                            Rectangle()
                                                .frame(width: abs(end.x - start.x), height: abs(end.y - start.y))
                                                .position(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
                                        )
                                } else if activeTool == .blackout {
                                    Rectangle()
                                        .fill(Color(red: 0.05, green: 0.05, blue: 0.07))
                                        .frame(width: abs(end.x - start.x), height: abs(end.y - start.y))
                                        .position(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
                                }
                            }
                            
                            // Vector Annotations Render (excluding redactions & text)
                            ForEach(annotations) { element in
                                if element.tool != .blur && element.tool != .blackout && element.tool != .text {
                                    AnnotationPath(element: element)
                                }
                            }
                            
                            // Committed text annotations
                            ForEach(annotations) { element in
                                if element.tool == .text {
                                    Text(element.text)
                                        .font(.system(size: element.fontSize, weight: .bold, design: .rounded))
                                        .foregroundColor(element.color)
                                        .fixedSize()
                                        .offset(x: element.start.x + 4, y: element.start.y + 4)
                                }
                            }
                            
                            // Live drawing path preview for standard vector tools
                            if let start = dragStartPoint, let end = dragEndPoint, activeTool != .blur && activeTool != .blackout && activeTool != .text {
                                AnnotationPath(
                                    element: AnnotationElement(
                                        tool: activeTool,
                                        start: start,
                                        end: end,
                                        points: currentPoints,
                                        color: strokeColor
                                    )
                                )
                            }
                            
                            // Inline text field for active editing
                            if let pos = textEditingPosition {
                                TextField("", text: $textInput)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: selectedFontSize, weight: .bold, design: .rounded))
                                    .foregroundColor(strokeColor)
                                    .focused($isTextFieldFocused)
                                    .frame(width: 200)
                                    .padding(4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(strokeColor, lineWidth: 1)
                                            .background(Color.black.opacity(0.65))
                                    )
                                    .offset(x: pos.x, y: pos.y)
                                    .onSubmit {
                                        commitText()
                                    }
                            }
                        }
                        .cornerRadius(cornerRadius)
                        .shadow(
                            color: Color.black.opacity(shadowRadius > 0 ? 0.35 : 0),
                            radius: shadowRadius,
                            x: 0,
                            y: shadowRadius / 2
                        )
                        .contentShape(Rectangle()) // Make the whole image area interactive
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    guard activeTool != .none else { return }
                                    
                                    let location = value.location
                                    
                                    if activeTool == .text {
                                        if textEditingPosition != nil {
                                            commitText()
                                        }
                                        textEditingPosition = location
                                        textInput = ""
                                        isTextFieldFocused = true
                                        return
                                    }
                                    
                                    if dragStartPoint == nil {
                                        dragStartPoint = location
                                    }
                                    dragEndPoint = location
                                    
                                    if activeTool == .pen {
                                        currentPoints.append(location)
                                    }
                                }
                                .onEnded { _ in
                                    guard activeTool != .none, activeTool != .text,
                                          let start = dragStartPoint,
                                          let end = dragEndPoint else { return }
                                    
                                    // Ignore tiny accidental drags (less than 4 pixels) to prevent broken markup
                                    let dx = end.x - start.x
                                    let dy = end.y - start.y
                                    if sqrt(dx*dx + dy*dy) > 4 {
                                        let element = AnnotationElement(
                                            tool: activeTool,
                                            start: start,
                                            end: end,
                                            points: currentPoints,
                                            color: strokeColor
                                        )
                                        annotations.append(element)
                                    }
                                    
                                    // Reset active states
                                    dragStartPoint = nil
                                    dragEndPoint = nil
                                    currentPoints = []
                                }
                        )
                        .padding(selectedBackground == .none ? 0 : padding)
                    }
                    
                    Spacer()
                }
                Spacer()
            }
            .frame(minWidth: 620, minHeight: 600)
        }
    }
    
    private var sidebarControls: some View {
        VStack(spacing: DT.Spacing.l) {
            // Header
            HStack {
                Text("Edit Capture")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(DT.Color.textPrimary)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(DT.Color.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, DT.Spacing.l)
            
            Divider()
                .background(DT.Color.stroke)
            
            // Annotation controls
            VStack(alignment: .leading, spacing: DT.Spacing.s) {
                Text("Markup Tools")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(DT.Color.textSecondary)
                
                // Grid of tools (3 columns)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: DT.Spacing.s) {
                    ForEach(AnnotationTool.allCases, id: \.rawValue) { tool in
                        Button {
                            activeTool = tool
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: tool.imageName)
                                    .font(.system(size: 14))
                                Text(tool.title)
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .foregroundColor(activeTool == tool ? DT.Color.accent : DT.Color.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: DT.Radius.s)
                                    .fill(activeTool == tool ? DT.Color.accentMuted : Color.white.opacity(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DT.Radius.s)
                                    .stroke(activeTool == tool ? DT.Color.accent : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                if activeTool != .none {
                    // Color Picker
                    HStack(spacing: 8) {
                        ForEach(availableColors, id: \.self) { color in
                            Circle()
                                .fill(color)
                                .frame(width: 18, height: 18)
                                .overlay(
                                    Circle()
                                        .stroke(strokeColor == color ? Color.white : Color.clear, lineWidth: 1.5)
                                )
                                .onTapGesture {
                                    strokeColor = color
                                }
                        }
                        
                        Spacer()
                        
                        if !annotations.isEmpty {
                            Button {
                                annotations.removeLast()
                            } label: {
                                Image(systemName: "arrow.uturn.backward.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(DT.Color.textSecondary)
                            }
                            .buttonStyle(.plain)
                            .help("Undo last markup")
                        }
                    }
                    .padding(.vertical, DT.Spacing.xxs)
                }
                
                if activeTool == .text {
                    VStack(alignment: .leading, spacing: DT.Spacing.xs) {
                        HStack {
                            Text("Font Size")
                                .font(.system(size: 10))
                                .foregroundColor(DT.Color.textSecondary)
                            Spacer()
                            Text("\(Int(selectedFontSize))pt")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(DT.Color.textPrimary)
                        }
                        Slider(value: $selectedFontSize, in: 12...64, step: 2)
                            .tint(DT.Color.accent)
                    }
                    .padding(.top, DT.Spacing.xs)
                }
            }
            
            Divider()
                .background(DT.Color.stroke)
            
            // Background Canvas controls
            VStack(alignment: .leading, spacing: DT.Spacing.s) {
                Text("Canvas Background")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(DT.Color.textSecondary)
                
                // Grid of presets
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: DT.Spacing.s) {
                    ForEach(CanvasBackgroundPreset.allCases) { preset in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedBackground = preset
                            }
                        } label: {
                            Text(preset.rawValue)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(selectedBackground == preset ? DT.Color.accent : DT.Color.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 30)
                                .background(
                                    RoundedRectangle(cornerRadius: DT.Radius.s)
                                        .fill(selectedBackground == preset ? DT.Color.accentMuted : Color.white.opacity(0.04))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: DT.Radius.s)
                                        .stroke(selectedBackground == preset ? DT.Color.accent : Color.clear, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                if selectedBackground != .none {
                    VStack(spacing: DT.Spacing.xs) {
                        // Padding slider
                        HStack {
                            Text("Padding")
                                .font(.system(size: 10))
                                .foregroundColor(DT.Color.textSecondary)
                            Spacer()
                            Text("\(Int(padding))px")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(DT.Color.textPrimary)
                        }
                        Slider(value: $padding, in: 16...80, step: 8)
                            .tint(DT.Color.accent)
                        
                        // Corner radius slider
                        HStack {
                            Text("Corners")
                                .font(.system(size: 10))
                                .foregroundColor(DT.Color.textSecondary)
                            Spacer()
                            Text("\(Int(cornerRadius))px")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(DT.Color.textPrimary)
                        }
                        Slider(value: $cornerRadius, in: 0...32, step: 4)
                            .tint(DT.Color.accent)
                        
                        // Shadow slider
                        HStack {
                            Text("Shadow")
                                .font(.system(size: 10))
                                .foregroundColor(DT.Color.textSecondary)
                            Spacer()
                            Text("\(Int(shadowRadius))px")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(DT.Color.textPrimary)
                        }
                        Slider(value: $shadowRadius, in: 0...40, step: 5)
                            .tint(DT.Color.accent)
                    }
                    .padding(.top, DT.Spacing.xs)
                }
            }
            
            Divider()
                .background(DT.Color.stroke)
            
            // OCR Feature
            VStack(alignment: .leading, spacing: DT.Spacing.s) {
                Text("Text Recognition (OCR)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(DT.Color.textSecondary)
                
                Button {
                    Task {
                        isExtractingText = true
                        let text = await OCRService.recognizeText(from: image)
                        await MainActor.run {
                            ocrText = text
                            isExtractingText = false
                            showOcrPopover = true
                        }
                    }
                } label: {
                    HStack {
                        if isExtractingText {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "text.viewfinder")
                        }
                        Text("Extract Text")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(Color.blue.opacity(0.8))
                    .cornerRadius(DT.Radius.s)
                }
                .buttonStyle(.plain)
                .disabled(isExtractingText)
                .popover(isPresented: $showOcrPopover, arrowEdge: .leading) {
                    VStack(alignment: .leading, spacing: DT.Spacing.s) {
                        Text("Recognized Text")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(DT.Color.textPrimary)
                        
                        ScrollView {
                            Text(ocrText.isEmpty ? "No text recognized." : ocrText)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(DT.Color.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .frame(width: 250, height: 150)
                        .padding(DT.Spacing.xs)
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(DT.Radius.s)
                        
                        HStack {
                            Button("Copy Text") {
                                let pb = NSPasteboard.general
                                pb.clearContents()
                                pb.setString(ocrText, forType: .string)
                                showOcrPopover = false
                                
                                // Show a notification/sound if available
                                NSSound.beep()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(ocrText.isEmpty)
                            
                            Spacer()
                            
                            Button("Close") {
                                showOcrPopover = false
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(DT.Spacing.m)
                }
            }
            
            Spacer()
            
            // Bottom Action buttons
            VStack(spacing: DT.Spacing.s) {
                Button {
                    if let rendered = renderComposite() {
                        onSave(rendered)
                    }
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Save File...")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DT.Color.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(DT.Radius.s)
                }
                .buttonStyle(.plain)
                
                Button {
                    if let rendered = renderComposite() {
                        onCopy(rendered)
                    }
                } label: {
                    HStack {
                        Image(systemName: "doc.on.clipboard")
                        Text("Copy to Clipboard")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(DT.Color.accent)
                    .cornerRadius(DT.Radius.s)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, DT.Spacing.l)
        }
        .padding(.horizontal, DT.Spacing.l)
    }
    
    private func commitText() {
        guard let pos = textEditingPosition else { return }
        let trimmed = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let element = AnnotationElement(
                tool: .text,
                start: pos,
                end: pos,
                points: [],
                color: strokeColor,
                text: trimmed,
                fontSize: selectedFontSize
            )
            annotations.append(element)
        }
        textEditingPosition = nil
        textInput = ""
        isTextFieldFocused = false
    }
    
    /// Renders the composite SwiftUI view with annotations, background, padding, etc., to a single NSImage.
    @MainActor
    private func renderComposite() -> NSImage? {
        let exportView = ExportContainerView(
            image: image,
            preset: selectedBackground,
            padding: padding,
            cornerRadius: cornerRadius,
            shadowRadius: shadowRadius,
            annotations: annotations
        )
        
        let renderer = ImageRenderer(content: exportView)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
        return renderer.nsImage
    }
}

// MARK: - Annotation Rendering helpers

struct ExportContainerView: View {
    let image: NSImage
    let preset: CanvasBackgroundPreset
    let padding: CGFloat
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    let annotations: [AnnotationElement]
    
    var body: some View {
        ZStack {
            if let gradient = preset.gradient {
                gradient
                    .frame(
                        width: image.size.width + padding * 2,
                        height: image.size.height + padding * 2
                    )
            }
            
            ZStack(alignment: .topLeading) {
                Image(nsImage: image)
                    .resizable()
                    .frame(width: image.size.width, height: image.size.height)
                
                // Render Redactions (Blur and Blackout) on export
                ForEach(annotations) { element in
                    if element.tool == .blur {
                        Image(nsImage: image)
                            .resizable()
                            .frame(width: image.size.width, height: image.size.height)
                            .blur(radius: 16)
                            .mask(
                                Rectangle()
                                    .frame(width: abs(element.end.x - element.start.x), height: abs(element.end.y - element.start.y))
                                    .position(x: (element.start.x + element.end.x) / 2, y: (element.start.y + element.end.y) / 2)
                            )
                    } else if element.tool == .blackout {
                        Rectangle()
                            .fill(Color(red: 0.05, green: 0.05, blue: 0.07))
                            .frame(width: abs(element.end.x - element.start.x), height: abs(element.end.y - element.start.y))
                            .position(x: (element.start.x + element.end.x) / 2, y: (element.start.y + element.end.y) / 2)
                    }
                }
                
                // Vector Annotations Render (excluding redactions & text)
                ForEach(annotations) { element in
                    if element.tool != .blur && element.tool != .blackout && element.tool != .text {
                        AnnotationPath(element: element)
                    }
                }
                
                // Text Annotations Render
                ForEach(annotations) { element in
                    if element.tool == .text {
                        Text(element.text)
                            .font(.system(size: element.fontSize, weight: .bold, design: .rounded))
                            .foregroundColor(element.color)
                            .fixedSize()
                            .offset(x: element.start.x + 4, y: element.start.y + 4)
                    }
                }
            }
            .cornerRadius(cornerRadius)
            .shadow(
                color: Color.black.opacity(shadowRadius > 0 && preset != .none ? 0.35 : 0),
                radius: shadowRadius,
                x: 0,
                y: shadowRadius / 2
            )
            .padding(preset == .none ? 0 : padding)
        }
        .frame(
            width: image.size.width + (preset == .none ? 0 : padding * 2),
            height: image.size.height + (preset == .none ? 0 : padding * 2)
        )
    }
}

struct AnnotationPath: View {
    let element: AnnotationElement
    
    var body: some View {
        Path { path in
            switch element.tool {
            case .pen:
                guard !element.points.isEmpty else { return }
                path.move(to: element.points[0])
                for point in element.points.dropFirst() {
                    path.addLine(to: point)
                }
            case .arrow:
                drawArrow(from: element.start, to: element.end, path: &path)
            case .rectangle:
                let rect = CGRect(
                    x: min(element.start.x, element.end.x),
                    y: min(element.start.y, element.end.y),
                    width: abs(element.start.x - element.end.x),
                    height: abs(element.start.y - element.end.y)
                )
                path.addRect(rect)
            case .none, .blur, .blackout, .text:
                break
            }
        }
        .stroke(element.color, style: StrokeStyle(lineWidth: element.lineWidth, lineCap: .round, lineJoin: .round))
    }
    
    private func drawArrow(from start: CGPoint, to end: CGPoint, path: inout Path) {
        path.move(to: start)
        path.addLine(to: end)
        
        let dx = end.x - start.x
        let dy = end.y - start.y
        let angle = atan2(dy, dx)
        let length: CGFloat = 14
        let arrowAngle = CGFloat.pi / 6 // 30 degrees
        
        let p1 = CGPoint(
            x: end.x - length * cos(angle - arrowAngle),
            y: end.y - length * sin(angle - arrowAngle)
        )
        let p2 = CGPoint(
            x: end.x - length * cos(angle + arrowAngle),
            y: end.y - length * sin(angle + arrowAngle)
        )
        
        path.move(to: end)
        path.addLine(to: p1)
        path.move(to: end)
        path.addLine(to: p2)
    }
}

enum AnnotationTool: String, CaseIterable {
    case none = "cursorarrow"
    case pen = "pencil"
    case arrow = "arrow.up.forward"
    case rectangle = "square"
    case text = "textformat"
    case blur = "sparkles"
    case blackout = "eye.slash.fill"
    
    var title: String {
        switch self {
        case .none: return "Select"
        case .pen: return "Pen"
        case .arrow: return "Arrow"
        case .rectangle: return "Rect"
        case .text: return "Text"
        case .blur: return "Blur"
        case .blackout: return "Blackout"
        }
    }
    
    var imageName: String {
        self.rawValue
    }
}
