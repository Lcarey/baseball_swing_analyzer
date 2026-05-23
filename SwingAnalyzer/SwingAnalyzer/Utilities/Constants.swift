import Foundation
import SwiftUI
import AVFoundation

struct AppConstants {
    // Video Settings
    static let videoWidth: Int = 1080
    static let videoHeight: Int = 1920
    static let frameRate: Int = 120
    static let videoBitRate: Int = 12_000_000

    // Exposure Settings
    static let shutterSpeedFast: CMTime = CMTime(value: 1, timescale: 1000)
    static let shutterSpeedMedium: CMTime = CMTime(value: 1, timescale: 500)
    static let lowLightISOThreshold: Float = 400.0

    // Swing replay UI
    static let swingReplayPadding: Double = 0.1

    // Analysis Settings
    static let minSwingDuration: Double = 0.3 // seconds
    static let maxSwingDuration: Double = 1.0 // seconds
    static let motionThreshold: Double = 0.05 // normalized units
    static let rotationThreshold: Double = 30.0 // degrees
    static let confidenceThreshold: Float = 0.3

    // UI Colors
    static let colorGreen = Color(red: 0.3, green: 0.686, blue: 0.314)
    static let colorOrange = Color(red: 1.0, green: 0.596, blue: 0.0)
    static let colorRed = Color(red: 0.957, green: 0.263, blue: 0.212)

    // Storage
    static let videosDirectory = "RecordedVideos"
    static let thumbnailsDirectory = "Thumbnails"
}

extension Double {
    func toRadians() -> Double {
        return self * .pi / 180
    }

    func toDegrees() -> Double {
        return self * 180 / .pi
    }
}

extension Date {
    func formattedForDisplay() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE MMM d, yyyy"
        return formatter.string(from: self)
    }

    func formattedTimeForDisplay() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: self)
    }
}
