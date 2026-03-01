#!/bin/bash

# This script builds the FSOFT Virtual Desktop Client for macOS.
# It supports both Apple Silicon (arm64) and Intel (x86_64) architectures.

APP_NAME="FSOFT Virtual Desktop Client"
ICON_PATH="macosx/uds.icns"

# Ensure we are in the src directory
cd "$(dirname "$0")/../src"

# Create virtual environment if it doesn't exist
if [ ! -d "venv_mac" ]; then
    python3 -m venv venv_mac
fi

source venv_mac/bin/activate
pip install -r ../requirements.txt
pip install pyinstaller

# Build for both architectures (Universal Binary)
# Note: This requires a Mac with universal binary support for Python and dependencies.
python3 -m PyInstaller --onefile --windowed \
    --name="$APP_NAME" \
    --icon="$ICON_PATH" \
    --hidden-import=certifi \
    --target-arch universal2 \
    UDSClient.py

echo "Build complete. The app is available in dist/$APP_NAME.app"
