#!/bin/bash
#
# set_dmg_icon.sh - Set custom icon for AirVM DMG
# Usage: ./set_dmg_icon.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DMG_PATH="$SCRIPT_DIR/dmg/AirVM.dmg"
ICON_PATH="$SCRIPT_DIR/图标/app_icon.png"
ICNS_PATH="$SCRIPT_DIR/dmg/AirVM.icns"

echo "=== AirVM DMG Icon Setter ==="
echo ""

# Check if DMG exists
if [ ! -f "$DMG_PATH" ]; then
    echo "Error: DMG not found at $DMG_PATH"
    echo "Please build the DMG first using build_dmg.sh"
    exit 1
fi

# Check if icon exists
if [ ! -f "$ICON_PATH" ]; then
    echo "Error: Icon not found at $ICON_PATH"
    exit 1
fi

# Convert PNG to ICNS if needed
if [ ! -f "$ICNS_PATH" ]; then
    echo "Converting icon to ICNS format..."
    python3 -c "
from PIL import Image
img = Image.open('$ICON_PATH')
img.save('$ICNS_PATH', format='ICNS')
print('Icon converted successfully')
"
fi

# Create read-write DMG
echo "Creating read-write DMG..."
RW_DMG="$SCRIPT_DIR/dmg/AirVM_rw.dmg"
rm -f "$RW_DMG"
hdiutil create -volname AirVM -srcfolder "/Users/wenyi/Library/Developer/Xcode/DerivedData/AirVM-awzhokwxfxinarboxpqnlulyvzri/Build/Products/Release/AirVM.app" -ov -format UDRW "$RW_DMG"

# Mount DMG read-write
echo "Mounting DMG..."
# Unmount existing if any
if [ -d "/Volumes/AirVM" ]; then
    diskutil unmount force "/Volumes/AirVM" 2>/dev/null || true
    sleep 1
fi
hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG"
sleep 2

MOUNT_POINT="/Volumes/AirVM"

if [ -d "$MOUNT_POINT" ]; then
    # Copy icon
    echo "Setting custom icon..."
    cp "$ICNS_PATH" "$MOUNT_POINT/.VolumeIcon.icns"
    SetFile -a C "$MOUNT_POINT"
    echo "Icon set successfully"
    
    # Unmount
    echo "Unmounting..."
    diskutil unmount "$MOUNT_POINT"
    sleep 2
    
    # Convert to compressed DMG
    echo "Creating compressed DMG..."
    hdiutil convert "$RW_DMG" -format UDZO -o "$DMG_PATH"
    
    # Cleanup
    rm -f "$RW_DMG" "$ICNS_PATH"
    
    echo ""
    echo "=== Done! ==="
    echo "DMG with custom icon: $DMG_PATH"
else
    echo "Error: Failed to mount DMG"
    rm -f "$RW_DMG"
    exit 1
fi
