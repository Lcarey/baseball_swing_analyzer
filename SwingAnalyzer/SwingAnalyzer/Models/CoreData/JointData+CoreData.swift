import Foundation
import CoreData

@objc(JointData)
public class JointData: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var frameNumber: Int32
    @NSManaged public var timestamp: Double
    @NSManaged public var jointPositionsJSON: String
    @NSManaged public var swing: Swing?
}

extension JointData: Identifiable {
    var jointPositions: [String: CGPoint]? {
        guard let data = jointPositionsJSON.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: [String: Double]].self, from: data) else {
            return nil
        }

        var positions: [String: CGPoint] = [:]
        for (key, value) in dict {
            if let x = value["x"], let y = value["y"] {
                positions[key] = CGPoint(x: x, y: y)
            }
        }
        return positions
    }
}
