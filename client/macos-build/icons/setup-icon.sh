#!/bin/bash
#==============================================================================
# setup-icon.sh — Tải logo, tạo iconset và file .icns trên macOS
#
# Chạy TRƯỚC build-universal-dmg.sh (hoặc chạy cùng, nó tự gọi)
#
# Usage:
#   ./setup-icon.sh                    # Tải logo mặc định
#   ./setup-icon.sh /path/to/logo.png  # Dùng logo tùy chỉnh
#==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ICONS_DIR="$SCRIPT_DIR"
LOGO_URL="https://quisitive.com/wp-content/uploads/2021/09/chsimmons_AVD_Install_4-472x315-1.png"
LOGO_PNG="${1:-$ICONS_DIR/app-logo.png}"
FSOFT_ICNS="$ICONS_DIR/FSOFTClient.icns"
APP_DISPLAY_NAME="FSOFT Virtual Desktop Client"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log() { echo -e "${GREEN}[ICON]${NC}  $1"; }
warn() { echo -e "${YELLOW}[ICON]${NC}  $1"; }
err() { echo -e "${RED}[ICON]${NC}  $1"; exit 1; }

echo ""
echo "========================================"
echo "  FSOFT Client — Icon Setup"
echo "========================================"

# ── Step 1: Download logo ──────────────────────────────────────────────────
if [ -f "$LOGO_PNG" ]; then
    log "Logo đã tồn tại: $LOGO_PNG"
else
    log "Tải logo từ $LOGO_URL..."
    curl -fsSL "$LOGO_URL" -o "$LOGO_PNG" || \
    curl -fsSL "https://raw.githubusercontent.com/quisitive/quisitive/main/wp-content/uploads/2021/09/chsimmons_AVD_Install_4-472x315-1.png" -o "$LOGO_PNG" || true

    if [ ! -f "$LOGO_PNG" ] || [ ! -s "$LOGO_PNG" ]; then
        warn "Không tải được logo, sẽ dùng placeholder"
        # Create a minimal placeholder PNG (1x1 transparent)
        printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82' > "$LOGO_PNG"
    fi
fi

log "Logo: $LOGO_PNG"
file "$LOGO_PNG"

# ── Step 2: Check/create sizes directory ─────────────────────────────────
SIZES_DIR="$ICONS_DIR/iconset"
rm -rf "$SIZES_DIR"
mkdir -p "$SIZES_DIR"

# ── Step 3: Generate PNGs at required sizes ──────────────────────────────
# Check for sips (built-in macOS image resizer) — MUCH better than ImageMagick
if command -v sips &>/dev/null; then
    log "Using macOS sips for image resizing..."

    # Create iconset PNGs at standard macOS sizes
    # sips uses -z height width format
    sizes=(
        "16:16"
        "32:32"
        "64:64"
        "128:128"
        "256:256"
        "512:512"
        "1024:1024"
    )

    # Temp high-res version for retina
    cp "$LOGO_PNG" /tmp/icon_src.png

    for entry in "${sizes[@]}"; do
        IFS=':' read -r w h <<< "$entry"
        out="$SIZES_DIR/icon_${w}x${h}.png"
        sips -z "$h" "$w" "$LOGO_PNG" --out "$out" &>/dev/null
        log "  Created ${w}x${h}"
    done

    # Retina sizes (@2x) — use 2x source
    retina_sizes=(
        "32:32"    # 16x16@2x  → ic16
        "64:64"    # 32x32@2x  → ic17
        "128:128"  # 64x64@2x  → ic14
        "256:256"  # 128x128@2x → ic18
        "512:512"  # 256x256@2x → ic20
        "1024:1024" # 512x512@2x → ic21
    )

    for entry in "${retina_sizes[@]}"; do
        IFS=':' read -r w h <<< "$entry"
        out="$SIZES_DIR/icon_${w}x${h}@2x.png"
        sips -z "$h" "$w" "$LOGO_PNG" --out "$out" &>/dev/null
        log "  Created ${w}x${h}@2x"
    done

    rm -f /tmp/icon_src.png

elif command -v convert &>/dev/null; then
    log "Using ImageMagick convert for image resizing..."
    # ImageMagick
    for size in 16 32 64 128 256 512 1024; do
        out="$SIZES_DIR/icon_${size}x${size}.png"
        convert "$LOGO_PNG" -resize "${size}x${size}" "$out"
        log "  Created ${size}x${size}"
    done
    for size in 32 64 128 256 512 1024; do
        out="$SIZES_DIR/icon_${size}x${size}@2x.png"
        convert "$LOGO_PNG" -resize "$((size * 2))x$((size * 2))" "$out"
        log "  Created ${size}x${size}@2x"
    done

else
    err "Không tìm thấy sips hoặc convert."
    err "Cài đặt ImageMagick: brew install imagemagick"
    err "Hoặc dùng macOS mặc định đã có sips"
fi

# ── Step 4: Verify iconset ────────────────────────────────────────────────
icon_count=$(ls "$SIZES_DIR" | wc -l | tr -d ' ')
log "Đã tạo $icon_count file iconset"

if [ "$icon_count" -lt 7 ]; then
    warn "Iconset thiếu file. Đảm bảo logo có kích thước đủ lớn (>= 512px)"
fi

ls -la "$SIZES_DIR/"

# ── Step 5: Convert to .icns using iconutil ──────────────────────────────
if command -v iconutil &>/dev/null; then
    log "Chuyển iconset → FSOFTClient.icns..."

    iconutil -c icns "$SIZES_DIR" -o "$FSOFT_ICNS" 2>/dev/null || {
        warn "iconutil thất bại, thử với sudo..."
        sudo iconutil -c icns "$SIZES_DIR" -o "$FSOFT_ICNS" 2>/dev/null || true
    }

    if [ -f "$FSOFT_ICNS" ] && [ -s "$FSOFT_ICNS" ]; then
        log "✓ .icns tạo thành công: $FSOFT_ICNS"
        ls -lh "$FSOFT_ICNS"
    else
        warn "iconutil không tạo được .icns"
        warn "Thử dùng python3 để tạo (xem create-icns.py)..."
    fi
else
    warn "iconutil không có (không phải macOS)."
    warn "Chạy script này trên macOS để tạo .icns."
    warn "Hoặc chạy: python3 icons/create-icns.py"
fi

# ── Step 6: Summary ───────────────────────────────────────────────────────
echo ""
echo "========================================"
echo "  Icon Setup Complete"
echo "========================================"
echo ""
if [ -f "$FSOFT_ICNS" ] && [ -s "$FSOFT_ICNS" ]; then
    echo "  ✓ FSOFTClient.icns: $FSOFT_ICNS ($(du -h "$FSOFT_ICNS" | cut -f1))"
else
    echo "  ⚠  FSOFTClient.icns: Cần tạo trên macOS (xem trên)"
fi
echo "  ✓ Iconset: $SIZES_DIR/"
echo "  ✓ Logo: $LOGO_PNG"
echo ""
echo "  Logo sẽ được dùng làm:"
echo "  • App icon trong .app bundle (FSOFTClient.icns)"
echo "  • App icon trong DMG window"
echo ""
