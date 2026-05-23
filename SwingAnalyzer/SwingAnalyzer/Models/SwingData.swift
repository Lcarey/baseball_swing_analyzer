import Foundation
import CoreGraphics

struct SwingData {
    let startTime: Double
    let endTime: Double
    let peakVelocityTime: Double
    var duration: Double {
        endTime - startTime
    }
}

struct FrameJointData {
    let frameNumber: Int
    let timestamp: Double
    let joints: [String: CGPoint]
}

enum JointName: String, CaseIterable {
    case nose
    case neck
    case leftShoulder
    case rightShoulder
    case leftElbow
    case rightElbow
    case leftWrist
    case rightWrist
    case leftHip
    case rightHip
    case leftKnee
    case rightKnee
    case leftAnkle
    case rightAnkle

    var visionKey: String {
        switch self {
        case .nose: return "nose"
        case .neck: return "neck"
        case .leftShoulder: return "left_shoulder"
        case .rightShoulder: return "right_shoulder"
        case .leftElbow: return "left_elbow"
        case .rightElbow: return "right_elbow"
        case .leftWrist: return "left_wrist"
        case .rightWrist: return "right_wrist"
        case .leftHip: return "left_hip"
        case .rightHip: return "right_hip"
        case .leftKnee: return "left_knee"
        case .rightKnee: return "right_knee"
        case .leftAnkle: return "left_ankle"
        case .rightAnkle: return "right_ankle"
        }
    }
}
