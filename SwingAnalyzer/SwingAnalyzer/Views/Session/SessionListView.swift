import SwiftUI
import CoreData

struct SessionListView: View {
    @EnvironmentObject var viewModel: SessionViewModel
    @State private var showingCamera = false

    var body: some View {
        ZStack {
            if viewModel.sessions.isEmpty {
                emptyStateView
            } else {
                sessionsList
            }
        }
        .navigationTitle("Sessions")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingCamera = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView()
                .environmentObject(viewModel)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No Sessions Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Tap the + button to record your first swing session")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: {
                showingCamera = true
            }) {
                Label("Start Recording", systemImage: "video.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.top, 20)
        }
    }

    private var sessionsList: some View {
        List {
            ForEach(viewModel.sessions) { session in
                NavigationLink(destination: SessionAverageView(session: session)) {
                    SessionRowView(session: session)
                }
            }
            .onDelete(perform: deleteSessions)
        }
        .refreshable {
            viewModel.fetchSessions()
        }
    }

    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            let session = viewModel.sessions[index]
            viewModel.deleteSession(session)
        }
    }
}

struct SessionRowView: View {
    let session: Session

    var body: some View {
        HStack(spacing: 15) {
            // Score Circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                    .frame(width: 50, height: 50)

                Circle()
                    .trim(from: 0, to: session.averageScore / 100)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))

                Text("\(Int(session.averageScore))")
                    .font(.system(size: 16, weight: .bold))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(session.date.formattedForDisplay())
                    .font(.headline)

                Text("\(session.swingCount) swing\(session.swingCount == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }

    private var scoreColor: Color {
        if session.averageScore >= 80 {
            return AppConstants.colorGreen
        } else if session.averageScore >= 60 {
            return AppConstants.colorOrange
        } else {
            return AppConstants.colorRed
        }
    }
}

#Preview {
    NavigationStack {
        SessionListView()
            .environmentObject(SessionViewModel(context: PersistenceController.preview.container.viewContext))
    }
}
