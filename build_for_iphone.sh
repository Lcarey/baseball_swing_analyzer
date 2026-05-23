#!/bin/bash

# Build and deploy to Lucas's iPhone
# Make sure Developer Mode is enabled on your iPhone first!

set -e

echo "🔨 Building SwingAnalyzer for your iPhone 15..."
echo ""

cd "$(dirname "$0")/SwingAnalyzer"

# Device ID for Lucas's iPhone
DEVICE_ID="00008120-000C68AC1A82201E"

# Build for device
echo "Building..."
xcodebuild \
  -project SwingAnalyzer.xcodeproj \
  -scheme SwingAnalyzer \
  -destination "id=${DEVICE_ID}" \
  -allowProvisioningUpdates \
  build

echo ""
echo "✅ Build complete!"
echo ""
echo "To install on your iPhone:"
echo "1. Make sure Developer Mode is enabled (Settings → Privacy & Security → Developer Mode)"
echo "2. Trust your Mac on your iPhone when prompted"
echo "3. In Xcode: Window → Devices and Simulators → Select your iPhone → Install the app"
echo ""
echo "Or simply run the app from Xcode (Cmd+R) with your iPhone selected"
