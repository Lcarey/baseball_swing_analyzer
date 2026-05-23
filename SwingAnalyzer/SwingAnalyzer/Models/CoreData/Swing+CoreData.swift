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

    public var videoStartTime: Double {
        if let session {
            let offset = timestamp.timeIntervalSince(session.date)
            let reasonableUpperBound = max(session.recordingDuration, duration) + 5
            if offset >= 0, offset <= reasonableUpperBound {
                return offset
            }
        }

        let legacyOffset = timestamp.timeIntervalSince1970
        if legacyOffset >= 0, legacyOffset < 60 * 60 {
            return legacyOffset
        }

        return jointDataArray.first?.timestamp ?? 0
    }

    public var videoEndTime: Double {
        let frameEndTime = jointDataArray.last?.timestamp ?? 0
        return max(videoStartTime + duration, frameEndTime)
    }

    public var replayStartTime: Double {
        max(0, videoStartTime - AppConstants.swingReplayPadding)
    }

    public var replayEndTime: Double {
        let paddedEnd = videoEndTime + AppConstants.swingReplayPadding
        if let session, session.recordingDuration > 0 {
            return min(paddedEnd, session.recordingDuration)
        }
        return paddedEnd
    }

    public var replayDuration: Double {
        max(0, replayEndTime - replayStartTime)
    }

    public var videoDisplayTime: Date {
        if let session {
            return session.date.addingTimeInterval(videoStartTime)
        }

        return timestamp
    }
}
