#!/usr/bin/env bash
set -euo pipefail
command -v python3 >/dev/null || { echo "Python 3 is required" >&2; exit 1; }
if ! command -v ffmpeg >/dev/null || ! command -v ffprobe >/dev/null; then
  command -v apt-get >/dev/null || { echo "Install FFmpeg and FFprobe in the environment image" >&2; exit 1; }
  if [ "$(id -u)" -eq 0 ]; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ffmpeg fonts-dejavu-core
  elif command -v sudo >/dev/null && sudo -n true 2>/dev/null; then
    sudo -n apt-get update
    sudo -n env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ffmpeg fonts-dejavu-core
  else
    echo "Install FFmpeg and fonts-dejavu-core in the environment image" >&2
    exit 1
  fi
fi
mkdir -p input output work
ffmpeg -hide_banner -encoders 2>/dev/null | grep -q libx264 || { echo "FFmpeg needs libx264" >&2; exit 1; }
ffmpeg -hide_banner -encoders 2>/dev/null | grep -q aac || { echo "FFmpeg needs AAC" >&2; exit 1; }
ffmpeg -hide_banner -filters 2>/dev/null | grep -q subtitles || { echo "FFmpeg needs subtitles/libass support" >&2; exit 1; }
echo "Ready: Python, FFmpeg/FFprobe, H.264, AAC, subtitles."
