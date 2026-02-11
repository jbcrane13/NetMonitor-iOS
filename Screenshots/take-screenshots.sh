#!/bin/bash

# NetMonitor iOS Screenshot Automation Script
# Run this after the build completes successfully

set -e

PROJECT_DIR="/Users/blake/Projects/NetMonitor-ios/Netmonitor"
SCREENSHOT_DIR="/Users/blake/Projects/NetMonitor-ios/Screenshots/AppStore"
APP_PATH="$PROJECT_DIR/build/Build/Products/Release-iphonesimulator/Netmonitor.app"
BUNDLE_ID="com.blakemiller.netmonitor"

# Simulator UDIDs
IPHONE_16_PRO_MAX="B4BD6AED-C354-443D-BC10-026854FD64BA"
IPHONE_16_PRO="BE0ED125-81C1-4FED-ADA5-98221B140C40"

echo "🚀 NetMonitor iOS Screenshot Automation"
echo "========================================"

# Check if app was built
if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: App not found at $APP_PATH"
    echo "Please build the app first with:"
    echo "cd $PROJECT_DIR && xcodebuild -project Netmonitor.xcodeproj -scheme Netmonitor -sdk iphonesimulator -configuration Release -derivedDataPath ./build build"
    exit 1
fi

echo "✅ Found app at $APP_PATH"

# Create screenshot directory
mkdir -p "$SCREENSHOT_DIR"

# Function to take screenshots for a device
take_screenshots() {
    local DEVICE_UDID=$1
    local DEVICE_NAME=$2
    
    echo ""
    echo "📱 Taking screenshots for $DEVICE_NAME..."
    
    # Boot simulator if not already booted
    echo "   Booting simulator..."
    xcrun simctl boot "$DEVICE_UDID" 2>/dev/null || echo "   Simulator already booted"
    
    # Wait for boot
    sleep 3
    
    # Install app
    echo "   Installing app..."
    xcrun simctl install "$DEVICE_UDID" "$APP_PATH"
    
    # Launch app
    echo "   Launching app..."
    xcrun simctl launch "$DEVICE_UDID" "$BUNDLE_ID"
    
    # Wait for app to fully load
    sleep 5
    
    # Take screenshots
    echo "   Taking screenshots..."
    
    # Dashboard
    xcrun simctl io "$DEVICE_UDID" screenshot "$SCREENSHOT_DIR/${DEVICE_NAME}-01-dashboard.png"
    echo "   ✓ Dashboard captured"
    
    # You'll need to add UI automation here to navigate between screens
    # For now, this captures the initial screen
    
    # Note: To capture other screens, you could:
    # 1. Use UI testing with xctest
    # 2. Use AppleScript to control Simulator
    # 3. Manually navigate and run this script for each screen
    
    echo "   ✓ Screenshots saved to $SCREENSHOT_DIR"
}

# Take screenshots for both devices
take_screenshots "$IPHONE_16_PRO_MAX" "iPhone-16-Pro-Max"
take_screenshots "$IPHONE_16_PRO" "iPhone-16-Pro"

echo ""
echo "✅ Screenshot capture complete!"
echo "📁 Screenshots location: $SCREENSHOT_DIR"
echo ""
echo "⚠️  Note: This script only captures the initial app screen."
echo "   For additional screens, you'll need to:"
echo "   1. Manually navigate to each screen in the simulator"
echo "   2. Run: xcrun simctl io <UDID> screenshot <filename>"
echo ""
echo "Required screens to capture:"
echo "  - Dashboard (main screen)"
echo "  - Targets view"
echo "  - Devices view"  
echo "  - Tools view"
echo "  - Any widgets"
