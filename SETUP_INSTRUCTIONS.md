# SwingAnalyzer - Setup Instructions

## Project Structure Created

I've created the initial Swift source files for the SwingAnalyzer app. Now you need to create the Xcode project to tie everything together.

## Step 1: Create Xcode Project

1. Open Xcode (make sure you have Xcode 14 or later)
2. Select **File > New > Project**
3. Choose **iOS > App**
4. Click **Next**

### Project Settings:
- **Product Name**: SwingAnalyzer
- **Team**: Select your Apple Developer team (or leave as None for now)
- **Organization Identifier**: com.yourname (use your own identifier)
- **Interface**: SwiftUI
- **Language**: Swift
- **Storage**: Core Data (CHECK THIS BOX - very important!)
- **Include Tests**: Uncheck for now

5. Click **Next**
6. Save the project in: `/Users/lcarey/Develop/baseball_swing_analyzer/SwingAnalyzer`

## Step 2: Replace Generated Files

Xcode will create some default files. We need to replace them with our custom files:

1. In the Project Navigator (left sidebar), delete these Xcode-generated files (select "Move to Trash"):
   - `SwingAnalyzerApp.swift` (if it exists at the root)
   - `ContentView.swift` (if it exists at the root)
   - Keep the `SwingAnalyzer.xcdatamodeld` file for now

2. Now add our custom directory structure:
   - Right-click on the `SwingAnalyzer` folder (blue icon) in Xcode
   - Select **Add Files to "SwingAnalyzer"...**
   - Navigate to `/Users/lcarey/Develop/baseball_swing_analyzer/SwingAnalyzer/SwingAnalyzer/`
   - Select all the folders: `App`, `Models`, `ViewModels`, `Views`, `Services`, `Utilities`
   - Make sure **"Create groups"** is selected
   - Make sure **"SwingAnalyzer" target is checked**
   - Click **Add**

## Step 3: Configure Core Data Model

Now we need to set up the Core Data model file:

1. In Xcode, locate the `SwingAnalyzer.xcdatamodeld` file in the Project Navigator
2. Click on it to open the Core Data Model Editor

### Create Session Entity:
1. Click the **"Add Entity"** button at the bottom
2. Name it: **Session**
3. Select Session, then click **"+"** in the Attributes section to add:
   - `id`: UUID
   - `date`: Date
   - `location`: String (Optional)
   - `averageScore`: Double
   - `swingCount`: Integer 16

4. In Relationships section, click **"+"**:
   - Name: `swings`
   - Destination: Swing (we'll create this next)
   - Type: To Many
   - Delete Rule: Cascade

### Create Swing Entity:
1. Click **"Add Entity"** again
2. Name it: **Swing**
3. Add Attributes:
   - `id`: UUID
   - `timestamp`: Date
   - `score`: Double
   - `videoURL`: String
   - `duration`: Double
   - `thumbnailData`: Binary Data (Optional)

4. Add Relationships:
   - Name: `session`, Destination: Session, Type: To One, Delete Rule: Nullify
   - Name: `metrics`, Destination: SwingMetrics, Type: To One, Delete Rule: Cascade
   - Name: `jointData`, Destination: JointData, Type: To Many, Delete Rule: Cascade

### Create SwingMetrics Entity:
1. Click **"Add Entity"**
2. Name it: **SwingMetrics**
3. Add Attributes:
   - `id`: UUID
   - `kneeBend`: Double
   - `hipRotation`: Double
   - `hipHorizontalMovement`: Double
   - `hipVerticalMovement`: Double
   - `hipShoulderAlignment`: Double
   - `timeToContact`: Double

4. Add Relationship:
   - Name: `swing`, Destination: Swing, Type: To One, Delete Rule: Nullify

### Create JointData Entity:
1. Click **"Add Entity"**
2. Name it: **JointData**
3. Add Attributes:
   - `id`: UUID
   - `frameNumber`: Integer 32
   - `timestamp`: Double
   - `jointPositionsJSON`: String

4. Add Relationship:
   - Name: `swing`, Destination: Swing, Type: To One, Delete Rule: Nullify

### Set Inverse Relationships:
Make sure inverse relationships are set correctly (Xcode usually does this automatically):
- Session.swings ↔ Swing.session
- Swing.metrics ↔ SwingMetrics.swing
- Swing.jointData ↔ JointData.swing

## Step 4: Configure Info.plist

1. In Xcode Project Navigator, find `Info.plist`
2. Right-click and select **Open As > Source Code**
3. Replace its contents with the Info.plist file I created at:
   `/Users/lcarey/Develop/baseball_swing_analyzer/SwingAnalyzer/SwingAnalyzer/Info.plist`

Or you can add the keys manually in the Property List editor:
- **Privacy - Camera Usage Description**: "SwingAnalyzer needs camera access to record and analyze your baseball swings"
- **Privacy - Photo Library Additions Usage Description**: "SwingAnalyzer needs photo library access to save swing videos"

## Step 5: Set Minimum iOS Version

1. Click on the blue **SwingAnalyzer** project icon at the top of the Project Navigator
2. Select the **SwingAnalyzer** target (under TARGETS)
3. Go to the **General** tab
4. Under **Deployment Info**, set:
   - **Minimum Deployments**: iOS 15.0
   - **Supported Destinations**: iPhone only (uncheck iPad and Mac)
   - **Device Orientation**: Portrait only

## Step 6: Build and Test

1. Select a simulator (iPhone 14 or later) from the device selector
2. Press **Cmd+B** to build
3. Fix any errors (there may be some namespace issues with imports)
4. Press **Cmd+R** to run

You should see an empty Sessions list with a message "No Sessions Yet" and a + button in the navigation bar.

## Current Status

✅ **Phase 1 Complete**: Project foundation is set up with:
- Core Data schema (Session, Swing, SwingMetrics, JointData)
- Basic models and data structures
- Biomechanics calculation utilities
- Session list view with empty state
- Project constants and color scheme

## Next Steps

After you verify the project builds and runs, we'll continue with:

**Phase 2**: Video Recording & Camera Interface
- CameraService.swift
- CameraView.swift
- RecordingViewModel.swift

**Phase 3**: Pose Detection & Body Tracking
- PoseDetectionService.swift
- Integration with Vision framework

Let me know once you have the Xcode project created and building successfully, and we'll continue with the camera functionality!

## Troubleshooting

### Build Errors
- If you get "Cannot find type 'Session' in scope" errors, make sure you added all the folders to the project with the correct target membership
- If Core Data errors occur, double-check the entity names and relationships

### File Organization
- The file structure should look like this in Xcode:
```
SwingAnalyzer/
├── App/
│   ├── SwingAnalyzerApp.swift
│   └── ContentView.swift
├── Models/
│   ├── CoreData/
│   │   ├── SwingAnalyzer.xcdatamodeld
│   │   ├── Session+CoreData.swift
│   │   ├── Swing+CoreData.swift
│   │   ├── SwingMetrics+CoreData.swift
│   │   ├── JointData+CoreData.swift
│   │   └── PersistenceController.swift
│   ├── BiomechanicsMetrics.swift
│   └── SwingData.swift
├── ViewModels/
│   └── SessionViewModel.swift
├── Views/
│   └── Session/
│       └── SessionListView.swift
├── Utilities/
│   ├── Constants.swift
│   └── BiomechanicsCalculations.swift
├── Info.plist
└── Assets.xcassets
```
