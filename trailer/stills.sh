#!/usr/bin/env bash
# Clean (HUD-free) PNG stills of a shot at 1080p and 4K, no movie:
#   trailer/stills.sh <shot> <t1,t2,…>     e.g. trailer/stills.sh drift 9.2,32.4
# Landscape framing; the shot's camera schedule runs as in the movie.
set -euo pipefail
cd "$(dirname "$0")/.."
shot=$1; times=$2
# 1080p straight from the window; 4K from an offscreen view (macOS caps windows at the display size).
MOVIE= SIZE=1920x1080 BASE=1152x648 trailer/capture.sh "$shot" --stills="$times"
MOVIE= SIZE=1920x1080 BASE=1152x648 trailer/capture.sh "$shot" --stills="$times" --still-size=3840x2160
