# Discovery: why the Mac cannot control the BTR5's volume over USB, and what fixes it

Investigation done on 2026-10-26 on macOS 27.0.1 (build 26A434), Apple Silicon MacBook Pro.
Raw output of every probe referenced below is in [`../evidence`](../evidence).

## 1. Symptom

With the FiiO BTR5 connected over USB and selected as output, macOS shows no volume slider and
the volume keys do nothing:

```
$ osascript -e 'get volume settings'
output volume:missing value, input volume:50, alert volume:57, output muted:missing value
```

## 2. The device

- USB vendor `0x2972` (10610), product `0x0047` (71), product string "FiiO BTR5".
- Driven by Apple's stock USB audio class driver (`usbaudiod` / AppleUSBAudio). No FiiO driver
  is involved on macOS.
- Also paired over Bluetooth, which shows up as a second CoreAudio device "FiiO BTR5"
  (transport `blue`) with a working volume control (range −40…0 dB). macOS occasionally falls
  back to this device after `coreaudiod` restarts, which muddied a couple of tests.

## 3. USB 2.0 mode (the default): no volume control at all

`bin/usbdesc` ([evidence 01](../evidence/01-usb2-mode-initial-probe.txt),
[02](../evidence/02-usb2-mode-after-host-reenumerate.txt)):

- `bcdDevice 0x002E`, high speed, two byte-identical configurations, Audio Control interface
  protocol `0x20` (UAC2).
- Topology: `INPUT_TERMINAL id=2 (USB streaming)` → `OUTPUT_TERMINAL id=20 (speaker)`, clock
  source 41 behind clock selector 40. **There is no FEATURE_UNIT**, so the device offers no
  volume or mute control to the host. Formats: 32-bit and 16-bit PCM, plus a DSD-style raw
  format.
- CoreAudio therefore exposes only `clck/glob` and `evis/outp` control objects:
  `VirtualMainVolume: has=false`.

This is intentional on FiiO's side: their FAQ says to set the computer to maximum and use the
device's buttons.

## 4. USB 1.0 mode: a volume control that the firmware ignores

The BTR5 menu has `U-AUDIO → USB 1.0`. Switching it only takes effect after a **physical
replug** (the host-side `USBDeviceReEnumerate` in `bin/usbreenum` re-enumerated the device but
it came back in the same mode, evidence 02).

In USB 1.0 mode ([evidence 03](../evidence/03-usb1-mode-after-replug.txt)):

- `bcdDevice 0x002F`, full speed, one configuration, UAC1. CoreAudio names it "FiiO BTR5 1.1".
- `FEATURE_UNIT id=10` with **per-channel mute and volume** on channels 1 and 2 (none on the
  master channel). 24-bit PCM at 44.1/48/88.2/96 kHz only.
- CoreAudio exposes `VirtualMainVolume` (settable) plus `vlme`/`mute` on elements 1 and 2,
  range −127…0 dB. The slider appears and `osascript` reports a value.
- **Setting the volume is acknowledged and reads back** (e.g. 0.2014 for 20 %), but it has no
  audible effect: a test tone at −32 dB played at full device volume, and mute did nothing.
  Routing was double-checked with `bin/running` (only the USB device had `runningSomewhere=1`,
  the Bluetooth device was idle). A Head-Fi report of the same behaviour on Windows ("only the
  UP/DOWN buttons vary volume") matches.

So the firmware accepts the USB `SET_CUR` requests and stores the value, but never applies it
to the DAC's gain. There is nothing a host-side driver can do about that.

## 5. Conclusion: a software gain stage is needed

The only working approach is a virtual output device that applies volume and mute to the
audio samples itself and then forwards them to the BTR5. Two were tried, one more was assessed
([alternatives](alternatives.md)).

## 6. Background Music 0.5.0: cannot work by design

Installed from the Homebrew cask pkg. Result: the slider moved, and Background Music mirrored
its value onto the BTR5's (dead) hardware control, but all three test beeps, including the
"muted" one, were heard ([evidence 04](../evidence/04-background-music-installed-state.txt)).

The source explains it. `BGMDriver/BGMDriver/BGM_Device.cpp` says the main device "doesn't
apply volume to its audio because BGMApp changes the real output device's volume directly"
(only the separate UI-sounds device calls `SetWillApplyVolumeToAudio(true)`), and
`BGMApp/BGMApp/BGMDeviceControlsList.cpp` disables BGMDevice's own controls when the output
device has none. Feature requests for software volume on such devices have been open since
2018 (#176, #153, #196, #518, #866).

Uninstalled with the bundled `_uninstall-non-interactive.sh`. It left behind a hidden system
user `_BGMXPCHelper`; remove with `sudo dscl . -delete /Users/_BGMXPCHelper`.

## 7. eqMac 1.9.2: works, with one condition

`brew install --cask eqmac`, launched once to let it install its HAL driver. Its virtual device
"FiiO BTR5 (eqMac)" (UID `EQMOutputCapture`, range −96…0 dB, volume + mute) became default
output; `bin/setdefault EQMOutputCapture` also made it the system-sounds output.

First test (BTR5 still in USB 1.0 mode): **mute worked, volume did not.** The eqMac device's
own volume changed, and the BTR5's hardware volume followed it, but loudness stayed the same.

Cause, from eqMac's source (`native/app/Source/Audio/Volume/Volume.swift`, `gain` setter):

```swift
if (volumeSupported) {            // device.virtualMasterVolume(direction: .playback) != nil
  device.setVirtualMasterVolume(Float32(gain), direction: .playback)   // hardware control
} else {
  virtualVolume = gain            // software gain
}
mixer.outputVolume = Float(virtualVolume)
```

and in the `muted` setter mute is always software: `mixer.outputVolume = 0`. So eqMac only
attenuates in software when the output device has **no** hardware volume control. In USB 1.0
mode the BTR5 has one (that it ignores), so eqMac just forwarded the value. There is no eqMac
setting to force software volume.

Fix: switch the BTR5 back to **USB 2.0 mode** and replug. `tools/wait_uac2.sh` caught the
re-enumeration, confirmed the raw device now has no volume control, re-pinned eqMac's device as
default and system output and ran the tone test
([evidence 05](../evidence/05-eqmac-switch-back-to-usb2-and-tone-test.txt)). Verified by ear:
volume up/down and mute now work.

Side observations from that run:

- At the moment of re-enumeration eqMac briefly routed to the **Bluetooth** BTR5
  (`runningSomewhere=1` on the `blue` device) before settling on USB.
- The **system-sounds output drifted back to the raw USB device** during the switch and had to
  be re-pinned. Selecting any device in the Sound menu does the same: eqMac re-grabs the
  default output within a second but leaves the system-sounds output alone.

## 8. Can the raw "FiiO BTR5" entry be hidden? No

`bin/hidden` checks `kAudioDevicePropertyIsHidden` on the FiiO and eqMac devices: the property
exists, reads 0, and `AudioObjectSetPropertyData` fails with `'nope'`
(`kAudioHardwareUnsupportedOperationError`). The flag belongs to the driver (Apple's USB audio
driver, no override available), and the raw device must exist anyway because eqMac streams
into it. Only the Bluetooth entry can be removed, by disconnecting Bluetooth.

## 9. Final state

- BTR5 in USB 2.0 mode (32-bit, high speed), no hardware volume control exposed.
- eqMac running; "FiiO BTR5 (eqMac)" is default output and system-sounds output.
- Mac volume keys and mute control what comes out of the headphones.
