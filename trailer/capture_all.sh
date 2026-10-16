#!/usr/bin/env bash
# Render every trailer shot and the stills in one go (about 20 minutes on an M1).
set -euo pipefail
cd "$(dirname "$0")/.."
for shot in battle drift intro daynight cars garage; do
	echo "== $shot"
	trailer/capture.sh "$shot"
done
trailer/stills.sh drift 9.2,32.4,37.0
trailer/stills.sh battle 7.0,21.6
ls -la trailer/out
