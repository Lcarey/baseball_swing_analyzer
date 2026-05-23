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
    @NSManaged public var swing: Swing?
}

extension SwingMetrics: Identifiable {}
