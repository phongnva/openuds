#!/bin/bash
#==============================================================================
# build-macos.sh — Automated UDSClient macOS DMG build script
# Usage: ./build-macos.sh [arm64|x86_64|universal]
# Requires: Homebrew, Python 3.11, pyinstaller, create-dmg
#==============================================================================

set -euo pipefail

# === CONFIGURATION ===
APP_NAME="UDSClient"
VERSION="4.0.0"
ARCH="${1:-arm64}"
BUILD_DIR="$(cd "$(dirname "$0")" && pwd)"
CLIENT_ROOT="$(dirname "$BUILD_DIR")"
SRC_DIR="$CLIENT_ROOT/src"
VENV_DIR="$BUILD_DIR/venv"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[BUILD]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

echo "=============================================="
echo " UDSClient macOS Build Script"
echo " Version : $VERSION"
echo " Arch    : $ARCH"
echo "=============================================="

# === STEP 1: Virtual Environment ===
log "[1/8] Setting up Python virtual environment..."

if [ ! -d "$VENV_DIR" ]; then
    log "Creating new virtual environment at $VENV_DIR..."
    python3.11 -m venv "$VENV_DIR" || python3 -m venv "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"

log "Upgrading pip..."
pip install --upgrade pip wheel setuptools

log "Installing dependencies..."
pip install -r "$CLIENT_ROOT/requirements.txt"

log "Installing PyInstaller..."
pip install pyinstaller

VENV_SITE=$(python -c "import site; print(site.getsitepackages()[0])")
log "Virtual environment site-packages: $VENV_SITE"

# === STEP 2: Generate Spec File ===
log "[2/8] Generating PyInstaller spec file..."

SPEC_CONTENT=$(cat << 'SPECEOF'
# -*- mode: python ; coding: utf-8 -*-
import sys, os
from PyInstaller.utils.hooks import collect_data_files, collect_submodules

# Collect PySide6 data files (Qt plugins, translations, etc.)
datas = collect_data_files('PySide6', include_py_files=False)

# Hidden imports needed at runtime (certifi is especially important)
hiddenimports = [
    'certifi',
    'cryptography',
    'psutil',
    'uds',
    'uds.ui',
    'uds.rest',
    'uds.tunnel',
    'uds.log',
    'uds.consts',
    'uds.exceptions',
    'uds.tools',
    'uds.os_detector',
    'uds.net.udssock',
    'uds.types',
    'UDSClient',
    'UDSClientLauncher',
    'uds.ui.pyside6.UDSWindow',
    'uds.ui.pyside6.UDSLauncherMac',
    'uds.ui.pyside6.UDSResources_rc',
    'PySide6.QtCore',
    'PySide6.QtGui',
    'PySide6.QtWidgets',
]

a = Analysis(
    ['__SRC__'],
    pathex=[],
    binaries=[],
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        'tkinter', 'matplotlib', 'numpy', 'scipy', 'pandas',
        'matplotlib', 'PIL', 'Pillow',
    ],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=None,
    noarchive=False,
    optimize=0,
)

pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='UDSClient',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,                 # NEVER use UPX on macOS — breaks arm64 binaries
    runtime_tmpdir=None,
    console=False,             # Windowed app — no terminal window
    disable_windowed_traceback=False,
    argv_emulation=True,       # Essential: passes URL args to the app bundle
    target_arch='__ARCH__',
    codesign_identity=None,
    entitlements_file=None,
)

app = BUNDLE(
    exe,
    name='UDSClient.app',
    info_plist={
        'CFBundleName': 'UDSClient',
        'CFBundleDisplayName': 'UDS Client',
        'CFBundleIdentifier': 'com.udsenterprise.UDSClient3',
        'CFBundleVersion': '__VERSION__',
        'CFBundleShortVersionString': '__VERSION__',
        'CFBundlePackageType': 'APPL',
        'CFBundleExecutable': 'UDSClient',
        'LSMinimumSystemVersion': '12.0',
        'LSApplicationCategoryType': 'public.app-category.productivity',
        'NSHighResolutionCapable': True,
        'NSPrincipalClass': 'NSApplication',
        # URL Schemes — handles uds:// and udss:// from browsers
        'CFBundleURLTypes': [
            {
                'CFBundleURLName': 'UDS Standard',
                'CFBundleURLSchemes': ['uds'],
            },
            {
                'CFBundleURLName': 'UDS Secure',
                'CFBundleURLSchemes': ['udss'],
            },
        ],
        # Force Qt to use Cocoa platform (not X11)
        'QT_QPA_PLATFORM': 'cocoa',
    },
    macos_module_content=[],
    force_kernel_extension=False,
    arch='__ARCH__',
)
SPECEOF
)

# Substitute placeholders
SPEC_CONTENT="${SPEC_CONTENT//__SRC__/$SRC_DIR}"
SPEC_CONTENT="${SPEC_CONTENT//__VERSION__/$VERSION}"
SPEC_CONTENT="${SPEC_CONTENT//__ARCH__/$ARCH}"

echo "$SPEC_CONTENT" > "$BUILD_DIR/UDSClient.spec"
log "Spec file written: $BUILD_DIR/UDSClient.spec"

# === STEP 3: PyInstaller Build ===
log "[3/8] Running PyInstaller..."

DIST_DIR="$BUILD_DIR/dist-$ARCH"
rm -rf "$DIST_DIR"

cd "$SRC_DIR"
pyinstaller \
    "$BUILD_DIR/UDSClient.spec" \
    --noconfirm \
    --distpath "$DIST_DIR" \
    --workpath "$BUILD_DIR/build-$ARCH" \
    --specpath "$BUILD_DIR"

APP_DIR="$DIST_DIR/UDSClient.app"

if [ ! -d "$APP_DIR" ]; then
    err "Build failed: UDSClient.app was not created"
fi

log "App bundle created: $APP_DIR"

# === STEP 4: Copy Qt Plugins ===
log "[4/8] Copying Qt plugins into app bundle..."

PLUGINS_DIR="$APP_DIR/Contents/Resources/qt_plugins"
mkdir -p "$PLUGINS_DIR"

for plugin_type in platforms styles imageformats iconengines; do
    src="$VENV_SITE/PySide6/plugins/$plugin_type"
    dst="$PLUGINS_DIR/$plugin_type"

    if [ -d "$src" ]; then
        mkdir -p "$dst"
        # Copy all shared libraries for this plugin type
        for ext in so dylib dylib.1 dylib.1.0.0 dylib.1.0; do
            cp -r "$src"/*."$ext" "$dst/" 2>/dev/null || true
        done
        # Also copy the whole directory content
        cp -rn "$src"/* "$dst/" 2>/dev/null || true
        log "  Copied $plugin_type plugins"
    else
        warn "  Plugin type '$plugin_type' not found at $src"
    fi
done

# Create qt.conf so Qt finds its plugins inside the bundle
cat > "$APP_DIR/Contents/Resources/qt.conf" << 'QTEOF'
[Paths]
Plugins = Resources/qt_plugins
QTEOF

log "Qt configuration written: $APP_DIR/Contents/Resources/qt.conf"

# === STEP 5: Verify Build ===
log "[5/8] Verifying build..."

EXE_PATH="$APP_DIR/Contents/MacOS/UDSClient"
if [ ! -f "$EXE_PATH" ]; then
    err "Executable not found: $EXE_PATH"
fi

log "Architecture check:"
file "$EXE_PATH"

EXPECTED_ARCH="$ARCH"
if [ "$ARCH" = "universal" ]; then
    if file "$EXE_PATH" | grep -q "arm64"; then
        log "  arm64 slice: OK"
    fi
    # Check x86_64 slice if available
    if lipo "$EXE_PATH" -info 2>/dev/null | grep -q "x86_64"; then
        log "  x86_64 slice: OK"
    fi
else
    if file "$EXE_PATH" | grep -q "$EXPECTED_ARCH"; then
        log "  Architecture matches: $EXPECTED_ARCH"
    else
        warn "  Architecture mismatch! Expected $EXPECTED_ARCH"
    fi
fi

# === STEP 6: Create DMG ===
log "[6/8] Creating DMG installer..."

cd "$BUILD_DIR"
DMG_NAME="UDSClient-$VERSION-$ARCH.dmg"
DMG_VOLNAME="UDSClient $VERSION"

# Remove old DMG if exists
rm -f "$DMG_NAME"
hdiutil detach "/Volumes/$DMG_VOLNAME" 2>/dev/null || true

create-dmg \
    --volname "$DMG_VOLNAME" \
    --volicon "" \
    --window-pos 200 120 \
    --window-size 640 420 \
    --icon-size 110 \
    --icon "UDSClient.app" 160 185 \
    --app-drop-link 480 185 \
    --hide-extension "UDSClient.app" \
    --eula "" \
    --no-internet-enable \
    "$DMG_NAME" \
    "dist-$ARCH/" 2>/dev/null || \
create-dmg \
    --volname "$DMG_VOLNAME" \
    --window-pos 200 120 \
    --window-size 640 420 \
    --icon "UDSClient.app" 160 185 \
    --app-drop-link 480 185 \
    "$DMG_NAME" \
    "dist-$ARCH/"

if [ -f "$DMG_NAME" ]; then
    log "DMG created: $BUILD_DIR/$DMG_NAME"
    ls -lh "$DMG_NAME"
else
    err "DMG creation failed"
fi

# === STEP 7: Code Signing (if available) ===
log "[7/8] Code signing..."

if command -v codesign &> /dev/null; then
    # Check for available signing identity
    AVAILABLE=$(codesign -vvv 2>&1 | grep -c "Signing" || true)
    if [ "$AVAILABLE" -gt 0 ]; then
        log "Code signing identity found"
        # Uncomment and fill in your identity to enable signing:
        # codesign --force --deep --sign "Developer ID Application: Your Name (TEAMID)" \
        #     --entitlements "$BUILD_DIR/UDSClient.entitlements" \
        #     --options runtime \
        #     "$APP_DIR"
        warn "  Code signing commented out — uncomment in this script to enable"
    else
        warn "  No code signing identity found — skipping"
    fi
else
    warn "  codesign not available — skipping"
fi

# === STEP 8: Summary ===
log "[8/8] Build complete!"
echo ""
echo "=============================================="
echo -e " ${GREEN}Build Successful${NC}"
echo "=============================================="
echo ""
echo " Output:"
echo "   App bundle : $APP_DIR"
echo "   DMG file   : $BUILD_DIR/$DMG_NAME"
echo ""
echo " File size:"
ls -lh "$DMG_NAME"
echo ""
echo " Next steps:"
echo ""
echo "  1. Code Sign & Notarize (required for distribution):"
echo "     a) Obtain a Developer ID certificate from Apple Developer portal"
echo "     b) Create UDSClient.entitlements (see BUILD-macOS.md)"
echo "     c) Sign the app:"
echo '        codesign --force --deep --sign "Developer ID Application: Name (TEAMID)" \'
echo "            --entitlements UDSClient.entitlements $APP_DIR"
echo "     d) Notarize:"
echo '        xcrun notarytool submit "$DMG_NAME" \'
echo '            --apple-id "email@domain.com" \'
echo '            --password "app-password" \'
echo '            --team-id "TEAMID" --wait'
echo "     e) Staple:"
echo "        xcrun stapler staple $APP_DIR"
echo ""
echo "  2. Universal build (arm64 + x86_64):"
echo "     Build for each arch separately, then combine:"
echo "        lipo -create dist-arm64/.../UDSClient dist-x86_64/.../UDSClient \\"
echo "              -output dist-universal/.../UDSClient"
echo ""
echo "  3. Test the app:"
echo "     open $DMG_NAME"
echo "     # or: open $APP_DIR"
echo ""
