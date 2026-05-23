import Foundation

struct SwingCoachPriority: Identifiable, Equatable {
    let id: String
    let title: String
    var scoreText: String?
    let playerCue: String
    let coachDetail: String
    let drillTitle: String
    let drillDetail: String
    let iconName: String
    let color: MetricColor
}

struct SwingCoachSummary: Equatable {
    let headline: String
    let subheadline: String
    let confidenceMessage: String?
    let personalBestMessage: String?
    let keepDoingTitle: String
    let keepDoingDetail: String
    let priorities: [SwingCoachPriority]
}

struct SessionCoachSummary: Equatable {
    let headline: String
    let subheadline: String
    let todayFocusTitle: String
    let todayFocusDetail: String
    let todayDrill: String
    let bestSwingText: String
    let consistencyText: String
    let confidenceText: String?
    let strengthText: String
}

enum SwingCoachAdviceFactory {
    static func summary(for swing: Swing) -> SwingCoachSummary {
        let breakdown = swing.metrics?.decodedScoreBreakdown
        let confidence = swing.metrics?.decodedScoreConfidence ?? breakdown?.confidence
        let components = breakdown?.components ?? []
        let priorities = priorities(from: components, confidence: confidence)
        let keepDoing = keepDoing(from: components, score: swing.score)

        return SwingCoachSummary(
            headline: headline(score: swing.score, confidence: confidence),
            subheadline: subheadline(for: priorities.first, score: swing.score),
            confidenceMessage: confidenceMessage(confidence, warnings: breakdown?.warnings ?? []),
            personalBestMessage: personalBestMessage(for: swing),
            keepDoingTitle: keepDoing.title,
            keepDoingDetail: keepDoing.detail,
            priorities: priorities
        )
    }

    static func summary(for session: Session) -> SessionCoachSummary? {
        let swings = session.swingsArray
            .filter { $0.metrics != nil }
            .sorted { $0.videoStartTime < $1.videoStartTime }

        guard !swings.isEmpty else { return nil }

        let bestSwing = swings.max { $0.score < $1.score }
        let breakdowns = swings.compactMap { $0.metrics?.decodedScoreBreakdown }
        let weakest = averagedComponents(from: breakdowns).sorted { $0.score < $1.score }.first
        let strongest = averagedComponents(from: breakdowns).sorted { $0.score > $1.score }.first
        let focusAdvice = weakest.map { componentAdvice(for: $0) }
        let strengthAdvice = strongest.map { componentAdvice(for: $0) }
        let lowConfidenceCount = swings.filter { ($0.metrics?.decodedScoreConfidence ?? $0.metrics?.decodedScoreBreakdown?.confidence) == .low }.count
        let mediumConfidenceCount = swings.filter { ($0.metrics?.decodedScoreConfidence ?? $0.metrics?.decodedScoreBreakdown?.confidence) == .medium }.count

        return SessionCoachSummary(
            headline: sessionHeadline(score: session.averageScore, swingCount: swings.count),
            subheadline: sessionSubheadline(swingCount: swings.count),
            todayFocusTitle: focusAdvice?.title ?? "Build one repeatable move",
            todayFocusDetail: focusAdvice?.playerCue ?? "Pick one cue and repeat it for the next round instead of chasing every metric at once.",
            todayDrill: focusAdvice.map { "\($0.drillTitle): \($0.drillDetail)" } ?? "Five clean reps: take five swings where the only goal is repeating the same setup and finish.",
            bestSwingText: bestSwingText(bestSwing: bestSwing, in: swings),
            consistencyText: consistencyText(for: swings),
            confidenceText: sessionConfidenceText(low: lowConfidenceCount, medium: mediumConfidenceCount, total: swings.count),
            strengthText: strengthAdvice.map { "Keep: \($0.playerCue)" } ?? "Keep: the swings that feel balanced and easy to repeat."
        )
    }

    private static func priorities(from components: [SwingScoreComponent], confidence: ScoreConfidence?) -> [SwingCoachPriority] {
        var results: [SwingCoachPriority] = []

        if confidence == .low {
            results.append(SwingCoachPriority(
                id: "recording_quality",
                title: "Make the video easier to trust",
                scoreText: nil,
                playerCue: "Record from a clear side view with the whole body and bat in frame.",
                coachDetail: "The pose confidence is low, so the app should treat the score as a rough hint instead of a coaching verdict.",
                drillTitle: "Camera check",
                drillDetail: "Take one slow practice swing before recording and make sure feet, hands, and bat stay visible.",
                iconName: "video.badge.checkmark",
                color: .orange
            ))
        }

        let scoredPriorities = components
            .sorted { weightedGap($0) > weightedGap($1) }
            .filter { $0.score < 88 }
            .prefix(confidence == .low ? 1 : 2)
            .map { component -> SwingCoachPriority in
                var priority = componentAdvice(for: component)
                priority.scoreText = "\(Int(component.score.rounded()))/100"
                return priority
            }

        results.append(contentsOf: scoredPriorities)

        if results.isEmpty, let weakest = components.min(by: { $0.score < $1.score }) {
            var priority = componentAdvice(for: weakest)
            priority.scoreText = "\(Int(weakest.score.rounded()))/100"
            results.append(priority)
        }

        if results.isEmpty {
            results.append(SwingCoachPriority(
                id: "repeatability",
                title: "Keep repeating the same move",
                scoreText: nil,
                playerCue: "The main goal is repeatability: same setup, same tempo, same finish.",
                coachDetail: "There is not enough detailed score data to choose a specific mechanical priority.",
                drillTitle: "Three-ball checkpoint",
                drillDetail: "Take three swings and try to finish balanced in the same spot each time.",
                iconName: "repeat",
                color: .green
            ))
        }

        return Array(results.prefix(3))
    }

    private static func componentAdvice(for component: SwingScoreComponent) -> SwingCoachPriority {
        let color: MetricColor = component.score >= 85 ? .green : (component.score >= 60 ? .orange : .red)

        switch component.id {
        case "hip_shoulder_separation":
            return SwingCoachPriority(
                id: component.id,
                title: "Stay loaded a little longer",
                scoreText: nil,
                playerCue: "Let the front side start while the hands stay back.",
                coachDetail: "This is the app's X-factor check. For young hitters, the useful cue is not a huge twist; it is a small stretch before the torso turns.",
                drillTitle: "Stride and hold",
                drillDetail: "Stride, pause with hands back for one beat, then swing.",
                iconName: "bolt.fill",
                color: color
            )
        case "pelvis_rotation_contact":
            return SwingCoachPriority(
                id: component.id,
                title: "Finish the hip turn",
                scoreText: nil,
                playerCue: "Turn the belt buckle through the ball.",
                coachDetail: "The pelvis rotation estimate is low or out of range at contact, which can leave the swing arm-heavy.",
                drillTitle: "No-stride turn drill",
                drillDetail: "Start balanced, keep the head quiet, and rotate the hips without a big stride.",
                iconName: "arrow.triangle.2.circlepath",
                color: color
            )
        case "torso_rotation_contact":
            return SwingCoachPriority(
                id: component.id,
                title: "Bring the chest through contact",
                scoreText: nil,
                playerCue: "Let the chest follow the hips instead of stopping early.",
                coachDetail: "The torso rotation check looks at whether the upper body is arriving with the lower body at the contact estimate.",
                drillTitle: "Half-speed turn through",
                drillDetail: "Swing at 50 percent and finish with the chest facing the pitcher.",
                iconName: "figure.core.training",
                color: color
            )
        case "time_to_contact":
            return SwingCoachPriority(
                id: component.id,
                title: "Get to contact on time",
                scoreText: nil,
                playerCue: "Short, quick move to the ball.",
                coachDetail: "Timing is measured inside the detected swing window, so use it as a quickness and sequencing cue rather than exact pitch timing.",
                drillTitle: "Quick-turn tee reps",
                drillDetail: "Use a short stride and try to launch the hands without rushing the head forward.",
                iconName: "stopwatch.fill",
                color: color
            )
        case "lead_leg":
            return SwingCoachPriority(
                id: component.id,
                title: "Firm up the front side",
                scoreText: nil,
                playerCue: "Land soft, then brace the front leg as you turn.",
                coachDetail: "The lead knee should accept the stride and then firm up into contact so energy can rotate instead of leak forward.",
                drillTitle: "Step, brace, swing",
                drillDetail: "Step into landing, feel the front leg hold, then rotate through.",
                iconName: "figure.strengthtraining.traditional",
                color: color
            )
        case "posture":
            return SwingCoachPriority(
                id: component.id,
                title: "Stay athletic through the swing",
                scoreText: nil,
                playerCue: "Keep the chest over the plate and finish balanced.",
                coachDetail: "The posture check looks for a usable forward bend without folding over or popping straight up.",
                drillTitle: "Mirror posture reps",
                drillDetail: "Freeze at heel strike and contact; the head should stay quiet and the chest angle should still look athletic.",
                iconName: "figure.stand",
                color: color
            )
        case "pelvis_thrust_proxy":
            return SwingCoachPriority(
                id: component.id,
                title: "Rotate instead of drifting",
                scoreText: nil,
                playerCue: "Turn around the middle, do not slide past it.",
                coachDetail: "This 2D proxy flags extra hip-center movement, which often means the hitter is drifting instead of rotating.",
                drillTitle: "Chair or wall constraint",
                drillDetail: "Set a chair or wall just outside the front hip and swing without bumping into it.",
                iconName: "arrow.up.forward",
                color: color
            )
        default:
            return SwingCoachPriority(
                id: component.id,
                title: component.title,
                scoreText: nil,
                playerCue: component.detail,
                coachDetail: component.target,
                drillTitle: "Focused reps",
                drillDetail: "Take five slower swings where this is the only thing you are watching.",
                iconName: "target",
                color: color
            )
        }
    }

    private static func keepDoing(from components: [SwingScoreComponent], score: Double) -> (title: String, detail: String) {
        guard let strongest = components.max(by: { $0.score < $1.score }) else {
            if score >= 80 {
                return ("Keep doing", "This swing graded well. Try to repeat the same setup and tempo.")
            }
            return ("Keep doing", "Keep the parts of the swing that feel balanced and easy to repeat.")
        }

        let advice = componentAdvice(for: strongest)
        return ("Keep doing", advice.playerCue)
    }

    private static func headline(score: Double, confidence: ScoreConfidence?) -> String {
        if confidence == .low {
            return "Start with a clearer video"
        }

        switch score {
        case 85...:
            return "Strong swing. Fine-tune one detail."
        case 70..<85:
            return "Good base. Pick one focus."
        default:
            return "Start with one clean move."
        }
    }

    private static func subheadline(for priority: SwingCoachPriority?, score: Double) -> String {
        guard let priority else {
            return score >= 85 ? "The next step is making this move repeatable." : "Use the next few reps to find a repeatable feel."
        }

        return "Next focus: \(priority.title.lowercased())."
    }

    private static func confidenceMessage(_ confidence: ScoreConfidence?, warnings: [String]) -> String? {
        guard let confidence else { return nil }

        switch confidence {
        case .high:
            return nil
        case .medium:
            if let warning = warnings.first {
                return "Medium confidence: \(warning)"
            }
            return "Medium confidence: useful for coaching, but verify with a clear side-view rep."
        case .low:
            if let warning = warnings.first {
                return "Low confidence: \(warning)"
            }
            return "Low confidence: use this as a camera/setup check before trusting the score."
        }
    }

    private static func personalBestMessage(for swing: Swing) -> String? {
        guard let session = swing.session else { return nil }
        let swings = session.swingsArray.sorted { $0.videoStartTime < $1.videoStartTime }
        guard let best = swings.max(by: { $0.score < $1.score }) else { return nil }
        let swingNumber = swings.firstIndex(where: { $0.id == swing.id }).map { $0 + 1 } ?? 1
        let bestNumber = swings.firstIndex(where: { $0.id == best.id }).map { $0 + 1 } ?? swingNumber

        if best.id == swing.id {
            return "Best swing in this session so far."
        }

        let difference = max(0, Int((best.score - swing.score).rounded()))
        return "Swing \(swingNumber) is \(difference) point\(difference == 1 ? "" : "s") behind session-best Swing \(bestNumber)."
    }

    private static func sessionHeadline(score: Double, swingCount: Int) -> String {
        switch score {
        case 85...:
            return "Good session. Make it repeatable."
        case 70..<85:
            return "Solid work. One focus for the next round."
        default:
            return swingCount == 1 ? "One swing logged. Get a few more looks." : "Build the swing around one simple cue."
        }
    }

    private static func sessionSubheadline(swingCount: Int) -> String {
        "Based on \(swingCount) analyzed swing\(swingCount == 1 ? "" : "s")."
    }

    private static func bestSwingText(bestSwing: Swing?, in swings: [Swing]) -> String {
        guard let bestSwing else {
            return "Best swing: not available yet."
        }

        let number = swings.firstIndex(where: { $0.id == bestSwing.id }).map { $0 + 1 } ?? 1
        return "Best swing: Swing \(number), \(Int(bestSwing.score.rounded())) points."
    }

    private static func consistencyText(for swings: [Swing]) -> String {
        guard swings.count > 1 else {
            return "Consistency: record at least two swings to compare repeatability."
        }

        let scores = swings.map(\.score)
        let average = scores.reduce(0, +) / Double(scores.count)
        let variance = scores.reduce(0) { $0 + pow($1 - average, 2) } / Double(scores.count)
        let spread = sqrt(variance)

        switch spread {
        case 0..<6:
            return "Consistency: tight score spread. Good day to refine details."
        case 6..<13:
            return "Consistency: some swing-to-swing variation. Keep the same cue for a full round."
        default:
            return "Consistency: scores are spread out. Simplify the goal and chase repeatable contact."
        }
    }

    private static func sessionConfidenceText(low: Int, medium: Int, total: Int) -> String? {
        if low > 0 {
            return "\(low) of \(total) swing\(total == 1 ? "" : "s") had low confidence. Prioritize cleaner video before making big mechanical calls."
        }

        if medium > 0 {
            return "\(medium) of \(total) swing\(total == 1 ? "" : "s") had medium confidence. Treat the focus as useful, not absolute."
        }

        return nil
    }

    private static func averagedComponents(from breakdowns: [SwingScoreBreakdown]) -> [SwingScoreComponent] {
        let grouped = Dictionary(grouping: breakdowns.flatMap(\.components), by: \.id)

        return grouped.compactMap { _, components in
            guard let first = components.first else { return nil }
            let count = Double(components.count)

            return SwingScoreComponent(
                id: first.id,
                title: first.title,
                score: components.reduce(0) { $0 + $1.score } / count,
                weight: first.weight,
                value: components.reduce(0) { $0 + $1.value } / count,
                target: first.target,
                detail: first.detail
            )
        }
    }

    private static func weightedGap(_ component: SwingScoreComponent) -> Double {
        max(0, 100 - component.score) * max(1, component.weight)
    }
}
