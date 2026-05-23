import Foundation
import AVFoundation
import Combine
import CoreData
import UIKit

class RecordingViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var captureSession: AVCaptureSession?
    @Published var error: String?
    @Published var showError = false
    @Published var isAuthorized = false
    @Published var isProcessing = false
    @Published var processingMessage = ""
    @Published var processingProgress: Double = 0
    @Published var dismissAfterError = false
    @Published var livePoseJoints: [String: CGPoint]?

    private let cameraService = CameraService()
    private var cancellables = Set<AnyCancellable>()
    private var analysisCancellables = Set<AnyCancellable>()
    private var recordingURL: URL?
    private var analysisViewModel: SwingAnalysisViewModel?
    private let viewContext: NSManagedObjectContext

    var session: Session?

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.viewContext = context
        setupBindings()
    }

    private func setupBindings() {
        cameraService.$isRecording
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRecording)

        cameraService.$recordingDuration
            .receive(on: DispatchQueue.main)
            .assign(to: &$recordingDuration)

        cameraService.$isAuthorized
            .receive(on: DispatchQueue.main)
            .assign(to: &$isAuthorized)

        cameraService.$livePoseJoints
            .receive(on: DispatchQueue.main)
            .assign(to: &$livePoseJoints)

        cameraService.$error
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                if let error = error {
                    self?.error = error.localizedDescription
                    self?.showError = true
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Camera Setup

    func setupCamera() {
        if captureSession != nil {
            print("RecordingViewModel: Camera already setup")
            return
        }

        print("RecordingViewModel: Setting up camera")
        do {
            let session = try cameraService.setupSession()
            print("RecordingViewModel: Camera session created successfully")
            captureSession = session
            print("RecordingViewModel: Capture session assigned to published property")
            cameraService.startSession()
        } catch {
            print("RecordingViewModel: ERROR - Camera setup failed: \(error)")
            DispatchQueue.main.async {
                self.error = "Failed to setup camera: \(error.localizedDescription)"
                self.showError = true
            }
        }
    }

    func checkCameraAuthorization() -> Bool {
        cameraService.checkAuthorization()
    }

    func requestCameraAccess() {
        cameraService.requestAuthorization()
        // Recheck after a delay to pick up changes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.cameraService.checkAuthorization()
        }
    }

    // MARK: - Recording Control

    func startRecording() {
        guard captureSession != nil else {
            error = "Camera is not ready yet. Please wait a moment and try again."
            showError = true
            return
        }

        do {
            recordingURL = try cameraService.startRecording()

            if session == nil {
                createSession()
            }

            session?.date = Date()
            session?.recordingURL = recordingURL?.path
            session?.recordingDuration = 0
            saveContext()
        } catch {
            self.error = "Failed to start recording: \(error.localizedDescription)"
            self.showError = true
        }
    }

    func stopRecording(completion: @escaping (URL?) -> Void) {
        let fallbackDuration = recordingDuration
        isProcessing = true
        processingMessage = "Finishing recording..."
        processingProgress = 0

        cameraService.stopRecording { [weak self] result in
            guard let self = self else {
                completion(nil)
                return
            }

            switch result {
            case .success(let url):
                self.finishRecording(url: url, fallbackDuration: fallbackDuration, completion: completion)

            case .failure(let error):
                self.isProcessing = false
                self.error = "Recording failed to finish: \(error.localizedDescription)"
                self.showError = true
                completion(nil)
            }
        }
    }

    private func finishRecording(url: URL, fallbackDuration: TimeInterval, completion: @escaping (URL?) -> Void) {
        Task { @MainActor in
            if FileManager.default.fileExists(atPath: url.path) {
                let duration = await self.recordingDuration(from: url, fallbackDuration: fallbackDuration)
                let thumbnailData = await self.thumbnailData(from: url)
                self.updateRecordingMetadata(url: url, duration: duration, thumbnailData: thumbnailData)
                completion(url)
            } else {
                self.isProcessing = false
                self.error = "Recording file not found"
                self.showError = true
                completion(nil)
            }
        }
    }

    // MARK: - Session Management

    func createSession() {
        let newSession = Session(context: viewContext)
        newSession.id = UUID()
        newSession.date = Date()
        newSession.averageScore = 0
        newSession.recordingDuration = 0
        newSession.swingCount = 0
        self.session = newSession

        saveContext()
    }

    private func recordingDuration(from url: URL, fallbackDuration: TimeInterval) async -> TimeInterval {
        do {
            let duration = try await AVAsset(url: url).load(.duration)
            let seconds = CMTimeGetSeconds(duration)
            if seconds.isFinite && seconds > 0 {
                return seconds
            }
        } catch {
            print("Failed to load recording duration: \(error)")
        }

        return fallbackDuration
    }

    private func thumbnailData(from url: URL) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            let asset = AVAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true

            do {
                let imageTime = CMTime(seconds: 0.2, preferredTimescale: 600)
                let image = try generator.copyCGImage(at: imageTime, actualTime: nil)
                return UIImage(cgImage: image).jpegData(compressionQuality: 0.75)
            } catch {
                print("Failed to generate recording thumbnail: \(error)")
                return nil
            }
        }.value
    }

    private func updateRecordingMetadata(url: URL, duration: TimeInterval, thumbnailData: Data?) {
        guard let session = session else { return }
        session.recordingURL = url.path
        session.recordingDuration = duration
        if let thumbnailData {
            session.thumbnailData = thumbnailData
        }
        saveContext()
    }

    func saveRecording(url: URL, completion: @escaping (Bool) -> Void) {
        guard let session = session else {
            createSession()
            saveRecording(url: url, completion: completion)
            return
        }

        print("Recording saved: \(url.path)")
        print("Session: \(session.id)")
        isProcessing = true
        processingMessage = "Detecting body pose..."
        processingProgress = 0
        dismissAfterError = false

        // Start video processing
        let analysisVM = SwingAnalysisViewModel(context: viewContext)
        analysisViewModel = analysisVM
        bindAnalysisProgress(analysisVM)
        analysisVM.processVideo(url: url, for: session) { [weak self] result in
            guard let self = self else { return }

            self.analysisCancellables.removeAll()
            self.analysisViewModel = nil

            switch result {
            case .success(let swingCount):
                print("Video analysis complete: \(swingCount) swing(s)")
                self.isProcessing = false
                completion(true)

            case .noSwingsDetected(let frameCount):
                print("Video analysis complete: no swings detected from \(frameCount) pose frame(s)")
                self.isProcessing = false
                self.dismissAfterError = true
                self.error = "No swing detected. Processed \(frameCount) pose frames. Try a clear side view with the full body in frame."
                self.showError = true
                completion(false)

            case .failed(let message):
                print("Video analysis failed: \(message)")
                self.isProcessing = false
                self.dismissAfterError = true
                self.error = message
                self.showError = true
                completion(false)
            }
        }
    }

    private func bindAnalysisProgress(_ analysisVM: SwingAnalysisViewModel) {
        analysisCancellables.removeAll()

        analysisVM.$statusMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                if !message.isEmpty {
                    self?.processingMessage = message
                }
            }
            .store(in: &analysisCancellables)

        analysisVM.$progress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.processingProgress = progress
            }
            .store(in: &analysisCancellables)
    }

    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving context: \(error)")
            self.error = "Failed to save session"
            self.showError = true
        }
    }

    // MARK: - Cleanup

    func cleanup() {
        cameraService.cleanup()
        captureSession = nil
        livePoseJoints = nil
    }

    deinit {
        cleanup()
    }
}
