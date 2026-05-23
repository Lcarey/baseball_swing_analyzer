# Baseball Swing Analyzer iOS App

An iPhone app that uses AI and computer vision to analyze baseball swings in real-time.

## Features

- 📹 **Continuous Video Recording**: Record multiple swings in a single session
- 🤖 **AI-Powered Analysis**: Automatic swing detection using Apple's Vision framework
- 📊 **Biomechanics Scoring**: Analyze 6 key swing metrics:
  - Knee Bend (degrees)
  - Hip Rotation (degrees)
  - Hip Horizontal Movement (inches)
  - Hip Vertical Movement (inches)
  - Hip-Shoulder Alignment (percentage)
  - Time to Contact (seconds)
- 🎬 **Slow-Motion Playback**: Review swings with skeleton overlay
- 📈 **Session Tracking**: Track progress over time with historical data

## Tech Stack

- **SwiftUI**: Modern iOS UI framework
- **AVFoundation**: Video capture and playback
- **Vision Framework**: On-device pose detection and body tracking
- **Core Data**: Local data persistence
- **Combine**: Reactive state management

## Project Status

### ✅ Completed: Phase 1 - Foundation Setup

Created core infrastructure:
- Project structure and file organization
- Core Data schema (4 entities: Session, Swing, SwingMetrics, JointData)
- Biomechanics calculation utilities
- Session list view with empty state
- Data models and constants

### 🔄 Next: Phase 2 - Video Recording

Upcoming work:
- Camera service implementation
- Video recording UI
- File management for recorded videos

## Getting Started

See [SETUP_INSTRUCTIONS.md](SETUP_INSTRUCTIONS.md) for detailed setup steps.

### Quick Start

1. Open Xcode and create a new iOS App project named "SwingAnalyzer"
2. Enable Core Data during project creation
3. Follow the setup instructions to integrate the source files
4. Build and run on a physical iPhone (camera required)

### Requirements

- Xcode 14 or later
- iOS 15.0+ deployment target
- Physical iPhone device (camera and pose detection require real hardware)
- Apple Developer account (for on-device testing)

## Architecture

### MVVM Pattern
- **Models**: Core Data entities + transient data structures
- **ViewModels**: Business logic and state management
- **Views**: SwiftUI views for UI presentation

### Key Services
- **CameraService**: Manages video capture
- **PoseDetectionService**: Processes video frames for body pose detection
- **SwingDetectionService**: Identifies individual swings from continuous video
- **BiomechanicsAnalyzer**: Calculates swing metrics and scores

## File Structure

```
SwingAnalyzer/
├── App/                          # App entry point
├── Models/
│   ├── CoreData/                 # Core Data entities and persistence
│   ├── BiomechanicsMetrics.swift # Scoring and metrics models
│   └── SwingData.swift           # Transient swing data structures
├── ViewModels/                   # State management
├── Views/
│   ├── Recording/                # Camera and recording UI
│   ├── Analysis/                 # Swing scoring and metrics display
│   ├── Playback/                 # Video player with skeleton overlay
│   └── Session/                  # Session list and management
├── Services/                     # Business logic services
└── Utilities/                    # Helper functions and constants
```

## Core Data Schema

### Entities
1. **Session**: Tracks recording sessions with multiple swings
2. **Swing**: Individual swing data with video reference
3. **SwingMetrics**: Calculated biomechanics metrics for each swing
4. **JointData**: Frame-by-frame body joint positions

### Relationships
- Session → Swings (one-to-many)
- Swing → SwingMetrics (one-to-one)
- Swing → JointData (one-to-many)

## Development Phases

1. ✅ **Foundation Setup** - Project structure, Core Data, basic UI
2. ⏳ **Video Recording** - Camera integration, recording controls
3. ⏳ **Pose Detection** - Vision framework integration, joint tracking
4. ⏳ **Swing Detection** - Automatic swing identification algorithm
5. ⏳ **Metrics Analysis** - Biomechanics calculations and scoring
6. ⏳ **Swing Score UI** - Detailed metrics display
7. ⏳ **Video Playback** - Slow-motion replay with skeleton overlay
8. ⏳ **Session Management** - Historical tracking and navigation
9. ⏳ **Navigation Flow** - Complete app navigation
10. ⏳ **Polish & Optimization** - UI polish, performance tuning, error handling

## License

Private project - all rights reserved.

## Credits

Designed and built with Claude Code (Anthropic).
