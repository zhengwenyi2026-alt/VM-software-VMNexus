#!/bin/bash
#
# build_dmg.sh - Build AirVM and package as DMG
# Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
APP_NAME="AirVM"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_DIR="$SCRIPT_DIR/dmg"
VERSION="1.0.0"

echo "=== AirVM Build Script ==="
echo ""

# Step 1: Generate Xcode project
echo "[1/5] Generating Xcode project..."
cd "$SCRIPT_DIR"
xcodegen generate --spec project.yml
echo "  Done."

# Step 2: Build
echo "[2/5] Building $APP_NAME..."
xcodebuild -project "$APP_NAME.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    ONLY_ACTIVE_ARCH=NO \
    clean build

# Find the built app
BUILT_APP=$(find "$BUILD_DIR/DerivedData/Build/Products/Release" -name "$APP_NAME.app" -maxdepth 1 2>/dev/null | head -1)
if [ -z "$BUILT_APP" ]; then
    echo "Error: Could not find built app."
    exit 1
fi
rm -rf "$BUILD_DIR/$APP_NAME.app"
cp -a "$BUILT_APP" "$BUILD_DIR/$APP_NAME.app"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
echo "  Built: $APP_BUNDLE"

# Step 3: Create DMG
echo "[3/5] Creating DMG..."
mkdir -p "$DMG_DIR"
DMG_PATH="$DMG_DIR/AirVM-$VERSION.dmg"
rm -f "$DMG_PATH"

# Create temporary directory for DMG contents
DMG_TEMP=$(mktemp -d)
cp -R "$APP_BUNDLE" "$DMG_TEMP/"
ln -s /Applications "$DMG_TEMP/Applications"

# Copy app icon to DMG root for custom icon
ICON_PATH="$SCRIPT_DIR/图标/app_icon.png"
if [ -f "$ICON_PATH" ]; then
    cp "$ICON_PATH" "$DMG_TEMP/.VolumeIcon.png"
    echo "  Icon copied."
fi

hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_TEMP" \
    -ov -format UDZO \
    "$DMG_PATH"

# Set custom icon on DMG
if [ -f "$ICON_PATH" ]; then
    # Convert PNG to ICNS for DMG icon
    ICON_TEMP=$(mktemp -d)
    sips -s format icns "$ICON_PATH" --out "$ICON_TEMP/AirVM.icns" 2>/dev/null || true
    if [ -f "$ICON_TEMP/AirVM.icns" ]; then
        # Set the volume icon
        hdiutil attach -readwrite -noverify -noautoopen "$DMG_PATH" 2>/dev/null
        DMG_DEVICE=$(hdiutil info | grep "$DMG_PATH" | head -1 | awk '{print $1}')
        if [ -n "$DMG_DEVICE" ]; then
            cp "$ICON_TEMP/AirVM.icns" "/Volumes/$APP_NAME/.VolumeIcon.icns"
            SetFile -a C "/Volumes/$APP_NAME" 2>/dev/null || xattr -w com.apple.FinderInfo "$(python3 -c "import struct; print(struct.pack('32s', b'\x00' * 32).hex())" )" "/Volumes/$APP_NAME" 2>/dev/null || true
            hdiutil detach "$DMG_DEVICE" 2>/dev/null
            echo "  DMG icon set."
        fi
    fi
    rm -rf "$ICON_TEMP"
fi

rm -rf "$DMG_TEMP"
echo "  DMG created: $DMG_PATH"

# Step 4: Print info
echo "[4/5] Build info:"
echo "  App: $APP_BUNDLE"
echo "  DMG: $DMG_PATH"
echo "  Size: $(du -sh "$DMG_PATH" | cut -f1)"

# Step 5: Verify
echo "[5/5] Verifying..."
if [ -f "$DMG_PATH" ]; then
    echo "  DMG verified OK."
else
    echo "  ERROR: DMG not found!"
    exit 1
fi

echo ""
echo "=== Build complete! ==="
echo "DMG is at: $DMG_PATH"
