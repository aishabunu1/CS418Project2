# Video Surveillance over IP

## Quick Start

```
1. ./setup.sh                                 # verify deps, configure nginx
2. nginx -c nginx/nginx_configured.conf -p nginx/
3. ./scripts/start_stream.sh [2|4|6]         # start streaming
4. open http://localhost:8080/
```

## Files

```
surveillance_project/
├── config.sh                  ← ALL system-specific parameters (edit this)
├── setup.sh                   ← One-time setup & verification
├── scripts/
│   ├── start_stream.sh        ← FFmpeg: capture → encode → DASH
│   ├── stop_stream.sh         ← Stop FFmpeg gracefully
│   ├── motion_detect.sh       ← Server-side motion detection (optional)
│   └── measure_latency.sh     ← Benchmark 2/4/6s segment latencies
├── nginx/
│   └── nginx.conf             ← NGINX template (setup.sh patches paths)
├── web/
│   └── index.html             ← HTML5 DASH player (no plugins)
├── dash_output/               ← FFmpeg writes segments here (auto-created)
├── logs/                      ← FFmpeg + NGINX logs (auto-created)
└── report/
    └── report.md              ← Full technical report
```

## Requirements

- FFmpeg (with libx264 + aac): `sudo apt install ffmpeg`
- NGINX: `sudo apt install nginx`
- Python 3 (for motion alerts JSON): usually pre-installed

## Configuration

Edit `config.sh` before running. Key settings:

```bash
CAMERA_DEVICE="/dev/video0"    # Your webcam device
CAMERA_FORMAT="v4l2"           # v4l2 | avfoundation | dshow
ENABLE_AUDIO=true              # Include microphone
SEGMENT_DURATION=4             # 2, 4, or 6 seconds
HTTP_PORT=8080                 # NGINX listen port
```

## Controls

| Key | Action |
|-----|--------|
| Space | Play / Pause |
| L | Jump to live edge |
| ← | Rewind 10 seconds |
| S | Save screenshot |
| F | Toggle fullscreen |

All controls also available via the on-screen UI (hover over video).
