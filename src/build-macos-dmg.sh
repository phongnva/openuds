#!/bin/bash
# =============================================================================
# Build script for UDS Client macOS Intel (x86_64) DMG
# Usage: cd uds-client/src && bash build-macos-dmg.sh
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="FSOFTVirtualDesktopClient"
APP_VERSION="4.0.0"
DMG_NAME="FSOFT-VDC-${APP_VERSION}-macOS-Intel"
VENV_DIR="${SCRIPT_DIR}/build_venv"

echo "============================================"
echo "  FSOFT Virtual Desktop Client macOS Intel Build"
echo "  Version: ${APP_VERSION}"
echo "  Architecture: x86_64 (Intel)"
echo "============================================"
echo ""

# -------------------------------------------------
# Step 1: Create virtualenv and install dependencies
# -------------------------------------------------
echo "[1/4] Setting up virtual environment..."
if [ -d "$VENV_DIR" ]; then
    echo "  Removing existing virtualenv..."
    rm -rf "$VENV_DIR"
fi

python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

echo "  Installing dependencies..."
pip install --upgrade pip setuptools wheel 
pip install PySide6 psutil cryptography certifi pyinstaller 

echo "  Installed packages:"
pip list --format=columns | grep -iE "pyside6|psutil|cryptography|certifi|pyinstaller"
echo ""

# -------------------------------------------------
# Step 2: Build .app bundle with PyInstaller
# -------------------------------------------------
echo "[2/4] Building .app bundle with PyInstaller..."

# Clean previous build artifacts
rm -rf build dist

pyinstaller UDSClient-macOS.spec --clean --noconfirm

if [ ! -d "dist/${APP_NAME}.app" ]; then
    echo "ERROR: .app bundle was not created!"
    exit 1
fi

echo "  .app bundle created successfully at dist/${APP_NAME}.app"
echo ""

# -------------------------------------------------
# Step 3: Verify the .app bundle
# -------------------------------------------------
echo "[3/4] Verifying .app bundle..."

# Check Info.plist
if [ -f "dist/${APP_NAME}.app/Contents/Info.plist" ]; then
    echo "  ✓ Info.plist exists"
    # Check URL schemes
    if /usr/libexec/PlistBuddy -c "Print :CFBundleURLTypes:0:CFBundleURLSchemes:0" "dist/${APP_NAME}.app/Contents/Info.plist" 2>/dev/null | grep -q "uds"; then
        echo "  ✓ URL scheme 'uds' registered"
    else
        echo "  ⚠ URL scheme 'uds' not found in Info.plist"
    fi
    if /usr/libexec/PlistBuddy -c "Print :CFBundleURLTypes:1:CFBundleURLSchemes:0" "dist/${APP_NAME}.app/Contents/Info.plist" 2>/dev/null | grep -q "udss"; then
        echo "  ✓ URL scheme 'udss' registered"
    else
        echo "  ⚠ URL scheme 'udss' not found in Info.plist"
    fi
else
    echo "  ✗ Info.plist is missing!"
fi

# Check main executable
if [ -f "dist/${APP_NAME}.app/Contents/MacOS/UDSClientLauncher" ]; then
    echo "  ✓ Main executable exists"
    FILE_INFO=$(file "dist/${APP_NAME}.app/Contents/MacOS/UDSClientLauncher")
    echo "  Architecture: $FILE_INFO"
else
    echo "  ✗ Main executable is missing!"
    exit 1
fi

# Check icon
if [ -f "dist/${APP_NAME}.app/Contents/Resources/uds.icns" ]; then
    echo "  ✓ App icon exists"
else
    echo "  ⚠ App icon missing (non-critical)"
fi

echo ""

# -------------------------------------------------
# Step 4: Create DMG
# -------------------------------------------------
echo "[4/4] Creating DMG installer..."

DMG_DIR="${SCRIPT_DIR}/dist/dmg"
DMG_FILE="${SCRIPT_DIR}/dist/${DMG_NAME}.dmg"

# Clean up
rm -rf "$DMG_DIR"
rm -f "$DMG_FILE"

# Create DMG staging directory
mkdir -p "$DMG_DIR"

# Copy .app to staging
cp -R "dist/${APP_NAME}.app" "$DMG_DIR/"

# Create symlink to /Applications for easy drag-and-drop install
ln -s /Applications "$DMG_DIR/Applications"

# Create DMG using hdiutil
echo "  Creating DMG image..."
hdiutil create \
    -volname "FSOFT Virtual Desktop Client" \
    -srcfolder "$DMG_DIR" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_FILE"

# Clean up staging directory
rm -rf "$DMG_DIR"

if [ -f "$DMG_FILE" ]; then
    DMG_SIZE=$(du -sh "$DMG_FILE" | cut -f1)
    echo ""
    echo "============================================"
    echo "  BUILD SUCCESSFUL!"
    echo "============================================"
    echo "  DMG file: $DMG_FILE"
    echo "  Size: $DMG_SIZE"
    echo "  Architecture: x86_64 (Intel)"
    echo "============================================"
else
    echo "ERROR: DMG was not created!"
    exit 1
fi

# Deactivate virtualenv
deactivate 2>/dev/null || true

echo ""
echo "Done! You can now distribute ${DMG_NAME}.dmg"
