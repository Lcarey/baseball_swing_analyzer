import SwiftUI
import AVFoundation
import UIKit

struct SwingSkeletonVideoView: View {
    let swing: Swing

    @State private var player: AVPlayer
    @State private var isPlaying = false
    @State private var currentTime: Double

    private var videoURL: URL {
        URL(fileURLWithPath: swing.videoURL)
    }

    private var jointFrames: [SwingJointFrame] {
        swing.jointDataArray.compactMap { jointData in
            guard let joints = jointData.jointPositions else { return nil }
            return SwingJointFrame(timestamp: jointData.timestamp, joints: joints)
        }
    }

    private var videoExists: Bool {
        FileManager.default.fileExists(atPath: videoURL.path)
    }

    init(swing: Swing) {
        self.swing = swing
        _player = State(initialValue: AVPlayer(url: URL(fileURLWithPath: swing.videoURL)))
        _currentTime = State(initialValue: swing.replayStartTime)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                if videoExists {
                    SkeletonOverlayPlayerRepresentable(
                        player: player,
                        frames: jointFrames,
                        startTime: swing.replayStartTime,
                        endTime: swing.replayEndTime,
                        currentTime: $currentTime,
                        onReachedEnd: {
                            isPlaying = false
                        }
                    )
                    .overlay(alignment: .topLeading) {
                        if jointFrames.isEmpty {
                            Label("Skeleton data unavailable", systemImage: "figure.walk")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.black.opacity(0.55))
                                .clipShape(Capsule())
                                .padding(12)
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "video.slash")
                            .font(.system(size: 44))
                            .foregroundColor(.white.opacity(0.75))

                        Text("Recording Unavailable")
                            .font(.headline)
                            .foregroundColor(.white)

                        Text("The original video file could not be found.")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.75))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                }

                playbackControls
            }
            .aspectRatio(9.0 / 16.0, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .onAppear {
            seekToReplayStart()
        }
        .onDisappear {
            player.pause()
            isPlaying = false
        }
    }

    private var playbackControls: some View {
        HStack(spacing: 12) {
            Button {
                togglePlayback()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(width: 42, height: 42)
                    .background(Color.white)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!videoExists)

            VStack(alignment: .leading, spacing: 3) {
                Text("Swing Replay")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)

                Text("\(formatElapsed(max(0, currentTime - swing.replayStartTime))) / \(formatElapsed(swing.replayDuration))")
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.white.opacity(0.78))
            }

            Spacer()

            Label("\(jointFrames.count) frames", systemImage: "figure.baseball")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.85))
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.0), .black.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func togglePlayback() {
        if isPlaying {
            player.pause()
            isPlaying = false
            return
        }

        if currentTime >= swing.replayEndTime - 0.04 {
            seekToReplayStart()
        }

        player.play()
        isPlaying = true
    }

    private func seekToReplayStart() {
        let targetTime = CMTime(seconds: swing.replayStartTime, preferredTimescale: 600)
        player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = swing.replayStartTime
    }

    private func formatElapsed(_ seconds: Double) -> String {
        let clampedSeconds = max(0, seconds)
        let wholeSeconds = Int(clampedSeconds)
        let tenths = Int((clampedSeconds - Double(wholeSeconds)) * 10)
        return String(format: "%d.%01ds", wholeSeconds, tenths)
    }
}

struct SwingJointFrame {
    let timestamp: Double
    let joints: [String: CGPoint]
}

struct SkeletonOverlayPlayerRepresentable: UIViewRepresentable {
    let player: AVPlayer
    let frames: [SwingJointFrame]
    let startTime: Double
    let endTime: Double
    @Binding var currentTime: Double
    let onReachedEnd: () -> Void

    func makeUIView(context: Context) -> SkeletonOverlayPlayerUIView {
        let view = SkeletonOverlayPlayerUIView()
        view.update(
            player: player,
            frames: frames,
            startTime: startTime,
            endTime: endTime
        )
        view.onTimeChange = { time in
            currentTime = time
        }
        view.onReachedEnd = onReachedEnd
        return view
    }

    func updateUIView(_ uiView: SkeletonOverlayPlayerUIView, context: Context) {
        uiView.update(
            player: player,
            frames: frames,
            startTime: startTime,
            endTime: endTime
        )
        uiView.onTimeChange = { time in
            currentTime = time
        }
        uiView.onReachedEnd = onReachedEnd
    }

    static func dismantleUIView(_ uiView: SkeletonOverlayPlayerUIView, coordinator: ()) {
        uiView.cleanup()
    }
}

final class SkeletonOverlayPlayerUIView: UIView {
    var onTimeChange: ((Double) -> Void)?
    var onReachedEnd: (() -> Void)?

    private let playerLayer = AVPlayerLayer()
    private let skeletonLineLayer = CAShapeLayer()
    private let skeletonJointLayer = CAShapeLayer()
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var frames: [SwingJointFrame] = []
    private var startTime: Double = 0
    private var endTime: Double = 0

    private let skeletonConnections: [(String, String)] = [
        ("nose", "neck"),
        ("neck", "left_shoulder"),
        ("neck", "right_shoulder"),
        ("left_shoulder", "right_shoulder"),
        ("left_shoulder", "left_elbow"),
        ("left_elbow", "left_wrist"),
        ("right_shoulder", "right_elbow"),
        ("right_elbow", "right_wrist"),
        ("left_shoulder", "left_hip"),
        ("right_shoulder", "right_hip"),
        ("left_hip", "right_hip"),
        ("left_hip", "left_knee"),
        ("left_knee", "left_ankle"),
        ("right_hip", "right_knee"),
        ("right_knee", "right_ankle")
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }

    deinit {
        cleanup()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
        skeletonLineLayer.frame = bounds
        skeletonJointLayer.frame = bounds
        updateSkeleton(at: player?.currentTime().seconds ?? startTime)
    }

    func update(player: AVPlayer, frames: [SwingJointFrame], startTime: Double, endTime: Double) {
        if self.player !== player {
            cleanup()
            self.player = player
            playerLayer.player = player
            attachTimeObserver(to: player)
        }

        self.frames = frames.sorted { $0.timestamp < $1.timestamp }
        self.startTime = startTime
        self.endTime = endTime
        updateSkeleton(at: player.currentTime().seconds)
    }

    func cleanup() {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }

        timeObserver = nil
    }

    private func setupLayers() {
        backgroundColor = .black

        playerLayer.videoGravity = .resizeAspect
        layer.addSublayer(playerLayer)

        skeletonLineLayer.fillColor = UIColor.clear.cgColor
        skeletonLineLayer.strokeColor = UIColor.white.cgColor
        skeletonLineLayer.lineCap = .round
        skeletonLineLayer.lineJoin = .round
        skeletonLineLayer.shadowColor = UIColor.black.cgColor
        skeletonLineLayer.shadowOpacity = 0.55
        skeletonLineLayer.shadowRadius = 3
        skeletonLineLayer.shadowOffset = .zero
        layer.addSublayer(skeletonLineLayer)

        skeletonJointLayer.fillColor = UIColor.white.cgColor
        skeletonJointLayer.strokeColor = UIColor.white.cgColor
        skeletonJointLayer.shadowColor = UIColor.black.cgColor
        skeletonJointLayer.shadowOpacity = 0.55
        skeletonJointLayer.shadowRadius = 3
        skeletonJointLayer.shadowOffset = .zero
        layer.addSublayer(skeletonJointLayer)
    }

    private func attachTimeObserver(to player: AVPlayer) {
        let interval = CMTime(seconds: 1.0 / 30.0, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self, weak player] time in
            guard let self, let player else { return }

            let seconds = time.seconds
            self.onTimeChange?(seconds)
            self.updateSkeleton(at: seconds)

            if self.endTime > self.startTime, seconds >= self.endTime {
                player.pause()
                let targetTime = CMTime(seconds: self.startTime, preferredTimescale: 600)
                player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
                self.updateSkeleton(at: self.startTime)
                self.onTimeChange?(self.startTime)
                self.onReachedEnd?()
            }
        }
    }

    private func updateSkeleton(at timestamp: Double) {
        guard bounds.width > 0,
              bounds.height > 0,
              let frame = nearestFrame(to: timestamp) else {
            skeletonLineLayer.path = nil
            skeletonJointLayer.path = nil
            return
        }

        let linePath = UIBezierPath()
        let jointPath = UIBezierPath()
        let lineWidth = max(5, min(bounds.width, bounds.height) * 0.018)
        let jointRadius = lineWidth * 0.75

        for connection in skeletonConnections {
            guard let firstPoint = frame.joints[connection.0],
                  let secondPoint = frame.joints[connection.1] else {
                continue
            }

            linePath.move(to: layerPoint(forVisionPoint: firstPoint))
            linePath.addLine(to: layerPoint(forVisionPoint: secondPoint))
        }

        for point in frame.joints.values {
            let center = layerPoint(forVisionPoint: point)
            let rect = CGRect(
                x: center.x - jointRadius,
                y: center.y - jointRadius,
                width: jointRadius * 2,
                height: jointRadius * 2
            )
            jointPath.append(UIBezierPath(ovalIn: rect))
        }

        skeletonLineLayer.lineWidth = lineWidth
        skeletonJointLayer.lineWidth = max(1, lineWidth * 0.25)
        skeletonLineLayer.path = linePath.cgPath
        skeletonJointLayer.path = jointPath.cgPath
    }

    private func nearestFrame(to timestamp: Double) -> SwingJointFrame? {
        guard !frames.isEmpty else { return nil }

        var lowerBound = 0
        var upperBound = frames.count

        while lowerBound < upperBound {
            let midpoint = (lowerBound + upperBound) / 2
            if frames[midpoint].timestamp < timestamp {
                lowerBound = midpoint + 1
            } else {
                upperBound = midpoint
            }
        }

        let candidates = [lowerBound - 1, lowerBound]
            .filter { frames.indices.contains($0) }

        guard let bestIndex = candidates.min(by: {
            abs(frames[$0].timestamp - timestamp) < abs(frames[$1].timestamp - timestamp)
        }) else {
            return nil
        }

        let frame = frames[bestIndex]
        return abs(frame.timestamp - timestamp) <= 0.2 ? frame : nil
    }

    private func layerPoint(forVisionPoint point: CGPoint) -> CGPoint {
        let videoRect = playerLayer.videoRect == .zero ? bounds : playerLayer.videoRect
        let normalizedX = min(max(point.x, 0), 1)
        let normalizedY = 1 - min(max(point.y, 0), 1)

        return CGPoint(
            x: videoRect.minX + normalizedX * videoRect.width,
            y: videoRect.minY + normalizedY * videoRect.height
        )
    }
}
