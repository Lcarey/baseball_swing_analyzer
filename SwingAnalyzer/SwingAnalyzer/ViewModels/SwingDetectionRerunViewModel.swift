import Foundation
import Combine
import CoreData

class SwingDetectionRerunViewModel: ObservableObject {
    @Published var configuration: SwingDetectionConfiguration
    @Published var previewResult: SwingDetectionPreviewResult?
    @Published var isProcessing = false
    @Published var progress: Double = 0
    @Published var statusMessage = ""
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var replacementComplete = false

    private let session: Session
    private let analysisViewModel: SwingAnalysisViewModel
    private var cancellables = Set<AnyCancellable>()

    init(
        session: Session,
        context: NSManagedObjectContext = PersistenceController.shared.container.viewContext
    ) {
        self.session = session
        var initialConfiguration = SwingDetectionConfiguration.forSession(session)
        if initialConfiguration.expectedSwingCount <= 0 {
            let currentCount = Int(session.swingCount)
            initialConfiguration.expectedSwingCount = currentCount > 0 ? currentCount : 1
        }
        self.configuration = initialConfiguration
        self.analysisViewModel = SwingAnalysisViewModel(context: context)
        bindAnalysis()
    }

    func applySensitivityPreset(_ preset: SwingDetectionSensitivityPreset) {
        configuration = configuration.applyingSensitivityPreset(preset)
        previewResult = nil
    }

    func updateExpectedSwingCount(_ count: Int) {
        configuration.expectedSwingCount = max(1, count)
        previewResult = nil
    }

    func applyCameraAnglePreset(_ preset: SwingDetectionCameraAnglePreset) {
        configuration = configuration.applyingCameraAnglePreset(preset)
        previewResult = nil
    }

    func updateAdvanced(_ update: (inout SwingDetectionConfiguration) -> Void) {
        update(&configuration)
        configuration.sensitivityPreset = .custom
        previewResult = nil
    }

    func runPreview() {
        guard configuration.expectedSwingCount > 0 else {
            presentError("Expected swing count is required.")
            return
        }

        guard let recordingURL = session.recordingFileURL,
              FileManager.default.fileExists(atPath: recordingURL.path) else {
            presentError("The source recording file could not be found.")
            return
        }

        previewResult = nil
        replacementComplete = false
        isProcessing = true
        statusMessage = "Preparing rerun..."

        analysisViewModel.previewDetection(
            url: recordingURL,
            session: session,
            configuration: configuration
        ) { [weak self] outcome in
            guard let self = self else { return }

            self.isProcessing = false

            switch outcome {
            case .success(let preview):
                self.previewResult = preview
                self.statusMessage = "Preview ready"

            case .failed(let message):
                self.presentError(message)
                self.statusMessage = "Preview failed"
            }
        }
    }

    func replaceCurrentResults() {
        guard let previewResult else {
            presentError("Run preview before replacing results.")
            return
        }

        isProcessing = true
        replacementComplete = false
        statusMessage = "Replacing swing results..."

        analysisViewModel.replaceSessionSwings(
            session: session,
            previewResult: previewResult,
            configuration: configuration
        ) { [weak self] result in
            guard let self = self else { return }

            self.isProcessing = false

            switch result {
            case .success(let swingCount):
                self.statusMessage = "Saved \(swingCount) swing\(swingCount == 1 ? "" : "s")"
                self.replacementComplete = true

            case .failure(let error):
                self.presentError(error.localizedDescription)
                self.statusMessage = "Replacement failed"
            }
        }
    }

    private func bindAnalysis() {
        analysisViewModel.$progress
            .receive(on: DispatchQueue.main)
            .assign(to: &$progress)

        analysisViewModel.$statusMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                guard !message.isEmpty else { return }
                self?.statusMessage = message
            }
            .store(in: &cancellables)

        analysisViewModel.$error
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                if let error {
                    self?.presentError(error)
                }
            }
            .store(in: &cancellables)
    }

    private func presentError(_ message: String) {
        errorMessage = message
        showError = true
    }
}
