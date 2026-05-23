import Foundation
import CoreData

@objc(Swing)
public class Swing: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var timestamp: Date
    @NSManaged public var score: Double
    @NSManaged public var videoURL: String
    @NSManaged public var duration: Double
    @NSManaged public var thumbnailData: Data?
    @NSManaged public var session: Session?
    @NSManaged public var metrics: SwingMetrics?
    @NSManaged public var jointData: NSSet?
}

// MARK: Generated accessors for jointData
extension Swing {
    @objc(addJointDataObject:)
    @NSManaged public func addToJointData(_ value: JointData)

    @objc(removeJointDataObject:)
    @NSManaged public func removeFromJointData(_ value: JointData)

    @objc(addJointData:)
    @NSManaged public func addToJointData(_ values: NSSet)

    @objc(removeJointData:)
    @NSManaged public func removeFromJointData(_ values: NSSet)
}

extension Swing: Identifiable {
    public var jointDataArray: [JointData] {
        let set = jointData as? Set<JointData> ?? []
        return set.sorted { $0.frameNumber < $1.frameNumber }
    }
}
