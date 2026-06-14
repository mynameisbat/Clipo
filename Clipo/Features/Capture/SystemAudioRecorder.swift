import ScreenCaptureKit
import AVFoundation

final class SystemAudioRecorder: NSObject, SCStreamOutput, @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.bat.clipo.systemaudio")
    
    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var audioInput: AVAssetWriterInput?
    private var isRecording = false
    private var startTime: CMTime?
    private var fileURL: URL?
    
    func startRecording() async throws {
        let content = try await SCShareableContent.current
        guard let display = content.displays.first else {
            throw NSError(domain: "SystemAudioRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "No displays found for audio capture"])
        }
        
        let currentBundleID = Bundle.main.bundleIdentifier
        let excludedApps = content.applications.filter { $0.bundleIdentifier == currentBundleID }
        
        let filter = SCContentFilter(display: display, excludingApplications: excludedApps, exceptingWindows: [])
        
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 10)
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "SystemAudio_\(Int(Date().timeIntervalSince1970)).m4a"
        let targetFileURL = tempDir.appendingPathComponent(fileName)
        
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream.addStreamOutput(self, type: SCStreamOutputType.audio, sampleHandlerQueue: self.queue)
        try stream.addStreamOutput(self, type: SCStreamOutputType.screen, sampleHandlerQueue: self.queue)
        
        try await stream.startCapture()
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            queue.async {
                self.stream = stream
                self.fileURL = targetFileURL
                self.isRecording = true
                continuation.resume()
            }
        }
    }
    
    func stopRecording() async throws -> URL? {
        let wasRecording = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, any Error>) in
            queue.async {
                let state = self.isRecording
                self.isRecording = false
                continuation.resume(returning: state)
            }
        }
        
        guard wasRecording else { return nil }
        
        let activeStream = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<SCStream?, any Error>) in
            queue.async {
                let s = self.stream
                self.stream = nil
                continuation.resume(returning: s)
            }
        }
        
        if let activeStream = activeStream {
            try? await activeStream.stopCapture()
        }
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL?, any Error>) in
            queue.async {
                if let writer = self.assetWriter {
                    self.audioInput?.markAsFinished()
                    writer.finishWriting {
                        self.queue.async {
                            let url = self.fileURL
                            self.assetWriter = nil
                            self.audioInput = nil
                            self.startTime = nil
                            continuation.resume(returning: url)
                        }
                    }
                } else {
                    let url = self.fileURL
                    self.assetWriter = nil
                    self.audioInput = nil
                    self.startTime = nil
                    continuation.resume(returning: url)
                }
            }
        }
    }
    
    // MARK: - SCStreamOutput
    
    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        
        // This callback runs on self.queue, so we can access/mutate queue properties safely
        self.handleAudioSample(sampleBuffer)
    }
    
    private func handleAudioSample(_ sampleBuffer: CMSampleBuffer) {
        guard isRecording else { return }
        
        if assetWriter == nil {
            setupAssetWriter(formatDescription: CMSampleBufferGetFormatDescription(sampleBuffer))
        }
        
        guard let writer = assetWriter, writer.status == .writing else { return }
        
        if startTime == nil {
            let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            writer.startSession(atSourceTime: pts)
            startTime = pts
        }
        
        if audioInput?.isReadyForMoreMediaData == true {
            audioInput?.append(sampleBuffer)
        }
    }
    
    private func setupAssetWriter(formatDescription: CMFormatDescription?) {
        guard let fileURL = fileURL else { return }
        do {
            let writer = try AVAssetWriter(url: fileURL, fileType: .m4a)
            
            var acl = AudioChannelLayout()
            acl.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo
            let aclData = Data(bytes: &acl, count: MemoryLayout<AudioChannelLayout>.size)
            
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: 2,
                AVSampleRateKey: 44100,
                AVEncoderBitRateKey: 128000,
                AVChannelLayoutKey: aclData
            ]
            
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
            input.expectsMediaDataInRealTime = true
            
            if writer.canAdd(input) {
                writer.add(input)
                self.audioInput = input
            }
            
            writer.startWriting()
            self.assetWriter = writer
        } catch {
            print("Failed to setup audio asset writer: \(error)")
        }
    }
    
    // MARK: - Video and Audio Track Merging Helper
    
    static func merge(videoURL: URL, systemAudioURL: URL?, outputURL: URL) async throws {
        let mixComposition = AVMutableComposition()
        let videoAsset = AVAsset(url: videoURL)
        
        // 1. Add original Video Track
        let videoTracks = try await videoAsset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw NSError(domain: "SystemAudioRecorder", code: 2, userInfo: [NSLocalizedDescriptionKey: "No video track found"])
        }
        
        let compositionVideoTrack = mixComposition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        
        let duration = try await videoAsset.load(.duration)
        try compositionVideoTrack?.insertTimeRange(
            CMTimeRange(start: .zero, duration: duration),
            of: videoTrack,
            at: .zero
        )
        
        // Preserve transform orientation
        let transform = try await videoTrack.load(.preferredTransform)
        compositionVideoTrack?.preferredTransform = transform
        
        // 2. Add original Microphone Audio Track (if it exists)
        let micAudioTracks = try await videoAsset.loadTracks(withMediaType: .audio)
        if let micAudioTrack = micAudioTracks.first {
            let compositionMicAudioTrack = mixComposition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
            try compositionMicAudioTrack?.insertTimeRange(
                CMTimeRange(start: .zero, duration: duration),
                of: micAudioTrack,
                at: .zero
            )
        }
        
        // 3. Add System Audio Track (if provided)
        if let systemAudioURL = systemAudioURL {
            let systemAudioAsset = AVAsset(url: systemAudioURL)
            let systemAudioTracks = try await systemAudioAsset.loadTracks(withMediaType: .audio)
            if let systemAudioTrack = systemAudioTracks.first {
                let compositionSystemAudioTrack = mixComposition.addMutableTrack(
                    withMediaType: .audio,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                )
                let systemAudioDuration = try await systemAudioAsset.load(.duration)
                let minDuration = min(duration, systemAudioDuration)
                try compositionSystemAudioTrack?.insertTimeRange(
                    CMTimeRange(start: .zero, duration: minDuration),
                    of: systemAudioTrack,
                    at: .zero
                )
            }
        }
        
        // 4. Export the final composition to a temporary file
        guard let exportSession = AVAssetExportSession(
            asset: mixComposition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw NSError(domain: "SystemAudioRecorder", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create merge export session"])
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        
        await exportSession.export()
        if let error = exportSession.error {
            throw error
        }
    }
}
