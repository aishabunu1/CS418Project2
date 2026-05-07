set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

if [[ $# -ge 1 ]]; then
    SEGMENT_DURATION="$1"
    GOP_SIZE=$(( CAMERA_FRAMERATE * SEGMENT_DURATION ))
    echo "[config] Segment duration overridden to ${SEGMENT_DURATION}s"
fi

mkdir -p "${OUTPUT_DIR}" "${LOG_DIR}" "${SNAPSHOT_DIR}"

echo "[setup] Cleaning old DASH segments in ${OUTPUT_DIR} ..."
find "${OUTPUT_DIR}" -name "*.m4s" -o -name "*.mpd" -o -name "chunk-*.m4s" 2>/dev/null | \
    xargs rm -f 2>/dev/null || true

OS="$(uname -s)"
case "${OS}" in
    Linux*)
        VIDEO_INPUT_FLAGS=(-f v4l2 -framerate "${CAMERA_FRAMERATE}" -video_size "${CAMERA_RESOLUTION}")
        AUDIO_INPUT_FLAGS=(-f alsa)
        ;;
    Darwin*)
        CAMERA_FORMAT="avfoundation"
        AUDIO_FORMAT="avfoundation"
        VIDEO_INPUT_FLAGS=(-f avfoundation -framerate "${CAMERA_FRAMERATE}")
        AUDIO_INPUT_FLAGS=(-f avfoundation)
        ;;
    MINGW*|CYGWIN*|MSYS*)
        CAMERA_FORMAT="dshow"
        AUDIO_FORMAT="dshow"
        VIDEO_INPUT_FLAGS=(-f dshow -framerate "${CAMERA_FRAMERATE}")
        AUDIO_INPUT_FLAGS=(-f dshow)
        ;;
    *)
        echo "[error] Unsupported OS: ${OS}"
        exit 1
        ;;
esac

echo "[stream] Starting DASH live stream"
echo "  Camera  : ${CAMERA_DEVICE} (${CAMERA_FORMAT})"
echo "  Audio   : $([ "${ENABLE_AUDIO}" = true ] && echo "${AUDIO_DEVICE}" || echo "disabled")"
echo "  Segment : ${SEGMENT_DURATION}s  |  GOP: ${GOP_SIZE}  |  Window: ${WINDOW_SIZE}"
echo "  Output  : ${OUTPUT_DIR}/${MANIFEST_NAME}"
echo ""

VIDEO_ENCODE_OPTS=(
    -c:v libx264
    -preset "${X264_PRESET}"
    -tune "${X264_TUNE}"
    -g "${GOP_SIZE}"
    -keyint_min "${GOP_SIZE}"
    -sc_threshold 0
    -profile:v baseline     
    -level 3.1
    -pix_fmt yuv420p
)

ABR_MAPS=(
    -map 0:v
    "${VIDEO_ENCODE_OPTS[@]}"
    -b:v:0 "${HIGH_BITRATE}" -maxrate:v:0 "${HIGH_MAXRATE}" -bufsize:v:0 "${HIGH_BUFSIZE}"
    -s:v:0 "${HIGH_RES}"

    -map 0:v
    "${VIDEO_ENCODE_OPTS[@]}"
    -b:v:1 "${MED_BITRATE}" -maxrate:v:1 "${MED_MAXRATE}" -bufsize:v:1 "${MED_BUFSIZE}"
    -s:v:1 "${MED_RES}"

    -map 0:v
    "${VIDEO_ENCODE_OPTS[@]}"
    -b:v:2 "${LOW_BITRATE}" -maxrate:v:2 "${LOW_MAXRATE}" -bufsize:v:2 "${LOW_BUFSIZE}"
    -s:v:2 "${LOW_RES}"
)


if [[ "${ENABLE_AUDIO}" == true ]]; then
    AUDIO_MAP=(-map 1:a -c:a aac -b:a "${AUDIO_BITRATE}" -ar "${AUDIO_SAMPLE_RATE}" -ac "${AUDIO_CHANNELS}")
    AUDIO_INPUT=("${AUDIO_INPUT_FLAGS[@]}" -i "${AUDIO_DEVICE}")
    ADAPTATION_SETS="id=0,streams=v id=1,streams=a"
else
    AUDIO_MAP=()
    AUDIO_INPUT=()
    ADAPTATION_SETS="id=0,streams=v"
fi


DASH_OPTS=(
    -f dash
    -seg_duration "${SEGMENT_DURATION}"
    -use_template 1
    -use_timeline 1
    -window_size "${WINDOW_SIZE}"
    -extra_window_size "${EXTRA_WINDOW_SIZE}"
    -remove_at_exit 0
    -update_period "${SEGMENT_DURATION}"
    -adaptation_sets "${ADAPTATION_SETS}"
    -dash_segment_type mp4
    -streaming 1
    -ldash 1          
    -target_latency "${SEGMENT_DURATION}"
)


CMD=(
    ffmpeg
    -loglevel info
    "${VIDEO_INPUT_FLAGS[@]}"
    -i "${CAMERA_DEVICE}"
    "${AUDIO_INPUT[@]}"
    "${ABR_MAPS[@]}"
    "${AUDIO_MAP[@]}"
    "${DASH_OPTS[@]}"
    "${OUTPUT_DIR}/${MANIFEST_NAME}"
)

echo $$ > "${LOG_DIR}/stream.pid"

echo "[stream] Running FFmpeg..."
echo "[stream] Press Ctrl+C to stop."
echo ""


exec "${CMD[@]}" 2> >(tee "${LOG_DIR}/ffmpeg_$(date +%Y%m%d_%H%M%S).log" >&2)
