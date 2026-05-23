import Foundation
import CoreGraphics

class SwingDetectionService {
    private let motionThreshold = AppConstants.motionThreshold
    private let minSwingDuration = AppConstants.minSwingDuration
    private let maxSwingDuration = AppConstants.maxSwingDuration

    // MARK: - Detect Swings

    func detectSwings(from frames: [FrameJointData], velocities: [Int: [String: Double]]) -> [SwingData] {
        var swings: [SwingData] = []
        var currentSwingStart: Int?
        var peakVelocityFrame: Int?
        var maxVelocity: Double = 0

        for i in 0..<frames.count {
            let frame = frames[i]

            // Calculate average hip velocity
            let hipVelocity = calculateAverageHipVelocity(frame: i, velocities: velocities)

            // Check if we're in a swing
            if hipVelocity > motionThreshold {
                if currentSwingStart == nil {
                    // Start of new swing
                    currentSwingStart = i
                    maxVelocity = hipVelocity
                    peakVelocityFrame = i
                } else {
                    // Continue tracking swing, update peak if necessary
                    if hipVelocity > maxVelocity {
                        maxVelocity = hipVelocity
                        peakVelocityFrame = i
                    }
                }
            } else if let startFrame = currentSwingStart {
                // End of swing - velocity dropped below threshold
                let swingDuration = frame.timestamp - frames[startFrame].timestamp

                // Validate swing duration
                if swingDuration >= minSwingDuration && swingDuration <= maxSwingDuration {
                    let swing = SwingData(
                        startTime: frames[startFrame].timestamp,
                        endTime: frame.timestamp,
                        peakVelocityTime: peakVelocityFrame != nil ? frames[peakVelocityFrame!].timestamp : frame.timestamp
                    )
                    swings.append(swing)
                }

                // Reset for next swing
                currentSwingStart = nil
                peakVelocityFrame = nil
                maxVelocity = 0
            }
        }

        // Handle case where recording ends during a swing
        if let startFrame = currentSwingStart, startFrame < frames.count - 1 {
            let endFrame = frames.count - 1
            let swingDuration = frames[endFrame].timestamp - frames[startFrame].timestamp

            if swingDuration >= minSwingDuration && swingDuration <= maxSwingDuration {
                let swing = SwingData(
                    startTime: frames[startFrame].timestamp,
                    endTime: frames[endFrame].timestamp,
                    peakVelocityTime: peakVelocityFrame != nil ? frames[peakVelocityFrame!].timestamp : frames[endFrame].timestamp
                )
                swings.append(swing)
            }
        }

        return swings
    }

    // MARK: - Calculate Hip Velocity

    private func calculateAverageHipVelocity(frame: Int, velocities: [Int: [String: Double]]) -> Double {
        guard let frameVelocities = velocities[frame] else { return 0 }

        var hipVelocities: [Double] = []

        if let leftHipVel = frameVelocities["left_hip"] {
            hipVelocities.append(leftHipVel)
        }
        if let rightHipVel = frameVelocities["right_hip"] {
            hipVelocities.append(rightHipVel)
        }

        guard !hipVelocities.isEmpty else { return 0 }

        return hipVelocities.reduce(0, +) / Double(hipVelocities.count)
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
