import SwiftUI
import AVKit
import UniformTypeIdentifiers

struct CaptureRecordingPreviewView: View {
    let videoURL: URL
    let onCancel: () -> Void
    
    @State private var player: AVPlayer
    @State private var isConverting = false
    @State private var conversionError: String? = nil
    @State private var videoDuration: String = "--:--"
    @State private var videoResolution: String = "--- × ---"
    
    // Trimming States
    @State private var maxDuration: Double = 0.0
    @State private var trimStart: Double = 0.0
    @State private var trimEnd: Double = 0.0
    @State private var timeObserver: Any? = nil
    
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
            cleanUpTimeObserver()
        }
    }
    
    private func setupLoopingAndLoadMetadata() {
        player.play()
        
        // Loop recording video playback
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak player] _ in
            guard let player = player else { return }
            player.seek(to: CMTime(seconds: trimStart, preferredTimescale: 600))
            player.play()
        }
        
        // Add periodic time observer to keep playback within trim boundaries
        let observer = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 10), queue: .main) { [weak player] time in
            guard let player = player else { return }
            let seconds = time.seconds
            if seconds < trimStart {
                player.seek(to: CMTime(seconds: trimStart, preferredTimescale: 600))
            } else if seconds > trimEnd {
                player.seek(to: CMTime(seconds: trimStart, preferredTimescale: 600))
                player.play()
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
    
    private func cleanUpTimeObserver() {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            self.timeObserver = nil
        }
    }
    
    private func closeAndCleanUp() {
        cleanUpTimeObserver()
        onCancel()
    }
    
    private func getProcessedVideoURL() async throws -> URL {
        let isTrimmed = trimStart > 0.05 || trimEnd < (maxDuration - 0.05)
        guard isTrimmed else { return videoURL }
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "Trimmed_\(Int(Date().timeIntervalSince1970)).mp4"
        let trimmedURL = tempDir.appendingPathComponent(fileName)
        
        let asset = AVAsset(url: videoURL)
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetPassthrough
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
                    
                    await MainActor.run {
                        self.isConverting = false
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
                    
                    await MainActor.run {
                        self.isConverting = false
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
                
                await MainActor.run {
                    self.isConverting = false
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
