import Foundation
import CoreData
import AVFoundation
import UIKit

/// Seeds the user's session library with example swing videos shipped in the app
/// bundle. If a sample is missing on launch (e.g. the user deleted it) it is
/// re-created and re-analyzed, so the example sessions are always present.
final class SampleSessionSeeder {
    struct SampleVideo {
        let bundleResourceName: String
        let bundleResourceExtension: String
        /// Stable Core Data identifier so we can detect whether this sample
        /// has already been seeded (and avoid duplicates across launches).
        let stableSessionID: UUID
        /// Stable on-disk filename in the Documents/RecordedVideos directory.
        let storedFileName: String
        /// Stable date used for the seeded Session so the list ordering does
        /// not jump around between launches.
        let displayDate: Date
    }

    static let shared = SampleSessionSeeder()

    private let samples: [SampleVideo]
    private let analysisQueue = DispatchQueue(label: "com.swinganalyzer.sampleSeeder", qos: .userInitiated)
    private var isRunning = false

    init(samples: [SampleVideo]? = nil) {
        if let samples = samples {
            self.samples = samples
        } else {
            self.samples = SampleSessionSeeder.defaultSamples()
        }
    }

    private static func defaultSamples() -> [SampleVideo] {
        let calendar = Calendar(identifier: .gregorian)
        func date(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            components.hour = hour
            components.minute = minute
            return calendar.date(from: components) ?? Date()
        }

        return [
            SampleVideo(
                bundleResourceName: "BP_000004",
                bundleResourceExtension: "mov",
                stableSessionID: UUID(uuidString: "B200B200-0000-0000-0000-000000000004")!,
                storedFileName: "sample_v2_BP_000004.mov",
                displayDate: date(year: 2026, month: 5, day: 15, hour: 14, minute: 30)
            ),
            SampleVideo(
                bundleResourceName: "BP_002026",
                bundleResourceExtension: "mov",
                stableSessionID: UUID(uuidString: "B200B200-0000-0000-0000-000000002026")!,
                storedFileName: "sample_v2_BP_002026.mov",
                displayDate: date(year: 2026, month: 5, day: 18, hour: 10, minute: 45)
            ),
            SampleVideo(
                bundleResourceName: "BP_002028",
                bundleResourceExtension: "mov",
                stableSessionID: UUID(uuidString: "B200B200-0000-0000-0000-000000002028")!,
                storedFileName: "sample_v2_BP_002028.mov",
                displayDate: date(year: 2026, month: 5, day: 20, hour: 16, minute: 15)
            )
        ]
    }

    /// Seeds any missing example sessions in the background. Safe to call on
    /// every launch: existing sample sessions are skipped.
    /// - Parameters:
    ///   - context: The view context to work against.
    ///   - onSessionUpdated: Called on the main thread after each sample session
    ///     finishes processing so the UI can refresh.
    func seedIfNeeded(
        context: NSManagedObjectContext,
        onSessionUpdated: (() -> Void)? = nil
    ) {
        DispatchQueue.main.async {
            guard !self.isRunning else { return }
            self.isRunning = true

            self.analysisQueue.async {
                let missing = self.missingSamples(context: context)
                guard !missing.isEmpty else {
                    DispatchQueue.main.async { self.isRunning = false }
                    return
                }

                self.processSamplesSequentially(missing, context: context, onSessionUpdated: onSessionUpdated) {
                    DispatchQueue.main.async { self.isRunning = false }
                }
            }
        }
    }

    // MARK: - Existence Check

    private func missingSamples(context: NSManagedObjectContext) -> [SampleVideo] {
        var missing: [SampleVideo] = []
        context.performAndWait {
            for sample in samples {
                let request: NSFetchRequest<Session> = Session.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", sample.stableSessionID as CVarArg)
                request.fetchLimit = 1
                if (try? context.count(for: request)) == 0 {
                    missing.append(sample)
                }
            }
        }
        return missing
    }

    // MARK: - Sequential Processing

    private func processSamplesSequentially(
        _ samples: [SampleVideo],
        context: NSManagedObjectContext,
        onSessionUpdated: (() -> Void)?,
        completion: @escaping () -> Void
    ) {
        guard let next = samples.first else {
            completion()
            return
        }

        processSample(next, context: context) {
            DispatchQueue.main.async {
                onSessionUpdated?()
            }
            self.analysisQueue.async {
                self.processSamplesSequentially(
                    Array(samples.dropFirst()),
                    context: context,
                    onSessionUpdated: onSessionUpdated,
                    completion: completion
                )
            }
        }
    }

    private func processSample(
        _ sample: SampleVideo,
        context: NSManagedObjectContext,
        completion: @escaping () -> Void
    ) {
        guard let bundleURL = Bundle.main.url(
            forResource: sample.bundleResourceName,
            withExtension: sample.bundleResourceExtension
        ) else {
            print("SampleSessionSeeder: missing bundled video for \(sample.bundleResourceName).\(sample.bundleResourceExtension)")
            completion()
            return
        }

        let destinationURL: URL
        do {
            destinationURL = try copyToDocumentsIfNeeded(from: bundleURL, fileName: sample.storedFileName)
        } catch {
            print("SampleSessionSeeder: failed to copy sample video: \(error)")
            completion()
            return
        }

        Task { [weak self] in
            guard let self = self else {
                completion()
                return
            }

            let duration = await self.duration(of: destinationURL)
            let thumbnail = await self.thumbnailData(of: destinationURL)

            await MainActor.run {
                self.createSessionAndAnalyze(
                    sample: sample,
                    videoURL: destinationURL,
                    duration: duration,
                    thumbnailData: thumbnail,
                    context: context,
                    completion: completion
                )
            }
        }
    }

    @MainActor
    private func createSessionAndAnalyze(
        sample: SampleVideo,
        videoURL: URL,
        duration: TimeInterval,
        thumbnailData: Data?,
        context: NSManagedObjectContext,
        completion: @escaping () -> Void
    ) {
        // Re-check existence on the main thread so we don't race with another
        // launch that may already be inserting the same sample.
        let request: NSFetchRequest<Session> = Session.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", sample.stableSessionID as CVarArg)
        request.fetchLimit = 1

        let existing = (try? context.fetch(request).first)

        let session: Session
        if let existing = existing {
            session = existing
        } else {
            session = Session(context: context)
            session.id = sample.stableSessionID
        }

        session.date = sample.displayDate
        session.recordingURL = videoURL.path
        session.recordingDuration = duration
        session.recordingFrameRate = Double(AppConstants.frameRate)
        session.averageScore = 0
        session.swingCount = 0
        if let thumbnailData {
            session.thumbnailData = thumbnailData
        }

        do {
            try context.save()
        } catch {
            print("SampleSessionSeeder: failed to save initial sample session: \(error)")
            completion()
            return
        }

        let analysisVM = SwingAnalysisViewModel(context: context)
        analysisVM.processVideo(url: videoURL, for: session) { result in
            switch result {
            case .success(let count):
                print("SampleSessionSeeder: seeded \(sample.bundleResourceName) with \(count) swing(s)")
            case .noSwingsDetected(let frameCount):
                print("SampleSessionSeeder: \(sample.bundleResourceName) returned no swings from \(frameCount) frame(s)")
            case .failed(let message):
                print("SampleSessionSeeder: \(sample.bundleResourceName) failed: \(message)")
            }
            completion()
        }
    }

    // MARK: - File Copy

    private func copyToDocumentsIfNeeded(from bundleURL: URL, fileName: String) throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videosDirectory = documentsPath.appendingPathComponent(AppConstants.videosDirectory)
        try FileManager.default.createDirectory(at: videosDirectory, withIntermediateDirectories: true)

        let destinationURL = videosDirectory.appendingPathComponent(fileName)
        if !FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.copyItem(at: bundleURL, to: destinationURL)
        }
        return destinationURL
    }

    // MARK: - Metadata Helpers

    private func duration(of url: URL) async -> TimeInterval {
        do {
            let asset = AVAsset(url: url)
            let duration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(duration)
            if seconds.isFinite, seconds > 0 {
                return seconds
            }
        } catch {
            print("SampleSessionSeeder: failed to load duration: \(error)")
        }
        return 0
    }

    private func thumbnailData(of url: URL) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            let asset = AVAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true

            do {
                let imageTime = CMTime(seconds: 0.2, preferredTimescale: 600)
                let image = try generator.copyCGImage(at: imageTime, actualTime: nil)
                return UIImage(cgImage: image).jpegData(compressionQuality: 0.75)
            } catch {
                return nil
            }
        }.value
    }
}
