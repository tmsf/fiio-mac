#!/bin/bash
# Fire only when the BTR5 re-appears with a NEW IORegistry entry id (a true re-enumeration,
# e.g. after a replug), then dump descriptors + CoreAudio controls. Times out after 10 min.
source "$(dirname "$0")/_common.sh"
getid() { fiio_node | grep -m1 -oE 'id 0x[0-9a-f]+'; }
orig=$(getid); echo "original registry id: ${orig:-none}"
gone=0
for i in $(seq 1 600); do
  cur=$(getid)
  [ -z "$cur" ] && gone=1
  if [ -n "$cur" ] && { [ "$cur" != "$orig" ] || [ $gone = 1 ]; }; then
    echo "re-enumerated after ${i}s (new id $cur, was ${orig:-none}); settling 5s"; sleep 5
    echo; echo "########## USB NODE ##########"; fiio_node_summary
    echo; echo "########## USB DESCRIPTORS ##########"; "$BIN/usbdesc"
    echo; echo "########## COREAUDIO CONTROLS ##########"; "$BIN/audioprops" | grep -A6 'FiiO.*usb'
    echo; echo "########## osascript ##########"; osascript -e 'get volume settings'
    exit 0
  fi
  sleep 1
done
echo "TIMEOUT: no FiiO re-enumeration within 10 minutes"; exit 2
