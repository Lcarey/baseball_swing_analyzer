import AVFoundation
import UIKit
import Combine

class CameraService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var error: CameraError?
    @Published var isAuthorized = false

    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureMovieFileOutput?
    private var videoDevice: AVCaptureDevice?
    private var currentRecordingURL: URL?
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?

    enum CameraError: Error, LocalizedError {
        case unauthorized
        case setupFailed
        case recordingFailed
        case deviceNotFound

        var errorDescription: String? {
            switch self {
            case .unauthorized:
                return "Camera access denied. Please enable camera access in Settings."
            case .setupFailed:
                return "Failed to setup camera. Please try again."
            case .recordingFailed:
                return "Failed to start recording. Please try again."
            case .deviceNotFound:
                return "Camera device not found."
            }
        }
    }

    override init() {
        super.init()
        checkAuthorization()
    }

    // MARK: - Authorization

    @discardableResult
    func checkAuthorization() -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = false
        case .denied, .restricted:
            isAuthorized = false
            error = .unauthorized
        @unknown default:
            isAuthorized = false
        }

        return isAuthorized
    }

    func requestAuthorization() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                if !granted {
                    self?.error = .unauthorized
                }
            }
        }
    }

    // MARK: - Session Setup

    func setupSession() throws -> AVCaptureSession {
        if let captureSession, videoOutput != nil {
            print("CameraService: Reusing existing session")
            return captureSession
        }

        print("CameraService: Starting session setup")
        let session = AVCaptureSession()
        session.beginConfiguration()

        // Set session preset for high quality
        if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
            print("CameraService: Set session preset to .high")
        } else {
            print("CameraService: WARNING - Cannot set .high preset")
        }

        // Get video device
        print("CameraService: Requesting back camera device")
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("CameraService: ERROR - No back camera found")
            throw CameraError.deviceNotFound
        }
        print("CameraService: Found video device: \(videoDevice.localizedName)")
        self.videoDevice = videoDevice

        // Configure device for 60fps
        print("CameraService: Configuring device for 60fps")
        do {
            try configureDevice(videoDevice)
            print("CameraService: Device configured successfully")
        } catch {
            print("CameraService: ERROR - Device configuration failed: \(error)")
            throw error
        }

        // Add video input
        print("CameraService: Creating video input")
        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoDevice)
            print("CameraService: Video input created")
        } catch {
            print("CameraService: ERROR - Failed to create video input: \(error)")
            throw CameraError.setupFailed
        }

        guard session.canAddInput(videoInput) else {
            print("CameraService: ERROR - Cannot add video input to session")
            throw CameraError.setupFailed
        }
        session.addInput(videoInput)
        print("CameraService: Video input added to session")

        // Add movie file output
        print("CameraService: Creating movie output")
        let movieOutput = AVCaptureMovieFileOutput()
        guard session.canAddOutput(movieOutput) else {
            print("CameraService: ERROR - Cannot add movie output to session")
            throw CameraError.setupFailed
        }
        session.addOutput(movieOutput)
        self.videoOutput = movieOutput
        print("CameraService: Movie output added to session")

        // Configure output
        if let connection = movieOutput.connection(with: .video) {
            if connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = .auto
                print("CameraService: Video stabilization enabled")
            }
        }

        session.commitConfiguration()
        self.captureSession = session
        print("CameraService: Session setup complete")

        return session
    }

    private func configureDevice(_ device: AVCaptureDevice) throws {
        try device.lockForConfiguration()

        // Try to set 60fps
        let desiredFrameRate: Double = 60
        var bestFormat: AVCaptureDevice.Format?
        var bestFrameRateRange: AVFrameRateRange?

        for format in device.formats {
            for range in format.videoSupportedFrameRateRanges {
                if range.maxFrameRate >= desiredFrameRate {
                    if bestFrameRateRange == nil || range.maxFrameRate < bestFrameRateRange!.maxFrameRate {
                        bestFormat = format
                        bestFrameRateRange = range
                    }
                }
            }
        }

        if let format = bestFormat, let _ = bestFrameRateRange {
            device.activeFormat = format
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(desiredFrameRate))
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(desiredFrameRate))
        }

        device.unlockForConfiguration()
    }

    // MARK: - Recording

    func startRecording() throws -> URL {
        guard let videoOutput = videoOutput else {
            throw CameraError.setupFailed
        }

        guard !videoOutput.isRecording else {
            return currentRecordingURL!
        }

        // Create unique file URL
        let outputURL = createVideoFileURL()
        currentRecordingURL = outputURL

        // Start recording
        videoOutput.startRecording(to: outputURL, recordingDelegate: self)

        // Start timer
        recordingStartTime = Date()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.recordingStartTime else { return }
            DispatchQueue.main.async {
                self.recordingDuration = Date().timeIntervalSince(startTime)
            }
        }

        DispatchQueue.main.async {
            self.isRecording = true
        }

        return outputURL
    }

    func stopRecording() {
        guard let videoOutput = videoOutput, videoOutput.isRecording else { return }

        videoOutput.stopRecording()
        recordingTimer?.invalidate()
        recordingTimer = nil

        DispatchQueue.main.async {
            self.isRecording = false
            self.recordingDuration = 0
        }
    }

    private func createVideoFileURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videosDirectory = documentsPath.appendingPathComponent(AppConstants.videosDirectory)

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: videosDirectory, withIntermediateDirectories: true)

        let fileName = "recording_\(UUID().uuidString).mov"
        return videosDirectory.appendingPathComponent(fileName)
    }

    // MARK: - Session Control

    func startSession() {
        print("CameraService: Starting capture session")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let session = self?.captureSession else {
                print("CameraService: ERROR - No capture session to start")
                return
            }
            session.startRunning()
            print("CameraService: Capture session started, isRunning: \(session.isRunning)")
        }
    }

    func stopSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.stopRunning()
        }
    }

    func cleanup() {
        stopRecording()
        stopSession()
        captureSession = nil
        videoOutput = nil
        videoDevice = nil
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension CameraService: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Recording error: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.error = .recordingFailed
            }
        } else {
            print("Recording saved to: \(outputFileURL)")
        }
    }

    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        print("Recording started: \(fileURL)")
    }
}
