# -*- mode: python ; coding: utf-8 -*-
# PyInstaller spec file for UDS Client on macOS Intel (x86_64)
# Usage: pyinstaller UDSClient-macOS.spec

import os
import sys

block_cipher = None

# Entry point is UDSClientLauncher.py for macOS
a = Analysis(
    ['UDSClientLauncher.py'],
    pathex=['.'],
    binaries=[],
    datas=[],
    hiddenimports=[
        'certifi',
        'psutil',
        'cryptography',
        'cryptography.hazmat.backends',
        'cryptography.hazmat.backends.openssl',
        'cryptography.hazmat.primitives',
        'cryptography.hazmat.primitives.hashes',
        'cryptography.hazmat.primitives.serialization',
        'cryptography.hazmat.primitives.asymmetric',
        'cryptography.hazmat.primitives.asymmetric.padding',
        'cryptography.x509',
        'PySide6',
        'PySide6.QtCore',
        'PySide6.QtWidgets',
        'PySide6.QtGui',
        'uds',
        'uds.ui',
        'uds.ui.pyside6',
        'uds.ui.pyside6.UDSLauncherMac',
        'uds.ui.pyside6.UDSWindow',
        'uds.ui.pyside6.UDSResources_rc',
        'uds.net',
        'uds.net.udssock',
        'uds.tunnel',
        'uds.rest',
        'uds.tools',
        'uds.log',
        'uds.consts',
        'uds.types',
        'uds.os_detector',
        'uds.exceptions',
        'UDSClient',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        'PyQt5',
        'PyQt6',
        'tkinter',
        'unittest',
    ],
    noarchive=False,
    optimize=0,
)

pyz = PYZ(a.pure, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='UDSClientLauncher',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=True,  # Critical for macOS URL scheme handling
    target_arch='x86_64',  # Intel
    codesign_identity=None,
    entitlements_file=None,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=False,
    upx_exclude=[],
    name='UDSClientLauncher',
)

app = BUNDLE(
    coll,
    name='FSOFTVirtualDesktopClient.app',
    icon='macosx/uds.icns',
    bundle_identifier='com.fsoft.VirtualDesktopClient',
    info_plist={
        'CFBundleName': 'FSOFT Virtual Desktop Client',
        'CFBundleDisplayName': 'FSOFT Virtual Desktop Client',
        'CFBundleIdentifier': 'com.fsoft.VirtualDesktopClient',
        'CFBundleVersion': '4.0.0',
        'CFBundleShortVersionString': '4.0.0',
        'CFBundlePackageType': 'APPL',
        'CFBundleSignature': '????',
        'LSMinimumSystemVersion': '10.13.0',
        'NSHighResolutionCapable': True,
        'LSApplicationCategoryType': 'public.app-category.utilities',
        'CFBundleURLTypes': [
            {
                'CFBundleURLName': 'UDS Protocol',
                'CFBundleURLSchemes': ['uds'],
                'CFBundleURLIconFile': 'uds.icns',
            },
            {
                'CFBundleURLName': 'UDS Protocol SSL',
                'CFBundleURLSchemes': ['udss'],
                'CFBundleURLIconFile': 'uds.icns',
            },
        ],
        'NSAppleEventsUsageDescription': 'FSOFT Virtual Desktop Client needs to handle URL events.',
    },
)
