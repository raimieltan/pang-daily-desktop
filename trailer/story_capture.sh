#!/usr/bin/env bash
# Record one story beat with Godot's Movie Maker for the story trailer, then convert it to H.264.
#   trailer/story_capture.sh <beat> [story_capture.gd flags]   e.g. trailer/story_capture.sh s14 --length=30
#   trailer/story_capture.sh --probe-story                     play the whole story headless once, so
#                                                              the passes, the cut and the crash log exist
# 16:9 1920×1080 (the 9:16 cut is reframed in the edit). user:// is the trailer-only folder, so the
# story save used here is never the player's.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-/Users/sean/Downloads/Godot.app/Contents/MacOS/Godot}
beat=${1:?usage: trailer/story_capture.sh <beat>|--probe-story [flags]}; shift
size=${SIZE:-1920x1080}; base=${BASE:-1152x648}
[ -e override.cfg ] && { echo "override.cfg already exists; move it aside first" >&2; exit 1; }
trap 'rm -f override.cfg' EXIT
cat > override.cfg <<CFG
[display]
window/size/viewport_width=${base%x*}
window/size/viewport_height=${base#*x}
window/size/window_width_override=${size%x*}
window/size/window_height_override=${size#*x}
[editor]
movie_writer/mjpeg_quality=0.95
[application]
config/use_custom_user_dir=true
config/custom_user_dir_name="pang_daily_trailer"
CFG
if [ "$beat" = "--probe-story" ]; then
	"$GODOT" --headless --fixed-fps 120 --path . -s res://tests/probe_story.gd "$@"
	exit
fi
mkdir -p trailer/out/story && touch trailer/out/.gdignore
name=$beat
for a in "$@"; do
	case $a in --name=*) name=${a#--name=} ;; --clean) [ "$name" = "$beat" ] && name=${beat}_clean ;; esac
done
movie=trailer/out/story/$name.avi
"$GODOT" --path . --fixed-fps 60 --write-movie "$movie" -s res://trailer/story_capture.gd -- --beat="$beat" "$@" &
pid=$!
( sleep "${LIMIT:-3600}"; kill "$pid" 2>/dev/null ) >/dev/null 2>&1 &
watchdog=$!
wait "$pid" || true
kill "$watchdog" 2>/dev/null || true; wait "$watchdog" 2>/dev/null || true
ffmpeg -v error -y -i "$movie" -c:v libx264 -preset medium -crf 16 -g 12 -pix_fmt yuv420p \
	-c:a aac -b:a 192k -movflags +faststart "${movie%.avi}.mp4"
rm -f "$movie"
echo "wrote ${movie%.avi}.mp4"
