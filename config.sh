#!/usr/bin/env bash
# =============================================================================
# config.sh — Central configuration for Video Surveillance over IP project
# All system-specific parameters live here. Never hard-code these elsewhere.
# =============================================================================

# --- Camera & Audio Devices --------------------------------------------------
# Linux (v4l2): typically /dev/video0
# macOS (avfoundation): "0" (first camera), list with: ffmpeg -f avfoundation -list_devices true -i ""
# Windows (dshow): "video=Integrated Camera", list with: ffmpeg -list_devices true -f dshow -i dummy
export CAMERA_DEVICE="video=HP HD Camera"
export CAMERA_FORMAT="v4l2"          # v4l2 | avfoundation | dshow
export CAMERA_RESOLUTION="1280x720"
export CAMERA_FRAMERATE="30"

# Audio (set ENABLE_AUDIO=false to disable)
export ENABLE_AUDIO=true
export AUDIO_DEVICE="default"        # Linux ALSA: "default" | macOS: ":0" | Windows: "audio=Microphone"
export AUDIO_FORMAT="alsa"           # alsa | avfoundation | dshow
export AUDIO_SAMPLE_RATE="44100"
export AUDIO_CHANNELS="2"

# --- Output Paths ------------------------------------------------------------
export PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export OUTPUT_DIR="${PROJECT_ROOT}/dash_output"
export WEB_ROOT="${PROJECT_ROOT}/web"
export LOG_DIR="${PROJECT_ROOT}/logs"
export MANIFEST_NAME="manifest.mpd"

# --- DASH Streaming Parameters -----------------------------------------------
export SEGMENT_DURATION=4            # Segment size in seconds (try 2, 4, 6)
export WINDOW_SIZE=10                # Number of live segments kept in playlist (visible to player)
export EXTRA_WINDOW_SIZE=65          # Extra segments kept on disk for time-shifting
                                     # 65 × 4s = 260s ≈ 4+ minutes of rewind buffer

# --- Encoding Profiles (Adaptive Bitrate) ------------------------------------
# High quality
export HIGH_RES="1280x720"
export HIGH_BITRATE="2000k"
export HIGH_MAXRATE="2500k"
export HIGH_BUFSIZE="5000k"

# Medium quality
export MED_RES="854x480"
export MED_BITRATE="800k"
export MED_MAXRATE="1000k"
export MED_BUFSIZE="2000k"

# Low quality
export LOW_RES="426x240"
export LOW_BITRATE="300k"
export LOW_MAXRATE="400k"
export LOW_BUFSIZE="800k"

# Audio
export AUDIO_BITRATE="128k"

# H.264 encoding settings
export X264_PRESET="ultrafast"       # ultrafast|superfast|veryfast|faster|fast
export X264_TUNE="zerolatency"       # Minimize encoder latency for live

# GOP size = framerate * segment_duration (keyframe every segment boundary)
export GOP_SIZE=$(( CAMERA_FRAMERATE * SEGMENT_DURATION ))

# --- HTTP Server -------------------------------------------------------------
export HTTP_PORT=8080
export SERVER_HOST="0.0.0.0"        # Bind to all interfaces for remote access

# --- Notification (motion detection) ----------------------------------------
export MOTION_SENSITIVITY=0.02       # Fraction of pixels changed to trigger alert
export SNAPSHOT_DIR="${OUTPUT_DIR}/snapshots"