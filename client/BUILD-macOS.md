# BUILD-macOS.md

Build guide for **FSOFT Virtual Desktop Client** on **macOS** — Apple Silicon (arm64) and Intel (x86_64), producing a `.dmg` installer.

> **Branding:** App display name = `FSOFT Virtual Desktop Client`, Bundle ID = `com.fsoft.virtualdesktop.client`, Icon = `FSOFTClient.icns`. To rename, edit the variables at the top of `build-universal-dmg.sh`.

---

## ⚡ Quick Start — Universal DMG (Recommended)

Build **cả hai arch** (arm64 + x86_64) và tạo **Universal DMG** trên cùng một máy Mac, **không cần Apple Developer Account**.

### One-liner

```bash
git clone <repo> && cd uds-client
chmod +x macos-build/build-universal-dmg.sh
./macos-build/build-universal-dmg.sh
```

### Output

```
macos-build/
├── dist-universal/
│   └── FSOFT Virtual Desktop Client.app/   ← Universal app
├── FSOFTClient-4.0.0-arm64.dmg    ← Apple Silicon only
├── FSOFTClient-4.0.0-x86_64.dmg   ← Intel only
└── FSOFTClient-4.0.0-Universal.dmg ← CẢ HAI, khuyến nghị dùng
```

### Chạy trên máy khác (không cần Developer Account)

```bash
# Gỡ quarantine (cho phép chạy không signed)
xattr -d -r com.apple.quarantine ~/Applications/FSOFT\ Virtual\ Desktop\ Client.app

# Hoặc nếu có cảnh báo:
# System Settings → Privacy & Security → Open Anyway
```

---

## Table of Contents

1. [⚡ Quick Start — Universal DMG](#-quick-start--universal-dmg-recommended) *(You are here)*
2. [Environment Overview](#1-environment-overview)
3. [Prerequisites](#2-prerequisites)
4. [Step 1 — macOS Environment Setup](#step-1--macos-environment-setup)
5. [Step 2 — Python Virtual Environment & Dependencies](#step-2--python-virtual-environment--dependencies)
6. [Step 3 — PyInstaller Spec File for macOS](#step-3--pyinstaller-spec-file-for-macos)
7. [Step 4 — Build the macOS Application Bundle](#step-4--build-the-macos-application-bundle)
8. [Step 5 — Create the .dmg Installer](#step-5--create-the-dmg-installer)
9. [Step 6 — Universal DMG (arm64 + x86_64)](#step-6--universal-dmg-arm64--x86_64)
10. [Step 7 — Code Signing & Notarization (Optional but Recommended)](#step-7--code-signing--notarization-optional-but-recommended)
11. [Full Automated Build Script](#full-automated-build-script)
12. [Troubleshooting](#troubleshooting)

---

## 1. Environment Overview

| Item | Details |
|------|---------|
| **Target OS** | macOS 12+ (Monterey and later) |
| **Architectures** | Apple Silicon (`arm64`) and Intel (`x86_64`) |
| **UI Framework** | PySide6 (Qt6) |
| **Packaging Tool** | PyInstaller |
| **DMG Creation** | `create-dmg` (via Homebrew) |
| **App Bundle** | Standard macOS `.app` bundle |
| **Entry Point** | `UDSClientLauncher.py` (handles `uds://` URL scheme) |

### macOS App Bundle Structure

```
UDSClient.app/
└── Contents/
    ├── Info.plist          # Declares URL scheme: uds://, udss://
    ├── MacOS/
    │   └── UDSClient       # PyInstaller bootloader binary
    ├── Resources/
    │   └── (Qt plugins, fonts, etc.)
    └── Frameworks/
        └── (Python, Qt, etc.)
```

---

## 2. Prerequisites

Install the following on your macOS machine (Apple Silicon recommended):

### 2.1 Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

> For Apple Silicon: Homebrew installs to `/opt/homebrew/bin`. Add to PATH:
> ```bash
> echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
> eval "$(/opt/homebrew/bin/brew shellenv)"
> ```

### 2.2 Xcode Command Line Tools

```bash
xcode-select --install
```

### 2.3 Required Homebrew Packages

```bash
brew install python@3.10 python@3.11 python@3.12   # Choose one version; 3.11 recommended for Qt6
brew install pyinstaller
brew install create-dmg
brew install qt@6                                   # Qt6 libraries for PySide6
```

> **Note for Apple Silicon:** All brew packages are installed as `arm64` native binaries.
> For Intel builds on Apple Silicon (or vice versa), use Rosetta 2 or a virtual machine.

---

## 3. Step 1 — macOS Environment Setup

### 3.1 Create Working Directory

```bash
cd /path/to/uds-client
mkdir -p macos-build && cd macos-build
```

### 3.2 Set Python Version

```bash
# Use Python 3.11 for best Qt6 compatibility
export PATH="/opt/homebrew/opt/python@3.11/bin:$PATH"
export PYTHON_VERSION=3.11
```

### 3.3 Verify Tools

```bash
python3 --version      # Should be 3.11.x
pyinstaller --version
create-dmg --version
```

---

## 4. Step 2 — Python Virtual Environment & Dependencies

### 4.1 Create Virtual Environment

```bash
cd /path/to/uds-client/src

# Apple Silicon (arm64)
python3.11 -m venv ../macos-build/venv

# Activate it
source ../macos-build/venv/bin/activate
```

### 4.2 Install Dependencies

```bash
# Upgrade pip
pip install --upgrade pip

# Install requirements
pip install -r ../requirements.txt

# Also install PyInstaller in the venv
pip install pyinstaller
```

> **Note on Qt:** `PySide6` from `requirements.txt` includes the Qt6 binaries (no separate Qt installation needed).
> If you prefer `PyQt6`, replace `PySide6` in requirements with `PyQt6`.

### 4.3 Resource Compilation (Optional — only if you modify .qrc files)

```bash
# If you have UDSResources.qrc, compile it:
pyside6-rcc -o UDSResources_rc.py UDSResources.qrc
```

---

## 5. Step 3 — PyInstaller Spec File for macOS

The spec file configures PyInstaller to build a macOS `.app` bundle. Generate it with:

```bash
cd /path/to/uds-client/src
source ../macos-build/venv/bin/activate
pyi-makespec --name=UDSClient --windowed --osx-bundle-identifier=com.udsenterprise.UDSClient3 \
    UDSClientLauncher.py
```

This creates `UDSClient.spec`. Edit it to match the configuration below:

### Complete `UDSClient.spec`

```python
# -*- mode: python ; coding: utf-8 -*-
# pyi-makespec --name=UDSClient --windowed --osx-bundle-identifier=com.udsenterprise.UDSClient3 \
#     UDSClientLauncher.py

import sys
import os

from PyInstaller.utils.hooks import collect_data_files, collect_submodules

# Collect PySide6 data files (Qt plugins, translations, etc.)
datas = collect_data_files('PySide6', include_py_files=False)

# Collect Qt plugins (platforms, styles, imageformats, etc.)
qt_plugins = [
    ('platforms', 'PySide6/plugins/platforms'),
    ('styles',    'PySide6/plugins/styles'),
    ('imageformats', 'PySide6/plugins/imageformats'),
    ('iconengines', 'PySide6/plugins/iconengines'),
]

# Collect uds resources (UDSResources_rc.py)
uds_resources = []
resource_file = 'UDSResources_rc.py'
if os.path.exists(resource_file):
    datas.append((resource_file, '.'))

# Hidden imports needed at runtime
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
]

a = Analysis(
    ['UDSClientLauncher.py'],
    pathex=[],
    binaries=[],
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        'tkinter',
        'matplotlib',
        'numpy',
        'scipy',
        'pandas',
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
    upx=False,                    # Do NOT use UPX on macOS; it breaks arm64 binaries
    runtime_tmpdir=None,
    console=False,                # Windowed app (no terminal)
    disable_windowed_traceback=False,
    argv_emulation=True,          # Essential for macOS bundle to handle URL args
    target_arch='arm64',          # 'arm64', 'x86_64', or None for universal
    codesign_identity=None,
    entitlements_file=None,
    icon='../macos-build/UDSClient.icns',  # Optional: set .icns icon
)

# MacOS App Bundle
app = BUNDLE(
    exe,
    name='UDSClient.app',
    info_plist={
        'CFBundleName': 'UDSClient',
        'CFBundleDisplayName': 'UDS Client',
        'CFBundleIdentifier': 'com.udsenterprise.UDSClient3',
        'CFBundleVersion': '4.0.0',
        'CFBundleShortVersionString': '4.0.0',
        'CFBundlePackageType': 'APPL',
        'CFBundleExecutable': 'UDSClient',
        'CFBundleIconFile': 'UDSClient.icns',
        'LSMinimumSystemVersion': '12.0',
        'LSApplicationCategoryType': 'public.app-category.productivity',
        'NSHighResolutionCapable': True,
        'NSPrincipalClass': 'NSApplication',
        # URL Scheme handlers
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
        # Signing entitlements
        # 'CodeSigningEntitlements': '../macos-build/UDSClient.entitlements',
    },
    macos_module_content=[],
    force_kernel_extension=False,
    arch='arm64',
)
```

### Key Differences from Windows Build

| Parameter | Windows | macOS |
|-----------|---------|-------|
| `console` | `True` | `False` |
| `argv_emulation` | `False` | `True` (handles URL args) |
| `upx` | `True` | `False` (breaks arm64) |
| `target_arch` | `None` | `'arm64'` |
| `BUNDLE` | Not used | Used to create `.app` |
| `info_plist` | Not used | Declares URL schemes |
| Entitlements | Registry | `com.apple.security.*` |

---

## 6. Step 4 — Build the macOS Application Bundle

### 6.1 Prepare Resources

```bash
cd /path/to/uds-client/macos-build

# Create a placeholder icon (or use your own .icns file)
# The build will work without an .icns, but the app won't have a custom icon

# Ensure you have a .icns file. You can convert a .png to .icns:
# brew install imagemagick
# convert icon.png -resize 512x512 icon_512.png
# png2icns UDSClient.icns icon_512.png
```

### 6.2 Build the App

```bash
cd /path/to/uds-client/src
source ../macos-build/venv/bin/activate

# Run PyInstaller with the spec file
pyinstaller ../macos-build/UDSClient.spec --noconfirm

# Output location:
#   macos-build/dist/UDSClient.app
```

### 6.3 Copy Required Qt Plugins Into the App Bundle

PyInstaller needs Qt plugins to be bundled manually. Run this post-build script:

```bash
#!/bin/bash
# post-build.sh — run after PyInstaller completes

set -e

APP_DIR="macos-build/dist/UDSClient.app"
VENV_PYTHON=$(realpath macos-build/venv/lib/python*/site-packages)

echo "Fixing Qt plugins in $APP_DIR..."

# Create plugins directory inside Resources
PLUGINS_DIR="$APP_DIR/Contents/Resources/qt_plugins"
mkdir -p "$PLUGINS_DIR"

# Copy Qt plugins from venv
for plugin_type in platforms styles imageformats iconengines; do
    src="$VENV_PYTHON/PySide6/plugins/$plugin_type"
    dst="$PLUGINS_DIR/$plugin_type"
    if [ -d "$src" ]; then
        mkdir -p "$dst"
        cp -r "$src"/*.so "$dst/" 2>/dev/null || true
        cp -r "$src"/*.dylib "$dst/" 2>/dev/null || true
        echo "  Copied $plugin_type"
    fi
done

# Set QT_QPA_PLATFORM_PLUGINS environment variable via Info.plist
PLIST="$APP_DIR/Contents/Info.plist"
# Note: Qt sets this automatically via qt.conf, but we verify it exists
echo "App bundle ready at: $APP_DIR"
ls -la "$APP_DIR/Contents/MacOS/"
```

```bash
chmod +x post-build.sh && ./post-build.sh
```

### 6.4 Verify the App Bundle

```bash
# Check bundle structure
ls -la macos-build/dist/UDSClient.app/Contents/

# Check executable architecture
file macos-build/dist/UDSClient.app/Contents/MacOS/UDSClient
# Expected for Apple Silicon: "Mach-O 64-bit executable arm64"
# Expected for Intel:          "Mach-O 64-bit executable x86_64"

# Test launch (should show the launcher window)
open macos-build/dist/UDSClient.app
```

---

## 7. Step 5 — Create the .dmg Installer

### 7.1 Install create-dmg

```bash
brew install create-dmg
```

### 7.2 Create the DMG

```bash
cd macos-build/dist

# Basic DMG creation
create-dmg \
    --volname "UDSClient 4.0.0" \
    --volicon "../UDSClient.icns" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon UDSClient.app 150 180 \
    --hide-extension UDSClient.app \
    --app-drop-link 450 180 \
    --codesign \
    UDSClient-4.0.0-arm64.dmg \
    .

# Output: UDSClient-4.0.0-arm64.dmg
```

### 7.3 Create a Universal DMG (arm64 + x86_64)

If you need a **Universal** DMG that runs on both Apple Silicon and Intel:

```bash
# Step 1: Build arm64 version (in venv with arm64 Python)
# Step 2: Build x86_64 version (requires Rosetta or separate machine)

# Combine both app bundles into one .app using lipo (if you have both architectures)
# Then create DMG from the combined app
lipo -create \
    dist-arm64/UDSClient.app/Contents/MacOS/UDSClient \
    dist-x86_64/UDSClient.app/Contents/MacOS/UDSClient \
    -output dist-universal/UDSClient.app/Contents/MacOS/UDSClient

# Create DMG from the universal bundle
create-dmg \
    --volname "UDSClient 4.0.0 Universal" \
    --volicon "../UDSClient.icns" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon UDSClient.app 150 180 \
    --app-drop-link 450 180 \
    UDSClient-4.0.0-Universal.dmg \
    dist-universal/
```

### 7.4 DMG Output

```
macos-build/dist/
├── UDSClient-4.0.0-arm64.dmg        # Apple Silicon
├── UDSClient-4.0.0-x86_64.dmg       # Intel
└── UDSClient-4.0.0-Universal.dmg   # Both architectures
```

---

## 6. Step 6 — Universal DMG (arm64 + x86_64)

**Build cả hai kiến trúc trên cùng một máy Mac (Apple Silicon)** và ghép lại bằng `lipo`.

### 6.1 Tại sao cần Universal?

| DMG | Apple Silicon Mac | Intel Mac |
|-----|-------------------|-----------|
| `arm64.dmg` | ✅ Chạy native | ❌ Không chạy |
| `x86_64.dmg` | ❌ Không chạy | ✅ Chạy native |
| `Universal.dmg` | ✅ Chạy native | ✅ Chạy native |

### 6.2 Tự động (Khuyến nghị)

```bash
# Chạy script hoàn chỉnh
chmod +x macos-build/build-universal-dmg.sh
./macos-build/build-universal-dmg.sh
```

Script sẽ tự động:
1. Cài Miniforge nếu chưa có (để có universal2 Python wheels)
2. Tạo 2 conda env riêng: `uds-arm64` và `uds-x86`
3. Build arm64 app bundle (conda env arm64)
4. Build x86_64 app bundle (conda env x86_64, qua Rosetta 2)
5. Ghép binary bằng `lipo`
6. Tạo DMG từ app bundle

### 6.3 Thủ công từng bước

#### Bước A: Cài Miniforge

```bash
# Miniforge cho phép cài Python arm64 và x86_64 trên cùng 1 máy
curl -fsSL https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-MacOSX-$(uname -m).sh -o /tmp/miniforge.sh
bash /tmp/miniforge.sh -b
rm /tmp/miniforge.sh

# Kích hoạt conda
source ~/miniforge3/etc/profile.d/conda.sh
export PATH="$HOME/miniforge3/bin:$PATH"
```

#### Bước B: Tạo conda environment cho từng arch

```bash
# Apple Silicon env
conda create -n uds-arm64 -c conda-forge python=3.11 pyside6 cryptography certifi psutil pyinstaller -y
conda activate uds-arm64
# Override subdir để lấy đúng arch packages
eval "$(conda shell.bash hook)"
conda activate uds-arm64
conda env config vars set -n uds-arm64 CONDA_SUBDIR=osx-arm64

# Intel env
conda create -n uds-x86 -c conda-forge python=3.11 pyside6 cryptography certifi psutil pyinstaller -y
conda activate uds-x86
conda env config vars set -n uds-x86 CONDA_SUBDIR=osx-64
```

#### Bước C: Build arm64

```bash
source ~/miniforge3/etc/profile.d/conda.sh
export PATH="$HOME/miniforge3/bin:$PATH"
eval "$(conda shell.bash hook)"
conda activate uds-arm64

cd uds-client/src
python -m PyInstaller ../macos-build/UDSClient-arm64.spec \
    --distpath ../macos-build/dist-arm64 \
    --workpath ../macos-build/build-arm64

# Copy Qt plugins
VENV_SITE=$(python -c "import site; print(site.getsitepackages()[0])")
for plugin_type in platforms styles imageformats iconengines; do
    mkdir -p "dist-arm64/UDSClient.app/Contents/Resources/qt_plugins/$plugin_type"
    cp -rn "$VENV_SITE/PySide6/plugins/$plugin_type/"* \
        "dist-arm64/UDSClient.app/Contents/Resources/qt_plugins/$plugin_type/" 2>/dev/null || true
done
echo '[Paths]
Plugins = Contents/Resources/qt_plugins' > dist-arm64/UDSClient.app/Contents/Resources/qt.conf
```

#### Bước D: Build x86_64

```bash
source ~/miniforge3/etc/profile.d/conda.sh
export PATH="$HOME/miniforge3/bin:$PATH"
eval "$(conda shell.bash hook)"
conda activate uds-x86

cd uds-client/src
python -m PyInstaller ../macos-build/UDSClient-x86_64.spec \
    --distpath ../macos-build/dist-x86_64 \
    --workpath ../macos-build/build-x86_64

# Copy Qt plugins (tương tự)
VENV_SITE=$(python -c "import site; print(site.getsitepackages()[0])")
for plugin_type in platforms styles imageformats iconengines; do
    mkdir -p "dist-x86_64/UDSClient.app/Contents/Resources/qt_plugins/$plugin_type"
    cp -rn "$VENV_SITE/PySide6/plugins/$plugin_type/"* \
        "dist-x86_64/UDSClient.app/Contents/Resources/qt_plugins/$plugin_type/" 2>/dev/null || true
done
echo '[Paths]
Plugins = Contents/Resources/qt_plugins' > dist-x86_64/UDSClient.app/Contents/Resources/qt.conf
```

#### Bước E: Ghép Universal Binary bằng `lipo`

```bash
# Copy arm64 bundle làm base
cp -r dist-arm64/UDSClient.app dist-universal/

# Ghép executable bằng lipo
lipo -create \
    dist-arm64/UDSClient.app/Contents/MacOS/UDSClient \
    dist-x86_64/UDSClient.app/Contents/MacOS/UDSClient \
    -output dist-universal/UDSClient.app/Contents/MacOS/UDSClient

# Ghép dylibs trong bundle
for arm_lib in dist-arm64/UDSClient.app/**/*.dylib; do
    rel="${arm_lib#dist-arm64/UDSClient.app/}"
    x86_lib="dist-x86_64/UDSClient.app/$rel"
    uni_lib="dist-universal/UDSClient.app/$rel"
    if [ -f "$x86_lib" ]; then
        lipo -create "$arm_lib" "$x86_lib" -output "$uni_lib" 2>/dev/null || true
    fi
done

# Xác minh
file dist-universal/UDSClient.app/Contents/MacOS/UDSClient
# Output: Mach-O universal binary with 2 architectures
```

#### Bước F: Tạo Universal DMG

```bash
create-dmg \
    --volname "UDSClient 4.0.0 Universal" \
    --window-pos 200 120 \
    --window-size 660 440 \
    --icon "UDSClient.app" 165 190 \
    --app-drop-link 490 190 \
    --hide-extension "UDSClient.app" \
    UDSClient-4.0.0-Universal.dmg \
    dist-universal/
```

### 6.4 Xóa Quarantine để chạy không cần Developer Account

```bash
# Gỡ quarantine attribute
xattr -d -r com.apple.quarantine dist-universal/UDSClient.app

# Hoặc từ DMG
hdiutil attach UDSClient-4.0.0-Universal.dmg -mountpoint /tmp/uds-dmg
xattr -d -r com.apple.quarantine /tmp/uds-dmg/UDSClient.app
hdiutil detach /tmp/uds-dmg
```

---

## 7. Step 7 — Code Signing & Notarization (Optional but Recommended)

Without code signing, macOS may show a "developer cannot be verified" warning.
With notarization, the app runs without any warnings.

### 8.1 Request Developer ID Certificate

1. Enroll in the [Apple Developer Program](https://developer.apple.com/programs/) (paid, $99/year).
2. In Xcode: **Xcode → Settings → Accounts → Manage Certificates → Developer ID Application**.

### 8.2 Create Entitlements File

```xml
<!-- UDSClient.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <false/>
</dict>
</plist>
```

### 8.3 Code Sign the App

```bash
# Sign the .app bundle
codesign --force --deep --sign "Developer ID Application: Your Name (TEAMID)" \
    --entitlements UDSClient.entitlements \
    --options runtime \
    dist/UDSClient.app

# Verify signature
codesign --verify --verbose=2 dist/UDSClient.app
spctl --assess --type exec --verbose=2 dist/UDSClient.app
```

### 8.4 Notarize the App (Required for Distribution)

```bash
# Create a zip for upload
hdiutil create -volname "UDSClient" -srcfolder dist/UDSClient.app -ov -format zulu UDSClient.zip

# Upload to Apple for notarization
xcrun notarytool submit UDSClient.zip \
    --apple-id "your@email.com" \
    --password "APP-SPECIFIC-PASSWORD" \
    --team-id "TEAMID" \
    --wait

# Staple the notarization ticket to the app
xcrun stapler staple dist/UDSClient.app

# Verify stapling
xcrun stapler validate dist/UDSClient.app
```

### 8.5 Code Sign the DMG

```bash
# Sign the DMG
codesign --force --sign "Developer ID Application: Your Name (TEAMID)" \
    dist/UDSClient-4.0.0-arm64.dmg

# Notarize the DMG
hdiutil create -volname "UDSClient 4.0.0" \
    -srcfolder dist/UDSClient.app \
    -ov -format UDZO \
    UDSClient-4.0.0-arm64-signed.dmg

# Or use create-dmg with --codesign flag
create-dmg --codesign \
    --volname "UDSClient 4.0.0" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon UDSClient.app 150 180 \
    --app-drop-link 450 180 \
    UDSClient-4.0.0-arm64.dmg \
    dist/
```

---

## Full Automated Build Script

Save this as `macos-build/build-macos.sh` and run it from the `client` directory:

```bash
#!/bin/bash
#==============================================================================
# build-macos.sh — Automated UDSClient macOS DMG build script
# Usage: ./macos-build/build-macos.sh [arm64|x86_64|universal]
# Example: ./macos-build/build-macos.sh arm64
#==============================================================================

set -euo pipefail

# Configuration
APP_NAME="UDSClient"
VERSION="4.0.0"
ARCH="${1:-arm64}"
BUILD_DIR="$(cd "$(dirname "$0")" && pwd)"
CLIENT_ROOT="$(dirname "$BUILD_DIR")"
SRC_DIR="$CLIENT_ROOT/src"

echo "=============================================="
echo " UDSClient macOS Build Script"
echo " Version : $VERSION"
echo " Arch    : $ARCH"
echo "=============================================="

# 1. Python venv
echo "[1/7] Setting up Python virtual environment..."
VENV_DIR="$BUILD_DIR/venv"
if [ ! -d "$VENV_DIR" ]; then
    python3.11 -m venv "$VENV_DIR"
fi
source "$VENV_DIR/bin/activate"
pip install --upgrade pip
pip install -r "$CLIENT_ROOT/requirements.txt"
pip install pyinstaller

# 2. Spec file
echo "[2/7] Creating PyInstaller spec file..."
cat > "$BUILD_DIR/UDSClient.spec" << 'SPECEOF'
# -*- mode: python ; coding: utf-8 -*-
import sys, os
from PyInstaller.utils.hooks import collect_data_files

datas = collect_data_files('PySide6', include_py_files=False)

hiddenimports = [
    'certifi', 'cryptography', 'psutil',
    'uds', 'uds.ui', 'uds.rest', 'uds.tunnel', 'uds.log',
    'uds.consts', 'uds.exceptions', 'uds.tools', 'uds.os_detector',
    'uds.net.udssock', 'uds.types',
    'UDSClient', 'UDSClientLauncher',
    'uds.ui.pyside6.UDSWindow', 'uds.ui.pyside6.UDSLauncherMac',
    'uds.ui.pyside6.UDSResources_rc',
]

a = Analysis(
    ['__SRC__/UDSClientLauncher.py'],
    pathex=[],
    binaries=[],
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=['tkinter', 'matplotlib', 'numpy', 'scipy', 'pandas'],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=None,
    noarchive=False,
    optimize=0,
)

pyz = PYZ(a.pure)

exe = EXE(
    pyz, a.scripts, a.binaries, a.datas, [],
    name='UDSClient',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=True,
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
        'CFBundleURLTypes': [
            {'CFBundleURLName': 'UDS Standard', 'CFBundleURLSchemes': ['uds']},
            {'CFBundleURLName': 'UDS Secure',  'CFBundleURLSchemes': ['udss']},
        ],
    },
    macos_module_content=[],
    force_kernel_extension=False,
    arch='__ARCH__',
)
SPECEOF

# Substitute placeholders
sed -i '' "s|__SRC__|$SRC_DIR|g" "$BUILD_DIR/UDSClient.spec"
sed -i '' "s|__VERSION__|$VERSION|g" "$BUILD_DIR/UDSClient.spec"
sed -i '' "s|__ARCH__|$ARCH|g" "$BUILD_DIR/UDSClient.spec"

# 3. PyInstaller
echo "[3/7] Running PyInstaller..."
cd "$SRC_DIR"
pyinstaller "$BUILD_DIR/UDSClient.spec" --noconfirm --distpath "$BUILD_DIR/dist-$ARCH"
APP_DIR="$BUILD_DIR/dist-$ARCH/UDSClient.app"

# 4. Fix Qt plugins
echo "[4/7] Copying Qt plugins..."
VENV_SITE=$(python -c "import site; print(site.getsitepackages()[0])")
PLUGINS_DIR="$APP_DIR/Contents/Resources/qt_plugins"
mkdir -p "$PLUGINS_DIR"

for plugin_type in platforms styles imageformats iconengines; do
    src="$VENV_SITE/PySide6/plugins/$plugin_type"
    dst="$PLUGINS_DIR/$plugin_type"
    if [ -d "$src" ]; then
        mkdir -p "$dst"
        cp -r "$src"/*.so "$dst/" 2>/dev/null || true
        cp -r "$src"/*.dylib "$dst/" 2>/dev/null || true
        cp -r "$src"/"$plugin_type"*.so "$dst/" 2>/dev/null || true
    fi
done

# 5. Verify
echo "[5/7] Verifying build..."
file "$APP_DIR/Contents/MacOS/UDSClient"

# 6. Create DMG
echo "[6/7] Creating DMG..."
cd "$BUILD_DIR"
DMG_NAME="UDSClient-$VERSION-$ARCH.dmg"
create-dmg \
    --volname "UDSClient $VERSION" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon UDSClient.app 150 180 \
    --app-drop-link 450 180 \
    --hide-extension UDSClient.app \
    "$DMG_NAME" \
    "dist-$ARCH/"

echo "[7/7] Build complete!"
echo ""
echo " Output:"
echo "   App bundle : $APP_DIR"
echo "   DMG file   : $BUILD_DIR/$DMG_NAME"
echo ""
echo " Next steps:"
echo "   1. Code sign: codesign --force --deep --sign 'Developer ID' $APP_DIR"
echo "   2. Notarize:  xcrun notarytool submit $DMG_NAME --apple-id 'email' --password 'pwd' --team-id 'ID' --wait"
echo "   3. Staple:   xcrun stapler staple $APP_DIR"
echo ""
```

### Run the Build Script

```bash
# Make it executable
chmod +x macos-build/build-macos.sh

# Build for Apple Silicon
./macos-build/build-macos.sh arm64

# Build for Intel
./macos-build/build-macos.sh x86_64

# Build Universal (run both, then combine)
# See Section 7.3 for combining instructions
```

---

## Troubleshooting

### Q: `ModuleNotFoundError: No module named 'certifi'`

**Cause:** `certifi` is a hidden import that PyInstaller doesn't detect.

**Fix:** Add `'certifi'` to `hiddenimports` in the spec file. The spec above already includes this.

---

### Q: App launches but URL scheme `uds://` doesn't work

**Cause:** `argv_emulation=True` is missing from the spec, or `Info.plist` doesn't declare the URL scheme.

**Fix:** Ensure `Info.plist` contains `CFBundleURLTypes` (see spec above) and `argv_emulation=True` is set in the `EXE` block.

---

### Q: `ImportError: Qt platform plugin "xcb"` error on launch

**Cause:** Qt is trying to use an X11 plugin on macOS.

**Fix:** Set environment variable in app or Info.plist:
```xml
<key>QT_QPA_PLATFORM</key>
<string>cocoa</string>
```

---

### Q: `RuntimeError: Failed to load platform plugin 'cocoa'`

**Cause:** Qt plugins (platforms) are not bundled inside the `.app`.

**Fix:** Run the post-build Qt plugin copy script (Section 6.3).

---

### Q: Build fails with `PermissionError: [Errno 13] Permission denied` on `create-dmg`

**Cause:** The output DMG file already exists and is mounted/locked.

**Fix:** Unmount any existing DMG and remove the file:
```bash
hdiutil detach "/Volumes/UDSClient 4.0.0" 2>/dev/null || true
rm -f UDSClient-4.0.0-arm64.dmg
```

---

### Q: How to do a Universal build (arm64 + x86_64)?

**Option A — Run on Apple Silicon Mac with Rosetta:**
```bash
# Build x86_64 using Rosetta
arch -x86_64 /usr/bin/python3.11 -m venv venv-x86
arch -x86_64 ./venv-x86/bin/pip install -r requirements.txt
arch -x86_64 ./venv-x86/bin/pip install pyinstaller
arch -x86_64 ./venv-x86/bin/pyinstaller ... (target_arch='x86_64')
```

**Option B — Use GitHub Actions with macOS runners:**
See the CI/CD workflow in `macos-build/.github/workflows/build-macos.yml` (create this file for automated cross-architecture builds).

---

### Q: How to verify the .dmg works before distribution?

```bash
# Mount the DMG
open UDSClient-4.0.0-arm64.dmg

# Drag the .app to Applications
cp -r "/Volumes/UDSClient 4.0.0/UDSClient.app" /Applications/

# Launch and check logs
"/Applications/UDSClient.app/Contents/MacOS/UDSClient" --test

# Unmount
hdiutil detach "/Volumes/UDSClient 4.0.0"
```
