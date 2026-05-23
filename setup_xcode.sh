#!/bin/bash

# SwingAnalyzer Xcode Setup Script
# This script helps verify your project structure and provides guided setup

set -e

PROJECT_DIR="/Users/lcarey/Develop/baseball_swing_analyzer/SwingAnalyzer"
XCODE_PROJECT="$PROJECT_DIR/SwingAnalyzer.xcodeproj"
SOURCE_DIR="$PROJECT_DIR/SwingAnalyzer"

echo "🏗️  SwingAnalyzer Xcode Setup Script"
echo "===================================="
echo ""

# Check if Xcode project exists
if [ ! -d "$XCODE_PROJECT" ]; then
    echo "❌ Error: Xcode project not found at $XCODE_PROJECT"
    echo "Please create the Xcode project first."
    exit 1
fi

echo "✅ Found Xcode project"

# Check if source files exist
if [ ! -d "$SOURCE_DIR/App" ]; then
    echo "❌ Error: Source files not found at $SOURCE_DIR"
    exit 1
fi

echo "✅ Found source files"
echo ""

# Count Swift files
SWIFT_COUNT=$(find "$SOURCE_DIR" -name "*.swift" -type f | wc -l | tr -d ' ')
echo "📊 Found $SWIFT_COUNT Swift files"
echo ""

# Open Xcode
echo "🚀 Opening Xcode project..."
open "$XCODE_PROJECT"
sleep 3

echo ""
echo "📋 SETUP CHECKLIST - Follow these steps in Xcode:"
echo "=================================================="
echo ""
echo "STEP 1: Clean up Xcode-generated files"
echo "---------------------------------------"
echo "In Xcode's Project Navigator (left sidebar):"
echo "  1. Look for any duplicate SwingAnalyzerApp.swift at the ROOT level"
echo "  2. Look for any duplicate ContentView.swift at the ROOT level"
echo "  3. If found, RIGHT-CLICK → Delete → Move to Trash"
echo "  4. Keep the SwingAnalyzer.xcdatamodeld file (we'll configure it later)"
echo ""
read -p "Press ENTER when you've completed Step 1..."

echo ""
echo "STEP 2: Add source files to project"
echo "------------------------------------"
echo "  1. In Xcode, RIGHT-CLICK on the 'SwingAnalyzer' folder (blue icon)"
echo "  2. Select 'Add Files to SwingAnalyzer...'"
echo "  3. Navigate to: $SOURCE_DIR"
echo "  4. Hold CMD and SELECT these folders:"
echo "     • App"
echo "     • Models"
echo "     • ViewModels"
echo "     • Views"
echo "     • Utilities"
echo "  5. Make sure these options are CHECKED:"
echo "     ☑ Copy items if needed"
echo "     ☑ Create groups (not references)"
echo "     ☑ SwingAnalyzer target"
echo "  6. Click 'Add'"
echo ""
read -p "Press ENTER when you've completed Step 2..."

echo ""
echo "STEP 3: Add Info.plist"
echo "----------------------"
echo "  1. In Xcode, RIGHT-CLICK on the 'SwingAnalyzer' folder"
echo "  2. Select 'Add Files to SwingAnalyzer...'"
echo "  3. Navigate to: $SOURCE_DIR/Info.plist"
echo "  4. Make sure 'Copy items if needed' is CHECKED"
echo "  5. Click 'Add'"
echo ""
read -p "Press ENTER when you've completed Step 3..."

echo ""
echo "STEP 4: Configure Build Settings"
echo "---------------------------------"
echo "  1. Click on the blue 'SwingAnalyzer' project icon (top of navigator)"
echo "  2. Under TARGETS, select 'SwingAnalyzer'"
echo "  3. Go to 'Build Settings' tab"
echo "  4. Search for 'Info.plist'"
echo "  5. Set 'Info.plist File' to: SwingAnalyzer/Info.plist"
echo ""
read -p "Press ENTER when you've completed Step 4..."

echo ""
echo "STEP 5: Set minimum iOS version"
echo "--------------------------------"
echo "  1. Still in the SwingAnalyzer target"
echo "  2. Go to 'General' tab"
echo "  3. Under 'Deployment Info':"
echo "     • Set 'Minimum Deployments' to: iOS 15.0"
echo "     • Uncheck iPad and Mac (iPhone only)"
echo "     • Set 'Device Orientation' to: Portrait only"
echo ""
read -p "Press ENTER when you've completed Step 5..."

echo ""
echo "STEP 6: Try building the project"
echo "---------------------------------"
echo "  1. Select a simulator (iPhone 14 or later)"
echo "  2. Press CMD+B to build"
echo ""
read -p "Press ENTER to see Core Data setup instructions..."

echo ""
echo "STEP 7: Configure Core Data Model"
echo "----------------------------------"
echo "  1. In Xcode navigator, find and click 'SwingAnalyzer.xcdatamodeld'"
echo "  2. You should see the Core Data Model Editor"
echo ""
echo "Now we'll create 4 entities. I'll open detailed instructions..."
sleep 2

# Create detailed Core Data instructions
cat > /tmp/coredata_setup.txt << 'EOF'
CORE DATA MODEL SETUP
=====================

Entity 1: Session
-----------------
Click "Add Entity" button (bottom left), name it "Session"

Attributes (click + in Attributes section):
  • id          → Type: UUID
  • date        → Type: Date
  • location    → Type: String, Optional: ✓
  • averageScore → Type: Double
  • swingCount  → Type: Integer 16

Relationships (click + in Relationships section):
  • swings      → Destination: Swing, Type: To Many, Delete Rule: Cascade


Entity 2: Swing
---------------
Click "Add Entity", name it "Swing"

Attributes:
  • id           → Type: UUID
  • timestamp    → Type: Date
  • score        → Type: Double
  • videoURL     → Type: String
  • duration     → Type: Double
  • thumbnailData → Type: Binary Data, Optional: ✓

Relationships:
  • session      → Destination: Session, Type: To One, Delete Rule: Nullify
  • metrics      → Destination: SwingMetrics, Type: To One, Delete Rule: Cascade
  • jointData    → Destination: JointData, Type: To Many, Delete Rule: Cascade


Entity 3: SwingMetrics
----------------------
Click "Add Entity", name it "SwingMetrics"

Attributes:
  • id                      → Type: UUID
  • kneeBend               → Type: Double
  • hipRotation            → Type: Double
  • hipHorizontalMovement  → Type: Double
  • hipVerticalMovement    → Type: Double
  • hipShoulderAlignment   → Type: Double
  • timeToContact          → Type: Double

Relationships:
  • swing → Destination: Swing, Type: To One, Delete Rule: Nullify


Entity 4: JointData
-------------------
Click "Add Entity", name it "JointData"

Attributes:
  • id                 → Type: UUID
  • frameNumber        → Type: Integer 32
  • timestamp          → Type: Double
  • jointPositionsJSON → Type: String

Relationships:
  • swing → Destination: Swing, Type: To One, Delete Rule: Nullify


IMPORTANT: Set Inverse Relationships
-------------------------------------
Click on each relationship and verify/set the inverse:
  • Session.swings ↔ Swing.session
  • Swing.metrics ↔ SwingMetrics.swing
  • Swing.jointData ↔ JointData.swing

(Xcode usually does this automatically)


Save: CMD+S

EOF

# Open the instructions
open -a TextEdit /tmp/coredata_setup.txt

echo ""
echo "✅ I've opened detailed Core Data setup instructions in TextEdit"
echo ""
read -p "Press ENTER when you've completed the Core Data setup..."

echo ""
echo "STEP 8: Final build and test"
echo "-----------------------------"
echo "  1. Press CMD+B to build"
echo "  2. If successful, press CMD+R to run"
echo "  3. You should see an empty Sessions list with:"
echo "     • 'No Sessions Yet' message"
echo "     • A '+' button in the top right"
echo ""

echo ""
echo "🎉 Setup script complete!"
echo ""
echo "If you encounter any errors:"
echo "  • Missing file errors: Make sure you added all the folders"
echo "  • Core Data errors: Double-check entity names and relationships"
echo "  • Build errors: Check the issue navigator (CMD+4)"
echo ""
echo "Next steps after successful build:"
echo "  • Run the app in simulator"
echo "  • Verify the UI loads correctly"
echo "  • Then we'll continue with Phase 2 (Camera & Video Recording)"
echo ""
