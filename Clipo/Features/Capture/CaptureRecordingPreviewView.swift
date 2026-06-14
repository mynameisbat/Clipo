import SwiftUI
import AVKit
import UniformTypeIdentifiers

/// Reference-type box used to share live trimStart/trimEnd values with AVPlayer observer closures.
/// Required because SwiftUI Views are structs — [weak self] is not valid in struct closures.
final class TrimBoundaryBox: @unchecked Sendable {
    var start: Double = 0
    var end: Double = .infinity
}

struct CaptureRecordingPreviewView: View {
    let videoURL: URL
    let onCancel: () -> Void
    
    @State private var player: AVPlayer
    @State private var isConverting = false
    @State private var conversionError: String? = nil
    @State private var successMessage: String? = nil
    @State private var videoDuration: String = "--:--"
    @State private var videoResolution: String = "--- × ---"
    
    // Trimming States
    @State private var maxDuration: Double = 0.0
    @State private var trimStart: Double = 0.0
    @State private var trimEnd: Double = 0.0
    @State private var timeObserver: Any? = nil
    @State private var loopObserver: NSObjectProtocol? = nil
    @State private var trimBoundaryBox = TrimBoundaryBox()
    
    init(videoURL: URL, onCancel: @escaping () -> Void) {
        self.videoURL = videoURL
        self.onCancel = onCancel
        self._player = State(initialValue: AVPlayer(url: videoURL))
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Video Player Area
            ZStack {
                VideoPlayer(player: player)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .cornerRadius(DT.Radius.m)
                    .padding(DT.Spacing.m)
                
                if isConverting {
                    Color.black.opacity(0.7)
                        .cornerRadius(DT.Radius.m)
                        .padding(DT.Spacing.m)
                    
                    VStack(spacing: DT.Spacing.m) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .controlSize(.large)
                        Text(trimStart > 0.05 || trimEnd < (maxDuration - 0.05) ? "Processing Trimmed Asset..." : "Processing...")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Please wait...")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.9))
            
            // Sidebar Controls
            VStack(alignment: .leading, spacing: DT.Spacing.l) {
                Text("Recording Preview")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(DT.Color.textPrimary)
                
                // Video Details Card
                VStack(alignment: .leading, spacing: DT.Spacing.s) {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(DT.Color.textSecondary)
                        Text("Original Duration:")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(DT.Color.textSecondary)
                        Spacer()
                        Text(videoDuration)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(DT.Color.textPrimary)
                    }
                    
                    HStack {
                        Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                            .foregroundColor(DT.Color.textSecondary)
                        Text("Resolution:")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(DT.Color.textSecondary)
                        Spacer()
                        Text(videoResolution)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(DT.Color.textPrimary)
                    }
                }
                .padding(DT.Spacing.m)
                .background(DT.Color.surface.opacity(0.4))
                .cornerRadius(DT.Radius.s)
                .overlay(
                    RoundedRectangle(cornerRadius: DT.Radius.s)
                        .stroke(DT.Color.stroke, lineWidth: 1)
                )
                
                // Video Trimming Section
                if maxDuration > 0 {
                    VStack(alignment: .leading, spacing: DT.Spacing.xs) {
                        Text("Trim Video")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(DT.Color.textSecondary)
                            .textCase(.uppercase)
                        
                        VStack(spacing: DT.Spacing.s) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text("Start:")
                                        .font(.system(size: 11))
                                        .foregroundColor(DT.Color.textSecondary)
                                    Spacer()
                                    Text(String(format: "%.1fs", trimStart))
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(DT.Color.textPrimary)
                                }
                                Slider(value: $trimStart, in: 0...max(0.1, trimEnd - 0.1)) {
                                    Text("Start")
                                }
                                .controlSize(.small)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text("End:")
                                        .font(.system(size: 11))
                                        .foregroundColor(DT.Color.textSecondary)
                                    Spacer()
                                    Text(String(format: "%.1fs", trimEnd))
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(DT.Color.textPrimary)
                                }
                                Slider(value: $trimEnd, in: max(0.1, trimStart + 0.1)...maxDuration) {
                                    Text("End")
                                }
                                .controlSize(.small)
                            }
                        }
                        .padding(DT.Spacing.m)
                        .background(DT.Color.surface.opacity(0.4))
                        .cornerRadius(DT.Radius.s)
                        .overlay(
                            RoundedRectangle(cornerRadius: DT.Radius.s)
                                .stroke(DT.Color.stroke, lineWidth: 1)
                        )
                    }
                }
                
                if let message = successMessage {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(message)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.green)
                    }
                    .padding(.vertical, 4)
                }

                if let error = conversionError {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(DT.Color.danger)
                        .padding(.vertical, 4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: DT.Spacing.s) {
                    // Save MP4 Button
                    Button(action: saveMP4) {
                        HStack {
                            Image(systemName: "video.fill")
                            Text("Save MP4 Video")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(DT.Color.surface)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(DT.Color.accent)
                        .cornerRadius(DT.Radius.s)
                    }
                    .buttonStyle(.plain)
                    .disabled(isConverting)
                    
                    // Export GIF Button
                    Button(action: exportGIF) {
                        HStack {
                            Image(systemName: "doc.zipper")
                            Text("Export as GIF")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(DT.Color.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(DT.Color.surfaceElevated)
                        .cornerRadius(DT.Radius.s)
                        .overlay(
                            RoundedRectangle(cornerRadius: DT.Radius.s)
                                .stroke(DT.Color.stroke, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isConverting)
                    
                    // Copy to Clipboard
                    Button(action: copyToClipboard) {
                        HStack {
                            Image(systemName: "doc.on.doc.fill")
                            Text("Copy File")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(DT.Color.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(DT.Color.surfaceElevated)
                        .cornerRadius(DT.Radius.s)
                        .overlay(
                            RoundedRectangle(cornerRadius: DT.Radius.s)
                                .stroke(DT.Color.stroke, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isConverting)
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    // Cancel/Close Button
                    Button(action: closeAndCleanUp) {
                        Text("Close")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DT.Color.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.clear)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 260)
            .padding(DT.Spacing.l)
            .background(DT.Color.surfaceElevated)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(DT.Color.stroke)
                    .frame(width: 1)
            }
        }
        .frame(width: 800, height: 500)
        .onAppear {
            setupLoopingAndLoadMetadata()
        }
        .onDisappear {
            cleanUpObservers()
        }
        .onChange(of: trimStart) { newStart in
            trimBoundaryBox.start = newStart
            // BUG-05 fix: seek player immediately when trim slider changes
            player.seek(to: CMTime(seconds: newStart, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        }
        .onChange(of: trimEnd) { newEnd in
            trimBoundaryBox.end = newEnd
            // BUG-05 fix: if current position exceeds new trimEnd, seek back to trimStart
            let currentSeconds = player.currentTime().seconds
            if currentSeconds > newEnd {
                player.seek(to: CMTime(seconds: trimStart, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
            }
        }
    }
    
    private func setupLoopingAndLoadMetadata() {
        player.play()

        // Capture player directly (AVPlayer is a class — safe to capture strongly in closures)
        // TrimBoundary box lets us update live values without [weak self] on a struct
        let capturedPlayer = player
        let trimBox = trimBoundaryBox

        // BUG-01 fix: store observer token so it can be properly removed
        // BUG-02 fix: read live trimStart from trimBox, not a stale captured value
        let token = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            capturedPlayer.seek(to: CMTime(seconds: trimBox.start, preferredTimescale: 600))
            capturedPlayer.play()
        }
        self.loopObserver = token

        // BUG-08 fix: read live trimStart/trimEnd from trimBox inside periodic observer
        let observer = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 10), queue: .main) { time in
            let seconds = time.seconds
            if seconds < trimBox.start {
                capturedPlayer.seek(to: CMTime(seconds: trimBox.start, preferredTimescale: 600))
            } else if seconds > trimBox.end {
                capturedPlayer.seek(to: CMTime(seconds: trimBox.start, preferredTimescale: 600))
                capturedPlayer.play()
            }
        }
        self.timeObserver = observer
        
        // Fetch metadata
        let asset = AVPlayerItem(url: videoURL).asset
        Task {
            do {
                let duration = try await asset.load(.duration)
                let durationSeconds = CMTimeGetSeconds(duration)
                
                let tracks = try await asset.loadTracks(withMediaType: .video)
                let resolutionString: String
                if let videoTrack = tracks.first {
                    let size = try await videoTrack.load(.naturalSize)
                    resolutionString = "\(Int(size.width)) × \(Int(size.height))"
                } else {
                    resolutionString = "Unknown"
                }
                
                await MainActor.run {
                    self.maxDuration = durationSeconds
                    self.trimEnd = durationSeconds
                    self.videoDuration = String(format: "%.1fs", durationSeconds)
                    self.videoResolution = resolutionString
                }
            } catch {
                print("Failed to load video metadata: \(error)")
            }
        }
    }
    
    // BUG-01 fix: remove both observers (periodic + notification)
    private func cleanUpObservers() {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            self.timeObserver = nil
        }
        if let token = loopObserver {
            NotificationCenter.default.removeObserver(token)
            self.loopObserver = nil
        }
        player.pause()
    }
    
    private func closeAndCleanUp() {
        cleanUpObservers()
        onCancel()
    }
    
    private func getProcessedVideoURL() async throws -> URL {
        let isTrimmed = trimStart > 0.05 || trimEnd < (maxDuration - 0.05)
        guard isTrimmed else { return videoURL }
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "Trimmed_\(Int(Date().timeIntervalSince1970)).mp4"
        let trimmedURL = tempDir.appendingPathComponent(fileName)
        
        let asset = AVAsset(url: videoURL)
        // BUG-03 fix: AVAssetExportPresetPassthrough is incompatible with .mp4 container.
        // Use HighestQuality which re-muxes correctly into MP4.
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw NSError(domain: "CapturePreview", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
        }
        
        exportSession.outputURL = trimmedURL
        exportSession.outputFileType = .mp4
        
        let start = CMTime(seconds: trimStart, preferredTimescale: 600)
        let duration = CMTime(seconds: trimEnd - trimStart, preferredTimescale: 600)
        exportSession.timeRange = CMTimeRange(start: start, duration: duration)
        
        await exportSession.export()
        if let error = exportSession.error {
            throw error
        }
        return trimmedURL
    }
    
    private func saveMP4() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.mpeg4Movie]
        savePanel.nameFieldStringValue = "ScreenRecording_\(Int(Date().timeIntervalSince1970)).mp4"
        savePanel.title = "Save Screen Recording"
        
        savePanel.begin { response in
            guard response == .OK, let destinationURL = savePanel.url else { return }
            
            isConverting = true
            conversionError = nil
            
            Task {
                do {
                    let processedURL = try await getProcessedVideoURL()
                    
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.copyItem(at: processedURL, to: destinationURL)
                    
                    if processedURL != videoURL {
                        try? FileManager.default.removeItem(at: processedURL)
                    }
                    
                    // BUG-09 fix: show success feedback before closing
                    await MainActor.run {
                        self.isConverting = false
                        self.successMessage = "Video saved successfully!"
                    }
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    await MainActor.run {
                        self.closeAndCleanUp()
                    }
                } catch {
                    await MainActor.run {
                        self.isConverting = false
                        self.conversionError = "Failed to save: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    private func exportGIF() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.gif]
        savePanel.nameFieldStringValue = "ScreenRecording_\(Int(Date().timeIntervalSince1970)).gif"
        savePanel.title = "Export Recording as GIF"
        
        savePanel.begin { response in
            guard response == .OK, let destinationURL = savePanel.url else { return }
            
            isConverting = true
            conversionError = nil
            
            Task {
                do {
                    let processedURL = try await getProcessedVideoURL()
                    
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    
                    try await GIFConverter.convertVideoToGIF(videoURL: processedURL, outputURL: destinationURL)
                    
                    if processedURL != videoURL {
                        try? FileManager.default.removeItem(at: processedURL)
                    }
                    
                    // BUG-09 fix: show success feedback before closing
                    await MainActor.run {
                        self.isConverting = false
                        self.successMessage = "GIF exported successfully!"
                    }
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    await MainActor.run {
                        self.closeAndCleanUp()
                    }
                } catch {
                    await MainActor.run {
                        self.isConverting = false
                        self.conversionError = "GIF Export failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    private func copyToClipboard() {
        isConverting = true
        conversionError = nil
        
        Task {
            do {
                let processedURL = try await getProcessedVideoURL()
                
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.writeObjects([processedURL as NSURL])
                
                // BUG-09 fix: show success feedback before closing
                await MainActor.run {
                    self.isConverting = false
                    self.successMessage = "File copied to clipboard!"
                }
                try? await Task.sleep(nanoseconds: 800_000_000)
                await MainActor.run {
                    self.closeAndCleanUp()
                }
            } catch {
                await MainActor.run {
                    self.isConverting = false
                    self.conversionError = "Copy failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
