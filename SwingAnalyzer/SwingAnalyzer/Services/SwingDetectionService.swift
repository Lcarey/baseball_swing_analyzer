import Foundation
import CoreGraphics

class SwingDetectionService {
    private let motionThreshold = AppConstants.motionThreshold

    private struct SwingMotionSignal {
        let score: Double
        let hipVelocity: Double
        let shoulderVelocity: Double
        let armVelocity: Double
        let handVelocity: Double
        let batProxyVelocity: Double
    }

    // MARK: - Detect Swings

    func detectSwings(from frames: [FrameJointData], velocities: [Int: [String: Double]]) -> [SwingData] {
        let configuration = SwingDetectionConfiguration.balanced(expectedSwingCount: 0)
        return detectCandidatePool(from: frames, velocities: velocities, configuration: configuration)
            .map(\.swing)
            .sorted { $0.startTime < $1.startTime }
    }

    func detectCandidates(
        from frames: [FrameJointData],
        velocities: [Int: [String: Double]],
        configuration: SwingDetectionConfiguration
    ) -> [SwingDetectionCandidate] {
        detectCandidatePool(from: frames, velocities: velocities, configuration: configuration)
            .sorted { lhs, rhs in
                if lhs.rankingScore == rhs.rankingScore {
                    return lhs.swing.startTime < rhs.swing.startTime
                }
                return lhs.rankingScore > rhs.rankingScore
            }
    }

    private func detectCandidatePool(
        from frames: [FrameJointData],
        velocities: [Int: [String: Double]],
        configuration: SwingDetectionConfiguration
    ) -> [SwingDetectionCandidate] {
        var candidates: [SwingDetectionCandidate] = []
        var currentSwingStart: Int?
        var peakVelocityFrame: Int?
        var maxScore: Double = 0
        var peakHandVelocity: Double = 0
        var peakBatProxyVelocity: Double = 0

        for i in 0..<frames.count {
            let frame = frames[i]
            let signal = calculateSwingMotionSignal(
                frame: frame.frameNumber,
                velocities: velocities,
                configuration: configuration
            )
            let isLikelySwing = signal.score >= configuration.scoreThreshold &&
                signal.handVelocity >= configuration.minHandVelocity &&
                signal.armVelocity >= configuration.minArmVelocity
            let shouldContinueSwing = signal.score >= configuration.releaseThreshold &&
                signal.handVelocity >= configuration.minHandVelocity * 0.5

            if currentSwingStart == nil {
                if isLikelySwing {
                    currentSwingStart = i
                    maxScore = signal.score
                    peakVelocityFrame = i
                    peakHandVelocity = signal.handVelocity
                    peakBatProxyVelocity = signal.batProxyVelocity
                }
            } else if shouldContinueSwing {
                if signal.score > maxScore {
                    maxScore = signal.score
                    peakVelocityFrame = i
                }
                peakHandVelocity = max(peakHandVelocity, signal.handVelocity)
                peakBatProxyVelocity = max(peakBatProxyVelocity, signal.batProxyVelocity)
            } else if let startFrame = currentSwingStart {
                if let candidate = makeCandidate(
                    frames: frames,
                    startFrame: startFrame,
                    endFrame: i,
                    peakVelocityFrame: peakVelocityFrame,
                    peakScore: maxScore,
                    peakHandVelocity: peakHandVelocity,
                    peakBatProxyVelocity: peakBatProxyVelocity,
                    configuration: configuration
                ) {
                    candidates.append(candidate)
                }

                currentSwingStart = nil
                peakVelocityFrame = nil
                maxScore = 0
                peakHandVelocity = 0
                peakBatProxyVelocity = 0
            }
        }

        if let startFrame = currentSwingStart, startFrame < frames.count - 1 {
            if let candidate = makeCandidate(
                frames: frames,
                startFrame: startFrame,
                endFrame: frames.count - 1,
                peakVelocityFrame: peakVelocityFrame,
                peakScore: maxScore,
                peakHandVelocity: peakHandVelocity,
                peakBatProxyVelocity: peakBatProxyVelocity,
                configuration: configuration
            ) {
                candidates.append(candidate)
            }
        }

        return filterDuplicateCandidates(candidates, minSwingSeparation: configuration.minSwingSeparation)
    }

    // MARK: - Calculate Swing Motion

    private func calculateSwingMotionSignal(
        frame: Int,
        velocities: [Int: [String: Double]],
        configuration: SwingDetectionConfiguration
    ) -> SwingMotionSignal {
        let hipVelocity = calculateAverageVelocity(
            frame: frame,
            jointNames: [JointName.leftHip.visionKey, JointName.rightHip.visionKey],
            velocities: velocities
        )
        let shoulderVelocity = calculateAverageVelocity(
            frame: frame,
            jointNames: [JointName.leftShoulder.visionKey, JointName.rightShoulder.visionKey],
            velocities: velocities
        )
        let armVelocity = calculateAverageVelocity(
            frame: frame,
            jointNames: [
                JointName.leftElbow.visionKey,
                JointName.rightElbow.visionKey,
                JointName.leftWrist.visionKey,
                JointName.rightWrist.visionKey
            ],
            velocities: velocities
        )
        let handVelocity = calculateAverageVelocity(
            frame: frame,
            jointNames: [JointName.leftWrist.visionKey, JointName.rightWrist.visionKey],
            velocities: velocities
        )
        let coreVelocity = (hipVelocity + shoulderVelocity) / 2
        let batProxyVelocity = max(0, handVelocity - coreVelocity * 0.6)
        let weights = configuration.normalizedWeights
        let score = normalized(hipVelocity, threshold: motionThreshold) * weights.hip +
            normalized(shoulderVelocity, threshold: 0.08) * weights.shoulder +
            normalized(armVelocity, threshold: configuration.minArmVelocity) * weights.arm +
            normalized(batProxyVelocity, threshold: configuration.minHandVelocity) * weights.batProxy

        return SwingMotionSignal(
            score: score,
            hipVelocity: hipVelocity,
            shoulderVelocity: shoulderVelocity,
            armVelocity: armVelocity,
            handVelocity: handVelocity,
            batProxyVelocity: batProxyVelocity
        )
    }

    private func normalized(_ velocity: Double, threshold: Double) -> Double {
        guard threshold > 0 else { return 0 }
        return min(velocity / threshold, 4)
    }

    private func makeCandidate(
        frames: [FrameJointData],
        startFrame: Int,
        endFrame: Int,
        peakVelocityFrame: Int?,
        peakScore: Double,
        peakHandVelocity: Double,
        peakBatProxyVelocity: Double,
        configuration: SwingDetectionConfiguration
    ) -> SwingDetectionCandidate? {
        guard startFrame < frames.count, endFrame < frames.count else { return nil }

        let swingDuration = frames[endFrame].timestamp - frames[startFrame].timestamp
        guard swingDuration >= configuration.minSwingDuration,
              swingDuration <= configuration.maxSwingDuration,
              peakHandVelocity >= configuration.minHandVelocity else {
            return nil
        }

        let swing = SwingData(
            startTime: frames[startFrame].timestamp,
            endTime: frames[endFrame].timestamp,
            peakVelocityTime: peakVelocityFrame != nil ? frames[peakVelocityFrame!].timestamp : frames[endFrame].timestamp
        )
        let rankingScore = peakScore + peakHandVelocity * 0.35 + peakBatProxyVelocity * 0.45

        return SwingDetectionCandidate(
            swing: swing,
            peakScore: peakScore,
            peakHandVelocity: peakHandVelocity,
            peakBatProxyVelocity: peakBatProxyVelocity,
            rankingScore: rankingScore
        )
    }

    private func filterDuplicateCandidates(
        _ candidates: [SwingDetectionCandidate],
        minSwingSeparation: Double
    ) -> [SwingDetectionCandidate] {
        candidates.reduce(into: []) { accepted, candidate in
            guard let lastCandidate = accepted.last else {
                accepted.append(candidate)
                return
            }

            let timeSinceLastSwing = candidate.swing.startTime - lastCandidate.swing.endTime
            guard timeSinceLastSwing < minSwingSeparation else {
                accepted.append(candidate)
                return
            }

            let shouldReplaceLast = candidate.rankingScore > lastCandidate.rankingScore
            if shouldReplaceLast {
                accepted[accepted.count - 1] = candidate
            }
        }
    }

    // MARK: - Calculate Joint Velocity

    private func calculateAverageVelocity(frame: Int, jointNames: [String], velocities: [Int: [String: Double]]) -> Double {
        guard let frameVelocities = velocities[frame] else { return 0 }

        let jointVelocities = jointNames.compactMap { frameVelocities[$0] }
        guard !jointVelocities.isEmpty else { return 0 }

        return jointVelocities.reduce(0, +) / Double(jointVelocities.count)
    }
}
