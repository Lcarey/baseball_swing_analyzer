import SwiftUI
import CoreData

struct SwingScoreView: View {
    let swing: Swing

    private var metrics: SwingMetrics? {
        swing.metrics
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SwingSkeletonVideoView(swing: swing)
                    .padding(.horizontal)
                    .padding(.top)

                SwingReportSummaryCard(swing: swing)
                    .padding(.horizontal)

                if let metrics {
                    DetailedMetricsReportView(metrics: metrics)
                        .padding(.horizontal)

                    AlignmentReportView(metrics: metrics)
                        .padding(.horizontal)
                } else {
                    MissingMetricsView()
                        .padding(.horizontal)
                }

                SwingDataSummaryView(swing: swing)
                    .padding(.horizontal)
                    .padding(.bottom, 24)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Swing Report")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Summary

struct SwingReportSummaryCard: View {
    let swing: Swing

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 18) {
                ScoreCircleView(score: Int(swing.score))

                VStack(alignment: .leading, spacing: 8) {
                    Text(swing.videoDisplayTime.formattedForDisplay())
                        .font(.headline)

                    Text(swing.videoDisplayTime.formattedTimeForDisplay())
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Based on this swing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 12) {
                ReportStatBadge(
                    title: "Length",
                    value: formatDuration(swing.duration),
                    icon: "timer"
                )

                ReportStatBadge(
                    title: "Starts",
                    value: formatVideoOffset(swing.videoStartTime),
                    icon: "arrow.right.circle"
                )

                ReportStatBadge(
                    title: "Pose Frames",
                    value: "\(swing.jointDataArray.count)",
                    icon: "figure.baseball"
                )
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct ReportStatBadge: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: icon)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)

            Text(value)
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(UIColor.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Score Circle

struct ScoreCircleView: View {
    let score: Int

    var scoreColor: Color {
        if score >= 80 {
            return AppConstants.colorGreen
        } else if score >= 60 {
            return AppConstants.colorOrange
        } else {
            return AppConstants.colorRed
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.28), lineWidth: 8)
                .frame(width: 120, height: 120)

            Circle()
                .trim(from: 0, to: CGFloat(min(max(score, 0), 100)) / 100)
                .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(-90))

            Text("\(score)")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.primary)
        }
        .accessibilityLabel("Swing score \(score)")
    }
}

// MARK: - Metrics Report

struct DetailedMetricsReportView: View {
    let metrics: SwingMetrics

    private var reportItems: [MetricReportItem] {
        [
            MetricReportItem(
                type: .kneeBend,
                title: "Knee Bend",
                value: "\(Int(metrics.kneeBend.rounded()))°",
                icon: "figure.strengthtraining.traditional",
                target: "Target: 80°-120°",
                detail: "Measures back-knee flex at setup. This helps show whether the lower body is loaded without collapsing.",
                color: metricColor(for: .kneeBend)
            ),
            MetricReportItem(
                type: .hipRotation,
                title: "Hip Rotation",
                value: "\(Int(metrics.hipRotation.rounded()))°",
                icon: "arrow.triangle.2.circlepath",
                target: "Target: 75°+",
                detail: "Tracks how much the hips rotate from setup through contact. Strong rotation usually means better energy transfer.",
                color: metricColor(for: .hipRotation)
            ),
            MetricReportItem(
                type: .hipHorizontalMovement,
                title: "Hip Horizontal Mvmt.",
                value: String(format: "%.1f\"", metrics.hipHorizontalMovement),
                icon: "arrow.left.and.right",
                target: "Target: close to 0\"",
                detail: "Shows side-to-side hip drift. Lower movement suggests the swing is rotating instead of sliding.",
                color: metricColor(for: .hipHorizontalMovement)
            ),
            MetricReportItem(
                type: .hipVerticalMovement,
                title: "Hip Vertical Mvmt.",
                value: String(format: "%.1f\"", metrics.hipVerticalMovement),
                icon: "arrow.up.and.down",
                target: "Target: close to 0\"",
                detail: "Shows up-and-down hip movement. Lower movement keeps power moving into rotation instead of popping vertically.",
                color: metricColor(for: .hipVerticalMovement)
            ),
            MetricReportItem(
                type: .hipShoulderAlignment,
                title: "Hip-Shoulder Alignment",
                value: "\(Int(metrics.hipShoulderAlignment.rounded()))%",
                icon: "bolt.fill",
                target: "Target: near 100%",
                detail: "Compares hip and shoulder rotation timing. Higher alignment means the upper and lower body are sequencing together.",
                color: metricColor(for: .hipShoulderAlignment)
            ),
            MetricReportItem(
                type: .timeToContact,
                title: "Time to Contact",
                value: String(format: "%.2fs", metrics.timeToContact),
                icon: "stopwatch.fill",
                target: "Target: faster is better",
                detail: "Measures elapsed time from swing start to the contact estimate. Shorter times indicate a quicker move to contact.",
                color: metricColor(for: .timeToContact)
            )
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Metrics")
                .font(.title2.bold())

            VStack(spacing: 12) {
                ForEach(reportItems) { item in
                    MetricReportCard(item: item)
                }
            }
        }
    }

    private func metricColor(for type: MetricType) -> MetricColor {
        let metricsModel = BiomechanicsMetrics(
            kneeBend: metrics.kneeBend,
            hipRotation: metrics.hipRotation,
            hipHorizontalMovement: metrics.hipHorizontalMovement,
            hipVerticalMovement: metrics.hipVerticalMovement,
            hipShoulderAlignment: metrics.hipShoulderAlignment,
            timeToContact: metrics.timeToContact
        )

        return metricsModel.getMetricColor(for: type)
    }
}

struct MetricReportItem: Identifiable {
    let type: MetricType
    let title: String
    let value: String
    let icon: String
    let target: String
    let detail: String
    let color: MetricColor

    var id: MetricType { type }
}

struct MetricReportCard: View {
    let item: MetricReportItem

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: item.icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(item.color.color)
                .frame(width: 44, height: 44)
                .background(item.color.color.opacity(0.13))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.title)
                        .font(.headline)
                        .lineLimit(2)

                    Spacer()

                    Text(item.value)
                        .font(.title3.monospacedDigit().bold())
                        .foregroundColor(item.color.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Text(item.target)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(item.color.color)

                Text(item.detail)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(item.color.statusText)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(item.color.color)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(item.color.color.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Alignment Report

struct AlignmentReportView: View {
    let metrics: SwingMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hip-Shoulder Alignment Chart")
                .font(.title2.bold())

            VStack(spacing: 16) {
                MetricProgressBar(
                    title: "Hip rotation",
                    value: metrics.hipRotation,
                    target: 75,
                    maximum: 120,
                    suffix: "°",
                    color: color(for: .hipRotation)
                )

                MetricProgressBar(
                    title: "Hip-shoulder alignment",
                    value: metrics.hipShoulderAlignment,
                    target: 90,
                    maximum: 100,
                    suffix: "%",
                    color: color(for: .hipShoulderAlignment)
                )
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func color(for type: MetricType) -> Color {
        let metricsModel = BiomechanicsMetrics(
            kneeBend: metrics.kneeBend,
            hipRotation: metrics.hipRotation,
            hipHorizontalMovement: metrics.hipHorizontalMovement,
            hipVerticalMovement: metrics.hipVerticalMovement,
            hipShoulderAlignment: metrics.hipShoulderAlignment,
            timeToContact: metrics.timeToContact
        )

        return metricsModel.getMetricColor(for: type).color
    }
}

struct MetricProgressBar: View {
    let title: String
    let value: Double
    let target: Double
    let maximum: Double
    let suffix: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text("\(formatted(value))\(suffix)")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundColor(color)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 6)
                        .fill(color)
                        .frame(width: geometry.size.width * progress(for: value))

                    Rectangle()
                        .fill(Color.primary.opacity(0.45))
                        .frame(width: 3)
                        .offset(x: geometry.size.width * progress(for: target))
                }
            }
            .frame(height: 16)

            Text("Marker shows target")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private func progress(for number: Double) -> Double {
        guard maximum > 0 else { return 0 }
        return min(max(number / maximum, 0), 1)
    }

    private func formatted(_ number: Double) -> String {
        if number.rounded() == number {
            return "\(Int(number))"
        }

        return String(format: "%.1f", number)
    }
}

// MARK: - Data Summary

struct SwingDataSummaryView: View {
    let swing: Swing

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recording Details")
                .font(.title2.bold())

            VStack(spacing: 10) {
                DetailRow(label: "Swing window", value: "\(formatVideoOffset(swing.videoStartTime)) - \(formatVideoOffset(swing.videoEndTime))")
                DetailRow(label: "Swing length", value: formatDuration(swing.duration))
                DetailRow(label: "Pose frames", value: "\(swing.jointDataArray.count)")
                DetailRow(label: "Source video", value: URL(fileURLWithPath: swing.videoURL).lastPathComponent)
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            if FileManager.default.fileExists(atPath: swing.videoURL) {
                NavigationLink(destination: VideoPlaybackView(videoURL: URL(fileURLWithPath: swing.videoURL))) {
                    Label("Play Raw Recording", systemImage: "play.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer(minLength: 16)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }
}

struct MissingMetricsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Metrics Unavailable", systemImage: "exclamationmark.triangle")
                .font(.headline)

            Text("The swing was detected, but the saved pose data was not complete enough to calculate every metric.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Formatting

func formatVideoOffset(_ seconds: Double) -> String {
    let clampedSeconds = max(0, seconds)
    let minutes = Int(clampedSeconds / 60)
    let remainingSeconds = clampedSeconds - Double(minutes * 60)
    return String(format: "%02d:%05.2f", minutes, remainingSeconds)
}

func formatDuration(_ seconds: Double) -> String {
    String(format: "%.2fs", max(0, seconds))
}

extension MetricColor {
    var color: Color {
        switch self {
        case .green:
            return AppConstants.colorGreen
        case .orange:
            return AppConstants.colorOrange
        case .red:
            return AppConstants.colorRed
        }
    }

    var statusText: String {
        switch self {
        case .green:
            return "On target"
        case .orange:
            return "Watch"
        case .red:
            return "Needs work"
        }
    }
}

#Preview {
    NavigationStack {
        let context = PersistenceController.preview.container.viewContext
        let session = Session(context: context)
        session.id = UUID()
        session.date = Date()
        session.recordingDuration = 16
        session.swingCount = 1

        let swing = Swing(context: context)
        swing.id = UUID()
        swing.timestamp = session.date.addingTimeInterval(3.17)
        swing.score = 73
        swing.videoURL = ""
        swing.duration = 0.46
        swing.session = session

        let metrics = SwingMetrics(context: context)
        metrics.id = UUID()
        metrics.kneeBend = 160
        metrics.hipRotation = 108
        metrics.hipHorizontalMovement = 3.5
        metrics.hipVerticalMovement = -7.4
        metrics.hipShoulderAlignment = 90
        metrics.timeToContact = 0.45
        metrics.swing = swing

        return SwingScoreView(swing: swing)
    }
}
