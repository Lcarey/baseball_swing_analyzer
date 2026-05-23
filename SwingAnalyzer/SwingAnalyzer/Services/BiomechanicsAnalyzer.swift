import Foundation
import CoreGraphics

class BiomechanicsAnalyzer {
    private let coreJointNames = [
        "left_hip",
        "right_hip",
        "left_shoulder",
        "right_shoulder",
        "left_wrist",
        "right_wrist",
        "left_knee",
        "right_knee",
        "left_ankle",
        "right_ankle"
    ]

    // MARK: - Analyze Swing

    func analyzeSwing(frames: [FrameJointData], swingData: SwingData) -> BiomechanicsMetrics? {
        analyzeSwing(
            frames: frames,
            swingData: swingData,
            context: .youthHighSchoolDefault
        )?.legacyMetrics
    }

    func analyzeSwing(
        frames: [FrameJointData],
        swingData: SwingData,
        context: SwingAnalysisContext
    ) -> SwingAnalysisResult? {
        let frames = frames.sorted { $0.timestamp < $1.timestamp }
        guard frames.count >= 3 else { return nil }

        let phaseMarkers = detectPhases(frames: frames, swingData: swingData, context: context)
        let advancedMetrics = calculateAdvancedMetrics(
            frames: frames,
            swingData: swingData,
            phaseMarkers: phaseMarkers,
            context: context
        )
        let poseQuality = calculatePoseQuality(frames: frames, context: context)
        let scoreBreakdown = score(
            metrics: advancedMetrics,
            poseQuality: poseQuality,
            phaseMarkers: phaseMarkers,
            context: context
        )
        let legacyMetrics = BiomechanicsMetrics(
            kneeBend: advancedMetrics.leadKneeFlexionAtHeelStrike,
            hipRotation: advancedMetrics.pelvisRotationAtContact,
            hipHorizontalMovement: advancedMetrics.hipHorizontalMovement,
            hipVerticalMovement: advancedMetrics.hipVerticalMovement,
            hipShoulderAlignment: max(0, 100 - abs(advancedMetrics.hipShoulderSeparationAtContact) * 5),
            timeToContact: advancedMetrics.timeToContact,
            scoreBreakdown: scoreBreakdown
        )

        return SwingAnalysisResult(
            legacyMetrics: legacyMetrics,
            advancedMetrics: advancedMetrics,
            phaseMarkers: phaseMarkers,
            poseQuality: poseQuality,
            scoreBreakdown: scoreBreakdown,
            warnings: scoreBreakdown.warnings
        )
    }

    // MARK: - Phase Detection

    private func detectPhases(
        frames: [FrameJointData],
        swingData: SwingData,
        context: SwingAnalysisContext
    ) -> SwingPhaseMarkers {
        let pelvisAngles = smooth(values: frames.map { segmentAngle(in: $0, a: "left_hip", b: "right_hip") ?? 0 }, windowSize: 5)
        let pelvisVelocities = angularVelocities(values: pelvisAngles, frames: frames)

        let setupIndex = 0
        let contactIndex = nearestFrameIndex(frames: frames, timestamp: swingData.peakVelocityTime)
        let heelStrikeIndex = pelvisVelocities.firstIndex { abs($0) >= 100 } ?? setupIndex
        let firstMoveIndex = setupIndex

        return SwingPhaseMarkers(
            setupTime: frames[setupIndex].timestamp,
            heelStrikeTime: frames[heelStrikeIndex].timestamp,
            firstMoveTime: frames[firstMoveIndex].timestamp,
            contactTime: frames[contactIndex].timestamp,
            setupFrame: frames[setupIndex].frameNumber,
            heelStrikeFrame: frames[heelStrikeIndex].frameNumber,
            firstMoveFrame: frames[firstMoveIndex].frameNumber,
            contactFrame: frames[contactIndex].frameNumber
        )
    }

    private func firstMoveIndex(
        frames: [FrameJointData],
        handSpeeds: [Double],
        startingAt startIndex: Int,
        endingAt contactIndex: Int
    ) -> Int {
        guard !frames.isEmpty else { return 0 }
        let endIndex = min(max(contactIndex, startIndex), frames.count - 1)
        let threshold = max(0.35, percentile(values: Array(handSpeeds), percentile: 0.65))

        if startIndex <= endIndex {
            for index in startIndex...endIndex where handSpeeds[index] >= threshold {
                return index
            }
        }

        return min(frames.count - 1, max(startIndex, Int(Double(endIndex) * 0.35)))
    }

    // MARK: - Metrics

    private func calculateAdvancedMetrics(
        frames: [FrameJointData],
        swingData: SwingData,
        phaseMarkers: SwingPhaseMarkers,
        context: SwingAnalysisContext
    ) -> AdvancedSwingMetrics {
        let setupIndex = nearestFrameIndex(frames: frames, frameNumber: phaseMarkers.setupFrame)
        let heelStrikeIndex = nearestFrameIndex(frames: frames, frameNumber: phaseMarkers.heelStrikeFrame)
        let contactIndex = nearestFrameIndex(frames: frames, frameNumber: phaseMarkers.contactFrame)

        let setupFrame = frames[setupIndex]
        let heelStrikeFrame = frames[heelStrikeIndex]
        let contactFrame = frames[contactIndex]

        let pelvisRotations = rotationSeries(frames: frames, setupFrame: setupFrame, leftKey: "left_hip", rightKey: "right_hip")
        let torsoRotations = rotationSeries(frames: frames, setupFrame: setupFrame, leftKey: "left_shoulder", rightKey: "right_shoulder")
        let pelvisVelocities = angularVelocities(values: smooth(values: pelvisRotations, windowSize: 5), frames: frames)
        let torsoVelocities = angularVelocities(values: smooth(values: torsoRotations, windowSize: 5), frames: frames)
        let handSpeeds = handSpeeds(frames: frames)

        let pelvisRotationAtContact = pelvisRotations[contactIndex]
        let torsoRotationAtContact = torsoRotations[contactIndex]
        let peakSeparation = peakHipShoulderSeparation(
            pelvisRotations: pelvisRotations,
            torsoRotations: torsoRotations,
            contactIndex: contactIndex
        )
        let leadLegKeys = leadLegKeys(for: context.handedness)
        let heelStrikeKneeFlexion = kneeFlexion(frame: heelStrikeFrame, keys: leadLegKeys)
        let contactKneeFlexion = kneeFlexion(frame: contactFrame, keys: leadLegKeys)
        let hipMovement = hipMovement(setupFrame: setupFrame, contactFrame: contactFrame)

        return AdvancedSwingMetrics(
            hipShoulderSeparationAtFirstMove: peakSeparation,
            hipShoulderSeparationAtContact: torsoRotationAtContact - pelvisRotationAtContact,
            pelvisRotationAtContact: pelvisRotationAtContact,
            torsoRotationAtContact: torsoRotationAtContact,
            leadKneeFlexionAtHeelStrike: heelStrikeKneeFlexion,
            leadKneeFlexionAtContact: contactKneeFlexion,
            leadKneeExtensionToContact: max(0, heelStrikeKneeFlexion - contactKneeFlexion),
            timeToContact: max(0, phaseMarkers.contactTime - phaseMarkers.firstMoveTime),
            torsoForwardBendAtHeelStrike: torsoForwardBend(frame: heelStrikeFrame),
            torsoForwardBendAtContact: torsoForwardBend(frame: contactFrame),
            pelvisThrustProxy: pelvisThrustProxy(setupFrame: heelStrikeFrame, contactFrame: contactFrame),
            peakPelvisAngularVelocity: pelvisVelocities.map(abs).max() ?? 0,
            peakTorsoAngularVelocity: torsoVelocities.map(abs).max() ?? 0,
            peakHandVelocity: handSpeeds.max() ?? 0,
            hipHorizontalMovement: hipMovement.horizontal,
            hipVerticalMovement: hipMovement.vertical
        )
    }

    private func rotationSeries(
        frames: [FrameJointData],
        setupFrame: FrameJointData,
        leftKey: String,
        rightKey: String
    ) -> [Double] {
        let setupLength = segmentLength(in: setupFrame, a: leftKey, b: rightKey) ?? 0
        let setupAngle = segmentAngle(in: setupFrame, a: leftKey, b: rightKey) ?? 0

        return frames.map { frame in
            let currentLength = segmentLength(in: frame, a: leftKey, b: rightKey) ?? setupLength
            let currentAngle = segmentAngle(in: frame, a: leftKey, b: rightKey) ?? setupAngle
            let lengthRatio = setupLength > 0 ? min(max(currentLength / setupLength, 0), 1) : 1
            let foreshorteningRotation = acos(lengthRatio).toDegrees()
            let planarRotation = abs(shortestAngleDifference(currentAngle - setupAngle))
            return min(120, max(foreshorteningRotation, planarRotation))
        }
    }

    private func peakHipShoulderSeparation(
        pelvisRotations: [Double],
        torsoRotations: [Double],
        contactIndex: Int
    ) -> Double {
        let count = min(pelvisRotations.count, torsoRotations.count)
        guard count > 0 else { return 0 }
        let upperBound = min(max(contactIndex, 0), count - 1)

        return (0...upperBound)
            .map { torsoRotations[$0] - pelvisRotations[$0] }
            .max { abs($0) < abs($1) } ?? 0
    }

    private func calculatePoseQuality(frames: [FrameJointData], context: SwingAnalysisContext) -> PoseQualityReport {
        let totalFrames = max(context.totalVideoFrames ?? frames.count, frames.count)
        let framesWithCoreJoints = frames.filter { frame in
            coreJointNames.allSatisfy { frame.joints[$0] != nil }
        }.count
        let availableJointCount = frames.reduce(0) { total, frame in
            total + coreJointNames.filter { frame.joints[$0] != nil }.count
        }
        let possibleJointCount = max(frames.count * coreJointNames.count, 1)
        let keyJointAvailability = Double(availableJointCount) / Double(possibleJointCount)
        let detectionRate = Double(frames.count) / Double(max(totalFrames, 1))
        let jitter = jitterScore(frames: frames)
        var warnings: [String] = []

        if detectionRate < 0.75 {
            warnings.append("Pose was detected in fewer than 75% of expected frames.")
        }
        if keyJointAvailability < 0.85 {
            warnings.append("Important joints were missing in parts of the swing.")
        }
        if jitter > 0.12 {
            warnings.append("Pose jitter was high, so angular velocity estimates may be noisy.")
        }
        if context.cameraAngle == .front {
            warnings.append("Front-view video limits 2D pelvis and torso rotation accuracy.")
        } else if context.cameraAngle == .unknown {
            warnings.append("Camera angle is unknown; side-view rotation metrics are treated as estimates.")
        }

        let confidence: ScoreConfidence
        if detectionRate < 0.65 || keyJointAvailability < 0.70 || jitter > 0.30 {
            confidence = .low
        } else if detectionRate < 0.85 || keyJointAvailability < 0.88 || jitter > 0.18 || context.cameraAngle != .side {
            confidence = .medium
        } else {
            confidence = .high
        }

        return PoseQualityReport(
            totalFrames: totalFrames,
            framesWithCoreJoints: framesWithCoreJoints,
            keyJointAvailability: keyJointAvailability,
            detectionRate: detectionRate,
            jitterScore: jitter,
            confidence: confidence,
            warnings: warnings
        )
    }

    // MARK: - Scoring

    private func score(
        metrics: AdvancedSwingMetrics,
        poseQuality: PoseQualityReport,
        phaseMarkers: SwingPhaseMarkers,
        context: SwingAnalysisContext
    ) -> SwingScoreBreakdown {
        let profile = context.scoringProfile
        let separationScore = (
            scoreTargetRange(
                value: abs(metrics.hipShoulderSeparationAtFirstMove),
                ideal: 4...18,
                acceptable: 0...35
            ) * 0.6
        ) + (
            scoreLowIsGood(
                value: abs(metrics.hipShoulderSeparationAtContact),
                idealMax: 12,
                acceptableMax: 30
            ) * 0.4
        )
        let leadLegScore = (
            scoreTargetRange(
                value: metrics.leadKneeFlexionAtHeelStrike,
                ideal: 5...45,
                acceptable: 0...75
            ) * 0.45
        ) + (
            scoreTargetRange(
                value: metrics.leadKneeExtensionToContact,
                ideal: 0...35,
                acceptable: 0...60
            ) * 0.55
        )
        let postureScore = (
            scoreTargetRange(
                value: metrics.torsoForwardBendAtHeelStrike,
                ideal: 5...40,
                acceptable: 0...50
            ) * 0.55
        ) + (
            scoreLowIsGood(
                value: metrics.torsoForwardBendAtContact,
                idealMax: 15,
                acceptableMax: 35
            ) * 0.45
        )
        let pelvisThrustScore = (
            scoreLowIsGood(
                value: metrics.pelvisThrustProxy,
                idealMax: 0.12,
                acceptableMax: 0.35
            ) * 0.55
        ) + (
            scoreLowIsGood(
                value: abs(metrics.hipHorizontalMovement),
                idealMax: 4,
                acceptableMax: 10
            ) * 0.45
        )

        let components = [
            SwingScoreComponent(
                id: "hip_shoulder_separation",
                title: "Hip-Shoulder Separation",
                score: separationScore,
                weight: profile.hipShoulderSeparationWeight,
                value: metrics.hipShoulderSeparationAtFirstMove,
                target: "4-18 deg 2D stretch, closes near 0 deg at contact",
                detail: "Uses first move and contact instead of static alignment. The range is calibrated to the local good-example 2D videos."
            ),
            SwingScoreComponent(
                id: "pelvis_rotation_contact",
                title: "Pelvis Rotation at Contact",
                score: scoreTargetRange(value: metrics.pelvisRotationAtContact, ideal: 15...45, acceptable: 0...70),
                weight: profile.pelvisRotationWeight,
                value: metrics.pelvisRotationAtContact,
                target: "15-45 deg in this 2D Vision estimate",
                detail: "Literature targets are higher in 3D; this side-view score is calibrated to the local good-example videos."
            ),
            SwingScoreComponent(
                id: "torso_rotation_contact",
                title: "Torso Rotation at Contact",
                score: scoreTargetRange(value: metrics.torsoRotationAtContact, ideal: 15...45, acceptable: 0...75),
                weight: profile.torsoRotationWeight,
                value: metrics.torsoRotationAtContact,
                target: "15-45 deg in this 2D Vision estimate",
                detail: "Literature targets are higher in 3D; this side-view score is calibrated to the local good-example videos."
            ),
            SwingScoreComponent(
                id: "time_to_contact",
                title: "Time to Contact",
                score: scoreTargetRange(value: metrics.timeToContact, ideal: 0.08...0.50, acceptable: 0.04...0.85),
                weight: profile.timeToContactWeight,
                value: metrics.timeToContact,
                target: "0.08-0.50s in detected swing window",
                detail: "Measured from detector start to peak hand-speed contact estimate; Blast-style contact timing needs a confirmed pitch/contact event."
            ),
            SwingScoreComponent(
                id: "lead_leg",
                title: "Lead-Leg Behavior",
                score: leadLegScore,
                weight: profile.leadLegWeight,
                value: metrics.leadKneeExtensionToContact,
                target: "Flexed at heel strike, extends into contact",
                detail: "Scores the lead knee transition rather than one static knee angle."
            ),
            SwingScoreComponent(
                id: "posture",
                title: "Posture",
                score: postureScore,
                weight: profile.postureWeight,
                value: metrics.torsoForwardBendAtHeelStrike,
                target: "5-40 deg bend at heel strike, near upright at contact",
                detail: "Uses torso forward bend; side bend is not reliable from a side-only 2D view."
            ),
            SwingScoreComponent(
                id: "pelvis_thrust_proxy",
                title: "Pelvis Tilt/Thrust Proxy",
                score: pelvisThrustScore,
                weight: profile.pelvisThrustWeight,
                value: metrics.pelvisThrustProxy,
                target: "Controlled hip center movement into contact",
                detail: "2D proxy for lower-body thrust because true pelvis tilt needs 3D sensors."
            )
        ]

        let weightedTotal = components.reduce(0) { $0 + $1.score * $1.weight }
        let totalWeight = components.reduce(0) { $0 + $1.weight }
        let rawScore = totalWeight > 0 ? weightedTotal / totalWeight : 0
        let confidencePenalty: Double
        switch poseQuality.confidence {
        case .high:
            confidencePenalty = 1
        case .medium:
            confidencePenalty = 0.9
        case .low:
            confidencePenalty = 0.75
        }

        var warnings = poseQuality.warnings
        if phaseMarkers.firstMoveFrame == phaseMarkers.heelStrikeFrame {
            warnings.append("First move used the detected swing start because no separate foot-plant event is available.")
        }
        if poseQuality.confidence != .high {
            warnings.append("Score was reduced because pose confidence is \(poseQuality.confidence.displayName.lowercased()).")
        }

        return SwingScoreBreakdown(
            analysisVersion: "scoring_v2_youth_hs",
            profileID: profile.id,
            profileName: profile.displayName,
            rawScore: rawScore,
            finalScore: min(max(rawScore * confidencePenalty, 0), 100),
            confidence: poseQuality.confidence,
            components: components,
            warnings: Array(Set(warnings)).sorted()
        )
    }

    private func scoreTargetRange(
        value: Double,
        ideal: ClosedRange<Double>,
        acceptable: ClosedRange<Double>
    ) -> Double {
        if ideal.contains(value) {
            return 100
        }
        if value < acceptable.lowerBound || value > acceptable.upperBound {
            return 35
        }
        if value < ideal.lowerBound {
            let span = max(ideal.lowerBound - acceptable.lowerBound, 0.0001)
            return 35 + ((value - acceptable.lowerBound) / span) * 65
        }

        let span = max(acceptable.upperBound - ideal.upperBound, 0.0001)
        return 100 - ((value - ideal.upperBound) / span) * 65
    }

    private func scoreLowIsGood(value: Double, idealMax: Double, acceptableMax: Double) -> Double {
        if value <= idealMax {
            return 100
        }
        if value >= acceptableMax {
            return 35
        }

        let span = max(acceptableMax - idealMax, 0.0001)
        return 100 - ((value - idealMax) / span) * 65
    }

    // MARK: - Geometry Helpers

    private func segmentAngle(in frame: FrameJointData, a: String, b: String) -> Double? {
        guard let pointA = frame.joints[a], let pointB = frame.joints[b] else { return nil }
        return Double(atan2(pointB.y - pointA.y, pointB.x - pointA.x)).toDegrees()
    }

    private func segmentLength(in frame: FrameJointData, a: String, b: String) -> Double? {
        guard let pointA = frame.joints[a], let pointB = frame.joints[b] else { return nil }
        return BiomechanicsCalculations.distance(from: pointA, to: pointB)
    }

    private func torsoForwardBend(frame: FrameJointData) -> Double {
        guard let midHip = midpoint(frame: frame, a: "left_hip", b: "right_hip"),
              let neck = frame.joints["neck"] ?? midpoint(frame: frame, a: "left_shoulder", b: "right_shoulder") else {
            return 0
        }

        let dx = neck.x - midHip.x
        let dy = neck.y - midHip.y
        guard dx != 0 || dy != 0 else { return 0 }
        return abs(Double(atan2(dx, dy)).toDegrees())
    }

    private func kneeFlexion(frame: FrameJointData, keys: (hip: String, knee: String, ankle: String)) -> Double {
        guard let hip = frame.joints[keys.hip],
              let knee = frame.joints[keys.knee],
              let ankle = frame.joints[keys.ankle] else {
            return 0
        }

        let kneeAngle = BiomechanicsCalculations.calculateAngle(point1: hip, point2: knee, point3: ankle)
        return max(0, 180 - kneeAngle)
    }

    private func leadLegKeys(for handedness: BatterHandedness) -> (hip: String, knee: String, ankle: String) {
        switch handedness {
        case .right:
            return ("left_hip", "left_knee", "left_ankle")
        case .left:
            return ("right_hip", "right_knee", "right_ankle")
        }
    }

    private func hipMovement(setupFrame: FrameJointData, contactFrame: FrameJointData) -> (horizontal: Double, vertical: Double) {
        guard let setupHipCenter = midpoint(frame: setupFrame, a: "left_hip", b: "right_hip"),
              let contactHipCenter = midpoint(frame: contactFrame, a: "left_hip", b: "right_hip") else {
            return (0, 0)
        }

        let scale = bodyScaleInches(frame: setupFrame)
        let horizontal = Double(contactHipCenter.x - setupHipCenter.x) * scale
        let vertical = Double(contactHipCenter.y - setupHipCenter.y) * scale
        return (horizontal, vertical)
    }

    private func pelvisThrustProxy(setupFrame: FrameJointData, contactFrame: FrameJointData) -> Double {
        guard let setupHipCenter = midpoint(frame: setupFrame, a: "left_hip", b: "right_hip"),
              let contactHipCenter = midpoint(frame: contactFrame, a: "left_hip", b: "right_hip") else {
            return 0
        }

        return abs(Double(contactHipCenter.y - setupHipCenter.y))
    }

    private func midpoint(frame: FrameJointData, a: String, b: String) -> CGPoint? {
        guard let pointA = frame.joints[a], let pointB = frame.joints[b] else { return nil }
        return CGPoint(x: (pointA.x + pointB.x) / 2, y: (pointA.y + pointB.y) / 2)
    }

    private func bodyScaleInches(frame: FrameJointData) -> Double {
        guard let neck = frame.joints["neck"] ?? midpoint(frame: frame, a: "left_shoulder", b: "right_shoulder"),
              let hipCenter = midpoint(frame: frame, a: "left_hip", b: "right_hip") else {
            return 180
        }

        let torsoLength = max(BiomechanicsCalculations.distance(from: neck, to: hipCenter), 0.01)
        return 24 / torsoLength
    }

    private func handSpeeds(frames: [FrameJointData]) -> [Double] {
        guard frames.count > 1 else { return Array(repeating: 0, count: frames.count) }
        var speeds = Array(repeating: 0.0, count: frames.count)

        for index in 1..<frames.count {
            let current = frames[index]
            let previous = frames[index - 1]
            let deltaTime = current.timestamp - previous.timestamp
            guard deltaTime > 0 else { continue }

            let leftSpeed = speed(joint: "left_wrist", current: current, previous: previous, deltaTime: deltaTime)
            let rightSpeed = speed(joint: "right_wrist", current: current, previous: previous, deltaTime: deltaTime)
            speeds[index] = max(leftSpeed, rightSpeed)
        }

        return smooth(values: speeds, windowSize: 5)
    }

    private func speed(joint: String, current: FrameJointData, previous: FrameJointData, deltaTime: Double) -> Double {
        guard let currentPoint = current.joints[joint], let previousPoint = previous.joints[joint] else { return 0 }
        return BiomechanicsCalculations.distance(from: previousPoint, to: currentPoint) / deltaTime
    }

    private func angularVelocities(values: [Double], frames: [FrameJointData]) -> [Double] {
        guard values.count == frames.count, frames.count > 1 else {
            return Array(repeating: 0, count: frames.count)
        }

        var velocities = Array(repeating: 0.0, count: frames.count)
        for index in 1..<frames.count {
            let deltaTime = frames[index].timestamp - frames[index - 1].timestamp
            guard deltaTime > 0 else { continue }
            let deltaAngle = shortestAngleDifference(values[index] - values[index - 1])
            velocities[index] = deltaAngle / deltaTime
        }
        return velocities
    }

    private func shortestAngleDifference(_ angle: Double) -> Double {
        var normalized = angle.truncatingRemainder(dividingBy: 360)
        if normalized > 180 {
            normalized -= 360
        } else if normalized < -180 {
            normalized += 360
        }
        return normalized
    }

    private func smooth(values: [Double], windowSize: Int) -> [Double] {
        guard values.count >= windowSize, windowSize > 1 else { return values }
        let halfWindow = windowSize / 2

        return values.indices.map { index in
            let start = max(0, index - halfWindow)
            let end = min(values.count - 1, index + halfWindow)
            let slice = values[start...end]
            return slice.reduce(0, +) / Double(slice.count)
        }
    }

    private func nearestFrameIndex(frames: [FrameJointData], timestamp: Double) -> Int {
        frames.indices.min { lhs, rhs in
            abs(frames[lhs].timestamp - timestamp) < abs(frames[rhs].timestamp - timestamp)
        } ?? 0
    }

    private func nearestFrameIndex(frames: [FrameJointData], frameNumber: Int) -> Int {
        frames.indices.min { lhs, rhs in
            abs(frames[lhs].frameNumber - frameNumber) < abs(frames[rhs].frameNumber - frameNumber)
        } ?? 0
    }

    private func percentile(values: [Double], percentile: Double) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let clamped = min(max(percentile, 0), 1)
        let rawIndex = clamped * Double(sorted.count - 1)
        return sorted[Int(rawIndex.rounded())]
    }

    private func jitterScore(frames: [FrameJointData]) -> Double {
        guard frames.count > 1 else { return 0 }
        let torsoLengths = frames.compactMap { frame -> Double? in
            guard let neck = frame.joints["neck"] ?? midpoint(frame: frame, a: "left_shoulder", b: "right_shoulder"),
                  let hipCenter = midpoint(frame: frame, a: "left_hip", b: "right_hip") else {
                return nil
            }
            return BiomechanicsCalculations.distance(from: neck, to: hipCenter)
        }
        guard torsoLengths.count > 1 else { return 0 }
        let average = torsoLengths.reduce(0, +) / Double(torsoLengths.count)
        guard average > 0 else { return 0 }
        let variance = torsoLengths.reduce(0) { total, value in
            total + pow(value - average, 2)
        } / Double(torsoLengths.count)
        return sqrt(variance) / average
    }
}
