import Foundation

struct SwingDetectionCandidate: Identifiable {
    let id = UUID()
    let swing: SwingData
    let peakScore: Double
    let peakHandVelocity: Double
    let peakBatProxyVelocity: Double
    let rankingScore: Double
}

struct SwingDetectionPreviewResult {
    let configuration: SwingDetectionConfiguration
    let videoURL: URL
    let frames: [FrameJointData]
    let allCandidates: [SwingDetectionCandidate]
    let selectedCandidates: [SwingDetectionCandidate]
    let analysisResults: [SwingAnalysisResult]

    var metrics: [BiomechanicsMetrics] {
        analysisResults.map(\.legacyMetrics)
    }

    var proposedSwings: [SwingData] {
        selectedCandidates.map(\.swing)
    }
}
