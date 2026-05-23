import Foundation

enum SwingDetectionSensitivityPreset: String, CaseIterable, Codable, Identifiable {
    case conservative
    case balanced
    case sensitive
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .conservative:
            return "Conservative"
        case .balanced:
            return "Balanced"
        case .sensitive:
            return "Sensitive"
        case .custom:
            return "Custom"
        }
    }
}

enum SwingDetectionCameraAnglePreset: String, CaseIterable, Codable, Identifiable {
    case side
    case diagonal
    case front
    case unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .side:
            return "Side"
        case .diagonal:
            return "Diagonal"
        case .front:
            return "Front"
        case .unknown:
            return "Unknown"
        }
    }
}

struct SwingDetectionConfiguration: Codable, Equatable {
    var version: Int = 1
    var expectedSwingCount: Int
    var sensitivityPreset: SwingDetectionSensitivityPreset
    var cameraAnglePreset: SwingDetectionCameraAnglePreset
    var scoreThreshold: Double
    var releaseThreshold: Double
    var minHandVelocity: Double
    var minArmVelocity: Double
    var minSwingDuration: Double
    var maxSwingDuration: Double
    var minSwingSeparation: Double
    var hipWeight: Double
    var shoulderWeight: Double
    var armWeight: Double
    var batProxyWeight: Double

    static func balanced(expectedSwingCount: Int) -> SwingDetectionConfiguration {
        SwingDetectionConfiguration(
            expectedSwingCount: max(expectedSwingCount, 0),
            sensitivityPreset: .balanced,
            cameraAnglePreset: .unknown,
            scoreThreshold: 1.05,
            releaseThreshold: 0.58,
            minHandVelocity: 0.35,
            minArmVelocity: 0.25,
            minSwingDuration: AppConstants.minSwingDuration,
            maxSwingDuration: max(AppConstants.maxSwingDuration, 1.25),
            minSwingSeparation: 1.8,
            hipWeight: 0.18,
            shoulderWeight: 0.18,
            armWeight: 0.26,
            batProxyWeight: 0.38
        )
    }

    static func forSession(_ session: Session) -> SwingDetectionConfiguration {
        if let savedConfiguration = session.lastDetectionConfiguration {
            return savedConfiguration
        }

        let currentCount = Int(session.swingCount)
        return .balanced(expectedSwingCount: currentCount > 0 ? currentCount : 1)
    }

    func applyingSensitivityPreset(_ preset: SwingDetectionSensitivityPreset) -> SwingDetectionConfiguration {
        var configuration = self
        configuration.sensitivityPreset = preset

        switch preset {
        case .conservative:
            configuration.scoreThreshold = 1.25
            configuration.releaseThreshold = 0.70
            configuration.minHandVelocity = 0.45
            configuration.minArmVelocity = 0.32
            configuration.minSwingSeparation = 2.2
        case .balanced:
            configuration.scoreThreshold = 1.05
            configuration.releaseThreshold = 0.58
            configuration.minHandVelocity = 0.35
            configuration.minArmVelocity = 0.25
            configuration.minSwingSeparation = 1.8
        case .sensitive:
            configuration.scoreThreshold = 0.85
            configuration.releaseThreshold = 0.45
            configuration.minHandVelocity = 0.25
            configuration.minArmVelocity = 0.18
            configuration.minSwingSeparation = 1.4
        case .custom:
            break
        }

        return configuration
    }

    func applyingCameraAnglePreset(_ preset: SwingDetectionCameraAnglePreset) -> SwingDetectionConfiguration {
        var configuration = self
        configuration.cameraAnglePreset = preset

        switch preset {
        case .side:
            configuration.hipWeight = 0.18
            configuration.shoulderWeight = 0.20
            configuration.armWeight = 0.26
            configuration.batProxyWeight = 0.36
        case .diagonal:
            configuration.hipWeight = 0.12
            configuration.shoulderWeight = 0.18
            configuration.armWeight = 0.28
            configuration.batProxyWeight = 0.42
        case .front:
            configuration.hipWeight = 0.08
            configuration.shoulderWeight = 0.16
            configuration.armWeight = 0.28
            configuration.batProxyWeight = 0.48
        case .unknown:
            configuration.hipWeight = 0.18
            configuration.shoulderWeight = 0.18
            configuration.armWeight = 0.26
            configuration.batProxyWeight = 0.38
        }

        return configuration
    }

    var normalizedWeights: (hip: Double, shoulder: Double, arm: Double, batProxy: Double) {
        let total = hipWeight + shoulderWeight + armWeight + batProxyWeight
        guard total > 0 else {
            return (0.18, 0.18, 0.26, 0.38)
        }

        return (
            hip: hipWeight / total,
            shoulder: shoulderWeight / total,
            arm: armWeight / total,
            batProxy: batProxyWeight / total
        )
    }

    var settingsJSON: String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decode(from json: String?) -> SwingDetectionConfiguration? {
        guard let json, let data = json.data(using: .utf8) else {
            return nil
        }

        return try? JSONDecoder().decode(SwingDetectionConfiguration.self, from: data)
    }
}

