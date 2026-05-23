import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var sessionViewModel = SessionViewModel()

    var body: some View {
        NavigationStack {
            SessionListView()
                .environmentObject(sessionViewModel)
        }
        .task {
            SampleSessionSeeder.shared.seedIfNeeded(context: viewContext) {
                sessionViewModel.fetchSessions()
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
