import Foundation
import CoreData
import Combine

class SessionViewModel: ObservableObject {
    @Published var sessions: [Session] = []
    @Published var isLoading = false

    private var viewContext: NSManagedObjectContext

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.viewContext = context
        fetchSessions()
    }

    func fetchSessions() {
        isLoading = true

        let request: NSFetchRequest<Session> = Session.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Session.date, ascending: false)]

        do {
            sessions = try viewContext.fetch(request)
        } catch {
            print("Error fetching sessions: \(error)")
            sessions = []
        }

        isLoading = false
    }

    func createSession() -> Session {
        let session = Session(context: viewContext)
        session.id = UUID()
        session.date = Date()
        session.averageScore = 0
        session.recordingDuration = 0
        session.swingCount = 0

        saveContext()
        fetchSessions()

        return session
    }

    func deleteSession(_ session: Session) {
        // Delete associated video files
        for swing in session.swingsArray {
            deleteVideoFile(at: swing.videoURL)
        }

        viewContext.delete(session)
        saveContext()
        fetchSessions()
    }

    func updateSessionAverageScore(_ session: Session) {
        let swings = session.swingsArray
        guard !swings.isEmpty else {
            session.averageScore = 0
            return
        }

        let totalScore = swings.reduce(0.0) { $0 + $1.score }
        session.averageScore = totalScore / Double(swings.count)
        session.swingCount = Int16(swings.count)

        saveContext()
    }

    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }

    private func deleteVideoFile(at urlString: String) {
        let fileManager = FileManager.default
        if let url = URL(string: urlString),
           fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }
    }
}

extension Session {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Session> {
        return NSFetchRequest<Session>(entityName: "Session")
    }
}
