#!/bin/bash
# Quirk fix: pops or crackle through the proxy device. Raises the proxy's buffer (frames).
# usage: tools/fix_crackle.sh [frames]   (default 1024; driver default is 512, minimum 4)
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; BIN="$ROOT/bin"
[ -x "$BIN/padctl" ] || { echo "run 'make' in $ROOT first" >&2; exit 1; }
frames="${1:-1024}"
case "$frames" in ''|*[!0-9]*) echo "frames must be a number" >&2; exit 2;; esac
echo "== current =="; "$BIN/padctl" status | grep bufferFrameSize
"$BIN/padctl" set-buffer "$frames" | grep -E 'ok|failed|bufferFrameSize'
