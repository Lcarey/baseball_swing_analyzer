import Foundation
import CoreData

@objc(Session)
public class Session: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var date: Date
    @NSManaged public var location: String?
    @NSManaged public var averageScore: Double
    @NSManaged public var swingCount: Int16
    @NSManaged public var swings: NSSet?
}

// MARK: Generated accessors for swings
extension Session {
    @objc(addSwingsObject:)
    @NSManaged public func addToSwings(_ value: Swing)

    @objc(removeSwingsObject:)
    @NSManaged public func removeFromSwings(_ value: Swing)

    @objc(addSwings:)
    @NSManaged public func addToSwings(_ values: NSSet)

    @objc(removeSwings:)
    @NSManaged public func removeFromSwings(_ values: NSSet)
}

extension Session: Identifiable {
    public var swingsArray: [Swing] {
        let set = swings as? Set<Swing> ?? []
        return set.sorted { $0.timestamp > $1.timestamp }
    }
}
