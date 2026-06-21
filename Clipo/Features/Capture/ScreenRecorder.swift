import AVFoundation
import Cocoa
import CoreGraphics

@MainActor
protocol ScreenRecorderDelegate: AnyObject {
    func screenRecorderDidStart()
    func screenRecorderDidFinish(outputURL: URL?, error: Error?)
}

@MainActor
final class ScreenRecorder: NSObject, @unchecked Sendable {
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.bat.clipo.sessionQueue")
    private var screenInput: AVCaptureScreenInput?
    private var micInput: AVCaptureDeviceInput?
    private let fileOutput = AVCaptureMovieFileOutput()
    
    private(set) var isRecording = false
    private var shouldStopAsap = false
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
        
        isRecording = true
        shouldStopAsap = false
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
        
        guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            isRecording = false
            self.delegate?.screenRecorderDidFinish(outputURL: nil, error: NSError(domain: "ScreenRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to resolve Screen Number"]))
            return
        }
        
        let savedFps = UserDefaults.standard.integer(forKey: "clipo.recording.videoFps")
        let activeFps = savedFps > 0 ? savedFps : 30
        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(activeFps))
        
        let screenFrame = screen.frame
        let cgCropRect = CGRect(
            x: cropRect.origin.x,
            y: screenFrame.height - cropRect.origin.y - cropRect.size.height,
            width: cropRect.size.width,
            height: cropRect.size.height
        )
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            
            for input in self.session.inputs {
                self.session.removeInput(input)
            }
            for output in self.session.outputs {
                self.session.removeOutput(output)
            }
            
            guard let screenInput = AVCaptureScreenInput(displayID: displayID) else {
                self.session.commitConfiguration()
                Task { @MainActor in
                    self.isRecording = false
                    self.delegate?.screenRecorderDidFinish(outputURL: nil, error: NSError(domain: "ScreenRecorder", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create Screen Input"]))
                }
                return
            }
            
            screenInput.capturesCursor = true
            screenInput.minFrameDuration = frameDuration
            screenInput.cropRect = cgCropRect
            
            if self.session.canAddInput(screenInput) {
                self.session.addInput(screenInput)
                self.screenInput = screenInput
            } else {
                self.session.commitConfiguration()
                Task { @MainActor in
                    self.isRecording = false
                    self.delegate?.screenRecorderDidFinish(outputURL: nil, error: NSError(domain: "ScreenRecorder", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to add Screen Input"]))
                }
                return
            }
            
            if includeMic {
                if let mic = AVCaptureDevice.default(for: .audio) {
                    do {
                        let micInput = try AVCaptureDeviceInput(device: mic)
                        if self.session.canAddInput(micInput) {
                            self.session.addInput(micInput)
                            self.micInput = micInput
                        }
                    } catch {
                        print("Failed to start mic input: \(error)")
                    }
                }
            }
            
            if self.session.canAddOutput(self.fileOutput) {
                self.session.addOutput(self.fileOutput)
            } else {
                self.session.commitConfiguration()
                Task { @MainActor in
                    self.isRecording = false
                    self.delegate?.screenRecorderDidFinish(outputURL: nil, error: NSError(domain: "ScreenRecorder", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to add File Output"]))
                }
                return
            }
            
            self.session.commitConfiguration()
            self.session.startRunning()
            
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "Recording_\(Int(Date().timeIntervalSince1970)).mp4"
            let fileURL = tempDir.appendingPathComponent(fileName)
            
            Task { @MainActor in
                guard !self.shouldStopAsap else {
                    self.isRecording = false
                    self.sessionQueue.async {
                        self.session.stopRunning()
                    }
                    if self.recordSystemAudio {
                        _ = try? await self.systemAudioRecorder?.stopRecording()
                    }
                    return
                }
                self.tempFileURL = fileURL
                self.fileOutput.startRecording(to: fileURL, recordingDelegate: self)
            }
        }
    }
    
    /// Stops the recording.
    func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        
        if fileOutput.isRecording {
            fileOutput.stopRecording()
        } else {
            shouldStopAsap = true
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension ScreenRecorder: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        Task { @MainActor [weak self] in
            self?.delegate?.screenRecorderDidStart()
        }
    }
    
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: (any Error)?) {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
        
        Task { @MainActor [weak self] in
            guard let self = self else {
                try? FileManager.default.removeItem(at: outputFileURL)
                return
            }
            
            if self.recordSystemAudio, let systemAudioURL = try? await self.systemAudioRecorder?.stopRecording() {
                let tempDir = FileManager.default.temporaryDirectory
                let mergedFileName = "Merged_\(Int(Date().timeIntervalSince1970)).mp4"
                let mergedURL = tempDir.appendingPathComponent(mergedFileName)
                
                do {
                    try await SystemAudioRecorder.merge(videoURL: outputFileURL, systemAudioURL: systemAudioURL, outputURL: mergedURL)
                    
                    try? FileManager.default.removeItem(at: outputFileURL)
                    try? FileManager.default.removeItem(at: systemAudioURL)
                    
                    self.delegate?.screenRecorderDidFinish(outputURL: mergedURL, error: error)
                } catch {
                    print("Merging system audio track failed: \(error)")
                    try? FileManager.default.removeItem(at: systemAudioURL)
                    self.delegate?.screenRecorderDidFinish(outputURL: outputFileURL, error: error)
                }
            } else {
                self.delegate?.screenRecorderDidFinish(outputURL: outputFileURL, error: error)
            }
        }
    }
}
