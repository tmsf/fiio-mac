# fiio-mac

Making the Mac's volume keys (and mute) work for a **FiiO BTR5** used as a USB DAC.

Out of the box macOS shows no volume slider for the BTR5 over USB, and in the one USB mode
where it does show one, the slider does nothing. This repo holds the working setup, the
how-to, the full investigation and the small CoreAudio/IOKit probes written along the way.

## TL;DR

- The BTR5 firmware **ignores host volume over USB in both of its USB modes**. This is by
  design (FiiO's FAQ says to set the computer to max and use the device buttons).
- The fix is a **software gain stage in front of the USB stream**: a virtual output device
  that applies volume/mute to the samples and forwards them to the BTR5.
- Working setup: **eqMac** as the virtual device, with the BTR5 in **USB 2.0 mode**.
  USB 2.0 mode is required: in USB 1.0 mode the BTR5 advertises a (dead) hardware volume
  control and eqMac forwards volume to it instead of attenuating in software.
- Open-source alternative that would also work: **Proxy Audio Device** (see
  [docs/alternatives.md](docs/alternatives.md)). **Background Music cannot work** for this.

Details and evidence: [docs/discovery.md](docs/discovery.md).

## Setup (how-to)

Tested on macOS 27.0.1 (build 26A434), Apple Silicon MacBook Pro, eqMac 1.9.2, BTR5 USB id
`2972:0047`.

1. **Put the BTR5 in USB 2.0 mode.** Hold the round button ~2 s to open the menu, go to
   `U-AUDIO`, pick `USB 2.0`. Then **unplug and replug the USB cable**: the mode only changes
   on re-enumeration. Verify:

   ```sh
   ioreg -p IOUSB -l -w0 | grep -A12 '+-o FiiO' | grep -E 'bcdDevice|bNumConfigurations'
   # USB 2.0 mode: "bcdDevice" = 46, "bNumConfigurations" = 2  (CoreAudio name "FiiO BTR5")
   # USB 1.0 mode: "bcdDevice" = 47, "bNumConfigurations" = 1  (CoreAudio name "FiiO BTR5 1.1")
   ```

2. **Install eqMac.**

   ```sh
   brew install --cask eqmac
   open -a eqMac          # first launch installs /Library/Audio/Plug-Ins/HAL/eqMac.driver (admin password)
   ```

3. **Route eqMac to the BTR5.** Pick "FiiO BTR5" in eqMac's output selector, or simply select
   the plain "FiiO BTR5" entry in the macOS Sound menu: eqMac takes it as the target and
   re-selects its own "FiiO BTR5 (eqMac)" device as default output within a second.

4. **Send alert sounds through eqMac too**, otherwise they bypass the volume control and play
   at full BTR5 volume. System Settings › Sound › Sound Effects › *Play sound effects through*
   → "FiiO BTR5 (eqMac)". Or from a shell after `make`:

   ```sh
   bin/setdefault EQMOutputCapture      # sets default output AND system-sounds output to eqMac's device
   ```

5. **Set the BTR5's own volume once** (device buttons) to a comfortable maximum, then leave it
   alone and use the Mac keys.

6. **Make eqMac start at login** (eqMac settings → *Launch on startup*, or System Settings ›
   General › Login Items). Without it, audio falls back to the raw BTR5 at full volume after a
   reboot.

7. **Optional:** disconnect the BTR5's Bluetooth while using it over USB (FiiO recommends it).
   macOS sometimes falls back to the Bluetooth "FiiO BTR5" after Core Audio restarts.

8. **Verify by ear:**

   ```sh
   make && tools/test_tones.sh     # 60 % tone, 10 % tone, then a muted one you should NOT hear
   ```

## Things to know day to day

- **Three "FiiO BTR5" entries in the Sound menu** are expected: Bluetooth, the raw USB device,
  and "FiiO BTR5 (eqMac)". The raw one cannot be hidden: CoreAudio's `IsHidden` flag is owned
  by Apple's USB audio driver and is read-only (`bin/hidden` demonstrates this). Clicking the
  raw entry is harmless, eqMac re-selects itself. Only the Bluetooth entry can be removed, by
  disconnecting Bluetooth.
- **Volume keys stop working but mute still works** → the BTR5 is back in USB 1.0 mode (see
  step 1). This is the signature of eqMac forwarding volume to a hardware control.
- **Alerts suddenly at full volume** → the system-sounds output drifted to the raw BTR5
  (happens when a device is picked in the Sound menu or the BTR5 re-enumerates). Redo step 4.
- **No sound / volume ignored** → check System Settings › Sound shows "FiiO BTR5 (eqMac)" as
  output and that eqMac is running (`pgrep -fl eqMac`). `bin/running` shows which device is
  actually streaming (`runningSomewhere=1`).

## Tools

`make` builds everything into `bin/` (needs Xcode Command Line Tools).

| Tool | What it does |
| --- | --- |
| `bin/running` | Default output + system-sounds output, and for every output device: transport, whether it is streaming, main volume, per-channel dB and mute. |
| `bin/audioprops` | Per device: `VirtualMainVolume` presence/settability, per-channel volume/dB/mute controls, full list of control objects (`vlme`, `mute`, `clck`, …). |
| `bin/setdefault <UID>` | Sets both the default output and the system-sounds output to the device with that UID (eqMac's is `EQMOutputCapture`). |
| `bin/usbdesc` | Dumps and decodes the BTR5's USB configuration descriptors (UAC1 and UAC2 audio-class descriptors, feature units, formats, endpoints) via IOUSBLib. |
| `bin/usbreenum` | Asks the USB host to re-enumerate the BTR5 (`USBDeviceReEnumerate`). Does **not** switch USB modes, a physical replug is needed for that. |
| `bin/hidden` | Shows that `kAudioDevicePropertyIsHidden` exists but is not settable on the FiiO/eqMac devices. |
| `tools/test_tones.sh` | The 3-step audible test (60 % / 10 % / muted) through the default output device. |
| `tools/wait_and_probe.sh` | Waits for the BTR5 on USB, then dumps descriptors + CoreAudio controls. |
| `tools/wait_reenum.sh` | Waits for a true re-enumeration (new IORegistry id), then dumps the same. |
| `tools/wait_uac2.sh` | Waits for the BTR5 to come back in USB 2.0 mode, re-pins eqMac's device and runs the tone test. |
| `tools/make_tone.py` | Generates the 4 s / 440 Hz / 48 kHz stereo test tone (`bin/tone.wav`). |

Device UIDs seen on this machine: raw BTR5 `AppleUSBAudioEngine:FiiO:FiiO BTR5:1100000:1`
(the `1100000` part is the USB location id, it changes with the port), eqMac `EQMOutputCapture`.

## Repo layout

```
README.md            this file: setup and day-to-day notes
docs/discovery.md    the investigation: root cause, what was tried, why each thing did or did not work
docs/alternatives.md eqMac vs Background Music vs Proxy Audio Device vs SoundSource (licenses, mechanics)
evidence/            raw probe output captured during the investigation (descriptor dumps, CoreAudio state)
tools/src/           probe sources (Swift: CoreAudio; C: IOKit/IOUSBLib)
tools/*.sh           watcher and test scripts
Makefile             builds tools into bin/ (gitignored)
```
