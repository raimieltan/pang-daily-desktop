#!/usr/bin/env bash
# Render one trailer shot with Godot's Movie Maker, then convert it to H.264 for editing.
#   trailer/capture.sh <shot> [extra capture.gd flags]      e.g. trailer/capture.sh drift --car=dalagan_gsr
# Shots: battle drift intro daynight cars garage (see SHOTS in trailer/capture.gd).
# user:// points at a trailer-only folder (time-attack ghosts staged by `ta_best` live there, and the
# player's own records and settings are never read or written).
# Frame size and MJPEG quality come from a temporary override.cfg (Movie Maker reads them before
# any script runs); it is removed again on exit, so the game itself is never affected.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-/Users/sean/Downloads/Godot.app/Contents/MacOS/Godot}
shot=${1:?usage: trailer/capture.sh <shot> [flags]}; shift
case $shot in
	garage) size=2560x1440; base=1152x648 ;;   # landscape UI, zoomed into in the edit
	*) size=1080x1920; base=720x1280 ;;        # vertical; base size makes overlay text 1.5x
esac
size=${SIZE:-$size}; base=${BASE:-$base}
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
mkdir -p trailer/out && touch trailer/out/.gdignore   # keep Godot from importing captures
movie=${MOVIE-trailer/out/$shot.avi}
args=(--path . --fixed-fps 60)
[ -n "${HEADLESS:-}" ] && args+=(--headless)
[ -n "$movie" ] && args+=(--write-movie "$movie")
# Godot can hang on a script error instead of quitting: give each run a hard limit.
"$GODOT" "${args[@]}" -s res://trailer/capture.gd -- --trailer-shot="$shot" --out=res://trailer/out "$@" &
pid=$!
# Detached from stdout: a piped caller would otherwise wait out the sleep after Godot quits.
( sleep "${LIMIT:-900}"; kill "$pid" 2>/dev/null ) >/dev/null 2>&1 &
watchdog=$!
wait "$pid"
kill "$watchdog" 2>/dev/null || true; wait "$watchdog" 2>/dev/null || true
if [ -n "$movie" ]; then
	ffmpeg -v error -y -i "$movie" -c:v libx264 -preset slow -crf 15 -g 12 -pix_fmt yuv420p \
		-c:a aac -b:a 192k -movflags +faststart "${movie%.avi}.mp4"
	echo "wrote ${movie%.avi}.mp4"
fi
