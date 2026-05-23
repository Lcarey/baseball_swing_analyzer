import SwiftUI
import CoreData

struct SwingDetectionRerunView: View {
    let session: Session
    @StateObject private var viewModel: SwingDetectionRerunViewModel
    @State private var showReplaceConfirmation = false

    init(session: Session) {
        self.session = session
        _viewModel = StateObject(wrappedValue: SwingDetectionRerunViewModel(session: session))
    }

    var body: some View {
        Form {
            expectedCountSection
            presetsSection
            advancedSection
            actionSection
            previewSection
        }
        .navigationTitle("Rerun Detection")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Detection Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Something went wrong.")
        }
        .confirmationDialog(
            "Replace current swing results?",
            isPresented: $showReplaceConfirmation,
            titleVisibility: .visible
        ) {
            Button("Replace Current Results", role: .destructive) {
                viewModel.replaceCurrentResults()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete the current swings for this session and save the previewed results.")
        }
    }

    private var expectedCountSection: some View {
        Section("Swing Count") {
            Stepper(
                value: Binding(
                    get: { viewModel.configuration.expectedSwingCount },
                    set: { viewModel.updateExpectedSwingCount($0) }
                ),
                in: 1...50
            ) {
                HStack {
                    Text("Expected Swings")
                    Spacer()
                    Text("\(viewModel.configuration.expectedSwingCount)")
                        .foregroundColor(.secondary)
                }
            }

            Text("Required. The detector will select the best matching candidates for this count.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var presetsSection: some View {
        Section("Presets") {
            Picker("Sensitivity", selection: Binding(
                get: { viewModel.configuration.sensitivityPreset },
                set: { viewModel.applySensitivityPreset($0) }
            )) {
                ForEach(SwingDetectionSensitivityPreset.allCases) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }

            Picker("Camera Angle", selection: Binding(
                get: { viewModel.configuration.cameraAnglePreset },
                set: { viewModel.applyCameraAnglePreset($0) }
            )) {
                ForEach(SwingDetectionCameraAnglePreset.allCases) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }
        }
    }

    private var advancedSection: some View {
        Section("Advanced Parameters") {
            ParameterSlider(
                title: "Score Threshold",
                value: doubleBinding(\.scoreThreshold),
                range: 0.30...2.50,
                step: 0.05,
                format: "%.2f"
            )

            ParameterSlider(
                title: "Release Threshold",
                value: doubleBinding(\.releaseThreshold),
                range: 0.10...1.50,
                step: 0.05,
                format: "%.2f"
            )

            ParameterSlider(
                title: "Min Hand Velocity",
                value: doubleBinding(\.minHandVelocity),
                range: 0.05...1.20,
                step: 0.05,
                format: "%.2f"
            )

            ParameterSlider(
                title: "Min Arm Velocity",
                value: doubleBinding(\.minArmVelocity),
                range: 0.05...1.00,
                step: 0.05,
                format: "%.2f"
            )

            ParameterSlider(
                title: "Min Duration",
                value: doubleBinding(\.minSwingDuration),
                range: 0.10...1.00,
                step: 0.05,
                format: "%.2fs"
            )

            ParameterSlider(
                title: "Max Duration",
                value: doubleBinding(\.maxSwingDuration),
                range: 0.50...2.50,
                step: 0.05,
                format: "%.2fs"
            )

            ParameterSlider(
                title: "Min Separation",
                value: doubleBinding(\.minSwingSeparation),
                range: 0.50...4.00,
                step: 0.10,
                format: "%.1fs"
            )

            ParameterSlider(
                title: "Hip Weight",
                value: doubleBinding(\.hipWeight),
                range: 0...1,
                step: 0.05,
                format: "%.2f"
            )

            ParameterSlider(
                title: "Shoulder Weight",
                value: doubleBinding(\.shoulderWeight),
                range: 0...1,
                step: 0.05,
                format: "%.2f"
            )

            ParameterSlider(
                title: "Arm Weight",
                value: doubleBinding(\.armWeight),
                range: 0...1,
                step: 0.05,
                format: "%.2f"
            )

            ParameterSlider(
                title: "Bat Proxy Weight",
                value: doubleBinding(\.batProxyWeight),
                range: 0...1,
                step: 0.05,
                format: "%.2f"
            )
        }
    }

    private var actionSection: some View {
        Section {
            Button {
                viewModel.runPreview()
            } label: {
                Label("Run Detection Preview", systemImage: "waveform.path.ecg")
                    .frame(maxWidth: .infinity)
            }
            .disabled(viewModel.isProcessing)

            if viewModel.isProcessing {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: viewModel.progress)
                    Text(viewModel.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if !viewModel.statusMessage.isEmpty {
                Text(viewModel.statusMessage)
                    .font(.caption)
                    .foregroundColor(viewModel.replacementComplete ? AppConstants.colorGreen : .secondary)
            }
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        if let preview = viewModel.previewResult {
            Section("Preview") {
                DetectionPreviewSummary(
                    currentSwings: session.swingsArray,
                    preview: preview
                )

                Button(role: .destructive) {
                    showReplaceConfirmation = true
                } label: {
                    Label("Replace Current Results", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .disabled(viewModel.isProcessing)
            }
        }
    }

    private func doubleBinding(_ keyPath: WritableKeyPath<SwingDetectionConfiguration, Double>) -> Binding<Double> {
        Binding(
            get: { viewModel.configuration[keyPath: keyPath] },
            set: { newValue in
                viewModel.updateAdvanced { configuration in
                    configuration[keyPath: keyPath] = newValue
                }
            }
        )
    }
}

struct ParameterSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: format, value))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            Slider(value: $value, in: range, step: step)
        }
    }
}

struct DetectionPreviewSummary: View {
    let currentSwings: [Swing]
    let preview: SwingDetectionPreviewResult

    private var currentSortedSwings: [Swing] {
        currentSwings.sorted { $0.videoStartTime < $1.videoStartTime }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(
                "Found \(preview.allCandidates.count) candidate\(preview.allCandidates.count == 1 ? "" : "s"); selected \(preview.selectedCandidates.count)",
                systemImage: "checkmark.seal"
            )
            .font(.subheadline.weight(.semibold))

            VStack(alignment: .leading, spacing: 10) {
                Text("Current")
                    .font(.headline)

                if currentSortedSwings.isEmpty {
                    Text("No saved swings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(Array(currentSortedSwings.enumerated()), id: \.element.id) { item in
                        CurrentSwingPreviewRow(index: item.offset + 1, swing: item.element)
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Proposed")
                    .font(.headline)

                ForEach(Array(preview.selectedCandidates.enumerated()), id: \.element.id) { item in
                    ProposedSwingPreviewRow(
                        index: item.offset + 1,
                        candidate: item.element,
                        metrics: metric(at: item.offset)
                    )
                }
            }
        }
    }

    private func metric(at index: Int) -> BiomechanicsMetrics? {
        guard preview.metrics.indices.contains(index) else { return nil }
        return preview.metrics[index]
    }
}

struct CurrentSwingPreviewRow: View {
    let index: Int
    let swing: Swing

    private var details: String {
        var parts = ["Score \(Int(swing.score))"]
        if let metrics = swing.metrics {
            parts.append(String(format: "Contact %.2fs", metrics.timeToContact))
        }
        return parts.joined(separator: " • ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Swing \(index)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(formatVideoOffset(swing.videoStartTime)) • \(formatDuration(swing.duration))")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }

            Text(details)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct ProposedSwingPreviewRow: View {
    let index: Int
    let candidate: SwingDetectionCandidate
    let metrics: BiomechanicsMetrics?

    private var details: String {
        var parts = [
            "Peak \(formatVideoOffset(candidate.swing.peakVelocityTime))",
            String(format: "Signal %.2f", candidate.peakScore)
        ]

        if let metrics {
            parts.append(String(format: "Contact %.2fs", metrics.timeToContact))
            parts.append("Score \(Int(metrics.compositeScore))")
        }

        return parts.joined(separator: " • ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Swing \(index)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(formatVideoOffset(candidate.swing.startTime)) • \(formatDuration(candidate.swing.duration))")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }

            Text(details)
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        let context = PersistenceController.preview.container.viewContext
        let session = Session(context: context)
        session.id = UUID()
        session.date = Date()
        session.swingCount = 2
        session.averageScore = 72

        return SwingDetectionRerunView(session: session)
    }
}
