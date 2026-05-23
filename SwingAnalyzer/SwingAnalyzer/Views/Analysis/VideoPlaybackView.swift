import SwiftUI
import AVKit

struct VideoPlaybackView: View {
    let videoURL: URL
    @State private var player: AVPlayer

    init(videoURL: URL) {
        self.videoURL = videoURL
        _player = State(initialValue: AVPlayer(url: videoURL))
    }

    var body: some View {
        VStack {
            if FileManager.default.fileExists(atPath: videoURL.path) {
                VideoPlayer(player: player)
                    .ignoresSafeArea(edges: .bottom)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("Video Unavailable")
                        .font(.headline)

                    Text("The recording file could not be found.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
        .navigationTitle("Recording")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            player.pause()
        }
    }
}
