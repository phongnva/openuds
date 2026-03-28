#!/bin/bash
#==============================================================================
# build-universal-dmg.sh — Build FSOFT Virtual Desktop Client Universal DMG
#
# Build cả hai arch (arm64 + x86_64) và tạo Universal DMG trên cùng một máy Mac.
# KHÔNG cần Apple Developer Account.
#
# CÁCH SỬ DỤNG:
#   ./build-universal-dmg.sh               # Build cả hai arch → Universal DMG
#   ./build-universal-dmg.sh arm64         # Chỉ build arm64
#   ./build-universal-dmg.sh x86_64        # Chỉ build x86_64 (cần Rosetta 2)
#   ./build-universal-dmg.sh icons         # Chỉ setup icon (không build)
#   ./build-universal-dmg.sh clean         # Dọn build artifacts
#
# YÊU CẦU:
#   - macOS 12+ (Monterey or later)
#   - Apple Silicon (M1/M2/M3/M4) hoặc Intel Mac
#   - Xcode Command Line Tools: xcode-select --install
#   - Homebrew: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
#
# OUTPUT:
#   macos-build/dist-universal/FSOFTClient.app/
#   macos-build/FSOFTClient-4.0.0-Universal.dmg
#==============================================================================

set -euo pipefail

# ============================================================
# CẤU HÌNH APP
# ============================================================
# ── TÊN APP (đổi tại đây nếu cần) ──
APP_DISPLAY_NAME="FSOFT Virtual Desktop Client"
APP_BUNDLE_NAME="FSOFT Virtual Desktop Client"
APP_EXECUTABLE="FSOFTClient"
APP_BUNDLE_ID="com.fsoft.virtualdesktop.client"
VERSION="4.0.0"

# Logo (đặt trong thư mục icons/)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ICONS_DIR="$SCRIPT_DIR/icons"
FSOFT_ICNS="$ICONS_DIR/FSOFTClient.icns"
LOGO_FALLBACK="$ICONS_DIR/app-logo.png"

# URL Schemes mà app handle
URL_SCHEMES='["uds", "udss"]'

BUILD_DIR="$SCRIPT_DIR"
CLIENT_ROOT="$(dirname "$BUILD_DIR")"
SRC_DIR="$CLIENT_ROOT/src"

# ── Detect host arch ──
HOST_ARCH=$(uname -m)   # arm64 or x86_64
IS_ARM_MAC=false
[ "$HOST_ARCH" = "arm64" ] && IS_ARM_MAC=true

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

log()    { echo -e "${GREEN}[BUILD]${NC}  $1"; }
info()   { echo -e "${BLUE}[INFO]${NC}   $1"; }
warn()   { echo -e "${YELLOW}[WARN]${NC}  $1"; }
err()    { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
step()   { echo -e "\n${BOLD}${GREEN}[STEP]${NC} $1${NC}"; }

# ============================================================
# BANNER
# ============================================================
show_banner() {
    echo ""
    echo -e "${BOLD}============================================${NC}"
    echo -e "${BOLD}  ${APP_DISPLAY_NAME}${NC}"
    echo -e "${BOLD}  Universal DMG Builder${NC}"
    echo -e "${BOLD}  Version : ${VERSION}${NC}"
    echo -e "${BOLD}  Host    : ${HOST_ARCH}${NC}"
    echo -e "${BOLD}============================================${NC}"
    echo ""
}

# ============================================================
# KIỂM TRA HỆ THỐNG
# ============================================================
check_system() {
    step "Kiểm tra hệ thống..."

    # macOS version
    MACOS_VER=$(sw_vers -productVersion 2>/dev/null || echo "unknown")
    if [ "$MACOS_VER" = "unknown" ]; then
        warn "Không phải macOS — một số bước có thể bị bỏ qua"
    else
        MACOS_MAJOR=$(echo "$MACOS_VER" | cut -d. -f1)
        [ "${MACOS_MAJOR:-0}" -lt 12 ] && warn "Khuyến nghị macOS 12+"
        info "macOS: $MACOS_VER ($HOST_ARCH)"
    fi

    # Xcode CLI tools
    if command -v xcode-select &>/dev/null; then
        if xcode-select -p &>/dev/null; then
            info "Xcode CLI: OK"
        fi
    fi

    # Homebrew
    if command -v brew &>/dev/null; then
        info "Homebrew: $(brew --version | head -1)"
    fi

    # create-dmg
    if command -v create-dmg &>/dev/null; then
        info "create-dmg: OK"
    else
        warn "create-dmg chưa cài"
        if command -v brew &>/dev/null; then
            info "Cài create-dmg..."
            brew install create-dmg
        fi
    fi

    # Miniforge
    if [ -f "$HOME/miniforge3/etc/profile.d/conda.sh" ]; then
        info "Miniforge: OK ($HOME/miniforge3)"
        HAS_CONDA=true
    elif [ -f "/opt/miniforge3/etc/profile.d/conda.sh" ]; then
        info "Miniforge: OK (/opt/miniforge3)"
        export HOME=/Users/$(whoami)
        HAS_CONDA=true
    else
        warn "Miniforge chưa cài. Sẽ cài tự động."
        HAS_CONDA=false
    fi

    # Rosetta 2 on Apple Silicon
    if [ "$IS_ARM_MAC" = true ]; then
        if [ -f "/Library/Apple/System/Library/Receipts/com.apple.pkg.RosettaUpdateAuto.pkg" ] || \
           pgrep -q oahd 2>/dev/null; then
            info "Rosetta 2: Đã cài"
        else
            info "Rosetta 2: Sẽ cài tự động khi cần x86_64 build"
        fi
    fi
}

# ============================================================
# CÀI ĐẶT MINIFORGE
# ============================================================
install_miniforge() {
    step "Cài đặt Miniforge..."

    local miniforge_path="$HOME/miniforge3"
    local arch_suffix
    arch_suffix=$(uname -m)
    local url="https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-MacOSX-${arch_suffix}.sh"
    local script="/tmp/miniforge-$$.sh"

    if [ -f "$miniforge_path/etc/profile.d/conda.sh" ]; then
        info "Miniforge đã tồn tại"
        return 0
    fi

    info "Tải Miniforge..."
    curl -fsSL "$url" -o "$script" || \
    curl -fsSL "https://github.com/conda-forge/miniforge/releases/download/24.7.1-0/Miniforge3-MacOSX-${arch_suffix}.sh" -o "$script"

    bash "$script" -b -p "$miniforge_path"
    rm -f "$script"

    info "Miniforge cài tại: $miniforge_path"

    # Initialize conda
    source "$miniforge_path/etc/profile.d/conda.sh"
}

# ============================================================
# CONDA ENV
# ============================================================
setup_conda_env() {
    local env_name="$1"
    local arch="$2"
    local subdir="$3"

    step "Setup conda env: $env_name (arch=$arch, subdir=$subdir)"

    source "$HOME/miniforge3/etc/profile.d/conda.sh"
    export PATH="$HOME/miniforge3/bin:$PATH"

    # Remove if exists
    if conda env list 2>/dev/null | grep -q "^$env_name "; then
        info "Removing existing env: $env_name"
        conda env remove -n "$env_name" -y 2>/dev/null || true
    fi

    # Create env
    log "Creating conda env..."
    conda create \
        -n "$env_name" \
        -c conda-forge \
        python=3.11 \
        --override-channels \
        -y \
        2>&1 | grep -v "^$" | tail -5

    # Install packages in the env
    local env_python="$HOME/miniforge3/envs/$env_name/bin/python"
    local env_pip="$HOME/miniforge3/envs/$env_name/bin/pip"

    info "Installing packages..."
    $env_pip install --upgrade pip wheel setuptools 2>&1 | tail -3

    $env_pip install \
        pyside6 \
        cryptography \
        certifi \
        psutil \
        pyinstaller \
        2>&1 | tail -5

    info "Env '$env_name' sẵn sàng"
}

# ============================================================
# SETUP ICON
# ============================================================
setup_icon() {
    step "Setup App Icon..."

    # Check if .icns already exists
    if [ -f "$FSOFT_ICNS" ] && [ -s "$FSOFT_ICNS" ]; then
        info "Icon đã tồn tại: $FSOFT_ICNS ($(du -h "$FSOFT_ICNS" | cut -f1))"
        return 0
    fi

    # Check if iconset exists
    local iconset="$ICONS_DIR/iconset"
    if [ -d "$iconset" ] && [ "$(ls -A "$iconset" 2>/dev/null | wc -l)" -gt 5 ]; then
        info "Iconset đã tồn tại, convert sang .icns..."
        if command -v iconutil &>/dev/null; then
            iconutil -c icns "$iconset" -o "$FSOFT_ICNS" 2>/dev/null && \
                info "✓ iconutil tạo FSOFTClient.icns" || true
        fi
    fi

    if [ -f "$FSOFT_ICNS" ] && [ -s "$FSOFT_ICNS" ]; then
        return 0
    fi

    # Download logo if not exists
    if [ ! -f "$LOGO_FALLBACK" ] || [ ! -s "$LOGO_FALLBACK" ]; then
        warn "Logo không tồn tại, tải..."
        mkdir -p "$ICONS_DIR"
        curl -fsSL \
            "https://quisitive.com/wp-content/uploads/2021/09/chsimmons_AVD_Install_4-472x315-1.png" \
            -o "$LOGO_FALLBACK" 2>/dev/null || true
    fi

    if [ -f "$LOGO_FALLBACK" ] && [ -s "$LOGO_FALLBACK" ]; then
        info "Logo: $LOGO_FALLBACK"
        file "$LOGO_FALLBACK" | head -1

        # Try python script on macOS
        if command -v python3 &>/dev/null && [ -f "$SCRIPT_DIR/icons/create-icns.py" ]; then
            info "Chạy create-icns.py..."
            python3 "$SCRIPT_DIR/icons/create-icns.py" \
                "$LOGO_FALLBACK" "$FSOFT_ICNS" 16 32 64 128 256 512 1024 2>/dev/null || true
        fi

        # Try setup-icon.sh
        if [ -f "$SCRIPT_DIR/icons/setup-icon.sh" ]; then
            info "Chạy setup-icon.sh..."
            bash "$SCRIPT_DIR/icons/setup-icon.sh" "$LOGO_FALLBACK" 2>/dev/null || true
        fi
    fi

    if [ -f "$FSOFT_ICNS" ] && [ -s "$FSOFT_ICNS" ]; then
        info "✓ Icon sẵn sàng: $FSOFT_ICNS"
    else
        warn "Icon chưa tạo được — chạy trên macOS để tạo icon"
        warn "  Hoặc: brew install imagemagick && ./icons/setup-icon.sh"
    fi
}

# ============================================================
# TẠO SPEC FILE
# ============================================================
create_spec() {
    local arch="$1"
    local spec_file="$2"

    cat > "$spec_file" << SPECEOF
# -*- mode: python ; coding: utf-8 -*-
import os, sys
from PyInstaller.utils.hooks import collect_data_files

# Collect PySide6 data files
datas = collect_data_files('PySide6', include_py_files=False)

# Collect uds package
src_dir = '$SRC_DIR'
if os.path.exists(src_dir):
    for root, dirs, files in os.walk(src_dir):
        for f in files:
            if f.endswith('.py'):
                datas.append((os.path.join(root, f), os.path.join('uds', os.path.relpath(root, src_dir))))

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
    ['$SRC_DIR/UDSClientLauncher.py'],
    pathex=[],
    binaries=[],
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        'tkinter', 'matplotlib', 'numpy', 'scipy', 'pandas',
        'PIL', 'Pillow',
    ],
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
    name='$APP_EXECUTABLE',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=True,
    target_arch='$arch',
    codesign_identity=None,
    entitlements_file=None,
)

app = BUNDLE(
    exe,
    name='$APP_BUNDLE_NAME.app',
    info_plist={
        'CFBundleName': '$APP_BUNDLE_NAME',
        'CFBundleDisplayName': '$APP_DISPLAY_NAME',
        'CFBundleIdentifier': '$APP_BUNDLE_ID',
        'CFBundleVersion': '$VERSION',
        'CFBundleShortVersionString': '$VERSION',
        'CFBundlePackageType': 'APPL',
        'CFBundleExecutable': '$APP_EXECUTABLE',
        'LSMinimumSystemVersion': '12.0',
        'LSApplicationCategoryType': 'public.app-category.productivity',
        'NSHighResolutionCapable': True,
        'NSPrincipalClass': 'NSApplication',
        'CFBundleIconFile': 'FSOFTClient.icns',
        # URL Schemes — handles uds:// and udss://
        'CFBundleURLTypes': [
            {'CFBundleURLName': 'UDS Standard', 'CFBundleURLSchemes': ['uds']},
            {'CFBundleURLName': 'UDS Secure',   'CFBundleURLSchemes': ['udss']},
        ],
        # Qt settings
        'QT_QPA_PLATFORM': 'cocoa',
        # Network access
        'NSAppTransportSecurity': {
            'NSAllowsArbitraryLoads': True,
        },
        # Bundle info
        'LSMinimumSystemVersion': '12.0',
        'NSSupportsAutomaticTermination': False,
        'NSSupportsSuddenTermination': False,
    },
    macos_module_content=[],
    force_kernel_extension=False,
    arch='$arch',
)
SPECEOF

    info "Spec: $spec_file"
}

# ============================================================
# COPY QT PLUGINS
# ============================================================
copy_qt_plugins() {
    local app_dir="$1"
    local conda_env="$2"

    log "Copy Qt plugins..."

    # Find site-packages from conda env
    local env_site="$HOME/miniforge3/envs/$conda_env/lib/python3.11/site-packages"
    [ ! -d "$env_site" ] && env_site=$(python3 -c "import site; print(site.getsitepackages()[0])" 2>/dev/null) || true

    local plugins_dir="$app_dir/Contents/Resources/qt_plugins"
    mkdir -p "$plugins_dir"

    for plugin_type in platforms styles imageformats iconengines; do
        local src="$env_site/PySide6/plugins/$plugin_type"
        local dst="$plugins_dir/$plugin_type"

        if [ -d "$src" ]; then
            mkdir -p "$dst"
            # Copy all files
            cp -rn "$src/"* "$dst/" 2>/dev/null || true
            local count=$(ls "$dst" 2>/dev/null | wc -l | tr -d ' ')
            info "  $plugin_type: $count files"
        else
            warn "  $plugin_type: not found"
        fi
    done

    # Write qt.conf
    cat > "$app_dir/Contents/Resources/qt.conf" << 'QTEOF'
[Paths]
Plugins = Contents/Resources/qt_plugins
QtPlugins = Contents/Resources/qt_plugins
QTEOF
    info "qt.conf written"
}

# ============================================================
# COPY ICON INTO APP BUNDLE
# ============================================================
copy_icon_to_bundle() {
    local app_dir="$1"

    log "Copy icon vào app bundle..."

    if [ -f "$FSOFT_ICNS" ] && [ -s "$FSOFT_ICNS" ]; then
        local dest="$app_dir/Contents/Resources/FSOFTClient.icns"
        cp "$FSOFT_ICNS" "$dest"
        info "  ✓ FSOFTClient.icns → Contents/Resources/"
    else
        warn "  FSOFTClient.icns không tìm thấy — bỏ qua icon"
        warn "  Tạo icon bằng: ./icons/setup-icon.sh"
    fi
}

# ============================================================
# BUILD MỘT ARCH
# ============================================================
build_arch() {
    local target_arch="$1"
    local conda_env="$2"

    step "========== BUILD $target_arch =========="

    local dist_dir="$BUILD_DIR/dist-$target_arch"
    local build_dir="$BUILD_DIR/build-$target_arch"
    local spec_file="$BUILD_DIR/FSOFTClient-$target_arch.spec"

    rm -rf "$dist_dir" "$build_dir" "$spec_file"

    # Activate conda
    source "$HOME/miniforge3/etc/profile.d/conda.sh"
    export PATH="$HOME/miniforge3/bin:$PATH"
    eval "$(conda shell.bash hook)"
    conda activate "$conda_env" 2>/dev/null || true

    # Verify python arch
    local py_arch=$(python3 -c 'import struct; print(struct.calcsize("P") * 8)' 2>/dev/null || echo "unknown")
    log "Python arch: ${py_arch}bit (target: $target_arch)"

    # Generate spec
    create_spec "$target_arch" "$spec_file"

    # Run PyInstaller
    log "Running PyInstaller..."
    cd "$SRC_DIR"
    python3 -m PyInstaller \
        "$spec_file" \
        --noconfirm \
        --distpath "$dist_dir" \
        --workpath "$build_dir" \
        --specpath "$BUILD_DIR" \
        2>&1 | grep -E '(^(WARNING|ERROR|\s))' | tail -10 || true

    # Fallback if no output
    if [ ! -d "$dist_dir/$APP_BUNDLE_NAME.app" ]; then
        log "Retry PyInstaller without filter..."
        cd "$SRC_DIR"
        python3 -m PyInstaller \
            "$spec_file" \
            --noconfirm \
            --distpath "$dist_dir" \
            --workpath "$build_dir" \
            --specpath "$BUILD_DIR" \
            2>&1 | tail -20
    fi

    local app_dir="$dist_dir/$APP_BUNDLE_NAME.app"
    if [ ! -d "$app_dir" ]; then
        err "Build thất bại: $app_dir không tồn tại"
    fi

    # Copy Qt plugins
    copy_qt_plugins "$app_dir" "$conda_env"

    # Copy icon
    copy_icon_to_bundle "$app_dir"

    # Verify executable
    local exe="$app_dir/Contents/MacOS/$APP_EXECUTABLE"
    if [ -f "$exe" ]; then
        log "Binary: $(file "$exe")"
    else
        # Try UDSClient as fallback
        if [ -f "$app_dir/Contents/MacOS/UDSClient" ]; then
            mv "$app_dir/Contents/MacOS/UDSClient" "$exe"
            log "Renamed executable to $APP_EXECUTABLE"
        fi
    fi

    info "Build $target_arch hoàn tất: $app_dir"
}

# ============================================================
# GHÉP UNIVERSAL BINARY
# ============================================================
combine_universal() {
    step "========== GHÉP UNIVERSAL BINARY =========="

    local dist_arm="$BUILD_DIR/dist-arm64"
    local dist_x86="$BUILD_DIR/dist-x86_64"
    local dist_uni="$BUILD_DIR/dist-universal"

    [ ! -d "$dist_arm" ] && err "arm64 build không tồn tại"
    [ ! -d "$dist_x86" ] && err "x86_64 build không tồn tại"

    # Copy arm64 as base
    rm -rf "$dist_uni"
    cp -r "$dist_arm" "$dist_uni"

    local arm_exe="$dist_arm/$APP_BUNDLE_NAME.app/Contents/MacOS/$APP_EXECUTABLE"
    local x86_exe="$dist_x86/$APP_BUNDLE_NAME.app/Contents/MacOS/$APP_EXECUTABLE"
    local uni_exe="$dist_uni/$APP_BUNDLE_NAME.app/Contents/MacOS/$APP_EXECUTABLE"

    if [ ! -f "$arm_exe" ]; then
        arm_exe="$dist_arm/$APP_BUNDLE_NAME.app/Contents/MacOS/UDSClient"
    fi
    if [ ! -f "$x86_exe" ]; then
        x86_exe="$dist_x86/$APP_BUNDLE_NAME.app/Contents/MacOS/UDSClient"
    fi

    [ ! -f "$arm_exe" ] && err "arm64 executable không tìm thấy: $arm_exe"
    [ ! -f "$x86_exe" ] && err "x86_64 executable không tìm thấy: $x86_exe"

    log "Ghép executables bằng lipo..."
    lipo -create "$arm_exe" "$x86_exe" -output "$uni_exe"
    log "Binary: $(file "$uni_exe")"

    # Ghép dylibs
    log "Ghép dylibs..."
    find "$dist_arm/$APP_BUNDLE_NAME.app" -name "*.dylib" -type f 2>/dev/null | while read -r arm_lib; do
        local rel="${arm_lib#$dist_arm/$APP_BUNDLE_NAME.app/}"
        local x86_lib="$dist_x86/$APP_BUNDLE_NAME.app/$rel"
        local uni_lib="$dist_uni/$APP_BUNDLE_NAME.app/$rel"
        if [ -f "$x86_lib" ]; then
            lipo -create "$arm_lib" "$x86_lib" -output "$uni_lib" 2>/dev/null || true
        fi
    done

    # Ghép .so files
    find "$dist_arm/$APP_BUNDLE_NAME.app" -name "*.so" -type f 2>/dev/null | while read -r arm_so; do
        local rel="${arm_so#$dist_arm/$APP_BUNDLE_NAME.app/}"
        local x86_so="$dist_x86/$APP_BUNDLE_NAME.app/$rel"
        local uni_so="$dist_uni/$APP_BUNDLE_NAME.app/$rel"
        if [ -f "$x86_so" ]; then
            lipo -create "$arm_so" "$x86_so" -output "$uni_so" 2>/dev/null || true
        fi
    done

    info "Universal ghép thành công!"
}

# ============================================================
# TẠO DMG
# ============================================================
create_dmg() {
    local app_path="$1"   # e.g. dist-universal/FSOFT Virtual Desktop Client.app
    local dmg_name="$2"   # e.g. FSOFTClient-4.0.0-Universal.dmg
    local vol_name="$3"   # e.g. "FSOFT Virtual Desktop Client 4.0.0"

    step "========== TẠO DMG: $dmg_name =========="

    # Resolve full path
    local app_dir="$BUILD_DIR/$app_path"
    local dmg_path="$BUILD_DIR/$dmg_name"
    local containing_dir="$(dirname "$app_dir")"
    local base_name="$(basename "$app_path")"

    [ ! -d "$app_dir" ] && err "App bundle không tồn tại: $app_dir"

    # Unmount old volume
    hdiutil detach "/Volumes/$vol_name" 2>/dev/null || true
    rm -f "$dmg_path"

    log "App bundle: $app_dir"

    # Check/create-dmg availability
    if ! command -v create-dmg &>/dev/null; then
        warn "create-dmg không có — dùng hdiutil"
        create_dmg_hdiutil "$app_dir" "$dmg_path" "$vol_name"
        return
    fi

    # Try create-dmg with custom icon if available
    local volicon_arg=""
    if [ -f "$FSOFT_ICNS" ] && [ -s "$FSOFT_ICNS" ]; then
        volicon_arg="--volicon $FSOFT_ICNS"
    fi

    create-dmg \
        --volname "$vol_name" \
        $volicon_arg \
        --window-pos 200 120 \
        --window-size 680 460 \
        --icon-size 120 \
        --icon "$base_name" 170 195 \
        --app-drop-link 500 195 \
        --hide-extension "$base_name" \
        --eula "" \
        --no-internet-enable \
        "$dmg_path" \
        "$containing_dir/" 2>&1 | tail -10

    # Fallback to hdiutil if create-dmg fails
    if [ ! -f "$dmg_path" ] || [ ! -s "$dmg_path" ]; then
        warn "create-dmg thất bại, dùng hdiutil..."
        create_dmg_hdiutil "$app_dir" "$dmg_path" "$vol_name"
    fi

    if [ -f "$dmg_path" ] && [ -s "$dmg_path" ]; then
        info "✓ DMG: $dmg_path ($(du -h "$dmg_path" | cut -f1))"
    fi
}

create_dmg_hdiutil() {
    local app_dir="$1"
    local dmg_path="$2"
    local vol_name="$3"

    hdiutil create \
        -volname "$vol_name" \
        -srcfolder "$app_dir" \
        -ov \
        -format UDZO \
        -imagekey zlib-level=9 \
        "$dmg_path" 2>&1 | grep -v "^$"
}

# ============================================================
# GỠ QUARANTINE (cho phép chạy không Developer Account)
# ============================================================
remove_quarantine() {
    local dmg_path="$1"
    local app_path="$2"

    step "Gỡ quarantine..."

    # Gỡ từ app bundle
    if [ -d "$BUILD_DIR/$app_path" ]; then
        xattr -cr "$BUILD_DIR/$app_path" 2>/dev/null || true
    fi

    # Gỡ từ DMG đã mount
    for vol in /Volumes/*; do
        if [ -d "$vol/$APP_BUNDLE_NAME.app" ]; then
            xattr -cr "$vol/$APP_BUNDLE_NAME.app" 2>/dev/null || true
        fi
    done

    info "Done"
}

# ============================================================
# CLEAN
# ============================================================
do_clean() {
    step "Dọn artifacts..."
    rm -rf \
        "$BUILD_DIR/dist-arm64" \
        "$BUILD_DIR/dist-x86_64" \
        "$BUILD_DIR/dist-universal" \
        "$BUILD_DIR/build-arm64" \
        "$BUILD_DIR/build-x86_64" \
        "$BUILD_DIR/FSOFTClient-arm64.spec" \
        "$BUILD_DIR/FSOFTClient-x86_64.spec" \
        "$BUILD_DIR/FSOFTClient.spec" \
        "$BUILD_DIR/UDSClient-arm64.spec" \
        "$BUILD_DIR/UDSClient-x86_64.spec" \
        "$BUILD_DIR/UDSClient.spec" \
        "$BUILD_DIR"/*.dmg \
        "$BUILD_DIR"/FSOFTClient-*.dmg \
        "$BUILD_DIR"/UDSClient-*.dmg
    info "Đã dọn xong"
}

# ============================================================
# HƯỚNG DẪN CÀI ĐẶT (không cần Developer Account)
# ============================================================
show_install_guide() {
    echo ""
    echo -e "${BOLD}============================================${NC}"
    echo -e "${BOLD}  CÀI ĐẶT TRÊN MÁY KHÁC (không cần Dev Account)${NC}"
    echo -e "${BOLD}============================================${NC}"
    echo ""
    echo -e "  DMG ${GREEN}KHÔNG signed${NC} — macOS sẽ hiển thị cảnh báo:"
    echo ""
    echo -e "  CÁCH 1 — GUI (đơn giản):"
    echo -e "  1. Mở Finder → Applications"
    echo -e "  2. Kéo ${APP_DISPLAY_NAME}.app vào"
    echo -e "  3. Double-click app → cảnh báo 'developer cannot be verified'"
    echo -e "  4. System Settings → Privacy & Security → cuộn xuống"
    echo -e "  5. Click 'Open Anyway' → nhập password"
    echo ""
    echo -e "  CÁCH 2 — Terminal:"
    echo "     xattr -d -r com.apple.quarantine ~/Applications/\"$APP_BUNDLE_NAME.app\""
    echo "     open ~/Applications/\"$APP_BUNDLE_NAME.app\""
    echo ""
    echo -e "  CÁCH 3 — Tắt Gatekeeper tạm (không khuyến khích):"
    echo "     sudo spctl --master-disable"
    echo "     # Sau khi cài xong: sudo spctl --master-enable"
    echo ""
    echo -e "  ⚠ LƯU Ý QUAN TRỌNG:"
    echo -e "  - App chạy OK sau khi 'Open Anyway'"
    echo -e "  - Mỗi máy cần làm 1 lần"
    echo -e "  - Để phân phối rộng rãi → cần Apple Developer Account ($99/năm)"
    echo ""
}

# ============================================================
# MAIN
# ============================================================
main() {
    local TARGET="${1:-all}"

    show_banner

    # ── Command: clean ──
    if [ "$TARGET" = "clean" ]; then
        do_clean
        exit 0
    fi

    # ── Command: icons ──
    if [ "$TARGET" = "icons" ]; then
        setup_icon
        exit 0
    fi

    # ── Validate target ──
    if [[ ! "$TARGET" =~ ^(all|arm64|x86_64|universal)$ ]]; then
        err "Usage: $0 [all|arm64|x86_64|universal|icons|clean]"
    fi

    # ── Step 0: System check ──
    check_system

    # ── Step 1: Miniforge ──
    if [ "$HAS_CONDA" = false ]; then
        install_miniforge
    fi

    if [ ! -f "$HOME/miniforge3/etc/profile.d/conda.sh" ]; then
        err "Miniforge chưa được cài đặt"
    fi

    # ── Step 2: Icon ──
    setup_icon

    # ── Step 3: Conda environments ──
    step "========== SETUP CONDA ENVIRONMENTS =========="

    if [ "$TARGET" = "all" ] || [ "$TARGET" = "universal" ]; then
        setup_conda_env "fsoft-arm64" "arm64"   "osx-arm64"
        setup_conda_env "fsoft-x86"   "x86_64" "osx-64"
    elif [ "$TARGET" = "arm64" ]; then
        setup_conda_env "fsoft-arm64" "arm64" "osx-arm64"
    elif [ "$TARGET" = "x86_64" ]; then
        setup_conda_env "fsoft-x86"   "x86_64" "osx-64"
    fi

    # ── Step 4: Build ──
    if [ "$TARGET" = "all" ] || [ "$TARGET" = "universal" ]; then
        build_arch "arm64"   "fsoft-arm64"
        build_arch "x86_64"  "fsoft-x86"
        combine_universal

        create_dmg "dist-universal/$APP_BUNDLE_NAME.app" \
            "FSOFTClient-$VERSION-Universal.dmg" \
            "$APP_DISPLAY_NAME $VERSION"

        remove_quarantine \
            "$BUILD_DIR/FSOFTClient-$VERSION-Universal.dmg" \
            "dist-universal/$APP_BUNDLE_NAME.app"

    elif [ "$TARGET" = "arm64" ]; then
        build_arch "arm64" "fsoft-arm64"
        create_dmg "dist-arm64/$APP_BUNDLE_NAME.app" \
            "FSOFTClient-$VERSION-arm64.dmg" \
            "$APP_DISPLAY_NAME $VERSION arm64"
        remove_quarantine \
            "$BUILD_DIR/FSOFTClient-$VERSION-arm64.dmg" \
            "dist-arm64/$APP_BUNDLE_NAME.app"

    elif [ "$TARGET" = "x86_64" ]; then
        build_arch "x86_64" "fsoft-x86"
        create_dmg "dist-x86_64/$APP_BUNDLE_NAME.app" \
            "FSOFTClient-$VERSION-x86_64.dmg" \
            "$APP_DISPLAY_NAME $VERSION x86_64"
        remove_quarantine \
            "$BUILD_DIR/FSOFTClient-$VERSION-x86_64.dmg" \
            "dist-x86_64/$APP_BUNDLE_NAME.app"
    fi

    # ── Step 5: Summary ──
    step "========== HOÀN TẤT =========="
    echo ""
    echo -e "  ${GREEN}✓ BUILD THÀNH CÔNG${NC}"
    echo ""
    echo -e "  ${BOLD}Output files:${NC}"
    ls -lh "$BUILD_DIR"/FSOFTClient-*.dmg 2>/dev/null || echo "  (DMG files)"
    ls -d "$BUILD_DIR"/dist-*/"$APP_BUNDLE_NAME.app" 2>/dev/null | while read -r d; do
        echo -e "  $d"
    done
    echo ""
    echo -e "  ${BOLD}Icon used:${NC} ${FSOFT_ICNS}"
    [ -f "$FSOFT_ICNS" ] && ls -lh "$FSOFT_ICNS" || echo "  (icon file)"
    echo ""

    show_install_guide
}

main "$@"
