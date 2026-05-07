SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

ALERT_FILE="${OUTPUT_DIR}/motion_alerts.json"
mkdir -p "${SNAPSHOT_DIR}" "${LOG_DIR}"

echo "[]" > "${ALERT_FILE}"

OS="$(uname -s)"
case "${OS}" in
    Linux*)  INPUT_FLAGS=(-f v4l2 -framerate 5 -video_size 640x360) ;;  
    Darwin*) INPUT_FLAGS=(-f avfoundation -framerate 5) ;;
    MINGW*)  INPUT_FLAGS=(-f dshow -framerate 5) ;;
esac

echo "[motion] Starting motion detection (sensitivity=${MOTION_SENSITIVITY})"
echo "[motion] Snapshots → ${SNAPSHOT_DIR}"
echo "[motion] Alerts    → ${ALERT_FILE}"

LAST_ALERT=0
MIN_ALERT_INTERVAL=3   

ffmpeg \
    "${INPUT_FLAGS[@]}" \
    -i "${CAMERA_DEVICE}" \
    -vf "select='gt(scene,${MOTION_SENSITIVITY})',metadata=print:file=-" \
    -vsync vfr \
    -frame_pts true \
    -f image2pipe \
    -vcodec mjpeg \
    - 2>"${LOG_DIR}/motion_detect.log" | \
while IFS= read -r -d $'\0' frame_data 2>/dev/null || true; do
    NOW=$(date +%s)
    if (( NOW - LAST_ALERT >= MIN_ALERT_INTERVAL )); then
        TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        SNAPSHOT_FILE="${SNAPSHOT_DIR}/motion_${NOW}.jpg"

        echo "${frame_data}" > "${SNAPSHOT_FILE}" 2>/dev/null || true

        ALERT="{\"time\":\"${TIMESTAMP}\",\"unix\":${NOW},\"snapshot\":\"snapshots/motion_${NOW}.jpg\"}"
        python3 -c "
import json, sys
try:
    alerts = json.load(open('${ALERT_FILE}'))
except: alerts = []
alerts.insert(0, json.loads(sys.argv[1]))
alerts = alerts[:50]  # Keep last 50 alerts
json.dump(alerts, open('${ALERT_FILE}','w'))
" "${ALERT}" 2>/dev/null || true

        echo "[motion] Alert at ${TIMESTAMP} → ${SNAPSHOT_FILE}"
        LAST_ALERT=${NOW}
    fi
done

motion_detect_ffmpeg() {
    ffmpeg \
        "${INPUT_FLAGS[@]}" \
        -i "${CAMERA_DEVICE}" \
        -vf "
            split=2[a][b];
            [a]select='gt(scene,${MOTION_SENSITIVITY})'[motion];
            [b]nullsink;
            [motion]scale=640:360
        " \
        -vsync vfr \
        -strftime 1 \
        "${SNAPSHOT_DIR}/motion_%Y%m%d_%H%M%S.jpg" \
        2>>"${LOG_DIR}/motion_detect.log" &
}
