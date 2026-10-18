#!/usr/bin/env bash
# Every take the story trailer cuts from (trailer/out/story/<name>.mp4 + .events.json).
# Each line: beat, then story_capture.gd flags. Needs the trailer probe save first:
#   trailer/story_capture.sh --probe-story     (or copy a finished user://story_probe.json into
#                                               ~/Library/Application Support/pang_daily_trailer/)
# ONLY=<name,…> re-takes just those names.
set -uo pipefail
cd "$(dirname "$0")/.."
A=--advance=3.0
takes=(
	"s00   --length=80 $A"
	"s00   --length=80 --clean --name=s00_clean"
	"s14   --length=32 $A"
	"s14   --length=32 --clean --name=s14_clean"
	"s15   --length=50 $A"
	"s01   --length=70 $A"
	"s01   --length=70 --clean --name=s01_clean"
	"s03   --length=110 $A"
	"s03   --length=110 --clean --name=s03_clean --cams=0:chase,25:bumper,45:far,70:chase,90:hood"
	"s04t  --length=50 $A"
	"s05   --length=140 $A"
	"s05   --length=140 --clean --name=s05_clean --cams=0:chase,30:bumper,55:far,85:hood,110:chase"
	"s16   --length=100 $A"
	"s17e  --length=60 $A"
	"s17e  --length=15 --clean --name=s17e_clean"
	"s06   --length=150 $A"
	"s06   --length=150 --clean --name=s06_clean --cams=0:chase,40:hood,80:far,110:bumper"
	"s20   --length=60 $A"
	"s20   --length=15 --clean --name=s20_clean"
	"s18   --length=130 $A"
	"s18   --length=60 --clean --name=s18_clean --cams=0:chase,20:bumper,40:far"
	"s19   --length=32 $A"
	"s07   --length=60 $A"
	"s08   --length=60 $A"
	"s08   --length=60 --clean --name=s08_clean --cams=0:chase,18:far,32:bumper,46:chase"
	"s09   --length=170 $A"
	"s13   --length=130 $A"
	"s13   --length=75 --clean --name=s13_clean"
	"s27   --length=40 $A"
)
for line in "${takes[@]}"; do
	read -r beat flags <<<"$line"
	name=$beat
	for f in $flags; do case $f in --name=*) name=${f#--name=} ;; esac; done
	if [ -n "${ONLY:-}" ] && [[ ",$ONLY," != *",$name,"* ]]; then continue; fi
	echo "=== $name ($beat $flags)"
	# shellcheck disable=SC2086
	trailer/story_capture.sh "$beat" $flags 2>&1 | grep -E "^t=|wrote|ERROR|SCRIPT ERROR" || echo "!!! $name failed"
done
