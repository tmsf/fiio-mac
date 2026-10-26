#!/bin/bash
# Audible check that the Mac's volume and mute reach the headphones:
# plays a 4 s 440 Hz tone at 60%, then at 10%, then muted (should be silent), then restores 40% unmuted.
# Uses the *default output device*, i.e. whatever the volume keys control.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TONE="$ROOT/bin/tone.wav"
[ -f "$TONE" ] || { mkdir -p "$ROOT/bin"; python3 "$ROOT/tools/make_tone.py" "$TONE"; }
osascript -e 'set volume without output muted' -e 'set volume output volume 60'; echo "tone 1: 60%";    sleep 1.5; afplay "$TONE"
osascript -e 'set volume output volume 10';                                      echo "tone 2: 10%";    sleep 1.5; afplay "$TONE"
osascript -e 'set volume with output muted';                                     echo "tone 3: muted";  sleep 1.5; afplay "$TONE"
osascript -e 'set volume without output muted' -e 'set volume output volume 40'
echo "restored: 40%, unmuted"; osascript -e 'get volume settings'
