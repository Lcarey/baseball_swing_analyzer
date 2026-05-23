import Foundation

nonisolated enum BatterHandedness: String, Codable, CaseIterable, Identifiable {
    case right
    case left

    var id: String { rawValue }
}

nonisolated enum SwingCameraAngle: String, Codable, CaseIterable, Identifiable {
    case side
    case diagonal
    case front
    case unknown

    var id: String { rawValue }
}

nonisolated enum ScoreConfidence: String, Codable, CaseIterable {
    case high
    case medium
    case low

    var displayName: String {
        switch self {
        case .high:
            return "High"
        case .medium:
            return "Medium"
        case .low:
            return "Low"
        }
    }
}

nonisolated struct SwingScoringProfile: Codable, Equatable {
    let id: String
    let displayName: String
    let hipShoulderSeparationWeight: Double
    let pelvisRotationWeight: Double
    let torsoRotationWeight: Double
    let timeToContactWeight: Double
    let leadLegWeight: Double
    let postureWeight: Double
    let pelvisThrustWeight: Double

    static let youthHighSchoolDefault = SwingScoringProfile(
        id: "youth_hs_v1",
        displayName: "Youth/High School",
        hipShoulderSeparationWeight: 25,
        pelvisRotationWeight: 15,
        torsoRotationWeight: 15,
        timeToContactWeight: 15,
        leadLegWeight: 10,
        postureWeight: 10,
        pelvisThrustWeight: 10
    )
}

nonisolated struct SwingAnalysisContext: Codable, Equatable {
    var handedness: BatterHandedness
    var cameraAngle: SwingCameraAngle
    var scoringProfile: SwingScoringProfile
    var totalVideoFrames: Int?

    static let youthHighSchoolDefault = SwingAnalysisContext(
        handedness: .right,
        cameraAngle: .unknown,
        scoringProfile: .youthHighSchoolDefault,
        totalVideoFrames: nil
    )
}

nonisolated struct SwingPhaseMarkers: Codable, Equatable {
    let setupTime: Double
    let heelStrikeTime: Double
    let firstMoveTime: Double
    let contactTime: Double
    let setupFrame: Int
    let heelStrikeFrame: Int
    let firstMoveFrame: Int
    let contactFrame: Int
}

nonisolated struct AdvancedSwingMetrics: Codable, Equatable {
    let hipShoulderSeparationAtFirstMove: Double
    let hipShoulderSeparationAtContact: Double
    let pelvisRotationAtContact: Double
    let torsoRotationAtContact: Double
    let leadKneeFlexionAtHeelStrike: Double
    let leadKneeFlexionAtContact: Double
    let leadKneeExtensionToContact: Double
    let timeToContact: Double
    let torsoForwardBendAtHeelStrike: Double
    let torsoForwardBendAtContact: Double
    let pelvisThrustProxy: Double
    let peakPelvisAngularVelocity: Double
    let peakTorsoAngularVelocity: Double
    let peakHandVelocity: Double
    let hipHorizontalMovement: Double
    let hipVerticalMovement: Double
}

nonisolated struct PoseQualityReport: Codable, Equatable {
    let totalFrames: Int
    let framesWithCoreJoints: Int
    let keyJointAvailability: Double
    let detectionRate: Double
    let jitterScore: Double
    let confidence: ScoreConfidence
    let warnings: [String]
}

nonisolated struct SwingScoreComponent: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let score: Double
    let weight: Double
    let value: Double
    let target: String
    let detail: String
}

nonisolated struct SwingScoreBreakdown: Codable, Equatable {
    let analysisVersion: String
    let profileID: String
    let profileName: String
    let rawScore: Double
    let finalScore: Double
    let confidence: ScoreConfidence
    let components: [SwingScoreComponent]
    let warnings: [String]
}

nonisolated struct SwingAnalysisResult: Codable, Equatable {
    let legacyMetrics: BiomechanicsMetrics
    let advancedMetrics: AdvancedSwingMetrics
    let phaseMarkers: SwingPhaseMarkers
    let poseQuality: PoseQualityReport
    let scoreBreakdown: SwingScoreBreakdown
    let warnings: [String]
}

extension Encodable {
    nonisolated var encodedJSONString: String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

extension Decodable {
    nonisolated static func decodeJSON(from json: String?) -> Self? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }
}
