import Foundation

struct BiomechanicsMetrics {
    let kneeBend: Double // degrees
    let hipRotation: Double // degrees
    let hipHorizontalMovement: Double // inches
    let hipVerticalMovement: Double // inches
    let hipShoulderAlignment: Double // percentage 0-100
    let timeToContact: Double // seconds

    var compositeScore: Double {
        calculateCompositeScore()
    }

    private func calculateCompositeScore() -> Double {
        var score: Double = 0
        var totalWeight: Double = 0

        // Knee Bend (weight: 20)
        let kneeBendScore = scoreKneeBend(kneeBend)
        score += kneeBendScore * 20
        totalWeight += 20

        // Hip Rotation (weight: 25)
        let hipRotationScore = scoreHipRotation(hipRotation)
        score += hipRotationScore * 25
        totalWeight += 25

        // Hip-Shoulder Alignment (weight: 25)
        let alignmentScore = scoreAlignment(hipShoulderAlignment)
        score += alignmentScore * 25
        totalWeight += 25

        // Time to Contact (weight: 15)
        let timeScore = scoreTimeToContact(timeToContact)
        score += timeScore * 15
        totalWeight += 15

        // Hip Movement (weight: 15 combined)
        let movementScore = scoreHipMovement(horizontal: hipHorizontalMovement, vertical: hipVerticalMovement)
        score += movementScore * 15
        totalWeight += 15

        return score / totalWeight
    }

    private func scoreKneeBend(_ angle: Double) -> Double {
        switch angle {
        case 140...160:
            return 100
        case 120..<140, 160..<180:
            return 70
        default:
            return 30
        }
    }

    private func scoreHipRotation(_ angle: Double) -> Double {
        switch angle {
        case 90...:
            return 100
        case 60..<90:
            return 70
        default:
            return 30
        }
    }

    private func scoreAlignment(_ percentage: Double) -> Double {
        switch percentage {
        case 80...:
            return 100
        case 60..<80:
            return 70
        default:
            return 30
        }
    }

    private func scoreTimeToContact(_ time: Double) -> Double {
        switch time {
        case 0.4...0.5:
            return 100
        case 0.3..<0.4, 0.5..<0.6:
            return 70
        default:
            return 30
        }
    }

    private func scoreHipMovement(horizontal: Double, vertical: Double) -> Double {
        // Optimal ranges: horizontal 2-5 inches forward, vertical -2 to 2 inches
        let horizontalScore: Double
        switch abs(horizontal) {
        case 2...5:
            horizontalScore = 100
        case 1..<2, 5..<7:
            horizontalScore = 70
        default:
            horizontalScore = 30
        }

        let verticalScore: Double
        switch abs(vertical) {
        case 0...2:
            verticalScore = 100
        case 2..<4:
            verticalScore = 70
        default:
            verticalScore = 30
        }

        return (horizontalScore + verticalScore) / 2
    }

    func getMetricColor(for metric: MetricType) -> MetricColor {
        let score: Double
        switch metric {
        case .kneeBend:
            score = scoreKneeBend(kneeBend)
        case .hipRotation:
            score = scoreHipRotation(hipRotation)
        case .hipHorizontalMovement:
            score = scoreHipMovement(horizontal: hipHorizontalMovement, vertical: 0)
        case .hipVerticalMovement:
            score = scoreHipMovement(horizontal: 0, vertical: hipVerticalMovement)
        case .hipShoulderAlignment:
            score = scoreAlignment(hipShoulderAlignment)
        case .timeToContact:
            score = scoreTimeToContact(timeToContact)
        }

        if score >= 90 {
            return .green
        } else if score >= 60 {
            return .orange
        } else {
            return .red
        }
    }
}

enum MetricType {
    case kneeBend
    case hipRotation
    case hipHorizontalMovement
    case hipVerticalMovement
    case hipShoulderAlignment
    case timeToContact
}

enum MetricColor {
    case green
    case orange
    case red
}
