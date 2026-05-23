import Vision

enum VisionJointMapping {
    static let trackedJointNames: [VNHumanBodyPoseObservation.JointName] = [
        .nose,
        .neck,
        .leftShoulder,
        .rightShoulder,
        .leftElbow,
        .rightElbow,
        .leftWrist,
        .rightWrist,
        .leftHip,
        .rightHip,
        .leftKnee,
        .rightKnee,
        .leftAnkle,
        .rightAnkle
    ]

    static func appKey(for jointName: VNHumanBodyPoseObservation.JointName) -> String {
        switch jointName {
        case .nose:
            return JointName.nose.visionKey
        case .neck:
            return JointName.neck.visionKey
        case .leftShoulder:
            return JointName.leftShoulder.visionKey
        case .rightShoulder:
            return JointName.rightShoulder.visionKey
        case .leftElbow:
            return JointName.leftElbow.visionKey
        case .rightElbow:
            return JointName.rightElbow.visionKey
        case .leftWrist:
            return JointName.leftWrist.visionKey
        case .rightWrist:
            return JointName.rightWrist.visionKey
        case .leftHip:
            return JointName.leftHip.visionKey
        case .rightHip:
            return JointName.rightHip.visionKey
        case .leftKnee:
            return JointName.leftKnee.visionKey
        case .rightKnee:
            return JointName.rightKnee.visionKey
        case .leftAnkle:
            return JointName.leftAnkle.visionKey
        case .rightAnkle:
            return JointName.rightAnkle.visionKey
        default:
            return jointName.rawValue.rawValue
        }
    }
}
