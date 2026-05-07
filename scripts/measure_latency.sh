SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

RESULTS_FILE="${LOG_DIR}/latency_results.txt"
mkdir -p "${LOG_DIR}"

echo "============================================" | tee "${RESULTS_FILE}"
echo " Latency Measurement — $(date)"              | tee -a "${RESULTS_FILE}"
echo "============================================" | tee -a "${RESULTS_FILE}"

for SEG_DUR in 2 4 6; do
    echo ""
    echo "[measure] Testing segment duration: ${SEG_DUR}s"

    "${SCRIPT_DIR}/start_stream.sh" "${SEG_DUR}" &
    STREAM_PID=$!
    sleep $(( SEG_DUR * 3 + 2 ))   

    MPD_PATH="${OUTPUT_DIR}/${MANIFEST_NAME}"
    if [[ ! -f "${MPD_PATH}" ]]; then
        echo "  [error] MPD not found after ${SEG_DUR}s test" | tee -a "${RESULTS_FILE}"
        kill "${STREAM_PID}" 2>/dev/null; continue
    fi


    PUBLISH_TIME=$(grep -oP 'publishTime="\K[^"]+' "${MPD_PATH}" | tail -1 || echo "N/A")
    NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    echo "  Segment size    : ${SEG_DUR}s"                | tee -a "${RESULTS_FILE}"
    echo "  MPD publishTime : ${PUBLISH_TIME}"            | tee -a "${RESULTS_FILE}"
    echo "  Wall clock now  : ${NOW}"                     | tee -a "${RESULTS_FILE}"

    MIN_LATENCY_EST=$(echo "${SEG_DUR} + 0.5" | bc)
    MAX_LATENCY_EST=$(echo "${SEG_DUR} * 2 + 1" | bc)
    echo "  Estimated latency range: ${MIN_LATENCY_EST}s – ${MAX_LATENCY_EST}s" | tee -a "${RESULTS_FILE}"
    echo "--------------------------------------------" | tee -a "${RESULTS_FILE}"

    kill -INT "${STREAM_PID}" 2>/dev/null
    wait "${STREAM_PID}" 2>/dev/null || true
    sleep 1

    find "${OUTPUT_DIR}" -name "*.m4s" -o -name "*.mpd" 2>/dev/null | xargs rm -f 2>/dev/null || true
done

echo ""
echo "[measure] Results saved to ${RESULTS_FILE}"
