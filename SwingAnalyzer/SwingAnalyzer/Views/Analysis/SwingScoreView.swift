import SwiftUI
import CoreData

struct SwingScoreView: View {
    let swing: Swing
    @Environment(\.dismiss) private var dismiss

    private var metrics: SwingMetrics? {
        swing.metrics
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Date Card
                Text(swing.timestamp.formattedForDisplay())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.top)

                // Score Circle
                ScoreCircleView(score: Int(swing.score))
                    .padding(.vertical)

                // Metrics Grid
                if let metrics = metrics {
                    MetricsGridView(metrics: metrics)
                        .padding(.horizontal)
                }

                // Hip-Shoulder Alignment Bars
                if let metrics = metrics {
                    AlignmentBarsView(metrics: metrics)
                        .padding()
                }

                // Learn More Link
                Button(action: {
                    // TODO: Show explanation of metrics
                }) {
                    Text("Learn More")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Swing Score")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // TODO: Show options menu
                }) {
                    Image(systemName: "ellipsis")
                }
            }
        }
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
                .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                .frame(width: 120, height: 120)

            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(-90))

            Text("\(score)")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Metrics Grid

struct MetricsGridView: View {
    let metrics: SwingMetrics

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                MetricCardView(
                    title: "Knee Bend",
                    value: "\(Int(metrics.kneeBend))°",
                    icon: "figure.stand",
                    color: getColor(for: .kneeBend, value: metrics.kneeBend)
                )

                MetricCardView(
                    title: "Hip Rotation",
                    value: "\(Int(metrics.hipRotation))°",
                    icon: "arrow.triangle.2.circlepath",
                    color: getColor(for: .hipRotation, value: metrics.hipRotation)
                )
            }

            HStack(spacing: 16) {
                MetricCardView(
                    title: "Hip Horizontal Mvmt.",
                    value: String(format: "%.1f\"", metrics.hipHorizontalMovement),
                    icon: "arrow.left.and.right",
                    color: getColor(for: .hipHorizontalMovement, value: metrics.hipHorizontalMovement)
                )

                MetricCardView(
                    title: "Hip Vertical Mvmt.",
                    value: String(format: "%.1f\"", metrics.hipVerticalMovement),
                    icon: "arrow.up.and.down",
                    color: getColor(for: .hipVerticalMovement, value: metrics.hipVerticalMovement)
                )
            }

            HStack(spacing: 16) {
                MetricCardView(
                    title: "Hip-Shoulder Alignment",
                    value: "\(Int(metrics.hipShoulderAlignment))%",
                    icon: "bolt.fill",
                    color: getColor(for: .hipShoulderAlignment, value: metrics.hipShoulderAlignment)
                )

                MetricCardView(
                    title: "Time to Contact",
                    value: String(format: "%.2fs", metrics.timeToContact),
                    icon: "clock.fill",
                    color: getColor(for: .timeToContact, value: metrics.timeToContact)
                )
            }
        }
    }

    private func getColor(for metric: MetricType, value: Double) -> Color {
        let metricsModel = BiomechanicsMetrics(
            kneeBend: metrics.kneeBend,
            hipRotation: metrics.hipRotation,
            hipHorizontalMovement: metrics.hipHorizontalMovement,
            hipVerticalMovement: metrics.hipVerticalMovement,
            hipShoulderAlignment: metrics.hipShoulderAlignment,
            timeToContact: metrics.timeToContact
        )

        let colorType = metricsModel.getMetricColor(for: metric)

        switch colorType {
        case .green:
            return AppConstants.colorGreen
        case .orange:
            return AppConstants.colorOrange
        case .red:
            return AppConstants.colorRed
        }
    }
}

// MARK: - Metric Card

struct MetricCardView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 32)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Alignment Bars

struct AlignmentBarsView: View {
    let metrics: SwingMetrics

    var body: some View {
        VStack(spacing: 12) {
            // Hips Bar
            HStack {
                Text("Hips")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .leading)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 24)

                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppConstants.colorGreen)
                            .frame(width: geometry.size.width * (metrics.hipRotation / 180), height: 24)
                    }
                }
                .frame(height: 24)
            }

            // Shoulders Bar
            HStack {
                Text("Shoulders")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .leading)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 24)

                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppConstants.colorGreen)
                            .frame(width: geometry.size.width * (metrics.hipShoulderAlignment / 100), height: 24)
                    }
                }
                .frame(height: 24)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        let context = PersistenceController.preview.container.viewContext
        let swing = Swing(context: context)
        swing.id = UUID()
        swing.timestamp = Date()
        swing.score = 73

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
