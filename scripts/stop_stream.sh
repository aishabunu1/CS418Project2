#!/usr/bin/env bash
# =============================================================================
# stop_stream.sh — Gracefully stop the FFmpeg DASH streaming process
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

PID_FILE="${LOG_DIR}/stream.pid"

if [[ ! -f "${PID_FILE}" ]]; then
    echo "[stop] No PID file found. Is the stream running?"
    # Try finding by process name
    PIDS=$(pgrep -f "start_stream.sh\|ffmpeg.*manifest.mpd" || true)
    if [[ -n "${PIDS}" ]]; then
        echo "[stop] Found FFmpeg processes: ${PIDS}"
        echo "[stop] Sending SIGINT..."
        kill -INT ${PIDS} 2>/dev/null || true
    fi
    exit 0
fi

PID=$(cat "${PID_FILE}")
if kill -0 "${PID}" 2>/dev/null; then
    echo "[stop] Stopping stream (PID ${PID})..."
    kill -INT "${PID}"
    sleep 2
    if kill -0 "${PID}" 2>/dev/null; then
        echo "[stop] Process still running, forcing..."
        kill -KILL "${PID}"
    fi
    echo "[stop] Stream stopped."
else
    echo "[stop] Process ${PID} not found (already stopped?)."
fi

rm -f "${PID_FILE}"
