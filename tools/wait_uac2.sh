#!/bin/bash
# Wait (up to 15 min) for the BTR5 to come back in USB 2.0 / UAC2 mode (bNumConfigurations=2,
# bcdDevice=46), then probe, re-pin eqMac's device as default + system output, and play the
# 3-step audible test (60% / 10% / muted). Used when switching the BTR5 from USB 1.0 back to 2.0.
source "$(dirname "$0")/_common.sh"
for i in $(seq 1 900); do
  n=$(fiio_node)
  if echo "$n" | grep -q '"bNumConfigurations" = 2'; then
    echo "BTR5 back in USB 2.0 (UAC2) mode after ${i}s; settling 8s"; sleep 8
    echo; echo "########## USB NODE ##########"; echo "$n" | grep -E '\+-o |bcdDevice|USB Product Name|bNumConfigurations|"Device Speed"'
    echo; echo "########## eqMac processes ##########"; pgrep -fl 'eqMac' || echo "eqMac NOT running"
    echo; echo "########## devices before fix ##########"; "$BIN/running"
    echo; echo "########## BTR5 controls (expect NO volume) ##########"; "$BIN/audioprops" | grep -A6 'FiiO BTR5 *\[usb'
    echo; echo "########## ensure eqMac device is default + system output ##########"; "$BIN/setdefault" EQMOutputCapture
    sleep 2; "$BIN/running" | head -1
    echo; echo "########## audible test: 60% / 10% / muted ##########"; "$ROOT/tools/test_tones.sh"
    echo; echo "########## devices after test ##########"; "$BIN/running"
    exit 0
  fi
  sleep 1
done
echo "TIMEOUT: BTR5 did not re-appear in USB 2.0 mode within 15 minutes"; exit 2
