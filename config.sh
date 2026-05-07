export CAMERA_DEVICE="video=HP HD Camera"
export CAMERA_FORMAT="v4l2"         
export CAMERA_RESOLUTION="1280x720"
export CAMERA_FRAMERATE="30"

export ENABLE_AUDIO=true
export AUDIO_DEVICE="default"        
export AUDIO_FORMAT="alsa"           
export AUDIO_SAMPLE_RATE="44100"
export AUDIO_CHANNELS="2"

# Output Paths 
export PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export OUTPUT_DIR="${PROJECT_ROOT}/dash_output"
export WEB_ROOT="${PROJECT_ROOT}/web"
export LOG_DIR="${PROJECT_ROOT}/logs"
export MANIFEST_NAME="manifest.mpd"

# DASH Streaming Parameters 
export SEGMENT_DURATION=4            
export WINDOW_SIZE=10                
export EXTRA_WINDOW_SIZE=10          

# Encoding Profiles (Adaptive Bitrate) 
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
export X264_PRESET="ultrafast"       
export X264_TUNE="zerolatency"       

# GOP size = framerate * segment_duration (keyframe every segment boundary)
export GOP_SIZE=$(( CAMERA_FRAMERATE * SEGMENT_DURATION ))

# HTTP Server 
export HTTP_PORT=8080
export SERVER_HOST="0.0.0.0"        

# Notification (motion detection) 
export MOTION_SENSITIVITY=0.02       
export SNAPSHOT_DIR="${OUTPUT_DIR}/snapshots"
