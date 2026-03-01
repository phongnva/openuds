#!/bin/bash
# run_rebrand.sh
# Automates the execution of the rebranding script and redeploys the Docker App container.

set -e

# Get the script directory (openuds/server)
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Project root (openuds)
ROOT_DIR="$(dirname "$DIR")"

echo "=========================================="
echo " Starting FSOFT Virtual Desktop Rebrand"
echo "=========================================="

echo "[1/3] Running Python rebrand script via Docker to mutate source images and text strings..."
docker run --rm --entrypoint /bin/bash \
  -v "$ROOT_DIR":"$ROOT_DIR" \
  -w "$DIR" \
  docker-app:latest \
  -c "pip install Pillow && python rebrand.py"

echo "[2/3] Rebuilding the uds-app Docker image..."
cd "$DIR/deployment/Docker"
docker compose build app

echo "[3/3] Restarting the uds-app Docker container in the foreground to apply changes..."
docker compose up -d app

echo "=========================================="
echo " Rebranding process complete!"
echo " The application is now served at https://localhost/"
echo "=========================================="
