#!/bin/bash
# update_clients.sh
# Automates the building of UDS Client packages and copies them to the server static directory.

set -e

# Base directories
ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CLIENT_DIR="$ROOT_DIR/client"
SERVER_STATIC_CLIENTS="$ROOT_DIR/server/src/uds/static/clients"
VERSION="4.0.0"

echo "=========================================="
echo " Preparing UDS Clients for Server payload"
echo "=========================================="

echo "[1/4] Ensuring static/clients directory exists..."
mkdir -p "$SERVER_STATIC_CLIENTS"

echo "[2/4] Building Generic Linux tar.gz client..."
cd "$CLIENT_DIR/linux"
make -f ../Makefile DESTDIR=targz DISTRO=targz VERSION="$VERSION" install

echo "[3/4] Copying OS Installation packages into Server..."

# Copy Linux Tarball
cd "$CLIENT_DIR"
if [ -f "udsclient3-$VERSION.tar.gz" ]; then
    cp "udsclient3-$VERSION.tar.gz" "$SERVER_STATIC_CLIENTS/"
    echo " -> Copied udsclient3-$VERSION.tar.gz"
else
    echo " -> Error: udsclient3-$VERSION.tar.gz not found!"
    exit 1
fi

# Copy Windows MSI
if [ -f "src/FSOFT Virtual Desktop Client.msi" ]; then
    cp "src/FSOFT Virtual Desktop Client.msi" "$SERVER_STATIC_CLIENTS/"
    echo " -> Copied FSOFT Virtual Desktop Client.msi"
else
    echo " -> Error: FSOFT Virtual Desktop Client.msi not found! Ensure it was built via wix/pytest."
    exit 1
fi

# Copy MacOS PKG
if [ -f "src/build/FSOFT Virtual Desktop Client/FSOFT Virtual Desktop Client.pkg" ]; then
    # Server python mappings point to MAC_Client.pkg
    cp "src/build/FSOFT Virtual Desktop Client/FSOFT Virtual Desktop Client.pkg" "$SERVER_STATIC_CLIENTS/MAC_Client.pkg"
    echo " -> Copied MAC_Client.pkg"
else
    echo " -> Error: FSOFT Virtual Desktop Client.pkg not found! Ensure it was built via macos workflows."
    exit 1
fi

echo "=========================================="
echo " Client synchronization successfully completed."
echo " The payloads are now available for deployment inside:"
echo " $SERVER_STATIC_CLIENTS"
echo "=========================================="
