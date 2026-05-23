import Foundation
import CoreData
import Combine

enum VideoAnalysisResult {
    case success(swingCount: Int)
    case noSwingsDetected(frameCount: Int)
    case failed(message: String)
}

enum DetectionPreviewOutcome {
    case success(SwingDetectionPreviewResult)
    case failed(message: String)
}

class SwingAnalysisViewModel: ObservableObject {
    @Published var isProcessing = false
    @Published var progress: Double = 0
    @Published var statusMessage = ""
    @Published var error: String?

    private let poseDetectionService = PoseDetectionService()
    private let swingDetectionService = SwingDetectionService()
    private let biomechanicsAnalyzer = BiomechanicsAnalyzer()
    private let viewContext: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.viewContext = context
        setupBindings()
    }

    private func setupBindings() {
        poseDetectionService.$isProcessing
            .receive(on: DispatchQueue.main)
            .assign(to: &$isProcessing)

        poseDetectionService.$progress
            .receive(on: DispatchQueue.main)
            .assign(to: &$progress)
    }

    // MARK: - Process Video

    func processVideo(url: URL, for session: Session, completion: @escaping (VideoAnalysisResult) -> Void) {
        statusMessage = "Detecting body pose..."

        poseDetectionService.processVideo(url: url) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let frames):
                self.processFrames(frames, videoURL: url, session: session, completion: completion)

            case .failure(let error):
                DispatchQueue.main.async {
                    let message = "Pose detection failed: \(error.localizedDescription)"
                    self.error = message
                    completion(.failed(message: message))
                }
            }
        }
    }

    func previewDetection(
        url: URL,
        session: Session,
        configuration: SwingDetectionConfiguration,
        completion: @escaping (DetectionPreviewOutcome) -> Void
    ) {
        guard configuration.expectedSwingCount > 0 else {
            completion(.failed(message: "Enter the number of swings in this session before rerunning detection."))
            return
        }

        statusMessage = "Detecting body pose..."

        poseDetectionService.processVideo(url: url) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let frames):
                self.previewFrames(
                    frames,
                    videoURL: url,
                    configuration: configuration,
                    completion: completion
                )

            case .failure(let error):
                DispatchQueue.main.async {
                    let message = "Pose detection failed: \(error.localizedDescription)"
                    self.error = message
                    completion(.failed(message: message))
                }
            }
        }
    }

    func replaceSessionSwings(
        session: Session,
        previewResult: SwingDetectionPreviewResult,
        configuration: SwingDetectionConfiguration,
        completion: @escaping (Result<Int, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let saved = self.saveSwings(
                swings: previewResult.proposedSwings,
                analysisResults: previewResult.analysisResults,
                frames: previewResult.frames,
                videoURL: previewResult.videoURL,
                session: session,
                configuration: configuration,
                replaceExisting: true
            )

            DispatchQueue.main.async {
                if saved {
                    completion(.success(previewResult.selectedCandidates.count))
                } else {
                    completion(.failure(NSError(
                        domain: "SwingAnalysis",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to save replacement swing detection results."]
                    )))
                }
            }
        }
    }

    // MARK: - Process Frames

    private func processFrames(_ frames: [FrameJointData], videoURL: URL, session: Session, completion: @escaping (VideoAnalysisResult) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.statusMessage = "Detecting swings..."
            }

            // Calculate velocities
            let velocities = self.poseDetectionService.calculateVelocities(frames: frames)

            // Detect swings
            let swings = self.swingDetectionService.detectSwings(from: frames, velocities: velocities)
            print("SwingAnalysis: poseFrames=\(frames.count), velocityFrames=\(velocities.count), detectedSwings=\(swings.count)")

            guard !swings.isEmpty else {
                self.saveEmptyAnalysis(for: session)
                DispatchQueue.main.async {
                    self.statusMessage = "No swings detected"
                    completion(.noSwingsDetected(frameCount: frames.count))
                }
                return
            }

            DispatchQueue.main.async {
                self.statusMessage = "Analyzing biomechanics..."
            }

            // Analyze each swing
            let analysisResults = self.analysisResultsForSwings(swings, frames: frames)

            // Save to Core Data
            self.saveSwings(
                swings: swings,
                analysisResults: analysisResults,
                frames: frames,
                videoURL: videoURL,
                session: session,
                configuration: nil,
                replaceExisting: false
            )

            DispatchQueue.main.async {
                self.statusMessage = "Complete!"
                completion(.success(swingCount: swings.count))
            }
        }
    }

    private func previewFrames(
        _ frames: [FrameJointData],
        videoURL: URL,
        configuration: SwingDetectionConfiguration,
        completion: @escaping (DetectionPreviewOutcome) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.statusMessage = "Detecting swing candidates..."
            }

            let velocities = self.poseDetectionService.calculateVelocities(frames: frames)
            let candidates = self.swingDetectionService.detectCandidates(
                from: frames,
                velocities: velocities,
                configuration: configuration
            )

            guard candidates.count >= configuration.expectedSwingCount else {
                DispatchQueue.main.async {
                    completion(.failed(message: "Found \(candidates.count) candidate swing\(candidates.count == 1 ? "" : "s"), but expected \(configuration.expectedSwingCount). Try a more sensitive preset or lower the expected count."))
                }
                return
            }

            DispatchQueue.main.async {
                self.statusMessage = "Analyzing proposed swings..."
            }

            let selectedCandidates = Array(candidates.prefix(configuration.expectedSwingCount))
                .sorted { $0.swing.startTime < $1.swing.startTime }
            let selectedSwings = selectedCandidates.map(\.swing)
            let analysisResults = self.analysisResultsForSwings(selectedSwings, frames: frames)
            let preview = SwingDetectionPreviewResult(
                configuration: configuration,
                videoURL: videoURL,
                frames: frames,
                allCandidates: candidates,
                selectedCandidates: selectedCandidates,
                analysisResults: analysisResults
            )

            DispatchQueue.main.async {
                self.statusMessage = "Preview ready"
                completion(.success(preview))
            }
        }
    }

    // MARK: - Save to Core Data

    private func saveEmptyAnalysis(for session: Session) {
        let context = viewContext

        context.performAndWait {
            session.swingCount = 0
            session.averageScore = 0

            do {
                try context.save()
            } catch {
                print("Failed to save empty analysis result: \(error)")
                DispatchQueue.main.async {
                    self.error = "Failed to save analysis results"
                }
            }
        }
    }

    @discardableResult
    private func saveSwings(
        swings: [SwingData],
        analysisResults: [SwingAnalysisResult],
        frames: [FrameJointData],
        videoURL: URL,
        session: Session,
        configuration: SwingDetectionConfiguration?,
        replaceExisting: Bool
    ) -> Bool {
        let context = viewContext
        var didSave = false

        context.performAndWait {
            if replaceExisting {
                for swing in session.swingsArray {
                    context.delete(swing)
                }
            }

            for (index, swingData) in swings.enumerated() {
                // Create Swing entity
                let swing = Swing(context: context)
                swing.id = UUID()
                swing.timestamp = session.date.addingTimeInterval(swingData.startTime)
                swing.videoURL = videoURL.path
                swing.duration = swingData.duration
                swing.session = session

                // Get metrics for this swing
                if index < analysisResults.count {
                    let analysisResult = analysisResults[index]
                    let swingMetrics = analysisResult.legacyMetrics

                    // Create SwingMetrics entity
                    let metricsEntity = SwingMetrics(context: context)
                    metricsEntity.id = UUID()
                    metricsEntity.kneeBend = swingMetrics.kneeBend
                    metricsEntity.hipRotation = swingMetrics.hipRotation
                    metricsEntity.hipHorizontalMovement = swingMetrics.hipHorizontalMovement
                    metricsEntity.hipVerticalMovement = swingMetrics.hipVerticalMovement
                    metricsEntity.hipShoulderAlignment = swingMetrics.hipShoulderAlignment
                    metricsEntity.timeToContact = swingMetrics.timeToContact
                    metricsEntity.analysisVersion = analysisResult.scoreBreakdown.analysisVersion
                    metricsEntity.scoreConfidence = analysisResult.scoreBreakdown.confidence.rawValue
                    metricsEntity.scoreBreakdownJSON = analysisResult.scoreBreakdown.encodedJSONString
                    metricsEntity.phaseMarkersJSON = analysisResult.phaseMarkers.encodedJSONString
                    metricsEntity.advancedMetricsJSON = analysisResult.advancedMetrics.encodedJSONString
                    metricsEntity.swing = swing

                    // Calculate and store score
                    swing.score = analysisResult.scoreBreakdown.finalScore
                }

                // Save joint data for this swing
                let swingFrames = frames.filter { frame in
                    frame.timestamp >= swingData.startTime && frame.timestamp <= swingData.endTime
                }

                for frame in swingFrames {
                    let jointData = JointData(context: context)
                    jointData.id = UUID()
                    jointData.frameNumber = Int32(frame.frameNumber)
                    jointData.timestamp = frame.timestamp
                    jointData.jointPositionsJSON = encodeJoints(frame.joints)
                    jointData.swing = swing
                }
            }

            // Update session
            session.swingCount = Int16(swings.count)
            session.lastDetectionSettingsJSON = configuration?.settingsJSON ?? session.lastDetectionSettingsJSON
            if !swings.isEmpty {
                let totalScore = swings.enumerated().reduce(0.0) { total, item in
                    if item.offset < analysisResults.count {
                        return total + analysisResults[item.offset].scoreBreakdown.finalScore
                    }
                    return total
                }
                session.averageScore = totalScore / Double(swings.count)
            }

            // Save context
            do {
                try context.save()
                didSave = true
            } catch {
                print("Failed to save context: \(error)")
                DispatchQueue.main.async {
                    self.error = "Failed to save analysis results"
                }
            }
        }

        return didSave
    }

    private func analysisResultsForSwings(_ swings: [SwingData], frames: [FrameJointData]) -> [SwingAnalysisResult] {
        swings.map { swing in
            let swingFrames = frames.filter { frame in
                frame.timestamp >= swing.startTime && frame.timestamp <= swing.endTime
            }

            return biomechanicsAnalyzer.analyzeSwing(
                frames: swingFrames,
                swingData: swing,
                context: .youthHighSchoolDefault
            ) ?? fallbackAnalysisResult(for: swing)
        }
    }

    private func fallbackAnalysisResult(for swing: SwingData) -> SwingAnalysisResult {
        let phaseMarkers = SwingPhaseMarkers(
            setupTime: swing.startTime,
            heelStrikeTime: swing.startTime,
            firstMoveTime: swing.startTime,
            contactTime: swing.peakVelocityTime,
            setupFrame: 0,
            heelStrikeFrame: 0,
            firstMoveFrame: 0,
            contactFrame: 0
        )
        let advancedMetrics = AdvancedSwingMetrics(
            hipShoulderSeparationAtFirstMove: 0,
            hipShoulderSeparationAtContact: 0,
            pelvisRotationAtContact: 0,
            torsoRotationAtContact: 0,
            leadKneeFlexionAtHeelStrike: 0,
            leadKneeFlexionAtContact: 0,
            leadKneeExtensionToContact: 0,
            timeToContact: max(0, swing.peakVelocityTime - swing.startTime),
            torsoForwardBendAtHeelStrike: 0,
            torsoForwardBendAtContact: 0,
            pelvisThrustProxy: 0,
            peakPelvisAngularVelocity: 0,
            peakTorsoAngularVelocity: 0,
            peakHandVelocity: 0,
            hipHorizontalMovement: 0,
            hipVerticalMovement: 0
        )
        let poseQuality = PoseQualityReport(
            totalFrames: 0,
            framesWithCoreJoints: 0,
            keyJointAvailability: 0,
            detectionRate: 0,
            jitterScore: 0,
            confidence: .low,
            warnings: ["Not enough pose frames to calculate biomechanics."]
        )
        let scoreBreakdown = SwingScoreBreakdown(
            analysisVersion: "scoring_v2_youth_hs",
            profileID: SwingScoringProfile.youthHighSchoolDefault.id,
            profileName: SwingScoringProfile.youthHighSchoolDefault.displayName,
            rawScore: 0,
            finalScore: 0,
            confidence: .low,
            components: [],
            warnings: poseQuality.warnings
        )
        let metrics = BiomechanicsMetrics(
            kneeBend: 0,
            hipRotation: 0,
            hipHorizontalMovement: 0,
            hipVerticalMovement: 0,
            hipShoulderAlignment: 0,
            timeToContact: advancedMetrics.timeToContact,
            scoreBreakdown: scoreBreakdown
        )

        return SwingAnalysisResult(
            legacyMetrics: metrics,
            advancedMetrics: advancedMetrics,
            phaseMarkers: phaseMarkers,
            poseQuality: poseQuality,
            scoreBreakdown: scoreBreakdown,
            warnings: poseQuality.warnings
        )
    }

    // MARK: - Encode Joints

    private func encodeJoints(_ joints: [String: CGPoint]) -> String {
        var dict: [String: [String: Double]] = [:]

        for (key, point) in joints {
            dict[key] = [
                "x": Double(point.x),
                "y": Double(point.y)
            ]
        }

        guard let jsonData = try? JSONEncoder().encode(dict),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "{}"
        }

        return jsonString
    }
}
