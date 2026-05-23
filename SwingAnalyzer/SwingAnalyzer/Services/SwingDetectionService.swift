import Foundation
import CoreGraphics

class SwingDetectionService {
    private let motionThreshold = AppConstants.motionThreshold
    private let minSwingDuration = AppConstants.minSwingDuration
    private let maxSwingDuration = max(AppConstants.maxSwingDuration, 1.25)
    private let swingScoreThreshold = 1.05
    private let swingReleaseThreshold = 0.58
    private let minHandVelocity = 0.35
    private let minArmVelocity = 0.25
    private let minSwingSeparation = 1.8

    private struct SwingMotionSignal {
        let score: Double
        let hipVelocity: Double
        let shoulderVelocity: Double
        let armVelocity: Double
        let handVelocity: Double
        let batProxyVelocity: Double
    }

    private struct SwingCandidate {
        let swing: SwingData
        let peakScore: Double
        let peakHandVelocity: Double
    }

    // MARK: - Detect Swings

    func detectSwings(from frames: [FrameJointData], velocities: [Int: [String: Double]]) -> [SwingData] {
        var candidates: [SwingCandidate] = []
        var currentSwingStart: Int?
        var peakVelocityFrame: Int?
        var maxScore: Double = 0
        var peakHandVelocity: Double = 0

        for i in 0..<frames.count {
            let frame = frames[i]
            let signal = calculateSwingMotionSignal(frame: frame.frameNumber, velocities: velocities)
            let isLikelySwing = signal.score >= swingScoreThreshold &&
                signal.handVelocity >= minHandVelocity &&
                signal.armVelocity >= minArmVelocity
            let shouldContinueSwing = signal.score >= swingReleaseThreshold &&
                signal.handVelocity >= minHandVelocity * 0.5

            if currentSwingStart == nil {
                if isLikelySwing {
                    currentSwingStart = i
                    maxScore = signal.score
                    peakVelocityFrame = i
                    peakHandVelocity = signal.handVelocity
                }
            } else if shouldContinueSwing {
                if signal.score > maxScore {
                    maxScore = signal.score
                    peakVelocityFrame = i
                }
                peakHandVelocity = max(peakHandVelocity, signal.handVelocity)
            } else if let startFrame = currentSwingStart {
                if let candidate = makeCandidate(
                    frames: frames,
                    startFrame: startFrame,
                    endFrame: i,
                    peakVelocityFrame: peakVelocityFrame,
                    peakScore: maxScore,
                    peakHandVelocity: peakHandVelocity
                ) {
                    candidates.append(candidate)
                }

                currentSwingStart = nil
                peakVelocityFrame = nil
                maxScore = 0
                peakHandVelocity = 0
            }
        }

        // Handle case where recording ends during a swing
        if let startFrame = currentSwingStart, startFrame < frames.count - 1 {
            if let candidate = makeCandidate(
                frames: frames,
                startFrame: startFrame,
                endFrame: frames.count - 1,
                peakVelocityFrame: peakVelocityFrame,
                peakScore: maxScore,
                peakHandVelocity: peakHandVelocity
            ) {
                candidates.append(candidate)
            }
        }

        return filterDuplicateCandidates(candidates).map(\.swing)
    }

    // MARK: - Calculate Swing Motion

    private func calculateSwingMotionSignal(frame: Int, velocities: [Int: [String: Double]]) -> SwingMotionSignal {
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
        let score = normalized(hipVelocity, threshold: motionThreshold) * 0.18 +
            normalized(shoulderVelocity, threshold: 0.08) * 0.18 +
            normalized(armVelocity, threshold: 0.25) * 0.26 +
            normalized(batProxyVelocity, threshold: 0.35) * 0.38

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
        peakHandVelocity: Double
    ) -> SwingCandidate? {
        guard startFrame < frames.count, endFrame < frames.count else { return nil }

        let swingDuration = frames[endFrame].timestamp - frames[startFrame].timestamp
        guard swingDuration >= minSwingDuration,
              swingDuration <= maxSwingDuration,
              peakHandVelocity >= minHandVelocity else {
            return nil
        }

        let swing = SwingData(
            startTime: frames[startFrame].timestamp,
            endTime: frames[endFrame].timestamp,
            peakVelocityTime: peakVelocityFrame != nil ? frames[peakVelocityFrame!].timestamp : frames[endFrame].timestamp
        )

        return SwingCandidate(
            swing: swing,
            peakScore: peakScore,
            peakHandVelocity: peakHandVelocity
        )
    }

    private func filterDuplicateCandidates(_ candidates: [SwingCandidate]) -> [SwingCandidate] {
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

            let shouldReplaceLast = candidate.peakScore > lastCandidate.peakScore ||
                (candidate.peakScore == lastCandidate.peakScore && candidate.peakHandVelocity > lastCandidate.peakHandVelocity)
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

    // MARK: - Get Frames for Swing

    func getFrames(for swing: SwingData, from allFrames: [FrameJointData]) -> [FrameJointData] {
        return allFrames.filter { frame in
            frame.timestamp >= swing.startTime && frame.timestamp <= swing.endTime
        }
    }

    // MARK: - Detect Rotation

    func detectHipRotation(frames: [FrameJointData]) -> Double {
        guard frames.count >= 2 else { return 0 }

        // Get first and last frames with hip data
        var firstFrame: FrameJointData?
        var lastFrame: FrameJointData?

        for frame in frames {
            if frame.joints["left_hip"] != nil && frame.joints["right_hip"] != nil {
                if firstFrame == nil {
                    firstFrame = frame
                }
                lastFrame = frame
            }
        }

        guard let first = firstFrame,
              let last = lastFrame,
              let firstLeftHip = first.joints["left_hip"],
              let firstRightHip = first.joints["right_hip"],
              let lastLeftHip = last.joints["left_hip"],
              let lastRightHip = last.joints["right_hip"] else {
            return 0
        }

        return BiomechanicsCalculations.calculateHipRotation(
            leftHip: lastLeftHip,
            rightHip: lastRightHip,
            referenceLeftHip: firstLeftHip,
            referenceRightHip: firstRightHip
        )
    }
}
