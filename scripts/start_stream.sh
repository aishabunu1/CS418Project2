#!/usr/bin/env bash
# =============================================================================
# start_stream.sh — Start FFmpeg live DASH stream
#
# Usage:
#   ./scripts/start_stream.sh          # uses SEGMENT_DURATION from config.sh
#   ./scripts/start_stream.sh 2        # override: 2-second segments
#   ./scripts/start_stream.sh 4        # override: 4-second segments
#   ./scripts/start_stream.sh 6        # override: 6-second segments
#
# All system-specific parameters come from config.sh — never hard-coded here.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

# Allow segment duration override from command-line argument
SEG="${1:-${SEGMENT_DURATION}}"

# Recompute GOP for this segment duration
GOP=$(( CAMERA_FRAMERATE * SEG ))

echo "======================================================"
echo " Video Surveillance over IP — Starting Stream"
echo " Camera  : ${CAMERA_DEVICE}"
echo " Format  : ${CAMERA_FORMAT}"
echo " Res     : ${CAMERA_RESOLUTION} @ ${CAMERA_FRAMERATE} fps"
echo " Segment : ${SEG}s  (GOP=${GOP})"
echo " Audio   : ${ENABLE_AUDIO}"
echo " Output  : ${OUTPUT_DIR}/${MANIFEST_NAME}"
echo "======================================================"

# Create output directories
mkdir -p "${OUTPUT_DIR}" "${SNAPSHOT_DIR}" "${LOG_DIR}"

# Remove stale segments from a previous run
find "${OUTPUT_DIR}" \( -name "*.m4s" -o -name "*.mpd" -o -name "*.mp4" \) \
  -not -path "${SNAPSHOT_DIR}/*" \
  -delete 2>/dev/null || true

# ---------------------------------------------------------------------------
# Build the FFmpeg command
# ---------------------------------------------------------------------------
# Input flags
INPUT_FLAGS=(
  -f "${CAMERA_FORMAT}"
  -framerate "${CAMERA_FRAMERATE}"
  -video_size "${CAMERA_RESOLUTION}"
  -i "${CAMERA_DEVICE}"
)

# Audio input (appended only when ENABLE_AUDIO=true)
AUDIO_FLAGS=()
if [[ "${ENABLE_AUDIO}" == "true" ]]; then
  AUDIO_FLAGS=(
    -f "${AUDIO_FORMAT}"
    -i "${AUDIO_DEVICE}"
  )
fi

# Video encoding — three adaptive bitrate renditions (H.264 / AVC)
VIDEO_ENC=(
  # High rendition
  -map 0:v -c:v:0 libx264
    -s:v:0 "${HIGH_RES}"
    -b:v:0 "${HIGH_BITRATE}" -maxrate:v:0 "${HIGH_MAXRATE}" -bufsize:v:0 "${HIGH_BUFSIZE}"

  # Medium rendition
  -map 0:v -c:v:1 libx264
    -s:v:1 "${MED_RES}"
    -b:v:1 "${MED_BITRATE}" -maxrate:v:1 "${MED_MAXRATE}" -bufsize:v:1 "${MED_BUFSIZE}"

  # Low rendition
  -map 0:v -c:v:2 libx264
    -s:v:2 "${LOW_RES}"
    -b:v:2 "${LOW_BITRATE}" -maxrate:v:2 "${LOW_MAXRATE}" -bufsize:v:2 "${LOW_BUFSIZE}"
)

# H.264 common settings (applied to all video streams via -x264-params or global flags)
H264_FLAGS=(
  -preset:v "${X264_PRESET}"
  -tune:v   "${X264_TUNE}"
  -profile:v baseline        # Widest device compatibility
  -level:v   3.1
  -pix_fmt   yuv420p         # Required by baseline profile

  # Keyframe / GOP settings — one keyframe per segment boundary (mandatory for DASH)
  -g         "${GOP}"
  -keyint_min "${GOP}"
  -sc_threshold 0            # Disable scene-cut keyframes (breaks DASH segmentation)
  -force_key_frames "expr:gte(t,n_forced*${SEG})"
)

# Audio encoding (AAC)
AUDIO_ENC=()
if [[ "${ENABLE_AUDIO}" == "true" ]]; then
  AUDIO_ENC=(
    -map 1:a -c:a aac
    -ar "${AUDIO_SAMPLE_RATE}"
    -ac "${AUDIO_CHANNELS}"
    -b:a "${AUDIO_BITRATE}"
  )
fi

# DASH muxer settings
DASH_FLAGS=(
  -f dash
  -seg_duration      "${SEG}"
  -use_template      1           # SegmentTemplate — required for live DASH
  -use_timeline      1           # SegmentTimeline — carries precise timing
  -window_size       "${WINDOW_SIZE}"
  -extra_window_size "${EXTRA_WINDOW_SIZE}"
  -streaming         1           # Chunked output → lower latency
  -ldash             1           # Low-latency DASH profile
  -dash_segment_type mp4         # fMP4 segments (.m4s)
  -remove_at_exit    0           # Keep segments on disk after exit
)

# Adaptation sets: separate video and audio streams
if [[ "${ENABLE_AUDIO}" == "true" ]]; then
  DASH_FLAGS+=( -adaptation_sets "id=0,streams=v id=1,streams=a" )
else
  DASH_FLAGS+=( -adaptation_sets "id=0,streams=v" )
fi

# Output path (manifest file)
MANIFEST_PATH="${OUTPUT_DIR}/${MANIFEST_NAME}"

# ---------------------------------------------------------------------------
# Run FFmpeg
# ---------------------------------------------------------------------------
echo ""
echo "[stream] Starting FFmpeg…"

ffmpeg \
  "${INPUT_FLAGS[@]}" \
  "${AUDIO_FLAGS[@]}" \
  "${VIDEO_ENC[@]}"   \
  "${H264_FLAGS[@]}"  \
  "${AUDIO_ENC[@]}"   \
  "${DASH_FLAGS[@]}"  \
  "${MANIFEST_PATH}"  \
  2>&1 | tee "${LOG_DIR}/ffmpeg_stream.log" &

FFMPEG_PID=$!
echo "${FFMPEG_PID}" > "${LOG_DIR}/ffmpeg.pid"
echo "[stream] FFmpeg PID: ${FFMPEG_PID}"
echo "[stream] Log: ${LOG_DIR}/ffmpeg_stream.log"
echo "[stream] Manifest: ${MANIFEST_PATH}"
echo ""
echo " Open in browser → http://localhost:${HTTP_PORT}/?mpd=dash/manifest.mpd&seg=${SEG}"
echo " Stop with: ./scripts/stop_stream.sh"

wait "${FFMPEG_PID}" || true
echo "[stream] FFmpeg exited."
