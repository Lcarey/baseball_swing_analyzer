import Foundation
import CoreData
import Combine

enum VideoAnalysisResult {
    case success(swingCount: Int)
    case noSwingsDetected(frameCount: Int)
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
            let metricsResults = self.biomechanicsAnalyzer.analyzeMultipleSwings(
                allFrames: frames,
                swings: swings
            )

            // Save to Core Data
            self.saveSwings(
                swings: swings,
                metrics: metricsResults,
                frames: frames,
                videoURL: videoURL,
                session: session
            )

            DispatchQueue.main.async {
                self.statusMessage = "Complete!"
                completion(.success(swingCount: swings.count))
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

    private func saveSwings(swings: [SwingData], metrics: [BiomechanicsMetrics], frames: [FrameJointData], videoURL: URL, session: Session) {
        let context = viewContext

        context.performAndWait {
            for (index, swingData) in swings.enumerated() {
                // Create Swing entity
                let swing = Swing(context: context)
                swing.id = UUID()
                swing.timestamp = session.date.addingTimeInterval(swingData.startTime)
                swing.videoURL = videoURL.path
                swing.duration = swingData.duration
                swing.session = session

                // Get metrics for this swing
                if index < metrics.count {
                    let swingMetrics = metrics[index]

                    // Create SwingMetrics entity
                    let metricsEntity = SwingMetrics(context: context)
                    metricsEntity.id = UUID()
                    metricsEntity.kneeBend = swingMetrics.kneeBend
                    metricsEntity.hipRotation = swingMetrics.hipRotation
                    metricsEntity.hipHorizontalMovement = swingMetrics.hipHorizontalMovement
                    metricsEntity.hipVerticalMovement = swingMetrics.hipVerticalMovement
                    metricsEntity.hipShoulderAlignment = swingMetrics.hipShoulderAlignment
                    metricsEntity.timeToContact = swingMetrics.timeToContact
                    metricsEntity.swing = swing

                    // Calculate and store score
                    swing.score = swingMetrics.compositeScore
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
            if !swings.isEmpty {
                let totalScore = swings.enumerated().reduce(0.0) { total, item in
                    if item.offset < metrics.count {
                        return total + metrics[item.offset].compositeScore
                    }
                    return total
                }
                session.averageScore = totalScore / Double(swings.count)
            }

            // Save context
            do {
                try context.save()
            } catch {
                print("Failed to save context: \(error)")
                DispatchQueue.main.async {
                    self.error = "Failed to save analysis results"
                }
            }
        }
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
