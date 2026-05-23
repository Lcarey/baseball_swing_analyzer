import Foundation
import CoreGraphics

class BiomechanicsAnalyzer {

    // MARK: - Analyze Swing

    func analyzeSwing(frames: [FrameJointData], swingData: SwingData) -> BiomechanicsMetrics? {
        guard !frames.isEmpty else { return nil }

        // Find key frames
        guard let setupFrame = frames.first,
              let contactFrame = findContactFrame(frames: frames, peakTime: swingData.peakVelocityTime) else {
            return nil
        }

        // Calculate each metric
        let kneeBend = calculateKneeBend(frame: setupFrame)
        let hipRotation = calculateHipRotation(setupFrame: setupFrame, contactFrame: contactFrame)
        let hipMovement = calculateHipMovement(setupFrame: setupFrame, contactFrame: contactFrame)
        let alignment = calculateHipShoulderAlignment(frame: contactFrame)
        let timeToContact = swingData.peakVelocityTime - swingData.startTime

        return BiomechanicsMetrics(
            kneeBend: kneeBend,
            hipRotation: hipRotation,
            hipHorizontalMovement: hipMovement.horizontal,
            hipVerticalMovement: hipMovement.vertical,
            hipShoulderAlignment: alignment,
            timeToContact: timeToContact
        )
    }

    // MARK: - Find Contact Frame

    private func findContactFrame(frames: [FrameJointData], peakTime: Double) -> FrameJointData? {
        // Find frame closest to peak velocity time
        var closestFrame: FrameJointData?
        var minDifference = Double.infinity

        for frame in frames {
            let difference = abs(frame.timestamp - peakTime)
            if difference < minDifference {
                minDifference = difference
                closestFrame = frame
            }
        }

        return closestFrame
    }

    // MARK: - Calculate Knee Bend

    private func calculateKneeBend(frame: FrameJointData) -> Double {
        // Calculate knee bend for lead leg (left leg for right-handed batter)
        // Using left knee as default
        guard let leftHip = frame.joints["left_hip"],
              let leftKnee = frame.joints["left_knee"],
              let leftAnkle = frame.joints["left_ankle"] else {
            return 0
        }

        return BiomechanicsCalculations.calculateAngle(
            point1: leftHip,
            point2: leftKnee,
            point3: leftAnkle
        )
    }

    // MARK: - Calculate Hip Rotation

    private func calculateHipRotation(setupFrame: FrameJointData, contactFrame: FrameJointData) -> Double {
        guard let setupLeftHip = setupFrame.joints["left_hip"],
              let setupRightHip = setupFrame.joints["right_hip"],
              let contactLeftHip = contactFrame.joints["left_hip"],
              let contactRightHip = contactFrame.joints["right_hip"] else {
            return 0
        }

        return BiomechanicsCalculations.calculateHipRotation(
            leftHip: contactLeftHip,
            rightHip: contactRightHip,
            referenceLeftHip: setupLeftHip,
            referenceRightHip: setupRightHip
        )
    }

    // MARK: - Calculate Hip Movement

    private func calculateHipMovement(setupFrame: FrameJointData, contactFrame: FrameJointData) -> (horizontal: Double, vertical: Double) {
        // Calculate center of hips
        guard let setupLeftHip = setupFrame.joints["left_hip"],
              let setupRightHip = setupFrame.joints["right_hip"],
              let contactLeftHip = contactFrame.joints["left_hip"],
              let contactRightHip = contactFrame.joints["right_hip"] else {
            return (0, 0)
        }

        let setupHipCenter = CGPoint(
            x: (setupLeftHip.x + setupRightHip.x) / 2,
            y: (setupLeftHip.y + setupRightHip.y) / 2
        )

        let contactHipCenter = CGPoint(
            x: (contactLeftHip.x + contactRightHip.x) / 2,
            y: (contactLeftHip.y + contactRightHip.y) / 2
        )

        let horizontal = BiomechanicsCalculations.horizontalMovement(
            from: setupHipCenter,
            to: contactHipCenter
        )

        let vertical = BiomechanicsCalculations.verticalMovement(
            from: setupHipCenter,
            to: contactHipCenter
        )

        // Convert normalized coordinates to inches (approximate)
        // Assuming frame height represents ~6 feet person
        let frameHeight: CGFloat = 1.0 // normalized
        let horizontalInches = BiomechanicsCalculations.normalizedToInches(
            distance: abs(horizontal),
            frameHeight: frameHeight
        )
        let verticalInches = BiomechanicsCalculations.normalizedToInches(
            distance: abs(vertical),
            frameHeight: frameHeight
        )

        return (
            horizontal: horizontal < 0 ? -horizontalInches : horizontalInches,
            vertical: vertical < 0 ? -verticalInches : verticalInches
        )
    }

    // MARK: - Calculate Hip-Shoulder Alignment

    private func calculateHipShoulderAlignment(frame: FrameJointData) -> Double {
        guard let leftHip = frame.joints["left_hip"],
              let rightHip = frame.joints["right_hip"],
              let leftShoulder = frame.joints["left_shoulder"],
              let rightShoulder = frame.joints["right_shoulder"] else {
            return 0
        }

        return BiomechanicsCalculations.calculateAlignment(
            leftHip: leftHip,
            rightHip: rightHip,
            leftShoulder: leftShoulder,
            rightShoulder: rightShoulder
        )
    }
}
