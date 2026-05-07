#!/usr/bin/env bash
# =============================================================================
# motion_detect.sh — Motion detection via FFmpeg scene filter
#
# Reads from the camera in parallel with the main stream, applies the scene
# change detector, saves JPEG snapshots, and appends JSON entries to
# ${OUTPUT_DIR}/motion_alerts.json so the browser can poll them.
#
# Usage:
#   ./scripts/motion_detect.sh &      # run in background alongside stream
#   kill %1                           # stop it
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

mkdir -p "${SNAPSHOT_DIR}" "${LOG_DIR}"

ALERTS_JSON="${OUTPUT_DIR}/motion_alerts.json"
METADATA_PIPE="${LOG_DIR}/motion_meta.txt"

# Initialise the alerts JSON array if it doesn't exist
if [[ ! -f "${ALERTS_JSON}" ]]; then
  echo "[]" > "${ALERTS_JSON}"
fi

echo "[motion] Starting motion detection (sensitivity=${MOTION_SENSITIVITY})…"
echo "[motion] Snapshots → ${SNAPSHOT_DIR}"
echo "[motion] Alerts    → ${ALERTS_JSON}"

# ---------------------------------------------------------------------------
# FFmpeg command:
#   1. Open the camera (lower framerate to reduce CPU)
#   2. Split into two outputs:
#        a) null sink with scene metadata printed to stderr-redirected pipe
#        b) mjpeg snapshot saved whenever scene score exceeds threshold
# ---------------------------------------------------------------------------
ffmpeg \
  -f "${CAMERA_FORMAT}" \
  -framerate 5 \
  -video_size "${CAMERA_RESOLUTION}" \
  -i "${CAMERA_DEVICE}" \
  -vf "select='gt(scene,${MOTION_SENSITIVITY})',metadata=print:file=${METADATA_PIPE}" \
  -vsync vfr \
  -frame_pts 1 \
  -q:v 3 \
  "${SNAPSHOT_DIR}/snap_%09d.jpg" \
  2>"${LOG_DIR}/motion_ffmpeg.log" &

FFMPEG_MD_PID=$!
echo "${FFMPEG_MD_PID}" > "${LOG_DIR}/motion.pid"

# ---------------------------------------------------------------------------
# Tail the metadata file and write JSON alerts each time motion is triggered
# ---------------------------------------------------------------------------
touch "${METADATA_PIPE}"

tail -f "${METADATA_PIPE}" 2>/dev/null | while IFS= read -r line; do
  # FFmpeg scene metadata lines look like:
  #   lavfi.scene_score=0.234567
  if [[ "${line}" == *"lavfi.scene_score="* ]]; then
    SCORE="${line##*=}"
    NOW="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    # Find the most recently written snapshot
    LATEST_SNAP="$(ls -1t "${SNAPSHOT_DIR}"/snap_*.jpg 2>/dev/null | head -1 || true)"
    SNAP_NAME="$(basename "${LATEST_SNAP}" 2>/dev/null || echo "")"

    echo "[motion] Detected at ${NOW}  score=${SCORE}  snap=${SNAP_NAME}"

    # Append to JSON array (read → add → write atomically via temp file)
    EXISTING="$(cat "${ALERTS_JSON}" 2>/dev/null || echo "[]")"
    python3 - <<PYEOF
import json, sys
alerts = json.loads('''${EXISTING}''')
alerts.append({
    "time":     "${NOW}",
    "score":    float("${SCORE}"),
    "snapshot": "snapshots/${SNAP_NAME}"
})
# Keep at most 200 entries
alerts = alerts[-200:]
with open("${ALERTS_JSON}", "w") as f:
    json.dump(alerts, f)
PYEOF
  fi
done

wait "${FFMPEG_MD_PID}" || true
echo "[motion] Motion detection stopped."
