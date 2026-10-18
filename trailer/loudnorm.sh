#!/usr/bin/env bash
# Two-pass loudness normalisation for platform delivery (-14 LUFS integrated, -1.5 dBTP), video copied.
#   trailer/loudnorm.sh in.mp4 out.mp4
set -euo pipefail
in=$1; out=$2
m=$(ffmpeg -hide_banner -i "$in" -af loudnorm=I=-14:TP=-1.5:LRA=11:print_format=json -f null - 2>&1 | sed -n '/^{/,/^}/p')
get() { python3 -c "import json,sys;print(json.loads(sys.stdin.read())['$1'])" <<<"$m"; }
ffmpeg -v error -y -i "$in" -c:v copy -c:a aac -b:a 256k -ar 48000 -movflags +faststart -af \
	"loudnorm=I=-14:TP=-1.5:LRA=11:measured_I=$(get input_i):measured_TP=$(get input_tp):measured_LRA=$(get input_lra):measured_thresh=$(get input_thresh):offset=$(get target_offset):linear=true" "$out"
echo "wrote $out"
