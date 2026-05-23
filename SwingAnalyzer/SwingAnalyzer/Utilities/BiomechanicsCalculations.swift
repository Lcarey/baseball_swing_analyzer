import Foundation
import CoreGraphics

struct BiomechanicsCalculations {

    // MARK: - Angle Calculations

    /// Calculate angle between three points (in degrees)
    /// - Parameters:
    ///   - point1: First point (e.g., hip)
    ///   - point2: Middle point/vertex (e.g., knee)
    ///   - point3: Third point (e.g., ankle)
    /// - Returns: Angle at point2 in degrees
    static func calculateAngle(point1: CGPoint, point2: CGPoint, point3: CGPoint) -> Double {
        let vector1 = CGPoint(x: point1.x - point2.x, y: point1.y - point2.y)
        let vector2 = CGPoint(x: point3.x - point2.x, y: point3.y - point2.y)

        let magnitude1 = sqrt(vector1.x * vector1.x + vector1.y * vector1.y)
        let magnitude2 = sqrt(vector2.x * vector2.x + vector2.y * vector2.y)

        guard magnitude1 > 0 && magnitude2 > 0 else { return 0 }

        let dotProduct = vector1.x * vector2.x + vector1.y * vector2.y
        let cosAngle = dotProduct / (magnitude1 * magnitude2)

        // Clamp to valid range for acos
        let clampedCos = max(-1.0, min(1.0, cosAngle))
        let angleRadians = acos(clampedCos)

        return Double(angleRadians).toDegrees()
    }

    /// Calculate the rotation angle of hips based on left and right hip positions
    static func calculateHipRotation(leftHip: CGPoint, rightHip: CGPoint, referenceLeftHip: CGPoint, referenceRightHip: CGPoint) -> Double {
        let currentVector = CGPoint(x: rightHip.x - leftHip.x, y: rightHip.y - leftHip.y)
        let referenceVector = CGPoint(x: referenceRightHip.x - referenceLeftHip.x, y: referenceRightHip.y - referenceLeftHip.y)

        let currentAngle = atan2(currentVector.y, currentVector.x)
        let referenceAngle = atan2(referenceVector.y, referenceVector.x)

        let rotationRadians = currentAngle - referenceAngle
        return abs(Double(rotationRadians).toDegrees())
    }

    // MARK: - Distance Calculations

    /// Calculate Euclidean distance between two points
    static func distance(from point1: CGPoint, to point2: CGPoint) -> Double {
        let dx = point2.x - point1.x
        let dy = point2.y - point1.y
        return sqrt(dx * dx + dy * dy)
    }

    /// Calculate horizontal movement (X-axis) between two points
    static func horizontalMovement(from point1: CGPoint, to point2: CGPoint) -> Double {
        return Double(point2.x - point1.x)
    }

    /// Calculate vertical movement (Y-axis) between two points
    static func verticalMovement(from point1: CGPoint, to point2: CGPoint) -> Double {
        return Double(point2.y - point1.y)
    }

    // MARK: - Velocity Calculations

    /// Calculate velocity between two points over time
    static func velocity(from point1: CGPoint, to point2: CGPoint, timeInterval: Double) -> Double {
        guard timeInterval > 0 else { return 0 }
        let dist = distance(from: point1, to: point2)
        return dist / timeInterval
    }

    // MARK: - Smoothing

    /// Apply moving average smoothing to an array of points
    static func smoothPoints(_ points: [CGPoint], windowSize: Int = 3) -> [CGPoint] {
        guard points.count >= windowSize else { return points }

        var smoothed: [CGPoint] = []
        let halfWindow = windowSize / 2

        for i in 0..<points.count {
            let start = max(0, i - halfWindow)
            let end = min(points.count, i + halfWindow + 1)

            var sumX: CGFloat = 0
            var sumY: CGFloat = 0
            var count = 0

            for j in start..<end {
                sumX += points[j].x
                sumY += points[j].y
                count += 1
            }

            smoothed.append(CGPoint(x: sumX / CGFloat(count), y: sumY / CGFloat(count)))
        }

        return smoothed
    }

    // MARK: - Coordinate Conversion

    /// Convert normalized coordinates (0-1) to pixel coordinates
    static func normalizedToPixel(point: CGPoint, imageSize: CGSize) -> CGPoint {
        return CGPoint(
            x: point.x * imageSize.width,
            y: (1.0 - point.y) * imageSize.height // Vision framework uses bottom-left origin
        )
    }

    /// Convert normalized distance to real-world inches (approximate)
    /// This is a rough estimate assuming person is ~6 feet tall and takes ~40% of frame height
    static func normalizedToInches(distance: Double, frameHeight: CGFloat) -> Double {
        let averagePersonHeightInches = 72.0 // 6 feet
        let personHeightRatio = 0.4 // Person occupies ~40% of frame height
        let pixelsPerInch = Double(frameHeight) * personHeightRatio / averagePersonHeightInches
        return distance / pixelsPerInch
    }

    // MARK: - Hip-Shoulder Alignment

    /// Calculate alignment percentage between hip line and shoulder line
    static func calculateAlignment(leftHip: CGPoint, rightHip: CGPoint, leftShoulder: CGPoint, rightShoulder: CGPoint) -> Double {
        let hipVector = CGPoint(x: rightHip.x - leftHip.x, y: rightHip.y - leftHip.y)
        let shoulderVector = CGPoint(x: rightShoulder.x - leftShoulder.x, y: rightShoulder.y - leftShoulder.y)

        let hipAngle = atan2(hipVector.y, hipVector.x)
        let shoulderAngle = atan2(shoulderVector.y, shoulderVector.x)

        let angleDifference = abs(hipAngle - shoulderAngle)
        let alignment = abs(cos(angleDifference)) * 100

        return alignment
    }
}
