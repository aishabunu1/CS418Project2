#!/usr/bin/env bash
# =============================================================================
# setup.sh — One-time setup: configure paths, prepare NGINX, verify FFmpeg
# Run this once before starting the stream.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

echo "======================================================"
echo " Video Surveillance over IP — Setup"
echo "======================================================"

# 1. Check dependencies
echo ""
echo "[check] Verifying dependencies..."

check_cmd() {
    if command -v "$1" &>/dev/null; then
        echo "  ✓ $1 ($(command -v "$1"))"
    else
        echo "  ✗ $1 — NOT FOUND. Please install it."
        MISSING=1
    fi
}

MISSING=0
check_cmd ffmpeg
check_cmd nginx
check_cmd python3
[[ $MISSING -eq 1 ]] && echo "" && echo "[error] Missing dependencies above." && exit 1

# 2. Verify FFmpeg has needed codecs
echo ""
echo "[check] Verifying FFmpeg codecs..."
CODECS=$(ffmpeg -encoders 2>/dev/null | grep -E "libx264|aac" || true)
echo "${CODECS:-  (could not verify — run ffmpeg -encoders manually)}"

# 3. Patch nginx.conf with real project root
echo ""
echo "[setup] Configuring NGINX with project root: ${PROJECT_ROOT}"
NGINX_CONF_SRC="${SCRIPT_DIR}/nginx/nginx.conf"
NGINX_CONF_OUT="${SCRIPT_DIR}/nginx/nginx_configured.conf"

sed "s|REPLACE_WITH_PROJECT_ROOT|${PROJECT_ROOT}|g" \
    "${NGINX_CONF_SRC}" > "${NGINX_CONF_OUT}"

echo "  → ${NGINX_CONF_OUT}"

# 4. Create log dirs
mkdir -p "${LOG_DIR}" "${OUTPUT_DIR}" "${SNAPSHOT_DIR}"

# 5. Show camera devices
echo ""
echo "[info] Available video devices:"
case "$(uname -s)" in
    Linux*)  ls /dev/video* 2>/dev/null || echo "  No /dev/video* found" ;;
    Darwin*) ffmpeg -f avfoundation -list_devices true -i "" 2>&1 | grep -E "\[AVFoundation|^\[" | head -20 || true ;;
    *)       echo "  (on Windows, run: ffmpeg -list_devices true -f dshow -i dummy)" ;;
esac

# 6. Print startup instructions
echo ""
echo "======================================================"
echo " Setup complete! Quick start:"
echo ""
echo "  1. Edit config.sh → set CAMERA_DEVICE to your webcam"
echo "  2. Start NGINX:"
echo "       nginx -c ${NGINX_CONF_OUT} -p ${PROJECT_ROOT}/nginx"
echo ""
echo "  3. Start streaming (choose one):"
echo "       ./scripts/start_stream.sh        # default segment size"
echo "       ./scripts/start_stream.sh 2      # 2-second segments (lower latency)"
echo "       ./scripts/start_stream.sh 6      # 6-second segments (more stable)"
echo ""
echo "  4. Open in browser:"
echo "       http://localhost:${HTTP_PORT}/"
echo ""
echo "  5. For motion detection (optional):"
echo "       ./scripts/motion_detect.sh &"
echo ""
echo "  6. Stop streaming:"
echo "       ./scripts/stop_stream.sh"
echo "======================================================"
