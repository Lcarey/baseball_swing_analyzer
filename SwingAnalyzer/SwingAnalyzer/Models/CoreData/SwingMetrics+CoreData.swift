import Foundation
import CoreData

@objc(SwingMetrics)
public class SwingMetrics: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var kneeBend: Double
    @NSManaged public var hipRotation: Double
    @NSManaged public var hipHorizontalMovement: Double
    @NSManaged public var hipVerticalMovement: Double
    @NSManaged public var hipShoulderAlignment: Double
    @NSManaged public var timeToContact: Double
    @NSManaged public var analysisVersion: String?
    @NSManaged public var scoreConfidence: String?
    @NSManaged public var scoreBreakdownJSON: String?
    @NSManaged public var phaseMarkersJSON: String?
    @NSManaged public var advancedMetricsJSON: String?
    @NSManaged public var swing: Swing?
}

extension SwingMetrics: Identifiable {
    var decodedScoreBreakdown: SwingScoreBreakdown? {
        SwingScoreBreakdown.decodeJSON(from: scoreBreakdownJSON)
    }

    var decodedPhaseMarkers: SwingPhaseMarkers? {
        SwingPhaseMarkers.decodeJSON(from: phaseMarkersJSON)
    }

    var decodedAdvancedMetrics: AdvancedSwingMetrics? {
        AdvancedSwingMetrics.decodeJSON(from: advancedMetricsJSON)
    }

    var decodedScoreConfidence: ScoreConfidence? {
        guard let scoreConfidence else { return nil }
        return ScoreConfidence(rawValue: scoreConfidence)
    }
}
