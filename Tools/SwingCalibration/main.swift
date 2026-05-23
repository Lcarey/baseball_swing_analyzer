import Foundation

struct CalibrationVideoManifest: Codable {
    let version: Int
    let videos: [CalibrationVideoEntry]
}

struct CalibrationVideoEntry: Codable {
    let path: String
    let label: String
    let expectedSwingCount: Int
    let handedness: BatterHandedness
    let cameraAngle: SwingCameraAngle
    let reviewOnly: Bool
}

struct CalibrationRunReport: Codable {
    let generatedAt: Date
    let inputDirectory: String
    let outputDirectory: String
    let profile: String
    let videos: [CalibrationVideoReport]
    let aggregate: CalibrationAggregate
}

struct CalibrationVideoReport: Codable {
    let videoPath: String
    let label: String
    let expectedSwingCount: Int
    let reviewOnly: Bool
    let poseFrameCount: Int
    let candidateCount: Int
    let selectedSwingCount: Int
    let swings: [CalibrationSwingReport]
    let warnings: [String]
}

struct CalibrationSwingReport: Codable {
    let index: Int
    let startTime: Double
    let duration: Double
    let score: Double
    let confidence: ScoreConfidence
    let advancedMetrics: AdvancedSwingMetrics
    let scoreBreakdown: SwingScoreBreakdown
    let warnings: [String]
}

struct CalibrationAggregate: Codable {
    let swingCount: Int
    let score: CalibrationDistribution
    let pelvisRotationAtContact: CalibrationDistribution
    let torsoRotationAtContact: CalibrationDistribution
    let hipShoulderSeparationAtFirstMove: CalibrationDistribution
    let timeToContact: CalibrationDistribution
}

struct CalibrationDistribution: Codable {
    let median: Double
    let q1: Double
    let q3: Double
}

enum SwingCalibrationCLI {
    static func main() throws {
        let options = try CalibrationOptions(arguments: CommandLine.arguments)

        if options.showHelp {
            printHelp()
            return
        }

        if options.selfTest {
            try runSelfTest()
            return
        }

        guard let input = options.input, let output = options.output else {
            printHelp()
            throw CalibrationError.message("Missing required --input and --output arguments.")
        }

        let runner = CalibrationRunner(inputDirectory: input, outputDirectory: output, profileID: options.profile)
        let report = try runner.run()
        print("Processed \(report.videos.count) videos and \(report.aggregate.swingCount) swings.")
        print("Report: \(output.appendingPathComponent("report.md").path)")
    }

    private static func printHelp() {
        print("""
        Usage:
          SwingCalibration --input <folder> --output <folder> [--profile youth_hs]
          SwingCalibration --self-test

        Example:
          SwingCalibration --input "/Users/lcarey/Desktop/test images and videos/example good swings/smaller videos of good swings" --output "/Users/lcarey/Desktop/test images and videos/example good swings/scoring_calibration" --profile youth_hs
        """)
    }

    private static func runSelfTest() throws {
        let low = ScoreConfidence.low
        guard low.displayName == "Low" else {
            throw CalibrationError.message("ScoreConfidence display name failed.")
        }

        let metrics = BiomechanicsMetrics(
            kneeBend: 35,
            hipRotation: 85,
            hipHorizontalMovement: 2,
            hipVerticalMovement: 1,
            hipShoulderAlignment: 94,
            timeToContact: 0.18
        )
        guard metrics.compositeScore > 0 else {
            throw CalibrationError.message("Legacy metric fallback score failed.")
        }

        print("SwingCalibration self-test passed.")
    }
}

try SwingCalibrationCLI.main()

struct CalibrationOptions {
    var input: URL?
    var output: URL?
    var profile = "youth_hs"
    var showHelp = false
    var selfTest = false

    init(arguments: [String]) throws {
        var index = 1
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--help", "-h":
                showHelp = true
            case "--self-test":
                selfTest = true
            case "--input":
                index += 1
                guard index < arguments.count else { throw CalibrationError.message("Missing value for --input.") }
                input = URL(fileURLWithPath: NSString(string: arguments[index]).expandingTildeInPath)
            case "--output":
                index += 1
                guard index < arguments.count else { throw CalibrationError.message("Missing value for --output.") }
                output = URL(fileURLWithPath: NSString(string: arguments[index]).expandingTildeInPath)
            case "--profile":
                index += 1
                guard index < arguments.count else { throw CalibrationError.message("Missing value for --profile.") }
                profile = arguments[index]
            default:
                throw CalibrationError.message("Unknown argument: \(argument)")
            }
            index += 1
        }
    }
}

enum CalibrationError: Error, LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let message):
            return message
        }
    }
}

final class CalibrationRunner {
    private let inputDirectory: URL
    private let outputDirectory: URL
    private let profileID: String
    private let fileManager = FileManager.default
    private let poseDetectionService = PoseDetectionService()
    private let swingDetectionService = SwingDetectionService()
    private let biomechanicsAnalyzer = BiomechanicsAnalyzer()

    init(inputDirectory: URL, outputDirectory: URL, profileID: String) {
        self.inputDirectory = inputDirectory
        self.outputDirectory = outputDirectory
        self.profileID = profileID
    }

    func run() throws -> CalibrationRunReport {
        try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let manifest = try makeManifest()
        try writeManifest(manifest)

        var videoReports: [CalibrationVideoReport] = []
        for entry in manifest.videos {
            let report: CalibrationVideoReport
            do {
                report = try process(entry: entry)
            } catch {
                report = failedReport(for: entry, error: error)
            }
            videoReports.append(report)
            try writeJSON(report, to: outputDirectory.appendingPathComponent("\(safeFileName(URL(fileURLWithPath: entry.path).deletingPathExtension().lastPathComponent)).json"))
        }

        let aggregate = makeAggregate(from: videoReports)
        let runReport = CalibrationRunReport(
            generatedAt: Date(),
            inputDirectory: inputDirectory.path,
            outputDirectory: outputDirectory.path,
            profile: profileID,
            videos: videoReports,
            aggregate: aggregate
        )

        try writeJSON(runReport, to: outputDirectory.appendingPathComponent("calibration_run.json"))
        try writeCSV(videoReports, to: outputDirectory.appendingPathComponent("swing_metrics.csv"))
        try writeMarkdown(runReport, to: outputDirectory.appendingPathComponent("report.md"))
        return runReport
    }

    private func makeManifest() throws -> CalibrationVideoManifest {
        let files = try fileManager.contentsOfDirectory(
            at: inputDirectory,
            includingPropertiesForKeys: nil
        )
        let videos = files
            .filter { ["mov", "mp4", "m4v", "mkv"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { url -> CalibrationVideoEntry in
                let isBP = url.lastPathComponent.hasPrefix("BP_")
                return CalibrationVideoEntry(
                    path: url.path,
                    label: "good",
                    expectedSwingCount: isBP ? 1 : 0,
                    handedness: .right,
                    cameraAngle: .side,
                    reviewOnly: !isBP
                )
            }

        return CalibrationVideoManifest(version: 1, videos: videos)
    }

    private func process(entry: CalibrationVideoEntry) throws -> CalibrationVideoReport {
        let url = URL(fileURLWithPath: entry.path)
        print("Processing \(url.lastPathComponent)...")

        let frames = try poseDetectionService.processVideoSynchronously(url: url)
        let velocities = poseDetectionService.calculateVelocities(frames: frames)
        let detectionConfiguration = SwingDetectionConfiguration.balanced(
            expectedSwingCount: entry.expectedSwingCount
        ).applyingCameraAnglePreset(.side)
        let candidates = swingDetectionService.detectCandidates(
            from: frames,
            velocities: velocities,
            configuration: detectionConfiguration
        )
        let selectedCandidates: [SwingDetectionCandidate]
        if entry.expectedSwingCount > 0 {
            selectedCandidates = Array(candidates.prefix(entry.expectedSwingCount))
                .sorted { $0.swing.startTime < $1.swing.startTime }
        } else {
            selectedCandidates = candidates.sorted { $0.swing.startTime < $1.swing.startTime }
        }

        let context = SwingAnalysisContext(
            handedness: entry.handedness,
            cameraAngle: entry.cameraAngle,
            scoringProfile: .youthHighSchoolDefault,
            totalVideoFrames: nil
        )
        var warnings: [String] = []
        if entry.expectedSwingCount > 0, selectedCandidates.count != entry.expectedSwingCount {
            warnings.append("Expected \(entry.expectedSwingCount) swing(s), selected \(selectedCandidates.count).")
        }
        if entry.reviewOnly {
            warnings.append("Review-only source; swing count and segments need manual confirmation.")
        }

        let swings = selectedCandidates.enumerated().compactMap { item -> CalibrationSwingReport? in
            let swing = item.element.swing
            let swingFrames = frames.filter { $0.timestamp >= swing.startTime && $0.timestamp <= swing.endTime }
            guard let result = biomechanicsAnalyzer.analyzeSwing(
                frames: swingFrames,
                swingData: swing,
                context: context
            ) else {
                warnings.append("Swing \(item.offset + 1) could not be analyzed.")
                return nil
            }

            return CalibrationSwingReport(
                index: item.offset + 1,
                startTime: swing.startTime,
                duration: swing.duration,
                score: result.scoreBreakdown.finalScore,
                confidence: result.scoreBreakdown.confidence,
                advancedMetrics: result.advancedMetrics,
                scoreBreakdown: result.scoreBreakdown,
                warnings: result.warnings
            )
        }

        return CalibrationVideoReport(
            videoPath: entry.path,
            label: entry.label,
            expectedSwingCount: entry.expectedSwingCount,
            reviewOnly: entry.reviewOnly,
            poseFrameCount: frames.count,
            candidateCount: candidates.count,
            selectedSwingCount: selectedCandidates.count,
            swings: swings,
            warnings: warnings
        )
    }

    private func failedReport(for entry: CalibrationVideoEntry, error: Error) -> CalibrationVideoReport {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        return CalibrationVideoReport(
            videoPath: entry.path,
            label: entry.label,
            expectedSwingCount: entry.expectedSwingCount,
            reviewOnly: entry.reviewOnly,
            poseFrameCount: 0,
            candidateCount: 0,
            selectedSwingCount: 0,
            swings: [],
            warnings: ["Video could not be processed: \(message)"]
        )
    }

    private func makeAggregate(from reports: [CalibrationVideoReport]) -> CalibrationAggregate {
        let swings = reports.flatMap(\.swings)
        return CalibrationAggregate(
            swingCount: swings.count,
            score: distribution(swings.map(\.score)),
            pelvisRotationAtContact: distribution(swings.map(\.advancedMetrics.pelvisRotationAtContact)),
            torsoRotationAtContact: distribution(swings.map(\.advancedMetrics.torsoRotationAtContact)),
            hipShoulderSeparationAtFirstMove: distribution(swings.map { abs($0.advancedMetrics.hipShoulderSeparationAtFirstMove) }),
            timeToContact: distribution(swings.map(\.advancedMetrics.timeToContact))
        )
    }

    private func distribution(_ values: [Double]) -> CalibrationDistribution {
        let sorted = values.sorted()
        guard !sorted.isEmpty else {
            return CalibrationDistribution(median: 0, q1: 0, q3: 0)
        }

        return CalibrationDistribution(
            median: percentile(sorted, 0.50),
            q1: percentile(sorted, 0.25),
            q3: percentile(sorted, 0.75)
        )
    }

    private func percentile(_ sortedValues: [Double], _ percentile: Double) -> Double {
        guard !sortedValues.isEmpty else { return 0 }
        let index = min(max(Int((Double(sortedValues.count - 1) * percentile).rounded()), 0), sortedValues.count - 1)
        return sortedValues[index]
    }

    private func writeManifest(_ manifest: CalibrationVideoManifest) throws {
        try writeJSON(manifest, to: outputDirectory.appendingPathComponent("manifest.generated.json"))
    }

    private func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        try data.write(to: url)
    }

    private func writeCSV(_ reports: [CalibrationVideoReport], to url: URL) throws {
        var rows = [
            "video,swing,start,duration,score,confidence,pelvis_rotation,torso_rotation,x_factor_first_move,x_factor_contact,time_to_contact,lead_knee_extension,pose_warning_count"
        ]
        for report in reports {
            let video = URL(fileURLWithPath: report.videoPath).lastPathComponent
            for swing in report.swings {
                let advanced = swing.advancedMetrics
                rows.append([
                    csv(video),
                    "\(swing.index)",
                    format(swing.startTime),
                    format(swing.duration),
                    format(swing.score),
                    swing.confidence.rawValue,
                    format(advanced.pelvisRotationAtContact),
                    format(advanced.torsoRotationAtContact),
                    format(advanced.hipShoulderSeparationAtFirstMove),
                    format(advanced.hipShoulderSeparationAtContact),
                    format(advanced.timeToContact),
                    format(advanced.leadKneeExtensionToContact),
                    "\(swing.warnings.count)"
                ].joined(separator: ","))
            }
        }
        try rows.joined(separator: "\n").appending("\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private func writeMarkdown(_ report: CalibrationRunReport, to url: URL) throws {
        var markdown = """
        # Swing Scoring Calibration Report

        Generated: \(ISO8601DateFormatter().string(from: report.generatedAt))

        Input: `\(report.inputDirectory)`

        Profile: `\(report.profile)`

        ## Aggregate

        | Metric | Median | Q1 | Q3 |
        |---|---:|---:|---:|
        \(distributionRow("Score", report.aggregate.score))
        \(distributionRow("Pelvis rotation at contact", report.aggregate.pelvisRotationAtContact))
        \(distributionRow("Torso rotation at contact", report.aggregate.torsoRotationAtContact))
        \(distributionRow("Hip-shoulder separation at first move", report.aggregate.hipShoulderSeparationAtFirstMove))
        \(distributionRow("Time to contact", report.aggregate.timeToContact))

        ## Videos

        """

        for video in report.videos {
            markdown += """
            ### \(URL(fileURLWithPath: video.videoPath).lastPathComponent)

            Pose frames: \(video.poseFrameCount)  
            Candidates: \(video.candidateCount)  
            Selected swings: \(video.selectedSwingCount)  
            Review only: \(video.reviewOnly ? "yes" : "no")

            """

            if !video.warnings.isEmpty {
                markdown += "Warnings:\n"
                for warning in video.warnings {
                    markdown += "- \(warning)\n"
                }
                markdown += "\n"
            }

            for swing in video.swings {
                markdown += """
                - Swing \(swing.index): score \(format(swing.score)), \(swing.confidence.displayName) confidence, start \(format(swing.startTime))s, duration \(format(swing.duration))s

                """
            }
        }

        try markdown.write(to: url, atomically: true, encoding: .utf8)
    }

    private func distributionRow(_ title: String, _ distribution: CalibrationDistribution) -> String {
        "| \(title) | \(format(distribution.median)) | \(format(distribution.q1)) | \(format(distribution.q3)) |"
    }

    private func safeFileName(_ name: String) -> String {
        name.replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "_", options: .regularExpression)
    }

    private func format(_ value: Double) -> String {
        String(format: "%.3f", value)
    }

    private func csv(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
