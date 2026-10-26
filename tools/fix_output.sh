#!/bin/bash
# Quirk fix: sound went quiet, volume keys ignored, or alerts at full volume.
# Re-points the proxy device at the USB BTR5 (it falls back to Bluetooth after Core Audio
# restarts) and makes "FiiO BTR5 (Proxy)" both the default output and the system-sounds output.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; BIN="$ROOT/bin"
[ -x "$BIN/padctl" ] && [ -x "$BIN/setdefault" ] && [ -x "$BIN/running" ] && [ -x "$BIN/audioprops" ] || { echo "run 'make' in $ROOT first" >&2; exit 1; }

echo "== before =="; "$BIN/running" | head -1

usb_uid=$("$BIN/audioprops" | sed -n 's/.*uid=\(AppleUSBAudioEngine:FiiO:.*\) outChans=.*/\1/p' | head -1)
[ -n "$usb_uid" ] || { echo "BTR5 not found on USB (is it plugged in?)" >&2; exit 1; }

target=$("$BIN/padctl" status | sed -n 's/^outputDevice UID: *\(.*\)   -> .*/\1/p')
if [ "$target" != "$usb_uid" ]; then
  echo "== proxy target is '$target', pointing it at the USB BTR5 =="
  "$BIN/padctl" set-output "$usb_uid" | head -1
fi

echo "== pin proxy device as default + system-sounds output =="
"$BIN/setdefault" ProxyAudioDevice_UID
sleep 2
echo "== after =="; "$BIN/running" | grep -E '^default|Proxy|\[usb|\[blue'
