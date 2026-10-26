#!/bin/bash
# Wait (up to 10 min) for the BTR5 to be present on USB, let the audio driver settle,
# then dump its USB descriptors, CoreAudio controls and IORegistry node.
source "$(dirname "$0")/_common.sh"
for i in $(seq 1 600); do
  if ioreg -p IOUSB -l -w0 2>/dev/null | grep -q '"idVendor" = 10610'; then
    echo "FiiO present after ${i}s; settling 4s"; sleep 4
    echo; echo "########## USB DESCRIPTORS ##########"; "$BIN/usbdesc"
    echo; echo "########## COREAUDIO CONTROLS ##########"; "$BIN/audioprops" | grep -A6 'FiiO.*usb'
    echo; echo "########## USB NODE ##########"; fiio_node_summary
    exit 0
  fi
  sleep 1
done
echo "TIMEOUT: FiiO not seen on USB within 10 minutes"; exit 2
