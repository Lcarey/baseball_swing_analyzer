import Foundation
import AVFoundation
import Combine
import CoreData

class RecordingViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var captureSession: AVCaptureSession?
    @Published var error: String?
    @Published var showError = false
    @Published var isAuthorized = false

    private let cameraService = CameraService()
    private var cancellables = Set<AnyCancellable>()
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
            session?.recordingDuration = 0
            saveContext()
        } catch {
            self.error = "Failed to start recording: \(error.localizedDescription)"
            self.showError = true
        }
    }

    func stopRecording(completion: @escaping (URL?) -> Void) {
        let fallbackDuration = recordingDuration
        cameraService.stopRecording()

        // Give it a moment to finish writing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self, let url = self.recordingURL else {
                completion(nil)
                return
            }

            // Verify file exists
            if FileManager.default.fileExists(atPath: url.path) {
                Task { @MainActor in
                    let duration = await self.recordingDuration(from: url, fallbackDuration: fallbackDuration)
                    self.updateRecordingDuration(duration)
                    completion(url)
                }
            } else {
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

    private func updateRecordingDuration(_ duration: TimeInterval) {
        guard let session = session else { return }
        session.recordingDuration = duration
        saveContext()
    }

    func saveRecording(url: URL, completion: @escaping () -> Void) {
        guard let session = session else {
            createSession()
            saveRecording(url: url, completion: completion)
            return
        }

        print("Recording saved: \(url.path)")
        print("Session: \(session.id)")

        // Start video processing
        let analysisVM = SwingAnalysisViewModel(context: viewContext)
        analysisViewModel = analysisVM
        analysisVM.processVideo(url: url, for: session) { success in
            if success {
                print("Video analysis complete!")
            } else {
                print("Video analysis failed")
            }
            self.analysisViewModel = nil
            completion()
        }
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
    }

    deinit {
        cleanup()
    }
}
