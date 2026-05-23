import SwiftUI
import AVFoundation
import CoreData

struct CameraView: View {
    @StateObject private var viewModel: RecordingViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var sessionViewModel: SessionViewModel

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        _viewModel = StateObject(wrappedValue: RecordingViewModel(context: context))
    }

    var body: some View {
        ZStack {
            // Camera Preview
            if let session = viewModel.captureSession {
                CameraPreviewView(session: session)
                    .ignoresSafeArea()
            } else {
                Color.black
                    .ignoresSafeArea()
            }

            // Overlay UI
            VStack {
                // Top bar
                HStack {
                    Button(action: {
                        if viewModel.isRecording {
                            stopRecordingAndDismiss()
                        } else {
                            dismiss()
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding()

                    Spacer()

                    // Recording indicator and timer
                    if viewModel.isRecording {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 12, height: 12)

                            Text(formatDuration(viewModel.recordingDuration))
                                .font(.system(size: 18, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(20)
                        .padding()
                    }
                }

                Spacer()

                // Grid overlay (for positioning guidance)
                if !viewModel.isRecording {
                    GridOverlay()
                        .opacity(0.3)
                }

                Spacer()

                // Recording controls
                RecordingControlsView(
                    isRecording: viewModel.isRecording,
                    onRecord: {
                        if viewModel.isRecording {
                            stopRecordingAndDismiss()
                        } else {
                            startRecording()
                        }
                    }
                )
                .padding(.bottom, 50)
            }

            // Authorization overlay
            if !viewModel.checkCameraAuthorization() {
                CameraAuthorizationView {
                    viewModel.requestCameraAccess()
                }
            }
        }
        .onAppear {
            if viewModel.checkCameraAuthorization() {
                viewModel.setupCamera()
                viewModel.createSession()
            }
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.error ?? "Unknown error")
        }
    }

    private func startRecording() {
        viewModel.startRecording()
    }

    private func stopRecordingAndDismiss() {
        viewModel.stopRecording { url in
            if let url = url {
                viewModel.saveRecording(url: url)
                sessionViewModel.fetchSessions()
            }
            dismiss()
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let milliseconds = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%01d", minutes, seconds, milliseconds)
    }
}

// MARK: - Recording Controls

struct RecordingControlsView: View {
    let isRecording: Bool
    let onRecord: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Record button
            Button(action: onRecord) {
                ZStack {
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 4)
                        .frame(width: 80, height: 80)

                    if isRecording {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red)
                            .frame(width: 32, height: 32)
                    } else {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 64, height: 64)
                    }
                }
            }

            Text(isRecording ? "Stop Recording" : "Start Recording")
                .font(.subheadline)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Grid Overlay

struct GridOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                // Vertical lines
                let thirdWidth = geometry.size.width / 3
                path.move(to: CGPoint(x: thirdWidth, y: 0))
                path.addLine(to: CGPoint(x: thirdWidth, y: geometry.size.height))
                path.move(to: CGPoint(x: thirdWidth * 2, y: 0))
                path.addLine(to: CGPoint(x: thirdWidth * 2, y: geometry.size.height))

                // Horizontal lines
                let thirdHeight = geometry.size.height / 3
                path.move(to: CGPoint(x: 0, y: thirdHeight))
                path.addLine(to: CGPoint(x: geometry.size.width, y: thirdHeight))
                path.move(to: CGPoint(x: 0, y: thirdHeight * 2))
                path.addLine(to: CGPoint(x: geometry.size.width, y: thirdHeight * 2))
            }
            .stroke(Color.white, lineWidth: 1)
        }
    }
}

// MARK: - Camera Authorization View

struct CameraAuthorizationView: View {
    let onRequestAccess: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "video.slash")
                    .font(.system(size: 60))
                    .foregroundColor(.white)

                Text("Camera Access Required")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Text("SwingAnalyzer needs camera access to record and analyze your swings")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Button(action: onRequestAccess) {
                    Text("Enable Camera Access")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.top, 20)

                Button(action: {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }) {
                    Text("Open Settings")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

#Preview {
    CameraView()
        .environmentObject(SessionViewModel())
}
