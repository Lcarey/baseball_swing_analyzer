import AVFoundation
import UIKit
import Combine
import Vision

class CameraService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var error: CameraError?
    @Published var isAuthorized = false
    @Published var livePoseJoints: [String: CGPoint]?

    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureMovieFileOutput?
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var videoDevice: AVCaptureDevice?
    private var currentRecordingURL: URL?
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var recordingCompletion: ((Result<URL, Error>) -> Void)?
    private let livePoseQueue = DispatchQueue(label: "com.swinganalyzer.livePoseQueue", qos: .userInitiated)
    private var lastLivePoseTime: CFTimeInterval = 0
    private var isProcessingLivePoseFrame = false
    private let livePoseInterval: CFTimeInterval = 0.1
    private let confidenceThreshold: Float = AppConstants.confidenceThreshold

    enum CameraError: Error, LocalizedError {
        case unauthorized
        case setupFailed
        case recordingFailed
        case deviceNotFound
        case unsupportedFrameRate(requested: Int, maxAvailable: Int)
        case exposureControlUnavailable
        case configurationFailed(reason: String)

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
            case .unsupportedFrameRate(let requested, let maxAvailable):
                return "This device doesn't support \(requested) FPS recording. Maximum: \(maxAvailable) FPS. iPhone 13 Pro or newer required."
            case .exposureControlUnavailable:
                return "Manual exposure control unavailable. Cannot set fast shutter speed for swing analysis."
            case .configurationFailed(let reason):
                return "Camera configuration failed: \(reason)"
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

        // Configure device for high-frame-rate swing capture.
        print("CameraService: Configuring device for \(AppConstants.frameRate)fps")
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

        // Add video data output for screen-only live pose detection. Recording can still
        // proceed if this auxiliary stream is unavailable on a device.
        print("CameraService: Creating live pose video data output")
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            videoDataOutput.setSampleBufferDelegate(self, queue: livePoseQueue)
            self.videoDataOutput = videoDataOutput
            print("CameraService: Live pose video data output added to session")
        } else {
            print("CameraService: WARNING - Cannot add live pose video data output; recording will continue without overlay")
        }

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
        defer { device.unlockForConfiguration() }

        print("CameraService: === Starting Camera Configuration ===")

        // STEP 1: Configure 120 FPS (required, hard fail if unsupported)
        let desiredFrameRate = Double(AppConstants.frameRate)
        print("CameraService: Target frame rate: \(Int(desiredFrameRate)) FPS")

        guard let selectedFormat = selectBestFormat(for: device, targetFPS: desiredFrameRate) else {
            let maxAvailable = findMaxAvailableFrameRate(for: device)
            print("CameraService: ERROR - \(Int(desiredFrameRate)) FPS not supported. Max: \(maxAvailable) FPS")
            throw CameraError.unsupportedFrameRate(requested: Int(desiredFrameRate), maxAvailable: maxAvailable)
        }

        device.activeFormat = selectedFormat
        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(AppConstants.frameRate))
        device.activeVideoMinFrameDuration = frameDuration
        device.activeVideoMaxFrameDuration = frameDuration
        print("CameraService: Frame rate set to \(Int(desiredFrameRate)) FPS")

        guard device.activeVideoMinFrameDuration == frameDuration,
              device.activeVideoMaxFrameDuration == frameDuration else {
            throw CameraError.configurationFailed(reason: "Could not apply \(AppConstants.frameRate) FPS frame duration.")
        }

        // STEP 2: Detect lighting conditions (sample auto-exposure before switching to manual)
        let currentISO = device.iso
        let currentExposureDuration = device.exposureDuration
        let currentExposureSeconds = CMTimeGetSeconds(currentExposureDuration)
        let currentShutterFraction = shutterFraction(for: currentExposureDuration)

        if currentShutterFraction > 0 {
            print("CameraService: Current auto-exposure - ISO: \(Int(currentISO)), Shutter: 1/\(currentShutterFraction)s")
        } else {
            print("CameraService: Current auto-exposure - ISO: \(Int(currentISO)), Shutter: unknown (\(currentExposureSeconds)s)")
        }

        // STEP 3: Select appropriate shutter speed based on lighting
        let targetShutterSpeed: CMTime
        let lightingCondition: String

        if currentISO < AppConstants.lowLightISOThreshold {
            targetShutterSpeed = AppConstants.shutterSpeedFast
            lightingCondition = "bright"
        } else {
            targetShutterSpeed = AppConstants.shutterSpeedMedium
            lightingCondition = "dim"
        }

        let targetShutterFraction = shutterFraction(for: targetShutterSpeed)
        print("CameraService: Lighting: \(lightingCondition) -> Selected shutter: 1/\(targetShutterFraction)s")

        // STEP 4: Validate exposure control availability
        guard device.isExposureModeSupported(.custom) else {
            print("CameraService: ERROR - Custom exposure mode not supported")
            throw CameraError.exposureControlUnavailable
        }

        // STEP 5: Calculate ISO to maintain brightness when switching to fast shutter
        let targetISO = calculateTargetISO(
            currentISO: currentISO,
            currentExposureDuration: currentExposureDuration,
            targetExposureDuration: targetShutterSpeed,
            device: device
        )

        print("CameraService: Calculated target ISO: \(Int(targetISO)) (range: \(Int(device.activeFormat.minISO))-\(Int(device.activeFormat.maxISO)))")

        // STEP 6: Apply manual exposure settings
        device.setExposureModeCustom(duration: targetShutterSpeed, iso: targetISO) { time in
            print("CameraService: Manual exposure applied at time: \(time)")
        }

        // STEP 7: Verify configuration (async readback after short delay)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.verifyDeviceConfiguration(device)
        }

        print("CameraService: === Configuration Complete ===")
    }

    private func selectBestFormat(for device: AVCaptureDevice, targetFPS: Double) -> AVCaptureDevice.Format? {
        var bestFormat: AVCaptureDevice.Format?
        var bestFrameRateRange: AVFrameRateRange?

        for format in device.formats {
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            guard dimensions.height >= AppConstants.videoWidth else { continue }

            for range in format.videoSupportedFrameRateRanges where range.minFrameRate <= targetFPS && range.maxFrameRate >= targetFPS {
                if bestFrameRateRange == nil || range.maxFrameRate < bestFrameRateRange!.maxFrameRate {
                    bestFormat = format
                    bestFrameRateRange = range
                }
            }
        }

        if let format = bestFormat, let range = bestFrameRateRange {
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            print("CameraService: Selected format - Resolution: \(dimensions.width)x\(dimensions.height), FPS: \(range.minFrameRate)-\(range.maxFrameRate)")
        }

        return bestFormat
    }

    private func findMaxAvailableFrameRate(for device: AVCaptureDevice) -> Int {
        var maxFPS: Double = 0

        for format in device.formats {
            for range in format.videoSupportedFrameRateRanges {
                maxFPS = max(maxFPS, range.maxFrameRate)
            }
        }

        return Int(maxFPS)
    }

    private func calculateTargetISO(
        currentISO: Float,
        currentExposureDuration: CMTime,
        targetExposureDuration: CMTime,
        device: AVCaptureDevice
    ) -> Float {
        let currentDuration = CMTimeGetSeconds(currentExposureDuration)
        let targetDuration = CMTimeGetSeconds(targetExposureDuration)

        guard targetDuration > 0, currentDuration > 0 else {
            print("CameraService: WARNING - Invalid duration, using current ISO")
            return currentISO
        }

        let compensationFactor = currentDuration / targetDuration
        let calculatedISO = currentISO * Float(compensationFactor)
        let clampedISO = max(device.activeFormat.minISO, min(device.activeFormat.maxISO, calculatedISO))

        if clampedISO >= device.activeFormat.maxISO * 0.95 {
            print("CameraService: WARNING - ISO at 95% of max (\(Int(clampedISO))), may be underexposed in low light")
        }

        return clampedISO
    }

    private func verifyDeviceConfiguration(_ device: AVCaptureDevice) {
        let actualFrameDurationSeconds = CMTimeGetSeconds(device.activeVideoMinFrameDuration)
        let actualFPS = actualFrameDurationSeconds > 0 ? 1.0 / actualFrameDurationSeconds : 0
        let actualISO = device.iso
        let actualExposure = device.exposureDuration
        let actualShutterFraction = shutterFraction(for: actualExposure)

        print("CameraService: === Configuration Verification ===")
        print("CameraService: Frame Rate: \(String(format: "%.1f", actualFPS)) FPS")
        print("CameraService: ISO: \(Int(actualISO)) (range: \(Int(device.activeFormat.minISO))-\(Int(device.activeFormat.maxISO)))")

        if actualShutterFraction > 0 {
            print("CameraService: Shutter: 1/\(actualShutterFraction)s")
        } else {
            print("CameraService: Shutter: unknown")
        }

        print("CameraService: Exposure Mode: \(device.exposureMode.rawValue)")
        print("CameraService: ====================================")
    }

    private func shutterFraction(for exposureDuration: CMTime) -> Int {
        let seconds = CMTimeGetSeconds(exposureDuration)
        guard seconds.isFinite, seconds > 0 else { return 0 }
        return Int((1.0 / seconds).rounded())
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

    func stopRecording(completion: ((Result<URL, Error>) -> Void)? = nil) {
        guard let videoOutput = videoOutput, videoOutput.isRecording else {
            if let currentRecordingURL {
                completion?(.success(currentRecordingURL))
            } else {
                completion?(.failure(CameraError.recordingFailed))
            }
            return
        }

        recordingCompletion = completion
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
        videoDataOutput?.setSampleBufferDelegate(nil, queue: nil)
        captureSession = nil
        videoOutput = nil
        videoDataOutput = nil
        videoDevice = nil
        DispatchQueue.main.async {
            self.livePoseJoints = nil
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension CameraService: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        let completion = recordingCompletion
        recordingCompletion = nil

        if let error = error, !recordingFinishedSuccessfully(error) {
            print("Recording error: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.error = .recordingFailed
                completion?(.failure(error))
            }
        } else {
            print("Recording saved to: \(outputFileURL)")
            DispatchQueue.main.async {
                completion?(.success(outputFileURL))
            }
        }
    }

    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        print("Recording started: \(fileURL)")
    }

    private func recordingFinishedSuccessfully(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool == true
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = CACurrentMediaTime()
        guard now - lastLivePoseTime >= livePoseInterval else { return }
        guard !isProcessingLivePoseFrame else { return }

        lastLivePoseTime = now
        isProcessingLivePoseFrame = true
        defer { isProcessingLivePoseFrame = false }

        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let joints = detectLivePose(in: imageBuffer)

        DispatchQueue.main.async {
            self.livePoseJoints = joints
        }
    }

    private func detectLivePose(in imageBuffer: CVPixelBuffer) -> [String: CGPoint]? {
        let request = VNDetectHumanBodyPoseRequest()
        request.revision = VNDetectHumanBodyPoseRequestRevision1

        let handler = VNImageRequestHandler(
            cvPixelBuffer: imageBuffer,
            orientation: .right,
            options: [:]
        )

        do {
            try handler.perform([request])

            guard let observation = request.results?.first else {
                return nil
            }

            return extractLiveJointPoints(from: observation)
        } catch {
            print("CameraService: Live pose detection failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func extractLiveJointPoints(from observation: VNHumanBodyPoseObservation) -> [String: CGPoint]? {
        var joints: [String: CGPoint] = [:]

        for jointName in VisionJointMapping.trackedJointNames {
            guard let point = try? observation.recognizedPoint(jointName),
                  point.confidence > confidenceThreshold else {
                continue
            }

            joints[VisionJointMapping.appKey(for: jointName)] = point.location
        }

        return joints.count >= 8 ? joints : nil
    }
}
