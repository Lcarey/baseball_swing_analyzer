import SwiftUI
import CoreData

struct ContentView: View {
    @StateObject private var sessionViewModel = SessionViewModel()

    var body: some View {
        NavigationStack {
            SessionListView()
                .environmentObject(sessionViewModel)
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
