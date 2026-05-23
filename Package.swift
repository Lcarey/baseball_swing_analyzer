// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwingAnalyzerTools",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SwingCalibration", targets: ["SwingCalibration"])
    ],
    targets: [
        .executableTarget(
            name: "SwingCalibration",
            path: ".",
            exclude: [
                "README.md",
                "example_images",
                "SwingAnalyzer/SwingAnalyzer/App",
                "SwingAnalyzer/SwingAnalyzer/Assets.xcassets",
                "SwingAnalyzer/SwingAnalyzer/Models/CoreData",
                "SwingAnalyzer/SwingAnalyzer/Models/SwingCoachingModels.swift",
                "SwingAnalyzer/SwingAnalyzer/Resources",
                "SwingAnalyzer/SwingAnalyzer/SwingAnalyzer.xcdatamodeld",
                "SwingAnalyzer/SwingAnalyzer/Services/CameraService.swift",
                "SwingAnalyzer/SwingAnalyzer/Services/SampleSessionSeeder.swift",
                "SwingAnalyzer/SwingAnalyzer/ViewModels",
                "SwingAnalyzer/SwingAnalyzer/Views",
                "Tools/SwingCalibration/calibration_manifest.example.json"
            ],
            sources: [
                "SwingAnalyzer/SwingAnalyzer/Models/SwingData.swift",
                "SwingAnalyzer/SwingAnalyzer/Models/BiomechanicsMetrics.swift",
                "SwingAnalyzer/SwingAnalyzer/Models/SwingDetectionConfiguration.swift",
                "SwingAnalyzer/SwingAnalyzer/Models/SwingDetectionPreview.swift",
                "SwingAnalyzer/SwingAnalyzer/Models/SwingScoringModels.swift",
                "SwingAnalyzer/SwingAnalyzer/Services/PoseDetectionService.swift",
                "SwingAnalyzer/SwingAnalyzer/Services/SwingDetectionService.swift",
                "SwingAnalyzer/SwingAnalyzer/Services/BiomechanicsAnalyzer.swift",
                "SwingAnalyzer/SwingAnalyzer/Utilities/BiomechanicsCalculations.swift",
                "SwingAnalyzer/SwingAnalyzer/Utilities/Constants.swift",
                "SwingAnalyzer/SwingAnalyzer/Utilities/VisionJointMapping.swift",
                "Tools/SwingCalibration/main.swift"
            ],
            swiftSettings: [
                .define("SWING_CALIBRATION_CLI")
            ]
        )
    ]
)
