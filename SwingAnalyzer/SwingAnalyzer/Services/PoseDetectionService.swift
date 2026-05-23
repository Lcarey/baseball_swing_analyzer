import Vision
import AVFoundation
import CoreGraphics
import ImageIO
import Combine

class PoseDetectionService: ObservableObject {
    @Published var isProcessing = false
    @Published var progress: Double = 0

    private let confidenceThreshold: Float = AppConstants.confidenceThreshold

    enum PoseError: Error, LocalizedError {
        case invalidVideoURL
        case trackReaderFailed
        case poseDetectionFailed

        var errorDescription: String? {
            switch self {
            case .invalidVideoURL:
                return "No readable video track was found."
            case .trackReaderFailed:
                return "The video track reader could not start."
            case .poseDetectionFailed:
                return "Pose detection failed."
            }
        }
    }

    // MARK: - Process Video

    func processVideo(url: URL, completion: @escaping (Result<[FrameJointData], Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isProcessing = true
                self.progress = 0
            }

            do {
                let asset = AVAsset(url: url)
                let frameData = try self.extractPoseData(from: asset)

                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.progress = 1.0
                    completion(.success(frameData))
                }
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    completion(.failure(error))
                }
            }
        }
    }

    func processVideoSynchronously(url: URL) throws -> [FrameJointData] {
        let asset = AVAsset(url: url)
        return try extractPoseData(from: asset)
    }

    // MARK: - Extract Pose Data

    private func extractPoseData(from asset: AVAsset) throws -> [FrameJointData] {
        // Using synchronous API for simplicity - async version would require restructuring
        #if compiler(>=5.5)
        #warning("Consider migrating to async loadTracks API in future update")
        #endif

        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            throw PoseError.invalidVideoURL
        }

        let orientation = imageOrientation(for: videoTrack.preferredTransform)
        print("PoseDetectionService: nominalFrameRate=\(videoTrack.nominalFrameRate), orientation=\(orientation.rawValue)")

        let assetReader = try AVAssetReader(asset: asset)
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        let trackOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: outputSettings)
        assetReader.add(trackOutput)

        guard assetReader.startReading() else {
            throw PoseError.trackReaderFailed
        }

        var frameData: [FrameJointData] = []
        var frameNumber = 0
        let frameRate = videoTrack.nominalFrameRate
        let duration = CMTimeGetSeconds(asset.duration)
        let totalFrames = Int(duration * Double(frameRate))

        while let sampleBuffer = trackOutput.copyNextSampleBuffer() {
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                continue
            }

            let timestamp = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))

            if let joints = detectPose(in: imageBuffer, orientation: orientation) {
                let frame = FrameJointData(
                    frameNumber: frameNumber,
                    timestamp: timestamp,
                    joints: joints
                )
                frameData.append(frame)
            }

            frameNumber += 1

            // Update progress
            if frameNumber % 10 == 0 {
                let currentProgress = Double(frameNumber) / Double(totalFrames)
                DispatchQueue.main.async {
                    self.progress = currentProgress
                }
            }
        }

        let detectionRate = frameNumber > 0 ? Double(frameData.count) / Double(frameNumber) : 0
        print("PoseDetectionService: framesRead=\(frameNumber), framesWithPose=\(frameData.count), detectionRate=\(String(format: "%.1f%%", detectionRate * 100))")

        return smoothJointData(frameData)
    }

    // MARK: - Pose Detection

    private func detectPose(in imageBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) -> [String: CGPoint]? {
        let request = VNDetectHumanBodyPoseRequest()
        request.revision = VNDetectHumanBodyPoseRequestRevision1

        let handler = VNImageRequestHandler(
            cvPixelBuffer: imageBuffer,
            orientation: orientation,
            options: [:]
        )

        do {
            try handler.perform([request])

            guard let observation = request.results?.first else {
                return nil
            }

            return extractJointPoints(from: observation)
        } catch {
            return nil
        }
    }

    private func extractJointPoints(from observation: VNHumanBodyPoseObservation) -> [String: CGPoint]? {
        var joints: [String: CGPoint] = [:]

        for jointName in VisionJointMapping.trackedJointNames {
            guard let point = try? observation.recognizedPoint(jointName),
                  point.confidence > confidenceThreshold else {
                continue
            }

            let key = VisionJointMapping.appKey(for: jointName)
            joints[key] = CGPoint(x: point.location.x, y: point.location.y)
        }

        // Only return if we have enough joints (at least 8)
        return joints.count >= 8 ? joints : nil
    }

    // MARK: - Data Smoothing

    private func smoothJointData(_ frames: [FrameJointData], windowSize: Int = 3) -> [FrameJointData] {
        guard frames.count >= windowSize else { return frames }

        var smoothedFrames: [FrameJointData] = []
        let halfWindow = windowSize / 2

        for i in 0..<frames.count {
            let start = max(0, i - halfWindow)
            let end = min(frames.count, i + halfWindow + 1)
            let windowFrames = Array(frames[start..<end])

            var smoothedJoints: [String: CGPoint] = [:]

            // Get all joint names from current frame
            for (jointName, _) in frames[i].joints {
                var sumX: CGFloat = 0
                var sumY: CGFloat = 0
                var count = 0

                for frame in windowFrames {
                    if let point = frame.joints[jointName] {
                        sumX += point.x
                        sumY += point.y
                        count += 1
                    }
                }

                if count > 0 {
                    smoothedJoints[jointName] = CGPoint(
                        x: sumX / CGFloat(count),
                        y: sumY / CGFloat(count)
                    )
                }
            }

            smoothedFrames.append(FrameJointData(
                frameNumber: frames[i].frameNumber,
                timestamp: frames[i].timestamp,
                joints: smoothedJoints
            ))
        }

        return smoothedFrames
    }

    // MARK: - Calculate Velocities

    func calculateVelocities(frames: [FrameJointData]) -> [Int: [String: Double]] {
        var velocities: [Int: [String: Double]] = [:]

        for i in 1..<frames.count {
            let currentFrame = frames[i]
            let previousFrame = frames[i - 1]
            let deltaTime = currentFrame.timestamp - previousFrame.timestamp

            guard deltaTime > 0 else { continue }

            var frameVelocities: [String: Double] = [:]

            for (jointName, currentPoint) in currentFrame.joints {
                if let previousPoint = previousFrame.joints[jointName] {
                    let distance = BiomechanicsCalculations.distance(from: previousPoint, to: currentPoint)
                    let velocity = distance / deltaTime
                    frameVelocities[jointName] = velocity
                }
            }

            velocities[currentFrame.frameNumber] = frameVelocities
        }

        return velocities
    }

    private func imageOrientation(for transform: CGAffineTransform) -> CGImagePropertyOrientation {
        switch (transform.a, transform.b, transform.c, transform.d) {
        case (0, 1, -1, 0):
            return .right
        case (0, -1, 1, 0):
            return .left
        case (-1, 0, 0, -1):
            return .down
        default:
            return .up
        }
    }
}
