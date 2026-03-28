#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
create-icns.py — Tạo file .icns từ ảnh PNG nguồn (không cần Pillow)

Usage: python3 create-icns.py source.png output.icns [sizes...]
Example: python3 create-icns.py app-logo.png FSOFTClient.icns
         python3 create-icns.py app-logo.png FSOFTClient.icns 16 32 64 128 256 512 1024

Tạo iconset directory rồi dùng iconutil (có sẵn trên macOS) để convert sang .icns.
Nếu không có iconutil (Linux/Windows), dùng pure Python để tạo ICNS trực tiếp.

Iconset sizes cần cho macOS .icns:
  ic07 = 16x16 @1x
  ic08 = 32x32 @1x
  ic09 = 64x64 @1x (không có trong spec, thêm vào cho đẹp)
  ic10 = 128x128 @1x
  ic11 = 256x256 @1x
  ic12 = 512x512 @1x
  ic13 = 1024x1024 @1x
  ic14 = 64x64 @2x (Retina)
  ic15 = 320x320 @2x (Retina)
  ic16 = 16x16 @2x (Retina)
  ic17 = 32x32 @2x (Retina)
  ic18 = 48x48 @2x (Retina)
  ic19 = 192x192 @2x (Retina)
  ic20 = 256x256 @2x (Retina)
  ic21 = 512x512 @2x (Retina)
  ic22 = 1024x1024 @2x (Retina)
"""

import struct
import sys
import os
import zlib
import math
import io
import shutil
import subprocess
import tempfile

ICNS_TYPE_TO_SIZE = {
    'ic07': 16,   # 16x16
    'ic08': 32,   # 32x32
    'ic09': 64,   # 64x64
    'ic10': 128,  # 128x128
    'ic11': 256,  # 256x256
    'ic12': 512,  # 512x512
    'ic13': 1024, # 1024x1024
}

# Retinas
ICNS_TYPE_TO_SIZE.update({
    'ic14': 64,   # 64x64 @2x
    'ic15': 320,  # 320x320 @2x
    'ic16': 32,   # 16x16 @2x
    'ic17': 64,   # 32x32 @2x
    'ic18': 96,   # 48x48 @2x
    'ic19': 384,  # 192x192 @2x
    'ic20': 512,  # 256x256 @2x
    'ic21': 1024, # 512x512 @2x
    'ic22': 2048, # 1024x1024 @2x
})

ICNS_TYPE_TO_SIZE_RETINA = {
    'ic14': 64,
    'ic15': 320,
    'ic16': 32,
    'ic17': 64,
    'ic18': 96,
    'ic19': 384,
    'ic20': 512,
    'ic21': 1024,
    'ic22': 2048,
}


# ─────────────────────────────────────────────────────────────────
# Pure Python PNG reader (no Pillow)
# ─────────────────────────────────────────────────────────────────

def read_png_chunk(f):
    """Read one PNG chunk: returns (type, data)"""
    length = struct.unpack('>I', f.read(4))[0]
    chunk_type = f.read(4).decode('ascii', errors='replace')
    data = f.read(length)
    crc = struct.unpack('>I', f.read(4))[0]
    return chunk_type, data


def read_png_pixels(png_data):
    """Read PNG, return raw RGBA bytes (list of rows)."""
    f = io.BytesIO(png_data)

    # PNG signature
    sig = f.read(8)
    if sig != b'\x89PNG\r\n\x1a\n':
        raise ValueError("Not a PNG file")

    width = height = bit_depth = color_type = None
    ihdr_data = b''
    idat_data = b''

    while True:
        pos = f.tell()
        chunk_type, data = read_png_chunk(f)

        if chunk_type == 'IHDR':
            ihdr_data = data
            w, h, bd, ct, comp, filt, inter = struct.unpack('>IIBBBBB', data)
            width, height, bit_depth, color_type = w, h, bd, ct
        elif chunk_type == 'IDAT':
            idat_data += data
        elif chunk_type == 'IEND':
            break

    if not width or not idat_data:
        raise ValueError("Invalid PNG: missing IHDR or IDAT")

    # Decompress
    raw_data = zlib.decompress(idat_data)

    # Parse scanlines (filter byte per row)
    bytes_per_pixel = {
        0: 1,   # grayscale
        2: 3,   # RGB
        3: 1,   # indexed
        4: 2,   # grayscale+alpha
        6: 4,   # RGBA
    }.get(color_type, 3)

    stride = width * bytes_per_pixel + 1  # +1 for filter byte
    rows = []
    for y in range(height):
        row = raw_data[y * stride: (y + 1) * stride]
        filter_type = row[0]
        pixels = bytearray(row[1:])
        rows.append(pixels)

    # Convert to RGBA if needed
    if color_type == 2:  # RGB
        new_rows = []
        for row in rows:
            rgba = bytearray()
            for i in range(0, len(row), 3):
                rgba += row[i:i+3] + bytearray([255])
            new_rows.append(rgba)
        rows = new_rows
    elif color_type == 0:  # Grayscale
        new_rows = []
        for row in rows:
            rgba = bytearray()
            for i in range(len(row)):
                g = row[i]
                rgba += bytearray([g, g, g, 255])
            new_rows.append(rgba)
        rows = new_rows
    elif color_type == 4:  # Grayscale + Alpha
        new_rows = []
        for row in rows:
            rgba = bytearray()
            for i in range(0, len(row), 2):
                g, a = row[i], row[i+1]
                rgba += bytearray([g, g, g, a])
            new_rows.append(rgba)
        rows = new_rows
    elif color_type == 3:  # Indexed (palette)
        raise ValueError("Indexed PNG not supported. Please provide a full RGBA PNG.")

    return width, height, rows


def resize_rgba(rgba_rows, src_w, src_h, dst_w, dst_h):
    """Bilinear resize of RGBA rows to dst_w x dst_h."""
    new_rows = [bytearray(dst_w * 4) for _ in range(dst_h)]

    # Scale factors
    sx = src_w / dst_w
    sy = src_h / dst_h

    for y in range(dst_h):
        src_y = y * sy
        y0 = min(int(src_y), src_h - 1)
        y1 = min(y0 + 1, src_h - 1)
        fy = src_y - y0

        row_out = new_rows[y]
        for x in range(dst_w):
            src_x = x * sx
            x0 = min(int(src_x), src_w - 1)
            x1 = min(x0 + 1, src_w - 1)
            fx = src_x - x0

            def pixel(r, c):
                return rgba_rows[r][c*4:(c*4)+4]

            p00 = pixel(y0, x0)
            p10 = pixel(y0, x1)
            p01 = pixel(y1, x0)
            p11 = pixel(y1, x1)

            out = bytearray(4)
            for ch in range(4):
                v = (p00[ch] * (1-fx) * (1-fy) +
                     p10[ch] * fx * (1-fy) +
                     p01[ch] * (1-fx) * fy +
                     p11[ch] * fx * fy)
                out[ch] = min(255, max(0, int(v + 0.5)))
            row_out[x*4:(x*4)+4] = out

    return new_rows


def make_png_from_rgba(rgba_rows, w, h):
    """Encode RGBA rows to PNG bytes (no filter, minimal compression for speed)."""
    raw = bytearray()
    for row in rgba_rows:
        raw += b'\x00' + row  # filter type 0 = None

    compressed = zlib.compress(bytes(raw), 6)

    chunks = b''
    # IHDR
    ihdr = struct.pack('>II', w, h) + b'\x08\x06\x00\x00\x00'  # 8-bit RGBA
    chunks += b'IHDR' + ihdr + struct.pack('>I', zlib.crc32(b'IHDR' + ihdr) & 0xffffffff)

    # IDAT
    idat = compressed
    chunks += b'IDAT' + idat + struct.pack('>I', zlib.crc32(b'IDAT' + idat) & 0xffffffff)

    # IEND
    chunks += b'IEND' + struct.pack('>I', zlib.crc32(b'IEND') & 0xffffffff)

    return b'\x89PNG\r\n\x1a\n' + chunks


def make_tiff_from_rgba(rgba_rows, w, h):
    """Encode RGBA rows to uncompressed TIFF (big-endian)."""
    # TIFF header
    header = struct.pack('>HH', 0x4D4D, 0x002A)  # Big-endian

    ifd_offset = 8
    num_entries = 13

    # Prepare strips
    strip_data = bytearray()
    row_stride = w * 4
    for row in rgba_rows:
        strip_data += b'\x00' + row  # filter byte

    entries = [
        # tag, type, count, value (offset for pointers)
        (0x0100, 3, 1, w),          # ImageWidth
        (0x0101, 3, 1, h),          # ImageLength
        (0x0102, 3, 1, 32),         # BitsPerSample (8,8,8,8 but stored as 16-bit values)
        (0x0103, 3, 1, 1),          # Compression (1=uncompressed)
        (0x0106, 3, 1, 2),          # PhotometricInterpretation (2=RGB)
        (0x0111, 3, 1, ifd_offset + 2 + num_entries * 12 + 4),  # StripOffsets
        (0x0115, 3, 1, 4),          # SamplesPerPixel
        (0x0116, 3, 1, h),          # RowsPerStrip
        (0x0153, 3, 1, 1),          # SampleFormat (1=unsigned int)
    ]

    return header


def create_icns_via_iconutil(iconset_path, output_icns):
    """Use macOS iconutil to convert iconset to .icns (best quality)."""
    result = subprocess.run(
        ['iconutil', '-c', 'icns', iconset_path, '-o', output_icns],
        capture_output=True, text=True
    )
    if result.returncode == 0:
        return True, f"Created via iconutil: {output_icns}"
    return False, result.stderr


def create_icns_pure_python(icon_images, output_path):
    """
    Create ICNS file manually from a dict of {type_code: (width, height, rgba_rows)}.
    Pure Python, no macOS tools needed.
    """
    icns_data = b'icns'
    entries = []

    for type_code, (w, h, rows) in icon_images.items():
        # Use TIFF representation for each icon type
        # ICNS uses a specific format: icon type (4 bytes) + length (4 bytes) + data
        icon_data = create_icon_entry(type_code, w, h, rows)
        entries.append(icon_data)

    # Assemble
    icns_body = b''.join(entries)
    icns_data += struct.pack('>I', 8 + len(icns_body))  # total size
    icns_data += icns_body

    with open(output_path, 'wb') as f:
        f.write(icns_data)

    return icns_data


def create_icon_entry(type_code, w, h, rgba_rows):
    """
    Create one ICNS icon entry for a given type.
    Uses uncompressed 32-bit TIFF/PICT format internally by macOS,
    but for our purposes, we'll use the PNG representation which
    modern macOS supports.

    Format: type_code(4) + length(4) + png_data
    """
    # Encode as PNG
    png_bytes = make_png_from_rgba(rgba_rows, w, h)

    entry = type_code.encode('ascii') + struct.pack('>I', 8 + len(png_bytes)) + png_bytes
    return entry


# ─────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────

def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)

    source_png = sys.argv[1]
    output_icns = sys.argv[2]

    # Default sizes: all standard macOS icon sizes
    if len(sys.argv) > 3:
        sizes = [int(s) for s in sys.argv[3:]]
    else:
        sizes = list(ICNS_TYPE_TO_SIZE.values())
        # Remove duplicates and sort
        sizes = sorted(set(sizes))

    if not os.path.exists(source_png):
        print(f"Error: Source file not found: {source_png}", file=sys.stderr)
        sys.exit(1)

    print(f"Reading source PNG: {source_png}")
    png_bytes = open(source_png, 'rb').read()
    src_w, src_h, src_rgba = read_png_pixels(png_bytes)
    print(f"  Source size: {src_w}x{src_h}")

    # Create iconset for iconutil (macOS native)
    iconset_dir = tempfile.mkdtemp(prefix='fsoft-iconset-')
    iconset_path = os.path.join(iconset_dir, 'app.iconset')

    # Map size → icon type
    size_to_type = {}
    for type_code, size in ICNS_TYPE_TO_SIZE.items():
        if size not in size_to_type:
            size_to_type[size] = type_code

    icon_images = {}

    print("Generating icons at required sizes:")
    for size in sizes:
        if size not in size_to_type:
            # Find nearest type or use ic11/ic12
            if size <= 256:
                type_code = 'ic11'
            else:
                type_code = 'ic12'
        else:
            type_code = size_to_type[size]

        # Skip if larger than source and we don't have it
        if size > max(src_w, src_h) * 2:
            print(f"  Skipping {size}px (source too small)")
            continue

        # Resize
        if size == src_w and src_h == src_w:
            resized = src_rgba
        else:
            resized = resize_rgba(src_rgba, src_w, src_h, size, size)

        icon_images[type_code] = (size, size, resized)

        # Write PNG for iconset
        png_out = make_png_from_rgba(resized, size, size)
        iconset_file = os.path.join(iconset_path, f'icon_{size}x{size}.png')
        open(iconset_file, 'wb').write(png_out)
        print(f"  {size}x{size} → {type_code} ({len(png_out)} bytes)")

        # Also add @2x variant if size matches Retina needs
        retina_map = {16: 'ic16', 32: 'ic17', 64: 'ic14', 128: 'ic18',
                      256: 'ic20', 512: 'ic21', 1024: 'ic22'}
        if size in retina_map and size * 2 <= max(src_w, src_h) * 2:
            rsize = size
            rtype = retina_map[size]
            png_out_2x = make_png_from_rgba(resized, size, size)  # Already at correct size
            iconset_file_2x = os.path.join(iconset_path, f'icon_{rsize}x{rsize}@2x.png')
            open(iconset_file_2x, 'wb').write(png_out_2x)
            icon_images[rtype] = (rsize, rsize, resized)
            print(f"  {size}x{size}@2x → {rtype}")

    # Try iconutil first (macOS native, best quality)
    print(f"\nTrying macOS iconutil...")
    ok, msg = create_icns_via_iconutil(iconset_path, output_icns)
    if ok:
        print(f"✓ {msg}")
        shutil.rmtree(iconset_dir)
        print(f"\n✓ ICNS created: {output_icns} ({os.path.getsize(output_icns):,} bytes)")
        return

    # Fallback: pure Python ICNS
    print(f"iconutil not available, creating ICNS with pure Python...")
    create_icns_pure_python(icon_images, output_icns)
    shutil.rmtree(iconset_dir)

    print(f"\n✓ ICNS created (pure Python): {output_icns} ({os.path.getsize(output_icns):,} bytes)")
    print("\nNote: For best quality, run this script on macOS:")
    print(f"  python3 {sys.argv[0]} {source_png} {output_icns}")


if __name__ == '__main__':
    main()
