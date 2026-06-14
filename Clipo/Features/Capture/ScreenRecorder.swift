import AVFoundation
import Cocoa
import CoreGraphics

@MainActor
protocol ScreenRecorderDelegate: AnyObject {
    func screenRecorderDidStart()
    func screenRecorderDidFinish(outputURL: URL?, error: Error?)
}

final class ScreenRecorder: NSObject, @unchecked Sendable {
    private let session = AVCaptureSession()
    private var screenInput: AVCaptureScreenInput?
    private var micInput: AVCaptureDeviceInput?
    private let fileOutput = AVCaptureMovieFileOutput()
    
    private(set) var isRecording = false
    private var tempFileURL: URL?
    
    // System Audio
    private var systemAudioRecorder: SystemAudioRecorder?
    private var recordSystemAudio = false
    
    weak var delegate: ScreenRecorderDelegate?
    
    override init() {
        super.init()
    }
    
    /// Starts recording a specific screen area.
    /// - Parameters:
    ///   - cropRect: Crop rectangle in AppKit coordinates (bottom-left relative to screen)
    ///   - screen: The NSScreen target
    ///   - includeMic: Toggle microphone recording
    func startRecording(cropRect: CGRect, on screen: NSScreen, includeMic: Bool, recordSystemAudio: Bool) {
        guard !isRecording else { return }
        
        self.recordSystemAudio = recordSystemAudio
        if recordSystemAudio {
            Task { @MainActor in
                let recorder = SystemAudioRecorder()
                self.systemAudioRecorder = recorder
                do {
                    try await recorder.startRecording()
                } catch {
                    print("Failed to start system audio capture: \(error)")
                }
            }
        }
        
        session.beginConfiguration()
        
        // Remove old inputs/outputs
        for input in session.inputs {
            session.removeInput(input)
        }
        for output in session.outputs {
            session.removeOutput(output)
        }
        
        // 1. Configure Display Screen Input
        guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            session.commitConfiguration()
            Task { @MainActor [weak self] in
                self?.delegate?.screenRecorderDidFinish(outputURL: nil, error: NSError(domain: "ScreenRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to resolve Screen Number"]))
            }
            return
        }
        
        guard let screenInput = AVCaptureScreenInput(displayID: displayID) else {
            session.commitConfiguration()
            Task { @MainActor [weak self] in
                self?.delegate?.screenRecorderDidFinish(outputURL: nil, error: NSError(domain: "ScreenRecorder", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create Screen Input"]))
            }
            return
        }
        
        screenInput.capturesCursor = true
        let savedFps = UserDefaults.standard.integer(forKey: "clipo.recording.videoFps")
        let activeFps = savedFps > 0 ? savedFps : 30
        screenInput.minFrameDuration = CMTime(value: 1, timescale: CMTimeScale(activeFps))
        
        // Map AppKit cropRect (origin bottom-left, y increases up) to AVCaptureScreenInput coordinates (origin top-left, y increases down)
        let screenFrame = screen.frame
        let cgCropRect = CGRect(
            x: cropRect.origin.x,
            y: screenFrame.height - cropRect.origin.y - cropRect.size.height,
            width: cropRect.size.width,
            height: cropRect.size.height
        )
        screenInput.cropRect = cgCropRect
        
        if session.canAddInput(screenInput) {
            session.addInput(screenInput)
            self.screenInput = screenInput
        } else {
            session.commitConfiguration()
            Task { @MainActor [weak self] in
                self?.delegate?.screenRecorderDidFinish(outputURL: nil, error: NSError(domain: "ScreenRecorder", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to add Screen Input"]))
            }
            return
        }
        
        // 2. Configure Mic Input (Optional)
        if includeMic {
            if let mic = AVCaptureDevice.default(for: .audio) {
                do {
                    let micInput = try AVCaptureDeviceInput(device: mic)
                    if session.canAddInput(micInput) {
                        session.addInput(micInput)
                        self.micInput = micInput
                    }
                } catch {
                    // Non-fatal, continue without microphone
                    print("Failed to start mic input: \(error)")
                }
            }
        }
        
        // 3. Configure File Output
        if session.canAddOutput(fileOutput) {
            session.addOutput(fileOutput)
        } else {
            session.commitConfiguration()
            Task { @MainActor [weak self] in
                self?.delegate?.screenRecorderDidFinish(outputURL: nil, error: NSError(domain: "ScreenRecorder", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to add File Output"]))
            }
            return
        }
        
        session.commitConfiguration()
        
        // Start capture session (on background thread as required by AVCaptureSession)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.session.startRunning()
            
            // Set output temporary path
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "Recording_\(Int(Date().timeIntervalSince1970)).mp4"
            let fileURL = tempDir.appendingPathComponent(fileName)
            self.tempFileURL = fileURL
            
            DispatchQueue.main.async {
                self.isRecording = true
                self.fileOutput.startRecording(to: fileURL, recordingDelegate: self)
            }
        }
    }
    
    /// Stops the recording.
    func stopRecording() {
        guard isRecording else { return }
        fileOutput.stopRecording()
        isRecording = false
        
        if recordSystemAudio {
            Task { @MainActor in
                _ = try? await self.systemAudioRecorder?.stopRecording()
            }
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension ScreenRecorder: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        Task { @MainActor [weak self] in
            self?.delegate?.screenRecorderDidStart()
        }
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: (any Error)?) {
        // Stop session running in background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
        }
        
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            if self.recordSystemAudio, let systemAudioURL = try? await self.systemAudioRecorder?.stopRecording() {
                let tempDir = FileManager.default.temporaryDirectory
                let mergedFileName = "Merged_\(Int(Date().timeIntervalSince1970)).mp4"
                let mergedURL = tempDir.appendingPathComponent(mergedFileName)
                
                do {
                    try await SystemAudioRecorder.merge(videoURL: outputFileURL, systemAudioURL: systemAudioURL, outputURL: mergedURL)
                    
                    // Cleanup temporary raw files
                    try? FileManager.default.removeItem(at: outputFileURL)
                    try? FileManager.default.removeItem(at: systemAudioURL)
                    
                    self.delegate?.screenRecorderDidFinish(outputURL: mergedURL, error: error)
                } catch {
                    print("Merging system audio track failed: \(error)")
                    // Fallback to raw video
                    self.delegate?.screenRecorderDidFinish(outputURL: outputFileURL, error: error)
                }
            } else {
                self.delegate?.screenRecorderDidFinish(outputURL: outputFileURL, error: error)
            }
        }
    }
}
