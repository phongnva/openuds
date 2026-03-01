#!/usr/bin/env python3

import os
import re
from PIL import Image

def resize_and_pad(img_path, target_size, output_path):
    print(f"Processing image {output_path} to {target_size}")
    source = Image.open(img_path).convert("RGBA")
    source_ratio = source.width / source.height
    target_ratio = target_size[0] / target_size[1]

    if source_ratio > target_ratio:
        new_width = target_size[0]
        new_height = int(new_width / source_ratio)
    else:
        new_height = target_size[1]
        new_width = int(new_height * source_ratio)

    resized = source.resize((new_width, new_height), Image.Resampling.LANCZOS)
    
    background = Image.new('RGBA', target_size, (255, 255, 255, 0))
    x_offset = (target_size[0] - new_width) // 2
    y_offset = (target_size[1] - new_height) // 2
    
    background.paste(resized, (x_offset, y_offset), resized)
    output_format = 'ICO' if output_path.lower().endswith('.ico') else 'PNG'
    if output_format == 'ICO':
        # Need to ensure no alpha channel for basic ICO compatibility, or keep it if Pillow supports RGBA ICO
        background.save(output_path, format=output_format)
    else:
        background.save(output_path, format=output_format)

def replace_in_file(file_path, replacements):
    if not os.path.exists(file_path):
        return
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    new_content = content
    for old_text, new_text in replacements.items():
        new_content = new_content.replace(old_text, new_text)
        
    # Also remove integrity attributes which break SRI when scripts are modified
    if file_path.endswith('.html'):
        new_content = re.sub(r'\s+integrity="[^"]+"', '', new_content)
        if 'modern' in file_path:
            new_content = re.sub(r'background:url\(data:image/png;base64,[^)]+\)', 'background:url(/uds/res/modern/img/udsicon.png) no-repeat center center / contain', new_content)
        elif 'admin' in file_path:
            new_content = re.sub(r'background:url\(data:image/png;base64,[^)]+\)', 'background:url(/uds/res/admin/img/udsicon.png) no-repeat center center / contain', new_content)
        
    if new_content != content:
        print(f"Updated {file_path}")
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(new_content)

def rebrand(base_dir):
    fpt_logo = os.path.join(base_dir, "../logo-fpt/fpt-logo.png")
    if not os.path.exists(fpt_logo):
        print("FPT logo not found at", fpt_logo)
        return

    # Images
    images_to_resize = {
        "src/uds/static/admin/img/udsicon.png": (128, 128),
        "src/uds/static/modern/img/udsicon.png": (128, 128),
        "src/uds/static/admin/img/favicon.png": (45, 46),
        "src/uds/static/modern/img/favicon.png": (45, 46),
        "src/uds/static/admin/img/favicon.ico": (48, 48),
        "src/uds/static/modern/img/favicon.ico": (48, 48),
        "src/uds/static/modern/img/login-img.png": (150, 213),
    }

    for rel_path, dimensions in images_to_resize.items():
        resize_and_pad(fpt_logo, dimensions, os.path.join(base_dir, rel_path))

    # Text replacements in files
    text_replacements = {
        "UDS Enterprise": "FSOFT Virtual Desktop",
        "Universal Desktop Services": "FSOFT Virtual Desktop",
        "udsenterprise.com": "fptsoftware.com",
        "<title>Uds</title>": "<title>FSOFT Virtual Desktop</title>",
        "© UDS Enterprise": "© FSOFT Virtual Desktop",
    }

    files_to_patch = [
        "src/uds/templates/uds/modern/index.html",
        "src/uds/templates/uds/admin/index.html",
        "src/uds/core/util/config.py",
        "src/uds/static/admin/main.js",
        "src/uds/static/modern/main.js",
    ]
    for rel_path in files_to_patch:
        replace_in_file(os.path.join(base_dir, rel_path), text_replacements)

    # Locales
    import glob
    po_files = glob.glob(os.path.join(base_dir, "src/uds/locale/*/LC_MESSAGES/django.po"))
    for po_file in po_files:
        replace_in_file(po_file, text_replacements)

if __name__ == "__main__":
    rebrand("/home/phongnva/Desktop/PhongNVA/openuds/server")
