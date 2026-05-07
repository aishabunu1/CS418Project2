#!/usr/bin/env bash
# =============================================================================
# stop_stream.sh — Stop the running FFmpeg live stream gracefully
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

PID_FILE="${LOG_DIR}/ffmpeg.pid"

if [[ -f "${PID_FILE}" ]]; then
  PID="$(cat "${PID_FILE}")"
  if kill -0 "${PID}" 2>/dev/null; then
    echo "[stop] Sending SIGINT to FFmpeg PID ${PID}…"
    kill -INT "${PID}"
    sleep 2
    # Force kill if still running
    if kill -0 "${PID}" 2>/dev/null; then
      echo "[stop] Force-killing PID ${PID}…"
      kill -9 "${PID}" 2>/dev/null || true
    fi
    echo "[stop] FFmpeg stopped."
  else
    echo "[stop] PID ${PID} is not running."
  fi
  rm -f "${PID_FILE}"
else
  echo "[stop] No PID file found. Attempting to kill all ffmpeg processes…"
  pkill -INT -x ffmpeg 2>/dev/null || true
  sleep 1
  pkill -9  -x ffmpeg 2>/dev/null || true
fi

echo "[stop] Done."
