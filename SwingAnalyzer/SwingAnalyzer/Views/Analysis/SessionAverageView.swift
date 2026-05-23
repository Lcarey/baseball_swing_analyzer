import SwiftUI
import CoreData

struct SessionAverageView: View {
    let session: Session
    @Environment(\.dismiss) private var dismiss

    var swings: [Swing] {
        session.swingsArray
    }

    var averageMetrics: AverageMetrics? {
        calculateAverageMetrics()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Session Info Card
                VStack(spacing: 8) {
                    Text("Session Average")
                        .font(.headline)

                    Text(session.date.formattedForDisplay())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top)

                // Average Score Circle
                VStack(spacing: 12) {
                    ScoreCircleView(score: Int(session.averageScore))

                    Text("Average Score")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Based on \(swings.count) swing\(swings.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()

                // Average Metrics
                if let metrics = averageMetrics {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Average Metrics")
                            .font(.headline)
                            .padding(.horizontal)

                        HStack(spacing: 16) {
                            AverageMetricCard(
                                title: "Knee Bend",
                                value: "\(Int(metrics.kneeBend))°",
                                icon: "figure.stand",
                                color: .orange
                            )

                            AverageMetricCard(
                                title: "Hip Rotation",
                                value: "\(Int(metrics.hipRotation))°",
                                icon: "arrow.triangle.2.circlepath",
                                color: .green
                            )
                        }
                        .padding(.horizontal)

                        HStack(spacing: 16) {
                            AverageMetricCard(
                                title: "Hip Horizontal",
                                value: String(format: "%.1f\"", metrics.hipHorizontalMovement),
                                icon: "arrow.left.and.right",
                                color: .orange
                            )

                            AverageMetricCard(
                                title: "Hip Vertical",
                                value: String(format: "%.1f\"", metrics.hipVerticalMovement),
                                icon: "arrow.up.and.down",
                                color: .orange
                            )
                        }
                        .padding(.horizontal)

                        HStack(spacing: 16) {
                            AverageMetricCard(
                                title: "Alignment",
                                value: "\(Int(metrics.hipShoulderAlignment))%",
                                icon: "bolt.fill",
                                color: .orange
                            )

                            AverageMetricCard(
                                title: "Time",
                                value: String(format: "%.2fs", metrics.timeToContact),
                                icon: "clock.fill",
                                color: .gray
                            )
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }

                // Swings List
                VStack(alignment: .leading, spacing: 12) {
                    Text("Swings")
                        .font(.headline)
                        .padding(.horizontal)

                    ForEach(swings) { swing in
                        NavigationLink(destination: SwingScoreView(swing: swing)) {
                            SwingRowCard(swing: swing)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func calculateAverageMetrics() -> AverageMetrics? {
        let swingsWithMetrics = swings.compactMap { $0.metrics }
        guard !swingsWithMetrics.isEmpty else { return nil }

        let count = Double(swingsWithMetrics.count)

        return AverageMetrics(
            kneeBend: swingsWithMetrics.reduce(0) { $0 + $1.kneeBend } / count,
            hipRotation: swingsWithMetrics.reduce(0) { $0 + $1.hipRotation } / count,
            hipHorizontalMovement: swingsWithMetrics.reduce(0) { $0 + $1.hipHorizontalMovement } / count,
            hipVerticalMovement: swingsWithMetrics.reduce(0) { $0 + $1.hipVerticalMovement } / count,
            hipShoulderAlignment: swingsWithMetrics.reduce(0) { $0 + $1.hipShoulderAlignment } / count,
            timeToContact: swingsWithMetrics.reduce(0) { $0 + $1.timeToContact } / count
        )
    }
}

// MARK: - Average Metrics Model

struct AverageMetrics {
    let kneeBend: Double
    let hipRotation: Double
    let hipHorizontalMovement: Double
    let hipVerticalMovement: Double
    let hipShoulderAlignment: Double
    let timeToContact: Double
}

// MARK: - Average Metric Card

struct AverageMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(value)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
            }

            Spacer()
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Swing Row Card

struct SwingRowCard: View {
    let swing: Swing

    var scoreColor: Color {
        if swing.score >= 80 {
            return AppConstants.colorGreen
        } else if swing.score >= 60 {
            return AppConstants.colorOrange
        } else {
            return AppConstants.colorRed
        }
    }

    var body: some View {
        HStack(spacing: 15) {
            // Score Circle (small)
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                    .frame(width: 50, height: 50)

                Circle()
                    .trim(from: 0, to: swing.score / 100)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))

                Text("\(Int(swing.score))")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(scoreColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(formatTime(swing.timestamp))
                    .font(.headline)

                if let metrics = swing.metrics {
                    HStack(spacing: 16) {
                        MetricPill(
                            icon: "arrow.triangle.2.circlepath",
                            value: "\(Int(metrics.hipRotation))°"
                        )

                        MetricPill(
                            icon: "bolt.fill",
                            value: "\(Int(metrics.hipShoulderAlignment))%"
                        )

                        MetricPill(
                            icon: "clock.fill",
                            value: String(format: "%.2fs", metrics.timeToContact)
                        )
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Metric Pill

struct MetricPill: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))

            Text(value)
                .font(.caption2)
        }
        .foregroundColor(.secondary)
    }
}

#Preview {
    NavigationStack {
        let context = PersistenceController.preview.container.viewContext
        let session = Session(context: context)
        session.id = UUID()
        session.date = Date()
        session.averageScore = 68
        session.swingCount = 2

        return SessionAverageView(session: session)
    }
}
